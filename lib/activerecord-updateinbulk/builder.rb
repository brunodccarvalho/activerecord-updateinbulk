# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord::UpdateInBulk
  class Builder
    class << self
      # Normalize the input shape into a paired format.
      def normalize_updates(model, updates)
        if updates.is_a?(Hash) # indexed format
          if model.composite_primary_key?
            updates.map { |id, assigns| [primary_key_zip(model.primary_key, id), assigns] }
          else
            updates.map { |id, assigns| [{ model.primary_key => primary_key_unwrap(id) }, assigns] }
          end
        else
          updates
        end.filter_map do |(conditions, assigns)|
          # Drop rows with blank assigns; stringify keys for consistent downstream handling.
          [conditions.stringify_keys, assigns.stringify_keys] unless assigns.blank?
        end
      end

      private
        def primary_key_zip(keys, values)
          unless values.is_a?(Array)
            raise ArgumentError, "Model has composite primary key, but a condition key given is not an array"
          end
          if keys.size != values.size
            raise ArgumentError, "Model primary key has length #{keys.size}, but condition key given has length #{values.size}"
          end
          keys.zip(values).to_h
        end

        def primary_key_unwrap(value)
          if !value.is_a?(Array)
            value
          elsif value.size == 1
            value.first
          else
            raise ArgumentError, "Expected a single value, but got #{value.inspect}"
          end
        end
    end

    attr_reader :model, :connection

    def initialize(relation, connection, updates, record_timestamps: nil)
      @model, @connection = relation.model, connection
      @record_timestamps = record_timestamps.nil? ? model.record_timestamps : record_timestamps
      @updates = self.class.normalize_updates(@model, updates)

      resolve_attribute_aliases!
      resolve_read_and_write_keys!
      verify_read_and_write_keys!
    end

    def build_arel
      types = (read_keys | write_keys).index_with { |key| model.type_for_attribute(key) }

      rows = serialize_values_rows do |key, value|
        next value if Arel::Nodes::SqlLiteral === value
        ActiveModel::Type::SerializeCastValue.serialize(type = types[key], type.cast(value))
      end
      append_bitmask_column(rows) unless bitmask_keys.empty?

      values_table = Arel::Nodes::ValuesTable.new("__active_record_bulk", rows)

      bitmask_functions = bitmask_keys.index_with.with_index(1) do |key, index|
        Arel::Nodes::NamedFunction.new("SUBSTRING", [values_table[-1], index, 1])
      end

      join_conditions = read_keys.map.with_index do |key, index|
        model.arel_table[key].eq(values_table[index])
      end
      set_assignments = write_keys.map.with_index do |key, index|
        rhs = values_table[index + read_keys.size]
        if function = bitmask_functions[key]
          rhs = Arel::Nodes::Case.new(function).when("1").then(rhs).else(model.arel_table[key])
        elsif optional_keys.include?(key)
          rhs = model.arel_table.coalesce(rhs, model.arel_table[key])
        end
        [model.arel_table[key], rhs]
      end
      set_assignments += timestamp_assignments(set_assignments) if timestamp_keys.any?

      model_types = read_keys.to_a.concat(write_keys.to_a).map! { |key| columns_hash.fetch(key) }
      derived_table = connection.typecast_values_table(values_table, model_types).alias("__active_record_bulk")

      [derived_table, join_conditions, set_assignments]
    end

    private
      attr_reader :read_keys, :write_keys, :bitmask_keys

      def columns_hash
        @columns_hash ||= model.columns_hash
      end

      def optional_keys
        @optional_keys ||= write_keys - @updates.map(&:second).map!(&:keys).reduce(write_keys, &:intersection)
      end

      def timestamp_keys
        @timestamp_keys ||= @record_timestamps ? model.timestamp_attributes_for_update_in_model.to_set - write_keys : Set.new
      end

      def resolve_attribute_aliases!
        return if model.attribute_aliases.empty?

        @updates.each do |(conditions, assigns)|
          conditions.transform_keys! { |attribute| model.attribute_alias(attribute) || attribute }
          assigns.transform_keys! { |attribute| model.attribute_alias(attribute) || attribute }
        end
      end

      def resolve_read_and_write_keys!
        @read_keys = @updates.first[0].keys.to_set
        @write_keys = @updates.map(&:second).flat_map(&:keys).to_set
      end

      def verify_read_and_write_keys!
        if @updates.empty?
          raise ArgumentError, "Empty updates object"
        end
        if read_keys.empty?
          raise ArgumentError, "Empty conditions object"
        end
        if write_keys.empty?
          raise ArgumentError, "Empty values object"
        end

        @updates.each do |(conditions, assigns)|
          if conditions.each_value.any?(nil)
            raise NotImplementedError, "NULL condition values are not supported"
          end
          if assigns.blank?
            raise ArgumentError, "Empty values object"
          end
          if read_keys != conditions.keys.to_set
            raise ArgumentError, "All objects being updated must have the same condition keys"
          end
        end

        columns = read_keys | write_keys
        unknown_column = (columns - @model.columns_hash.keys).first
        raise ActiveRecord::UnknownAttributeError.new(model.new, unknown_column) if unknown_column
      end

      def serialize_values_rows
        @bitmask_keys = Set.new

        @updates.map do |(conditions, assigns)|
          condition_values = read_keys.map do |key|
            yield(key, conditions[key])
          end
          write_values = write_keys.map do |key|
            next unless assigns.key?(key)
            value = yield(key, assigns[key])
            @bitmask_keys.add(key) if optional_keys.include?(key) && might_be_nil_value?(value)
            value
          end
          condition_values.concat(write_values)
        end
      end

      def append_bitmask_column(rows)
        rows.each_with_index do |row, row_index|
          assigns = @updates[row_index][1]
          bitmask = "0" * bitmask_keys.size
          bitmask_keys.each_with_index do |key, index|
            bitmask[index] = "1" if assigns.key?(key)
          end
          row.push(bitmask)
        end
      end

      def timestamp_assignments(set_assignments)
        case_conditions = set_assignments.map do |left, right|
          left.is_not_distinct_from(right)
        end

        timestamp_keys.map do |key|
          case_assignment = Arel::Nodes::Case.new.when(Arel::Nodes::And.new(case_conditions))
                                             .then(model.arel_table[key])
                                             .else(connection.high_precision_current_timestamp)
          [model.arel_table[key], Arel::Nodes::Grouping.new(case_assignment)]
        end
      end

      def might_be_nil_value?(value)
        case value
        when Arel::Nodes::SqlLiteral, Arel::Nodes::BindParam, ActiveModel::Attribute, nil then true
        when String, Symbol, Numeric, BigDecimal, Date, Time, true, false then false
        else true
        end
      end
  end
end
