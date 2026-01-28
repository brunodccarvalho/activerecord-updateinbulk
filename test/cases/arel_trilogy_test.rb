# frozen_string_literal: true

require "test_helper"

class ArelTrilogyTest < TestCase
  def setup
    skip unless current_adapter?(:TrilogyAdapter)
    @connection = ActiveRecord::Base.connection
  end

  def test_values_table_sql_with_default_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], default_columns(2))
    sql = to_sql(table)

    if @connection.values_table_requires_aliasing?
      # MariaDB: native column names are unknown, aliasing always required
      expected = "SELECT 1 #{q(default_columns(2)[0])}, 'one' #{q(default_columns(2)[1])} UNION ALL VALUES (2, 'two')"
    else
      # MySQL: native column names match defaults, bare VALUES emitted
      expected = "VALUES #{row_prefix}(1, 'one'), #{row_prefix}(2, 'two')"
    end
    assert_equal expected, sql
  end

  def test_values_table_sql_with_custom_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], %w[first second])
    sql = to_sql(table)

    expected = "SELECT 1 #{q("first")}, 'one' #{q("second")} UNION ALL VALUES #{row_prefix}(2, 'two')"
    assert_equal expected, sql
  end

  def test_values_table_sql_with_sql_literal_row
    table = Arel::Nodes::ValuesTable.new(:data, [[Arel.sql("CURRENT_TIMESTAMP"), 7]], %w[created_at count])
    sql = to_sql(table)

    expected = "SELECT CURRENT_TIMESTAMP #{q("created_at")}, 7 #{q("count")}"
    assert_equal expected, sql
  end

  def test_least_sql
    books = Book.arel_table
    node = Arel::Nodes::Least.new([books[:id], books[:pages]])
    sql = to_sql(node)

    expected = "LEAST(#{q("books")}.#{q("id")}, #{q("books")}.#{q("pages")})"
    assert_equal expected, sql
  end

  def test_greatest_sql
    books = Book.arel_table
    node = Arel::Nodes::Greatest.new([books[:id], books[:pages]])
    sql = to_sql(node)

    expected = "GREATEST(#{q("books")}.#{q("id")}, #{q("books")}.#{q("pages")})"
    assert_equal expected, sql
  end

  def test_least_with_literal_and_attribute
    books = Book.arel_table
    node = Arel::Nodes::Least.new([1000, books[:pages]])
    sql = to_sql(node)

    expected = "LEAST(1000, #{q("books")}.#{q("pages")})"
    assert_equal expected, sql
  end

  private
    def default_columns(width)
      @connection.values_table_default_column_names(width)
    end

    def q(name)
      @connection.quote_column_name(name)
    end

    def to_sql(node)
      visitor = Arel::Visitors::ToSql.new(@connection)
      collector = Arel::Collectors::SQLString.new
      visitor.accept(node, collector).value
    end

    def row_prefix
      @connection.values_table_row_prefix
    end
end
