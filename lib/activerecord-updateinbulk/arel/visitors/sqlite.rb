# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module SQLiteToSql
    private
      def visit_Arel_Nodes_Least(o, collector)
        collector << "MIN("
        inject_join(o.expressions, collector, ", ")
        collector << ")"
      end

      def visit_Arel_Nodes_Greatest(o, collector)
        collector << "MAX("
        inject_join(o.expressions, collector, ", ")
        collector << ")"
      end
  end
end

Arel::Visitors::SQLite.prepend(ActiveRecord::UpdateInBulk::SQLiteToSql)
