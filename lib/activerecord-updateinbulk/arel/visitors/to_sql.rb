# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module ToSql
    def visit_Arel_Nodes_Least(o, collector)
      collector << "LEAST("
      inject_join(o.expressions, collector, ", ")
      collector << ")"
    end

    def visit_Arel_Nodes_Greatest(o, collector)
      collector << "GREATEST("
      inject_join(o.expressions, collector, ", ")
      collector << ")"
    end

    def visit_Arel_Nodes_ValuesTable(o, collector)
      row_prefix = @connection.values_table_row_prefix

      if !@connection.values_table_requires_aliasing? && o.columns == @connection.values_table_default_column_names(o.width)
        return build_values_table_constructor(o.rows, collector, row_prefix)
      end

      column_aliases = o.columns

      # Extract the first row into a handrolled SELECT and put the aliases there.
      collector << "SELECT "
      o.rows[0].each_with_index do |value, i|
        collector << ", " unless i == 0
        collector = build_values_table_single_value(value, collector)
        collector << " " << quote_column_name(column_aliases[i])
      end
      unless o.rows.size == 1
        collector << " UNION ALL "
        collector = build_values_table_constructor(o.rows[1...], collector, row_prefix)
      end
      collector
    end

    private
      def build_values_table_single_value(value, collector)
        case value
        when Arel::Nodes::SqlLiteral, Arel::Nodes::BoundSqlLiteral, Arel::Nodes::BindParam, ActiveModel::Attribute
          visit(value, collector)
        else
          collector << quote(value).to_s
        end
      end

      def build_values_table_constructor(rows, collector, row_prefix = "")
        collector << "VALUES "
        rows.each_with_index do |row, i|
          collector << ", " unless i == 0
          collector << row_prefix << "("
          row.each_with_index do |value, i|
            collector << ", " unless i == 0
            collector = build_values_table_single_value(value, collector)
          end
          collector << ")"
        end
        collector
      end
  end
end

Arel::Visitors::ToSql.prepend(ActiveRecord::UpdateInBulk::ToSql)
