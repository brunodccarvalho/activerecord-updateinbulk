# frozen_string_literal: true

require "test_helper"

class ArelSqlite3Test < TestCase
  def setup
    skip unless sqlite?
    @connection = ActiveRecord::Base.connection
  end

  def test_arel_values_table_sql_with_default_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], default_columns(2))
    sql = to_sql(table)

    assert_equal "VALUES (1, 'one'), (2, 'two')", sql
  end

  def test_arel_values_table_sql_with_custom_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], %w[first second])
    sql = to_sql(table)

    assert_equal %{SELECT 1 "first", 'one' "second" UNION ALL VALUES (2, 'two')}, sql
  end

  def test_arel_values_table_sql_with_sql_literal_row
    table = Arel::Nodes::ValuesTable.new(:data, [[Arel.sql("CURRENT_TIMESTAMP"), 7]], %w[created_at count])
    sql = to_sql(table)

    assert_equal %{SELECT CURRENT_TIMESTAMP "created_at", 7 "count"}, sql
  end

  private
    def default_columns(width)
      @connection.values_table_default_column_names(width)
    end

    def to_sql(node)
      visitor = Arel::Visitors::SQLite.new(@connection)
      collector = Arel::Collectors::SQLString.new
      visitor.accept(node, collector).value
    end
end
