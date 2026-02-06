# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord::UpdateInBulk
  class Builder
    FORMULAS = [:add, :subtract, :concat_append, :concat_prepend, :min, :max].freeze
    SAFE_COMPARISON_TYPES = [:boolean, :string, :text, :integer, :float, :decimal].freeze

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
        formula = formula.to_sym if formula.is_a?(String)
        case formula
        when :add
          lhs + rhs
        when :subtract
          lhs - rhs
        when :concat_append
          lhs.concat(rhs)
        when :concat_prepend
          rhs.concat(lhs)
        when :min
          lhs.least(rhs)
        when :max
          lhs.greatest(rhs)
        when Proc
          node = apply_proc_formula(formula, lhs, rhs, model)
          unless Arel.arel_node?(node)
            raise ArgumentError, "Custom formula must return an Arel node"
          end
          node
        else
          raise ArgumentError, "Unknown formula: #{formula.inspect}"
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
      unless simple_update?
        detect_constant_columns!
        serialize_values!
      end
    end

    def build_arel
      table = model.arel_table
      values_table, bitmask_keys = build_values_table unless simple_update?
      conditions = build_conditions(table, values_table)
      set_assignments = build_set_assignments(table, values_table, bitmask_keys || Set.new)
      derived_table = typecast_values_table(values_table) if values_table

      [derived_table, conditions, set_assignments]
    end

    private
      attr_reader :read_keys, :write_keys, :constant_assigns

      def optional_keys
        @optional_keys ||= write_keys - @assigns.map(&:keys).reduce(write_keys, &:intersection)
      end

      def timestamp_keys
        @timestamp_keys ||= @record_timestamps ? model.timestamp_attributes_for_update_in_model.to_set - write_keys : Set.new
      end

      def simple_update?
        @conditions.size == 1 && @formulas.empty?
      end

      def build_simple_conditions(table)
        row_conditions = @conditions.first
        read_keys.map do |key|
          table[key].eq(cast_for_column(row_conditions.fetch(key), table[key]))
        end
      end

      def build_simple_assignments(table)
        row_assigns = @assigns.first
        write_keys.map do |key|
          [table[key], cast_for_column(row_assigns.fetch(key), table[key])]
        end
      end

      def detect_constant_columns!
        @constant_assigns = {}
        columns_hash = model.columns_hash

        (write_keys - optional_keys).each do |key|
          next if @formulas.key?(key) # need to pass Arel::Attribute as argument to formula
          next unless SAFE_COMPARISON_TYPES.include?(columns_hash.fetch(key).type)
          first = @assigns.first[key]
          @constant_assigns[key] = first if @assigns.all? { |a| !opaque_value?(v = a[key]) && v == first }
        end
      end

      def serialize_values!
        types = read_keys.index_with { |key| model.type_for_attribute(key) }
        @conditions.each do |row|
          row.each do |key, value|
            next if opaque_value?(value)
            row[key] = ActiveModel::Type::SerializeCastValue.serialize(type = types[key], type.cast(value))
          end
        end
        types = write_keys.index_with { |key| model.type_for_attribute(key) }
        @assigns.each do |row|
          row.each do |key, value|
            next if opaque_value?(value) || constant_assigns.key?(key)
            row[key] = ActiveModel::Type::SerializeCastValue.serialize(type = types[key], type.cast(value))
          end
        end
      end

      def build_values_table
        rows, bitmask_keys = build_values_table_rows
        append_bitmask_column(rows, bitmask_keys) unless bitmask_keys.empty?
        column_names = connection.values_table_default_column_names(rows.first.size)
        values_table = Arel::Nodes::ValuesTable.new(self.class.values_table_name, rows, column_names)
        [values_table, bitmask_keys]
      end

      def build_values_table_rows
        bitmask_keys = Set.new
        non_constant_write_keys = write_keys - constant_assigns.keys

        rows = @conditions.map.with_index do |row_conditions, row_index|
          row_assigns = @assigns[row_index]
          row = row_conditions.fetch_values(*read_keys)
          non_constant_write_keys.each do |key|
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

      def build_conditions(table, values_table)
        return build_simple_conditions(table) unless values_table

        read_keys.map.with_index do |key, index|
          table[key].eq(values_table[index])
        end
      end

      def build_set_assignments(table, values_table, bitmask_keys)
        set_assignments = if values_table
          build_join_assignments(table, values_table, bitmask_keys)
        else
          build_simple_assignments(table)
        end

        if timestamp_keys.any?
          # Timestamp assignments precede data assignments to increase the
          # chance MySQL will actually run them against the original data.
          set_assignments = timestamp_assignments(set_assignments) + set_assignments
        end

        set_assignments
      end

      def build_join_assignments(table, values_table, bitmask_keys)
        column = read_keys.size

        bitmask_functions = bitmask_keys.index_with.with_index(1) do |key, index|
          Arel::Nodes::NamedFunction.new("SUBSTRING", [values_table[-1], index, 1])
        end

        write_keys.map do |key|
          formula = @formulas[key]
          lhs = table[key]

          if constant_assigns.key?(key)
            rhs = Arel::Nodes::Casted.new(constant_assigns[key], lhs)
          else
            rhs = values_table[column]
            column += 1
            rhs = self.class.apply_formula(formula, lhs, rhs, model) if formula
          end

          if function = bitmask_functions[key]
            rhs = Arel::Nodes::Case.new(function).when("1").then(rhs).else(lhs)
          elsif optional_keys.include?(key)
            rhs = table.coalesce(rhs, lhs)
          end
          [lhs, rhs]
        end
      end

      def typecast_values_table(values_table)
        variable_keys = read_keys + write_keys.reject { |k| constant_assigns.key?(k) }
        columns_hash = model.columns_hash
        model_types = variable_keys.map! { |key| columns_hash.fetch(key) }
        connection.typecast_values_table(values_table, model_types).alias(self.class.values_table_name)
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

      # When you assign a value to NULL, we need to use a bitmask to distinguish that
      # row in the values table from rows where the column is not to be assigned at all.
      def might_be_nil_value?(value)
        value.nil? || opaque_value?(value)
      end

      def opaque_value?(value)
        Arel.arel_node?(value)
      end

      def cast_for_column(value, column)
        opaque_value?(value) ? value : Arel::Nodes::Casted.new(value, column)
      end

      def normalize_formulas(formulas)
        return {} if formulas.blank?

        normalized = formulas.to_h do |key, value|
          [key.to_s, value.is_a?(Proc) ? value : value.to_sym]
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
        @write_keys = @assigns.reduce(Set.new) { |set, row| set.merge(row.keys) }
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
