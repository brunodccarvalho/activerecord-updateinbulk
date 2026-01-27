# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module Relation
    def update_in_bulk(updates, values = nil, record_timestamps: nil, formulas: nil)
      unless limit_value.nil? && offset_value.nil? && order_values.empty? && group_values.empty? && having_clause.empty?
        raise NotImplementedError, "No support to update grouped or ordered relations (offset, limit, order, group, having clauses)"
      end

      conditions, assigns = Builder.normalize_updates(model, updates, values)
      return 0 if @none || conditions.empty?

      model.with_connection do |c|
        unless c.supports_values_tables?
          raise ArgumentError, "#{c.class} does not support VALUES table constructors"
        end

        arel = eager_loading? ? apply_join_dependency.arel : arel()
        arel.source.left = table

        values_table, join_conditions, set_assignments = Builder.new(
          self,
          c,
          conditions,
          assigns,
          record_timestamps:,
          formulas:
        ).build_arel
        arel = arel.join(values_table).on(*join_conditions)

        key = if model.composite_primary_key?
          primary_key.map { |pk| table[pk] }
        else
          table[primary_key]
        end
        stmt = arel.compile_update(set_assignments, key)
        c.update(stmt, "#{model} Update in Bulk").tap { reset }
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecord::UpdateInBulk::Relation)
