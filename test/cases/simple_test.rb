# frozen_string_literal: true

require "test_helper"
require "models"

class SimpleTest < TestCase
  fixtures :all

  before_suite do
    Book.record_timestamps = false
  end

  after_suite do
    Book.record_timestamps = true
  end

  def test_simple_without_formulas_uses_simple_update_without_values_table
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk({ 1 => { name: "Simple Update" } })
    end

    assert_model_delta(Book, { 1 => { name: "Simple Update" } })
  end

  def test_simple_with_multiple_conditions_uses_simple_update_without_values_table
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([[{ id: 1, status: :published }, { name: "Simple Conditions" }]])
    end

    assert_model_delta(Book, { 1 => { name: "Simple Conditions" } })
  end

  def test_simple_with_formulas_does_not_use_simple_update_optimization
    assert_query_sql(values: 2, on_width: 1) do
      ProductStock.update_in_bulk({ "Tree" => { quantity: 1 } }, formulas: { quantity: :add })
    end

    assert_model_delta(ProductStock, { "Tree" => { quantity: 11 } })
  end

  def test_simple_update_no_formulas
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([{ id: 2 }], [{ name: "Separated Simple" }])
    end

    assert_model_delta(Book, { 2 => { name: "Separated Simple" } })
  end

  def test_simple_update_with_timestamps
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([{ id: 2 }], [{ name: "Separated Simple" }], record_timestamps: true)
    end

    assert_model_delta(Book, { 2 => { name: "Separated Simple", updated_at: :_modified } })
  end

  def test_simple_update_with_explicit_nil_assign
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk({ 2 => { format: nil } })
    end

    assert_model_delta(Book, { 2 => { format: nil } })
  end

  def test_simple_update_with_explicit_hash_conditions
    assert_equal 0, Book.update_in_bulk([[{ id: 1, status: :proposed }, { name: "Should Not Change" }]])

    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([[{ id: 1, status: :published }, { name: "Hash Conditions" }]])
    end

    assert_model_delta(Book, { 1 => { name: "Hash Conditions" } })
  end

  def test_simple_update_with_composite_primary_key
    assert_query_sql(values: false, on_width: 0) do
      Car.update_in_bulk({ ["Toyota", "Camry"] => { year: 2001 } })
    end

    assert_model_delta(Car, { ["Toyota", "Camry"] => { year: 2001 } })
  end
end
