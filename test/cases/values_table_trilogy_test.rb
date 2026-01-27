# frozen_string_literal: true

require "test_helper"

class ValuesTableTrilogyTest < TestCase
  def setup
    skip unless current_adapter?(:TrilogyAdapter)
    @connection = ActiveRecord::Base.connection
  end

  def test_values_table_sql_without_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]])
    sql = to_sql(table)

    expected = "SELECT 1 #{quote_column("column1")}, 'one' #{quote_column("column2")} UNION ALL VALUES #{row_prefix}(2, 'two')"
    assert_equal expected, sql
  end

  def test_values_table_sql_with_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], columns: %w[first second])
    sql = to_sql(table)

    expected = "SELECT 1 #{quote_column("first")}, 'one' #{quote_column("second")} UNION ALL VALUES #{row_prefix}(2, 'two')"
    assert_equal expected, sql
  end

  def test_values_table_sql_with_sql_literal_row
    table = Arel::Nodes::ValuesTable.new(:data, [[Arel.sql("CURRENT_TIMESTAMP"), 7]], columns: %w[created_at count])
    sql = to_sql(table)

    expected = "SELECT CURRENT_TIMESTAMP #{quote_column("created_at")}, 7 #{quote_column("count")}"
    assert_equal expected, sql
  end

  private
    def to_sql(node)
      visitor = Arel::Visitors::ToSql.new(@connection)
      collector = Arel::Collectors::SQLString.new
      visitor.accept(node, collector).value
    end

    def quote_column(name)
      @connection.quote_column_name(name)
    end

    def row_prefix
      @connection.values_table_row_prefix
    end
end
