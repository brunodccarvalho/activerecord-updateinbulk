# frozen_string_literal: true

require "test_helper"
require "models"

class CastingTest < TestCase
  fixtures :all

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
  end

  def test_typecast_for_rails_enums_and_boolean_enums
    Book.update_in_bulk({
      1 => { cover: :hard,  status: :proposed,  boolean_status: :disabled,  author_id: "2" },
      2 => { cover: "soft", status: :published, boolean_status: :enabled,   author_id: nil }
    })

    books = Book.where(id: 1..2).order(:id).pluck(:cover, :status, :boolean_status, :author_id)
    assert_equal ["hard", "proposed", "disabled", 2], books[0]
    assert_equal ["soft", "published", "enabled", nil], books[1]
  end

  def test_typecast_for_jsons
    skip unless ActiveRecord::Base.connection.supports_json?

    User.update_in_bulk [
      [{ name: "David" }, { preferences: { color: "blue" } }],
      [{ name: "Joao" }, { preferences: { "width" => 1440 } }]
    ]

    assert_equal({ "color" => "blue" }, User.find_by(name: "David").preferences)
    assert_equal({ "width" => 1440 }, User.find_by(name: "Joao").preferences)
  end

  # == Group 1: Assign-side typecasting (SET clause values) ==

  def test_typecast_assigns_string_family
    TypeVariety.update_in_bulk({
      1 => { col_string: "gamma", col_varchar: "short_g", col_char: "char_g", col_text: "text gamma" },
      2 => { col_string: "delta", col_varchar: "short_d", col_char: "char_d", col_text: "text delta" }
    })

    assert_equal "gamma short_g char_g text gamma", TypeVariety.find(1).string_values
    assert_equal "delta short_d char_d text delta", TypeVariety.find(2).string_values
    assert_equal "omega short_c char_c text omega", TypeVariety.find(3).string_values
  end

  def test_typecast_assigns_integer_family
    TypeVariety.update_in_bulk({
      1 => { col_integer: "42", col_smallint: 3, col_bigint: 3298534883328 },
      2 => { col_integer: 99, col_smallint: 4, col_bigint: 1099511627776 }
    })

    assert_equal "42 3 3298534883328", TypeVariety.find(1).integer_values
    assert_equal "99 4 1099511627776", TypeVariety.find(2).integer_values
    assert_equal "30 3 4398046511104", TypeVariety.find(3).integer_values
  end

  def test_typecast_assigns_float_and_decimal
    TypeVariety.update_in_bulk({
      1 => { col_float: 3.14, col_decimal: BigDecimal("99.95") },
      2 => { col_float: 2.72, col_decimal: BigDecimal("0.01") }
    })

    assert_equal "3.14 99.95", TypeVariety.find(1).numeric_values
    assert_equal "2.72 0.01", TypeVariety.find(2).numeric_values
    assert_equal "3.50 30.25", TypeVariety.find(3).numeric_values
  end

  def test_typecast_assigns_date_and_time
    TypeVariety.update_in_bulk({
      1 => { col_date: Date.new(2024, 12, 25), col_datetime: Time.utc(2024, 12, 25, 10, 30, 0), col_time: "14:45:00" },
      2 => { col_date: Date.new(2024, 7, 4), col_datetime: Time.utc(2024, 7, 4, 20, 0, 0), col_time: "08:15:00" }
    })

    assert_equal "2024-12-25 2024-12-25 10:30 14:45", TypeVariety.find(1).temporal_values
    assert_equal "2024-07-04 2024-07-04 20:00 08:15", TypeVariety.find(2).temporal_values
    assert_equal "2024-11-05 2024-11-05 07:45 07:45", TypeVariety.find(3).temporal_values
  end

  def test_typecast_assigns_boolean_and_integer_coercion
    TypeVariety.update_in_bulk({
      1 => { col_boolean: false },
      2 => { col_boolean: true }
    })

    assert_equal false, TypeVariety.find(1).col_boolean
    assert_equal true, TypeVariety.find(2).col_boolean
    assert_equal true, TypeVariety.find(3).col_boolean

    # swap back using integer coercion
    TypeVariety.update_in_bulk({
      1 => { col_boolean: 1 },
      2 => { col_boolean: 0 }
    })

    assert_equal true, TypeVariety.find(1).col_boolean
    assert_equal false, TypeVariety.find(2).col_boolean
    assert_equal true, TypeVariety.find(3).col_boolean
  end

  def test_typecast_assigns_nil_across_types
    TypeVariety.update_in_bulk({
      1 => { col_string: nil, col_varchar: nil, col_char: nil, col_text: nil,
             col_integer: nil, col_smallint: nil, col_bigint: nil,
             col_float: nil, col_decimal: nil,
             col_date: nil, col_datetime: nil, col_time: nil,
             col_boolean: nil },
      2 => { col_string: nil, col_varchar: nil, col_char: nil, col_text: nil,
             col_integer: nil, col_smallint: nil, col_bigint: nil,
             col_float: nil, col_decimal: nil,
             col_date: nil, col_datetime: nil, col_time: nil,
             col_boolean: nil }
    })

    assert_equal TypeVariety.all_nil, TypeVariety.find(1).all_values
    assert_equal TypeVariety.all_nil, TypeVariety.find(2).all_values
    assert_equal "omega short_c char_c text omega 30 3 4398046511104 3.50 30.25 2024-11-05 2024-11-05 07:45 07:45 true", TypeVariety.find(3).all_values
  end

  def test_typecast_assigns_full_null_column
    TypeVariety.update_in_bulk({
      1 => { col_integer: 11, col_text: nil },
      2 => { col_integer: 22, col_text: nil }
    })

    assert_nil TypeVariety.find(1).col_text
    assert_equal 11, TypeVariety.find(1).col_integer
    assert_nil TypeVariety.find(2).col_text
    assert_equal 22, TypeVariety.find(2).col_integer
    assert_equal "text omega", TypeVariety.find(3).col_text
    assert_equal 30, TypeVariety.find(3).col_integer
  end

  def test_typecast_assigns_full_null_integer_column
    TypeVariety.update_in_bulk({
      1 => { col_integer: nil, col_text: "alpha" },
      2 => { col_integer: nil, col_text: "beta" }
    })

    assert_nil TypeVariety.find(1).col_integer
    assert_equal "alpha", TypeVariety.find(1).col_text
    assert_nil TypeVariety.find(2).col_integer
    assert_equal "beta", TypeVariety.find(2).col_text
    assert_equal 30, TypeVariety.find(3).col_integer
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_assigns_full_null_boolean_column
    TypeVariety.update_in_bulk({
      1 => { col_boolean: nil, col_text: "alpha" },
      2 => { col_boolean: nil, col_text: "beta" }
    })

    assert_nil TypeVariety.find(1).col_boolean
    assert_equal "alpha", TypeVariety.find(1).col_text
    assert_nil TypeVariety.find(2).col_boolean
    assert_equal "beta", TypeVariety.find(2).col_text
    assert_equal true, TypeVariety.find(3).col_boolean
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_assigns_string_truncation
    skip "SQLite does not enforce string length limits" if current_adapter?(:SQLite3Adapter)

    long_string = "x" * 20

    assert_raises(value_too_long_violation_type) do
      TypeVariety.update_in_bulk({ 1 => { col_varchar: long_string } })
    end
  end

  # == Group 2: Condition-side typecasting (JOIN clause values) ==

  def test_typecast_conditions_string_family
    # Match on col_string
    TypeVariety.update_in_bulk([
      [{ col_string: "alpha" }, { col_text: "matched by string" }],
      [{ col_string: "beta" }, { col_text: "matched by string 2" }]
    ])
    assert_equal "matched by string", TypeVariety.find(1).col_text
    assert_equal "matched by string 2", TypeVariety.find(2).col_text

    # Match on col_varchar
    TypeVariety.update_in_bulk([
      [{ col_varchar: "short_a" }, { col_text: "matched by varchar" }]
    ])
    assert_equal "matched by varchar", TypeVariety.find(1).col_text

    # Match on col_char
    TypeVariety.update_in_bulk([
      [{ col_char: "char_b" }, { col_text: "matched by char" }]
    ])
    assert_equal "matched by char", TypeVariety.find(2).col_text
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_conditions_integer_family
    # Match on col_integer
    TypeVariety.update_in_bulk([
      [{ col_integer: 10 }, { col_text: "int match" }]
    ])
    assert_equal "int match", TypeVariety.find(1).col_text

    # Match on col_smallint
    TypeVariety.update_in_bulk([
      [{ col_smallint: 2 }, { col_text: "smallint match" }]
    ])
    assert_equal "smallint match", TypeVariety.find(2).col_text

    # Match on col_bigint
    TypeVariety.update_in_bulk([
      [{ col_bigint: 1099511627776 }, { col_text: "bigint match" }]
    ])
    assert_equal "bigint match", TypeVariety.find(1).col_text
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_conditions_float_and_decimal
    # Match on col_float (exactly representable)
    TypeVariety.update_in_bulk([
      [{ col_float: 1.5 }, { col_text: "float match" }]
    ])
    assert_equal "float match", TypeVariety.find(1).col_text

    # Match on col_decimal
    TypeVariety.update_in_bulk([
      [{ col_decimal: BigDecimal("20.75") }, { col_text: "decimal match" }]
    ])
    assert_equal "decimal match", TypeVariety.find(2).col_text
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_conditions_date_and_time
    # Match on col_date
    TypeVariety.update_in_bulk([
      [{ col_date: Date.new(2025, 1, 15) }, { col_text: "date match" }]
    ])
    assert_equal "date match", TypeVariety.find(1).col_text

    # Match on col_datetime
    TypeVariety.update_in_bulk([
      [{ col_datetime: Time.utc(2025, 6, 30, 18, 30, 0) }, { col_text: "datetime match" }]
    ])
    assert_equal "datetime match", TypeVariety.find(2).col_text
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_conditions_boolean
    TypeVariety.update_in_bulk([
      [{ col_boolean: true }, { col_text: "bool true match" }],
      [{ col_boolean: false }, { col_text: "bool false match" }]
    ])

    assert_equal "bool true match", TypeVariety.find(1).col_text
    assert_equal "bool false match", TypeVariety.find(2).col_text
    assert_equal "bool true match", TypeVariety.find(3).col_text
    assert_equal "text theta", TypeVariety.find(4).col_text
  end

  def test_condition_with_oversized_string_matches_zero_rows
    affected = TypeVariety.update_in_bulk([
      [{ col_varchar: "short_a" }, { col_text: "should match" }],
      [{ col_varchar: "this_is_way_too_long_for_16" }, { col_text: "should not match" }]
    ])

    # The oversized condition matches nobody; the valid one matches row 1.
    assert_equal 1, affected
    assert_equal "should match", TypeVariety.find(1).col_text
    assert_not_equal "should not match", TypeVariety.find(2).col_text
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  # == Group 3: Formula-side typecasting ==

  def test_typecast_formula_add_numeric_family
    TypeVariety.update_in_bulk({
      1 => { col_integer: 5, col_smallint: 2, col_bigint: 100, col_float: 0.5, col_decimal: BigDecimal("1.25") },
      2 => { col_integer: 3, col_smallint: 1, col_bigint: 200, col_float: 0.25, col_decimal: BigDecimal("2.50") }
    }, formulas: { col_integer: :add, col_smallint: :add, col_bigint: :add, col_float: :add, col_decimal: :add })

    assert_equal "15 3 1099511627876", TypeVariety.find(1).integer_values  # 10+5 1+2 2^40+100
    assert_equal "2.00 11.75", TypeVariety.find(1).numeric_values         # 1.5+0.5 10.50+1.25
    assert_equal "23 3 2199023255752", TypeVariety.find(2).integer_values # 20+3 2+1 2^41+200
    assert_equal "2.75 23.25", TypeVariety.find(2).numeric_values         # 2.5+0.25 20.75+2.50
    assert_equal "30 3 4398046511104", TypeVariety.find(3).integer_values
    assert_equal "3.50 30.25", TypeVariety.find(3).numeric_values
  end

  def test_typecast_formula_add_with_optional_keys
    TypeVariety.update_in_bulk({
      1 => { col_integer: 5 },
      2 => { col_text: "replaced" }
    }, formulas: { col_integer: :add })

    assert_equal 15, TypeVariety.find(1).col_integer
    assert_equal 20, TypeVariety.find(2).col_integer
    assert_equal "replaced", TypeVariety.find(2).col_text
    assert_equal 30, TypeVariety.find(3).col_integer
    assert_equal "text omega", TypeVariety.find(3).col_text
  end

  def test_typecast_formula_concat_append_string_family
    TypeVariety.update_in_bulk({
      1 => { col_string: "_suffix", col_text: "_suffix" },
      2 => { col_string: "_end", col_text: "_end" }
    }, formulas: { col_string: :concat_append, col_text: :concat_append })

    assert_equal "alpha_suffix short_a char_a text alpha_suffix", TypeVariety.find(1).string_values
    assert_equal "beta_end short_b char_b text beta_end", TypeVariety.find(2).string_values
    assert_equal "omega short_c char_c text omega", TypeVariety.find(3).string_values
  end
end
