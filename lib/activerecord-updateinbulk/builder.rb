# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord::UpdateInBulk
  class Builder
    FORMULAS = %w[add subtract concat_append concat_prepend min max].freeze

    class << self
      attr_accessor :values_table_name

      # Normalize all input formats into separated format [conditions, assigns].
      def normalize_updates(model, updates, values = nil)
        conditions = []
        assigns = []

        if values # separated format
          unless updates.is_a?(Array) && values.is_a?(Array)
            raise ArgumentError, "Separated format expects arrays for conditions and values"
          end
          if updates.size != values.size
            raise ArgumentError, "Conditions and values must have the same length"
          end

          updates.each_with_index do |row_conditions, index|
            row_assigns = values[index]
            next if row_assigns.blank?
            conditions << normalize_conditions(model, row_conditions)
            assigns << row_assigns.stringify_keys
          end
        elsif updates.is_a?(Hash) # indexed format
          updates.each do |id, row_assigns|
            next if row_assigns.blank?
            conditions << normalize_conditions(model, id)
            assigns << row_assigns.stringify_keys
          end
        else # paired format
          updates.each do |(row_conditions, row_assigns)|
            next if row_assigns.blank?
            conditions << normalize_conditions(model, row_conditions)
            assigns << row_assigns.stringify_keys
          end
        end

        [conditions, assigns]
      end

      def apply_formula(formula, lhs, rhs, model)
        case formula
        when "add"
          lhs + rhs
        when "subtract"
          lhs - rhs
        when "concat_append"
          lhs.concat(rhs)
        when "concat_prepend"
          rhs.concat(lhs)
        when "min"
          lhs.least(rhs)
        when "max"
          lhs.greatest(rhs)
        when Proc
          node = apply_proc_formula(formula, lhs, rhs, model)
          unless Arel.arel_node?(node)
            raise ArgumentError, "Custom formula must return an Arel node"
          end
          node
        else
          rhs
        end
      end

      def apply_proc_formula(formula, lhs, rhs, model)
        case formula.arity
        when 2
          formula.call(lhs, rhs)
        when 3
          formula.call(lhs, rhs, model)
        else
          raise ArgumentError, "Custom formula must accept 2 or 3 arguments"
        end
      end

      private
        def normalize_conditions(model, conditions)
          if conditions.is_a?(Hash)
            conditions
          elsif model.composite_primary_key?
            primary_key_zip(model.primary_key, conditions)
          else
            { model.primary_key => primary_key_unwrap(conditions) }
          end.stringify_keys
        end

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
    self.values_table_name = "t"

    attr_reader :model, :connection

    def initialize(relation, connection, conditions, assigns, record_timestamps: nil, formulas: nil)
      @model, @connection = relation.model, connection
      @record_timestamps = record_timestamps.nil? ? model.record_timestamps : record_timestamps
      @conditions = conditions
      @assigns = assigns
      @formulas = normalize_formulas(formulas)

      resolve_attribute_aliases!
      resolve_read_and_write_keys!
      verify_read_and_write_keys!
      serialize_values!
      detect_constant_columns!
    end

    def build_arel
      values_table, bitmask_keys = build_values_table
      join_conditions = build_join_conditions(model.arel_table, values_table)
      set_assignments = build_set_assignments(model.arel_table, values_table, bitmask_keys)
      derived_table = typecast_values_table(values_table)

      [derived_table, join_conditions, set_assignments]
    end

    private
      attr_reader :read_keys, :write_keys, :constant_conditions, :constant_assigns

      def serialize_values!
        types = (read_keys | write_keys).index_with { |key| model.type_for_attribute(key) }
        @conditions.each do |row|
          row.each do |key, value|
            next if opaque_value?(value)
            row[key] = ActiveModel::Type::SerializeCastValue.serialize(type = types[key], type.cast(value))
          end
        end
        @assigns.each do |row|
          row.each do |key, value|
            next if opaque_value?(value)
            row[key] = ActiveModel::Type::SerializeCastValue.serialize(type = types[key], type.cast(value))
          end
        end
      end

      def detect_constant_columns!
        @constant_conditions = {}
        @constant_assigns = {}

        read_keys.each do |key|
          first = @conditions.first.fetch(key)
          @constant_conditions[key] = first if @conditions.all? { |c| !opaque_value?(v = c.fetch(key)) && v == first }
        end
        # We can't drop all the conditions columns
        @constant_conditions.delete(read_keys.first) if @constant_conditions.size == read_keys.size

        (write_keys - optional_keys).each do |key|
          next if @formulas.key?(key) # need to pass Arel::Attribute as argument to formula
          first = @assigns.first[key]
          @constant_assigns[key] = first if @assigns.all? { |a| !opaque_value?(v = a[key]) && v == first }
        end
      end

      def optional_keys
        @optional_keys ||= write_keys - @assigns.map(&:keys).reduce(write_keys, &:intersection)
      end

      def timestamp_keys
        @timestamp_keys ||= @record_timestamps ? model.timestamp_attributes_for_update_in_model.to_set - write_keys : Set.new
      end

      def build_values_table
        rows, bitmask_keys = serialize_values_rows
        append_bitmask_column(rows, bitmask_keys) unless bitmask_keys.empty?
        values_table = Arel::Nodes::ValuesTable.new(self.class.values_table_name, rows, connection.values_table_default_column_names(rows.first.size))
        [values_table, bitmask_keys]
      end

      def build_join_conditions(table, values_table)
        variable_index = 0
        read_keys.map do |key|
          if constant_conditions.key?(key)
            table[key].eq(Arel::Nodes::Casted.new(constant_conditions[key], table[key]))
          else
            condition = table[key].eq(values_table[variable_index])
            variable_index += 1
            condition
          end
        end
      end

      def build_set_assignments(table, values_table, bitmask_keys)
        column = read_keys.count { |k| !constant_conditions.key?(k) }

        bitmask_functions = bitmask_keys.index_with.with_index(1) do |key, index|
          Arel::Nodes::NamedFunction.new("SUBSTRING", [values_table[-1], index, 1])
        end

        set_assignments = write_keys.map do |key|
          formula = @formulas[key]
          lhs = table[key]

          if constant_assigns.key?(key)
            rhs = Arel::Nodes::Casted.new(constant_assigns[key], table[key])
          else
            rhs = values_table[column]
            column += 1
            rhs = self.class.apply_formula(formula, lhs, rhs, model) if formula
          end

          if function = bitmask_functions[key]
            rhs = Arel::Nodes::Case.new(function).when("1").then(rhs).else(table[key])
          elsif optional_keys.include?(key)
            rhs = table.coalesce(rhs, table[key])
          end
          [table[key], rhs]
        end

        if timestamp_keys.any?
          # Timestamp assignments precede data assignments to increase the
          # change MySQL will actually run them against the original data.
          set_assignments = timestamp_assignments(set_assignments) + set_assignments
        end

        set_assignments
      end

      def typecast_values_table(values_table)
        variable_keys = read_keys.reject { |k| constant_conditions.key?(k) } + write_keys.reject { |k| constant_assigns.key?(k) }
        columns_hash = model.columns_hash
        model_types = variable_keys.map! { |key| columns_hash.fetch(key) }
        connection.typecast_values_table(values_table, model_types).alias(self.class.values_table_name)
      end

      def serialize_values_rows
        bitmask_keys = Set.new

        rows = @conditions.each_with_index.map do |row_conditions, row_index|
          row_assigns = @assigns[row_index]
          row = []
          read_keys.each do |key|
            next if constant_conditions.key?(key)
            row << row_conditions[key]
          end
          write_keys.each do |key|
            next if constant_assigns.key?(key)
            next row << nil unless row_assigns.key?(key)
            value = row_assigns[key]
            bitmask_keys.add(key) if optional_keys.include?(key) && might_be_nil_value?(value)
            row << value
          end
          row
        end

        [rows, bitmask_keys]
      end

      def append_bitmask_column(rows, bitmask_keys)
        rows.each_with_index do |row, row_index|
          row_assigns = @assigns[row_index]
          bitmask = "0" * bitmask_keys.size
          bitmask_keys.each_with_index do |key, index|
            bitmask[index] = "1" if row_assigns.key?(key)
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

      # When you assign a value to NULL, we need to use a bitmask to distinguish
      # row in the values table from rows where the column is not to be assigned at all.
      def might_be_nil_value?(value)
        value.nil? || opaque_value?(value)
      end

      def opaque_value?(value)
        value.is_a?(Arel::Nodes::SqlLiteral) || value.is_a?(Arel::Nodes::BindParam)
      end

      def normalize_formulas(formulas)
        return {} if formulas.blank?

        normalized = formulas.to_h do |key, value|
          [key.to_s, value.is_a?(Proc) ? value : value.to_s]
        end
        invalid = normalized.values.reject { |v| v.is_a?(Proc) } - FORMULAS
        if invalid.any?
          raise ArgumentError, "Unknown formula: #{invalid.first.inspect}"
        end
        normalized
      end

      def resolve_attribute_aliases!
        return if model.attribute_aliases.empty?

        @conditions.each_with_index do |row_conditions, index|
          row_assigns = @assigns[index]
          row_conditions.transform_keys! { |attribute| model.attribute_alias(attribute) || attribute }
          row_assigns.transform_keys! { |attribute| model.attribute_alias(attribute) || attribute }
        end
      end

      def resolve_read_and_write_keys!
        @read_keys = @conditions.first.keys.to_set
        @write_keys = @assigns.flat_map(&:keys).to_set
      end

      def verify_read_and_write_keys!
        if @conditions.empty?
          raise ArgumentError, "Empty updates object"
        end
        if read_keys.empty?
          raise ArgumentError, "Empty conditions object"
        end
        if write_keys.empty?
          raise ArgumentError, "Empty values object"
        end

        @conditions.each_with_index do |row_conditions, index|
          row_assigns = @assigns[index]
          if row_conditions.each_value.any?(nil)
            raise NotImplementedError, "NULL condition values are not supported"
          end
          if row_assigns.blank?
            raise ArgumentError, "Empty values object"
          end
          if read_keys != row_conditions.keys.to_set
            raise ArgumentError, "All objects being updated must have the same condition keys"
          end
        end
        if @formulas.any?
          unknown_formula_key = (@formulas.keys.to_set - write_keys).first
          if unknown_formula_key
            raise ArgumentError, "Formula given for unknown column: #{unknown_formula_key}"
          end
        end

        columns = read_keys | write_keys
        unknown_column = (columns - model.columns_hash.keys).first
        raise ActiveRecord::UnknownAttributeError.new(model.new, unknown_column) if unknown_column
      end
  end
end
