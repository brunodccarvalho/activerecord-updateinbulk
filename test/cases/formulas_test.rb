# frozen_string_literal: true

require "test_helper"
require "models"

class FormulasTest < TestCase
  fixtures :all

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
  end

  def test_formulas_add
    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Toy train" => { quantity: 3 }
    }, formulas: { quantity: :add })

    assert_equal 15, ProductStock.find("Tree").quantity
    assert_equal 13, ProductStock.find("Toy train").quantity
    assert_equal 10, ProductStock.find("Toy car").quantity
  end

  def test_formulas_subtract
    ProductStock.update_in_bulk({
      "Christmas balls" => { quantity: 30 },
      "Wreath" => { quantity: 5 }
    }, formulas: { quantity: :subtract })

    assert_equal 70, ProductStock.find("Christmas balls").quantity
    assert_equal 45, ProductStock.find("Wreath").quantity
    assert_equal 400, ProductStock.find("Tree lights").quantity
  end

  def test_formulas_concat_append
    Book.update_in_bulk({
      1 => { name: " (2nd edition)" },
      2 => { name: " (revised)" }
    }, formulas: { name: :concat_append })

    assert_equal "Agile Web Development with Rails (2nd edition)", Book.find(1).name
    assert_equal "Ruby for Rails (revised)", Book.find(2).name
    assert_equal "Domain-Driven Design", Book.find(3).name
  end

  def test_formulas_concat_prepend
    Book.update_in_bulk({
      1 => { name: "Classic: " },
      2 => { name: "Classic: " }
    }, formulas: { name: :concat_prepend })

    assert_equal "Classic: Agile Web Development with Rails", Book.find(1).name
    assert_equal "Classic: Ruby for Rails", Book.find(2).name
    assert_equal "Domain-Driven Design", Book.find(3).name
  end

  def test_formulas_min
    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Toy train" => { quantity: 15 }
    }, formulas: { quantity: :min })

    assert_equal 5, ProductStock.find("Tree").quantity
    assert_equal 10, ProductStock.find("Toy train").quantity
    assert_equal 0, ProductStock.find("Stockings").quantity
  end

  def test_formulas_max
    ProductStock.update_in_bulk({
      "Stockings" => { quantity: 5 },
      "Sweater" => { quantity: 2 }
    }, formulas: { quantity: :max })

    assert_equal 5, ProductStock.find("Stockings").quantity
    assert_equal 2, ProductStock.find("Sweater").quantity
    assert_equal 10, ProductStock.find("Tree").quantity
  end

  def test_formulas_applied_only_to_specified_columns
    Book.update_all(pages: 1)

    Book.update_in_bulk({
      1 => { name: " X", pages: 100 },
      2 => { name: " Y", pages: 200 }
    }, formulas: { name: :concat_append })

    books = Book.where(id: 1..2).order(:id).to_a
    assert_equal "Agile Web Development with Rails X", books[0].name
    assert_equal 100, books[0].pages
    assert_equal "Ruby for Rails Y", books[1].name
    assert_equal 200, books[1].pages
    assert_equal "Domain-Driven Design", Book.find(3).name
  end

  def test_formulas_skipped_for_rows_missing_formula_column
    Book.update_in_bulk({
      1 => { name: " X" },
      2 => { pages: 7 }
    }, formulas: { name: :concat_append })

    assert_equal "Agile Web Development with Rails X", Book.find(1).name
    assert_equal "Ruby for Rails", Book.find(2).name
    assert_equal "Thoughtleadering", Book.find(4).name
  end

  def test_formulas_with_paired_format
    ProductStock.update_in_bulk([
      [{ name: "Tree" }, { quantity: 5 }],
      [{ name: "Toy train" }, { quantity: 3 }]
    ], formulas: { quantity: :add })

    assert_equal 15, ProductStock.find("Tree").quantity
    assert_equal 13, ProductStock.find("Toy train").quantity
    assert_equal 10, ProductStock.find("Toy car").quantity
  end

  def test_formulas_with_separated_format
    ProductStock.update_in_bulk(["Tree", "Toy train"], [{ quantity: 5 }, { quantity: 3 }], formulas: { quantity: :add })

    assert_equal 15, ProductStock.find("Tree").quantity
    assert_equal 13, ProductStock.find("Toy train").quantity
    assert_equal 10, ProductStock.find("Toy car").quantity
  end

  def test_rejects_unknown_formulas
    assert_raises(ArgumentError) do
      Book.update_in_bulk({ 1 => { name: "Scrum Development" } }, formulas: { name: :mystery })
    end
  end

  def test_rejects_formulas_for_unknown_columns
    assert_raises(ArgumentError) do
      Book.update_in_bulk({ 1 => { pages: 1 } }, formulas: { name: :concat_append })
    end
  end

  def test_custom_formula_proc_arity_2
    add_proc = lambda do |lhs, rhs|
      Arel::Nodes::InfixOperation.new("+", lhs, rhs)
    end

    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Toy train" => { quantity: 3 }
    }, formulas: { quantity: add_proc })

    assert_equal 15, ProductStock.find("Tree").quantity
    assert_equal 13, ProductStock.find("Toy train").quantity
    assert_equal 10, ProductStock.find("Toy car").quantity
  end

  def test_custom_formula_proc_arity_3
    concat_proc = lambda do |lhs, rhs, model|
      Arel::Nodes::Concat.new(model.arel_table[:name], rhs)
    end

    Book.update_in_bulk({
      1 => { name: " (custom)" },
      2 => { name: " (custom)" }
    }, formulas: { name: concat_proc })

    assert_equal "Agile Web Development with Rails (custom)", Book.find(1).name
    assert_equal "Ruby for Rails (custom)", Book.find(2).name
    assert_equal "Domain-Driven Design", Book.find(3).name
  end

  def test_custom_formula_proc_wrong_arity
    bad_proc = lambda { |lhs| lhs }

    assert_raises(ArgumentError) do
      Book.update_in_bulk({ 1 => { name: "Scrum Development" } }, formulas: { name: bad_proc })
    end
  end

  def test_custom_formula_proc_invalid_return
    bad_proc = lambda do |lhs, rhs|
      "not an arel node"
    end

    assert_raises(ArgumentError) do
      Book.update_in_bulk({ 1 => { name: "Scrum Development" } }, formulas: { name: bad_proc })
    end
  end

  def test_custom_formula_proc_with_optional_columns
    concat_proc = lambda do |lhs, rhs|
      Arel::Nodes::Concat.new(lhs, rhs)
    end

    Book.update_in_bulk({
      1 => { name: " X" },
      2 => { pages: 7 }
    }, formulas: { name: concat_proc })

    assert_equal "Agile Web Development with Rails X", Book.find(1).name
    assert_equal "Ruby for Rails", Book.find(2).name
    assert_equal "Thoughtleadering", Book.find(4).name
  end

  def test_custom_formula_proc_json_append
    skip unless json_array_append_proc

    User.update_in_bulk([
      [{ name: "David" }, { notifications: "Second" }],
      [{ name: "Joao" }, { notifications: "Third" }]
    ], formulas: { notifications: json_array_append_proc })

    assert_equal ["Second", "Welcome"], User.find_by(name: "David").notifications
    assert_equal ["Third", "Primeira", "Segunda"], User.find_by(name: "Joao").notifications
    assert_equal ["One", "Two", "Three"], User.find_by(name: "Albert").notifications
  end

  def test_custom_formula_proc_json_rotating_prepend
    skip unless json_array_rotating_prepend_proc

    User.update_in_bulk(
      [{ name: "Albert" }, { name: "Bernard" }, { name: "Carol" }],
      [{ notifications: "Hello" }, { notifications: "Hello" }, { notifications: "Hello" }],
      formulas: { notifications: json_array_rotating_prepend_proc })

    assert_equal ["Hello", "One", "Two", "Three"], User.find_by(name: "Albert").notifications
    assert_equal ["Hello", "One", "Two", "Three", "Four"], User.find_by(name: "Bernard").notifications
    assert_equal ["Hello", "One", "Two", "Three", "Four"], User.find_by(name: "Carol").notifications
    assert_equal ["Welcome"], User.find_by(name: "David").notifications
  end

  def test_formulas_subtract_decimal
    TypeVariety.update_in_bulk({
      1 => { col_decimal: BigDecimal("3.25") },
      2 => { col_decimal: BigDecimal("0.75") }
    }, formulas: { col_decimal: :subtract })

    assert_equal BigDecimal("7.25"), TypeVariety.find(1).col_decimal   # 10.50 - 3.25
    assert_equal BigDecimal("20.00"), TypeVariety.find(2).col_decimal  # 20.75 - 0.75
    assert_equal BigDecimal("30.25"), TypeVariety.find(3).col_decimal
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_formulas_subtract_unsigned_integer
      # Book.pages is unsigned on mysql/mariadb; subtracting beyond zero wraps or errors.
      Book.update_all(pages: 10)

      Book.update_in_bulk({
        1 => { pages: 3 },
        2 => { pages: 7 }
      }, formulas: { pages: :subtract })

      assert_equal 7, Book.find(1).pages    # 10 - 3
      assert_equal 3, Book.find(2).pages    # 10 - 7
    end
  end

  def test_formulas_min_date
    TypeVariety.update_in_bulk({
      1 => { col_date: Date.new(2024, 6, 15) }, # earlier than fixture 2025-01-15 → takes new
      2 => { col_date: Date.new(2026, 1, 1) }   # later than fixture 2025-06-30 → keeps old
    }, formulas: { col_date: :min })

    assert_equal Date.new(2024, 6, 15), TypeVariety.find(1).col_date
    assert_equal Date.new(2025, 6, 30), TypeVariety.find(2).col_date
    assert_equal Date.new(2024, 11, 5), TypeVariety.find(3).col_date
  end

  def test_formulas_max_datetime
    TypeVariety.update_in_bulk({
      1 => { col_datetime: Time.utc(2020, 1, 1) }, # earlier → keeps old
      2 => { col_datetime: Time.utc(2030, 1, 1) }  # later → takes new
    }, formulas: { col_datetime: :max })

    assert_equal "2025-01-15 09:00", TypeVariety.find(1).col_datetime.strftime("%Y-%m-%d %H:%M")
    assert_equal "2030-01-01 00:00", TypeVariety.find(2).col_datetime.strftime("%Y-%m-%d %H:%M")
    assert_equal "2024-11-05 07:45", TypeVariety.find(3).col_datetime.strftime("%Y-%m-%d %H:%M")
  end

  def test_rejects_subtract_below_zero
    assert_equal [10], ProductStock.where(name: ["Tree", "Toy train", "Toy car"]).pluck(:quantity).uniq

    assert_violation(check_constraint_violation_type) do
      transaction_if_postgresql(requires_new: true) do
        ProductStock.update_in_bulk({
          "Tree" => { quantity: 15 },
          "Toy train" => { quantity: 4 },
          "Toy car" => { quantity: 3 }
        }, formulas: { quantity: :subtract })
      end
    end

    assert_equal [10], ProductStock.where(name: ["Tree", "Toy train", "Toy car"]).pluck(:quantity).uniq
  end

  def test_rejects_concat_beyond_limit
    assert_equal [32, 14, 20], Book.where(id: [1, 2, 3]).order(:id).pluck(:title).map(&:length)

    assert_violation(value_too_long_violation_type) do
      transaction_if_postgresql(requires_new: true) do
        Book.update_in_bulk({
          1 => { name: " (3rd edition).........." },
          2 => { name: " (4th edition).........." },
          3 => { name: " (5th edition).........." }
        }, formulas: { name: :concat_append })
      end
    end

    assert_equal [32, 14, 20], Book.where(id: [1, 2, 3]).order(:id).pluck(:title).map(&:length)
  end

  private
    def assert_violation(violation, &block)
      assert_raises(violation, &block)
    end

    def transaction_if_postgresql(**kwargs, &block)
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        ProductStock.transaction(**kwargs, &block)
      else
        yield
      end
    end

    def json_array_append_proc
      return unless ActiveRecord::Base.connection.supports_json?

      @json_array_append_proc ||= if current_adapter?(:PostgreSQLAdapter)
        lambda do |lhs, rhs, model|
          lhs_sql = arel_sql(lhs, model.connection)
          rhs_sql = arel_sql(rhs, model.connection)
          Arel.sql("jsonb_build_array(#{rhs_sql}) || COALESCE(#{lhs_sql}::jsonb, '[]'::jsonb)")
        end
      elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        lambda do |lhs, rhs, model|
          lhs_sql = arel_sql(lhs, model.connection)
          rhs_sql = arel_sql(rhs, model.connection)
          Arel.sql("JSON_ARRAY_INSERT(COALESCE(#{lhs_sql}, JSON_ARRAY()), '$[0]', JSON_EXTRACT(#{rhs_sql}, '$'))")
        end
      end
    end

    def json_array_rotating_prepend_proc
      return unless ActiveRecord::Base.connection.supports_json?

      @json_array_rotating_prepend_proc ||= if current_adapter?(:PostgreSQLAdapter)
        lambda do |lhs, rhs, model|
          lhs_sql = arel_sql(lhs, model.connection)
          rhs_sql = arel_sql(rhs, model.connection)
          Arel.sql(<<~SQL.squish)
            (SELECT jsonb_agg(elem)
             FROM jsonb_array_elements(jsonb_build_array(#{rhs_sql}) || COALESCE(#{lhs_sql}::jsonb, '[]'::jsonb))
             WITH ORDINALITY AS t(elem, idx)
             WHERE idx <= 5)
          SQL
        end
      elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        lambda do |lhs, rhs, model|
          lhs_sql = arel_sql(lhs, model.connection)
          rhs_sql = arel_sql(rhs, model.connection)
          Arel.sql("JSON_EXTRACT(JSON_ARRAY_INSERT(COALESCE(#{lhs_sql}, JSON_ARRAY()), '$[0]', JSON_EXTRACT(#{rhs_sql}, '$')), '$[0 to 4]')")
        end
      end
    end

    def arel_sql(node, connection)
      visitor = Arel::Visitors::ToSql.new(connection)
      collector = Arel::Collectors::SQLString.new
      visitor.accept(node, collector).value
    end
end
