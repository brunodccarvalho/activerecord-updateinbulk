# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module Relation
    def update_in_bulk(updates, record_timestamps: nil)
      updates = ::ActiveRecord::UpdateInBulk::Builder.normalize_updates(model, updates)
      return 0 if @none || updates.empty?

      unless limit_value.nil? && offset_value.nil? && order_values.empty? && group_values.empty? && having_clause.empty?
        raise NotImplementedError, "No support to update grouped or ordered relations (offset, limit, order, group, having clauses)"
      end

      model.with_connection do |c|
        unless c.supports_values_tables?
          raise ArgumentError, "#{c.class} does not support VALUES table constructors"
        end

        arel = eager_loading? ? apply_join_dependency.arel : arel()
        arel.source.left = table

        values_table, join_conditions, set_assignments = ::ActiveRecord::UpdateInBulk::Builder.new(self, c, updates, record_timestamps:).build_arel
        arel = arel.join(values_table).on(*join_conditions)

        key = if model.composite_primary_key?
          primary_key.map { |pk| table[pk] }
        else
          table[primary_key]
        end
        stmt = arel.compile_update(set_assignments, key)
        c.update(stmt, "#{model} Update Bulk").tap { reset }
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecord::UpdateInBulk::Relation)
