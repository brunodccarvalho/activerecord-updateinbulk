# frozen_string_literal: true

require "test_helper"
require "models"

class ValuesTableTest < TestCase
  fixtures :books

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_values_table_columns
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], default_columns(2))

    assert_equal default_columns(2), table.columns
  end

  def test_values_table_columns_explicit
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], %w[first second])

    assert_equal ["first", "second"], table.columns
  end

  def test_values_table_attribute_lookup_by_index_and_symbol
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], default_columns(2))

    assert_equal default_columns(2)[0], table[0].name
    assert_equal default_columns(2)[1], table[1].name
    assert_equal default_columns(2)[0], table[default_columns(2)[0].to_sym].name
    assert_equal default_columns(2)[0], table[default_columns(2)[0]].name
  end

  def test_values_table_attribute_lookup_uses_aliases
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], %w[first second])

    assert_equal "first", table[0].name
    assert_equal "second", table[1].name
    assert_equal "first", table[:first].name
    assert_equal "first", table["first"].name
  end

  def test_arel_values_table_default_column_names
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], default_columns(2))
    result = exec_query(table.from.project(Arel.star))

    assert_equal default_columns(2), result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_arel_values_table_supports_aliases
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], %w[alias1 alias2])
    result = exec_query(table.from.project(Arel.star))

    assert_equal ["alias1", "alias2"], result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_values_table_cte_plain
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], default_columns(2))
    query = Arel::SelectManager.new.with(table.to_cte).from("data").project(Arel.star)
    result = exec_query(query)

    assert_equal default_columns(2), result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_values_table_cte_with_aliases
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], %w[alias1 alias2])
    query = Arel::SelectManager.new.with(table.to_cte).from("data").project(Arel.star)
    result = exec_query(query)

    assert_equal ["alias1", "alias2"], result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_values_table_alias_in_join
    columns = default_columns(2)
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "One"], [2, "Two"], [3, "Three"]], columns)
    aliased = table.alias("data")
    books = Book.arel_table

    query = books.project(books[:id], table[1, aliased].as("label"))
                 .join(aliased).on(books[:id].eq(table[0, aliased]))
                 .where(books[:id].in([1, 2, 4]))

    result = exec_query(query)
    assert_equal ["id", "label"], result.columns
    assert_equal [[1, "One"], [2, "Two"]], result.rows
  end

  def test_values_table_from_without_alias
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], default_columns(2))
    sql = to_sql(table.from(nil).project(Arel.star))

    assert_equal skips_aliasing_for_defaults?, sql.include?("VALUES")
    assert_no_match(/\sdata\b/, sql)
  end

  def test_values_table_equality_and_hash
    columns = default_columns(2)
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], columns)
    table2 = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], columns)
    table3 = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], %w[alias1 alias2])

    assert_equal table, table2
    assert_equal table.hash, table2.hash
    assert_not_equal table, table3
  end

  def test_least_sql
    books = Book.arel_table
    node = Arel::Nodes::Least.new([books[:id], books[:pages]])
    sql = to_sql(node)

    assert_equal "LEAST(#{q("books.id")}, #{q("books.pages")})", sql
  end

  def test_greatest_sql
    books = Book.arel_table
    node = Arel::Nodes::Greatest.new([books[:id], books[:pages]])
    sql = to_sql(node)

    assert_equal "GREATEST(#{q("books.id")}, #{q("books.pages")})", sql
  end

  def test_least_with_literal_and_attribute
    books = Book.arel_table
    node = Arel::Nodes::Least.new([1000, books[:pages]])
    sql = to_sql(node)

    assert_equal "LEAST(1000, #{q("books.pages")})", sql
  end

  private
    def exec_query(node)
      @connection.exec_query(unwrap_sql(to_sql(node)))
    end

    def to_sql(node)
      visitor = Arel::Visitors::ToSql.new(@connection)
      collector = Arel::Collectors::SQLString.new
      visitor.accept(node, collector).value
    end

    def unwrap_sql(sql)
      return sql unless sql.start_with?("(") && sql.end_with?(")")
      sql[1..-2]
    end

    def default_columns(width)
      @connection.values_table_default_column_names(width)
    end

    def skips_aliasing_for_defaults?
      !@connection.values_table_requires_aliasing?
    end

    def q(name)
      table, column = name.split(".")
      @connection.quote_table_name(table) + "." + @connection.quote_column_name(column)
    end
end
