# frozen_string_literal: true

require "test_helper"
require "models"

class FormulasTest < TestCase
  fixtures :all

  before_suite do
    Book.record_timestamps = false
  end

  after_suite do
    Book.record_timestamps = true
  end

  def test_formulas_add
    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Toy train" => { quantity: 3 },
      "Stockings" => { quantity: 0 }
    }, formulas: { quantity: :add })

    assert_model_delta(ProductStock, {
      "Tree" => { quantity: 15 },
      "Toy train" => { quantity: 13 }
    })
  end

  def test_formulas_subtract
    ProductStock.update_in_bulk({
      "Christmas balls" => { quantity: 30 },
      "Wreath" => { quantity: 5 },
      "Tree" => { quantity: 0 }
    }, formulas: { quantity: :subtract })

    assert_model_delta(ProductStock, {
      "Christmas balls" => { quantity: 70 },
      "Wreath" => { quantity: 45 }
    })
  end

  def test_formulas_concat_append
    Book.update_in_bulk({
      1 => { name: " (2nd edition)" },
      2 => { name: " (revised)" },
      3 => { name: "" }
    }, formulas: { name: :concat_append })

    assert_model_delta(Book, {
      1 => { name: "Agile Web Development with Rails (2nd edition)" },
      2 => { name: "Ruby for Rails (revised)" }
    })
  end

  def test_formulas_concat_prepend
    Book.update_in_bulk({
      1 => { name: "Classic: " },
      2 => { name: "Classic: " },
      3 => { name: "" },
    }, formulas: { name: :concat_prepend })

    assert_model_delta(Book, {
      1 => { name: "Classic: Agile Web Development with Rails" },
      2 => { name: "Classic: Ruby for Rails" }
    })
  end

  def test_formulas_applied_only_to_specified_rows_and_columns
    Book.update_in_bulk({
      1 => { name: " X", pages: 100 },
      2 => { pages: 200 }
    }, formulas: { name: :concat_append })

    assert_model_delta(Book, {
      1 => { name: "Agile Web Development with Rails X", pages: 100 },
      2 => { pages: 200 },
    })
  end

  def test_rejects_formulas_for_unspecified_columns
    assert_raises(ArgumentError) do
      Book.update_in_bulk({ 1 => { pages: 1 } }, formulas: { name: :concat_append })
    end
  end

  def test_register_formula
    ActiveRecord::UpdateInBulk.register_formula(:double_add) { |lhs, rhs| lhs + rhs + rhs }

    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Toy train" => { quantity: 3 }
    }, formulas: { quantity: :double_add })

    assert_model_delta(ProductStock, {
      "Tree" => { quantity: 20 },
      "Toy train" => { quantity: 16 }
    })

    ActiveRecord::UpdateInBulk.unregister_formula(:double_add)
    ActiveRecord::UpdateInBulk.register_formula(:dup_formula) { |lhs, rhs| lhs + rhs }

    assert_raises(ArgumentError, match: /unknown formula/i) do
      Book.update_in_bulk({ 1 => { name: "Scrum Development" } }, formulas: { name: :double_add })
    end
    assert_raises(ArgumentError, match: /missing block/i) do
      ActiveRecord::UpdateInBulk.register_formula(:no_block)
    end
    assert_raises(ArgumentError, match: /already registered/i) do
      ActiveRecord::UpdateInBulk.register_formula(:dup_formula) { |lhs, rhs| lhs - rhs }
    end
  ensure
    ActiveRecord::UpdateInBulk.unregister_formula(:double_add)
    ActiveRecord::UpdateInBulk.unregister_formula(:dup_formula)
  end

  def test_custom_formula_proc_arity_2
    add_proc = lambda do |lhs, rhs|
      lhs + rhs + 1
    end

    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Toy train" => { quantity: 3 }
    }, formulas: { quantity: add_proc })

    assert_model_delta(ProductStock, {
      "Tree" => { quantity: 16 },
      "Toy train" => { quantity: 14 }
    })
  end

  def test_custom_formula_proc_arity_3
    concat_proc = lambda do |lhs, rhs, model|
      Arel::Nodes::Concat.new(model.arel_table[:name], rhs)
    end

    Book.update_in_bulk({
      1 => { name: " (custom)" },
      2 => { name: " (custom)" }
    }, formulas: { name: concat_proc })

    assert_model_delta(Book, {
      1 => { name: "Agile Web Development with Rails (custom)" },
      2 => { name: "Ruby for Rails (custom)" }
    })
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

    assert_model_delta(Book, {
      1 => { name: "Agile Web Development with Rails X" },
      2 => { pages: 7 }
    })
  end

  def test_custom_formula_proc_json_append
    skip unless json_array_append_proc

    User.update_in_bulk([
      [{ name: "David" }, { notifications: "Second" }],
      [{ name: "Joao" }, { notifications: "Third" }]
    ], formulas: { notifications: json_array_append_proc })

    assert_model_delta(User, {
      1 => { notifications: ["Second", "Welcome"] },
      2 => { notifications: ["Third", "Primeira", "Segunda"] }
    })
  end

  def test_custom_formula_proc_json_rotating_prepend
    skip unless json_array_rotating_prepend_proc

    User.update_in_bulk(
      [{ name: "Albert" }, { name: "Bernard" }, { name: "Carol" }],
      [{ notifications: "Hello" }, { notifications: "Hello" }, { notifications: "Hello" }],
      formulas: { notifications: json_array_rotating_prepend_proc })

    assert_model_delta(User, {
      3 => { notifications: ["Hello", "One", "Two", "Three"] },
      4 => { notifications: ["Hello", "One", "Two", "Three", "Four"] },
      5 => { notifications: ["Hello", "One", "Two", "Three", "Four"] }
    })
  end

  def test_formulas_subtract_decimal
    TypeVariety.update_in_bulk({
      1 => { col_decimal: BigDecimal("3.25") },
      2 => { col_decimal: BigDecimal("0.75") }
    }, formulas: { col_decimal: :subtract })

    assert_model_delta(TypeVariety, {
      1 => { col_decimal: BigDecimal("7.25") },
      2 => { col_decimal: BigDecimal("20.00") }
    })
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
      @json_array_append_proc ||= if postgres?
        lambda do |lhs, rhs, model|
          lhs_sql = arel_sql(lhs, model.connection)
          rhs_sql = arel_sql(rhs, model.connection)
          Arel.sql("jsonb_build_array(#{rhs_sql}) || COALESCE(#{lhs_sql}::jsonb, '[]'::jsonb)")
        end
      elsif mysql?
        lambda do |lhs, rhs, model|
          lhs_sql = arel_sql(lhs, model.connection)
          rhs_sql = arel_sql(rhs, model.connection)
          Arel.sql("JSON_ARRAY_INSERT(COALESCE(#{lhs_sql}, JSON_ARRAY()), '$[0]', JSON_EXTRACT(#{rhs_sql}, '$'))")
        end
      end
    end

    def json_array_rotating_prepend_proc
      @json_array_rotating_prepend_proc ||= if postgres?
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
      elsif mysql?
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
