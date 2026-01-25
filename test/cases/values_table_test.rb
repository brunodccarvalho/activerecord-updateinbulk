# frozen_string_literal: true

require "test_helper"
require "models"

class ValuesTableTest < TestCase
  fixtures :books

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_values_table_column_aliases_default
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]])

    assert_equal ["column1", "column2"], table.column_aliases_or_default_names
  end

  def test_values_table_column_aliases_explicit
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], columns: %w[first second])

    assert_equal ["first", "second"], table.column_aliases_or_default_names
  end

  def test_values_table_attribute_lookup_by_index_and_symbol
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]])

    assert_equal "column1", table[0].name
    assert_equal "column2", table[1].name
    assert_equal "column1", table[:column1].name
    assert_equal "column1", table["column1"].name
  end

  def test_values_table_attribute_lookup_uses_aliases
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], columns: %w[first second])

    assert_equal "first", table[0].name
    assert_equal "second", table[1].name
    assert_equal "first", table[:first].name
    assert_equal "first", table["first"].name
  end

  def test_arel_values_table_default_column_names
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]])
    result = exec_query(table.from.project(Arel.star))

    assert_equal ["column1", "column2"], result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_arel_values_table_supports_aliases
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], columns: %w[alias1 alias2])
    result = exec_query(table.from.project(Arel.star))

    assert_equal ["alias1", "alias2"], result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_values_table_cte_plain
    # WITH data AS (SELECT 1 column1, 'one' column2 UNION ALL VALUES (2, 'two')) SELECT * FROM data
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]])
    query = Arel::SelectManager.new.with(table.to_cte).from("data").project(Arel.star)
    result = exec_query(query)

    assert_equal ["column1", "column2"], result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_values_table_cte_with_aliases
    # WITH data AS (SELECT 1 alias1, 'one' alias2 UNION ALL VALUES (2, 'two')) SELECT * FROM data
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"], [2, "two"]], columns: %w[alias1 alias2])
    query = Arel::SelectManager.new.with(table.to_cte).from("data").project(Arel.star)
    result = exec_query(query)

    assert_equal ["alias1", "alias2"], result.columns
    assert_equal [[1, "one"], [2, "two"]], result.rows
  end

  def test_values_table_alias_in_join
    # SELECT books.id, data.column2 AS label FROM books JOIN (SELECT 1 column1, 'One' column2 UNION ALL VALUES (2, 'Two'), (3, 'Three')) data ON books.id = data.column1 WHERE books.id IN (1, 2, 4)
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "One"], [2, "Two"], [3, "Three"]])
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
    # (SELECT * FROM (VALUES (1, 'one')))) or (SELECT * FROM (SELECT 1 column1, 'one' column2)) depending on DB
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]])
    sql = to_sql(table.from(nil).project(Arel.star))

    assert_equal good_default_names?, sql.include?("VALUES")
    assert_no_match(/\sdata\b/, sql)
  end

  def test_values_table_equality_and_hash
    table = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]])
    table2 = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]])
    table3 = Arel::Nodes::ValuesTable.new(:data, [[1, "one"]], columns: %w[alias1 alias2])

    assert_equal table, table2
    assert_equal table.hash, table2.hash
    assert_not_equal table, table3
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

    def good_default_names?
      !["Mysql2", "Trilogy"].include?(@connection.adapter_name)
    end
end
