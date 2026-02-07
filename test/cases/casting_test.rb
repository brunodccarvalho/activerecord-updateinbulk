# frozen_string_literal: true

require "test_helper"
require "models"
require "ipaddr"

class CastingTest < TestCase
  fixtures :all

  def test_typecast_assigns_and_conditions_boolean
    TypeVariety.update_in_bulk({
      1 => { col_boolean: "0" },
      2 => { col_boolean: 1 },
      3 => { col_boolean: "0" }
    })

    TypeVariety.update_in_bulk([
      [{ col_boolean: "-0" }, { col_text: "bool true match" }],
      [{ col_boolean: "0" }, { col_text: "bool false match" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_boolean: false, col_text: "bool false match" },
      2 => { col_boolean: true, col_text: "bool true match" },
      3 => { col_boolean: false, col_text: "bool false match" }
    })
  end

  def test_typecast_assigns_and_conditions_string_family
    TypeVariety.update_in_bulk({
      1 => { col_string: "gamma", col_varchar: "v_g_1", col_char: "c_g_1" },
      2 => { col_string: "delta", col_varchar: "v_d_2", col_char: "c_d_2" },
      3 => { col_string: "zeta", col_varchar: "v_z_3", col_char: "c_z_3" }
    })
    TypeVariety.update_in_bulk([
      [{ col_string: "gamma" }, { col_text: "matched by string" }],
      [{ col_string: "delta" }, { col_text: "matched by string 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_varchar: "v_g_1" }, { col_text: "matched by varchar" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_char: "c_d_2" }, { col_text: "matched by char" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_string: "gamma", col_varchar: "v_g_1", col_char: "c_g_1", col_text: "matched by varchar" },
      2 => { col_string: "delta", col_varchar: "v_d_2", col_char: "c_d_2", col_text: "matched by char" },
      3 => { col_string: "zeta", col_varchar: "v_z_3", col_char: "c_z_3" }
    })
  end

  def test_typecast_formula_concat_append_string_family
    TypeVariety.update_in_bulk({
      1 => { col_string: 123, col_text: {} },
      2 => { col_string: [], col_text: 123.5 }
    }, formulas: { col_string: :concat_append, col_text: :concat_append })

    assert_model_delta(TypeVariety, {
      1 => { col_string: "alpha123", col_text: "text alpha{}" },
      2 => { col_string: "beta[]", col_text: "text beta123.5" }
    })
  end

  def test_typecast_assigns_and_conditions_integer_family
    assert_no_queries_match(%r{0\.6}) do
      TypeVariety.update_in_bulk({
        1 => { col_integer: "100.6", col_smallint: 20.6.to_d, col_bigint: -300_000_000_000_000.6 },
        2 => { col_integer: 200.6, col_smallint: "30.6", col_bigint: 400_000_000_000_000.6.to_d },
        3 => { col_integer: -300.6, col_smallint: 40.6, col_bigint: "100000000000000.6" }
      })
      TypeVariety.update_in_bulk([
        [{ col_integer: "100.6" }, { col_text: "int match 1" }],
        [{ col_integer: 200.6.to_d }, { col_text: "int match 2" }],
        [{ col_integer: "-300.6" }, { col_text: "int match 3" }]
      ])
      TypeVariety.update_in_bulk([
        [{ col_smallint: "20.6" }, { col_char: "smallint 1" }],
        [{ col_smallint: 30.6.to_d }, { col_char: "smallint 2" }],
        [{ col_smallint: 40.6 }, { col_char: "smallint 3" }]
      ])
      TypeVariety.update_in_bulk([
        [{ col_bigint: "-300000000000000.6" }, { col_varchar: "bigint 1" }],
        [{ col_bigint: 400_000_000_000_000.6 }, { col_varchar: "bigint 2" }],
        [{ col_bigint: "100000000000000.6" }, { col_varchar: "bigint 3" }]
      ])
    end

    assert_model_delta(TypeVariety, {
      1 => { col_integer: 100, col_smallint: 20, col_bigint: -300_000_000_000_000, col_text: "int match 1", col_char: "smallint 1", col_varchar: "bigint 1" },
      2 => { col_integer: 200, col_smallint: 30, col_bigint: 400_000_000_000_000, col_text: "int match 2", col_char: "smallint 2", col_varchar: "bigint 2" },
      3 => { col_integer: -300, col_smallint: 40, col_bigint: 100_000_000_000_000, col_text: "int match 3", col_char: "smallint 3", col_varchar: "bigint 3" }
    })
  end

  def test_typecast_formula_add_numeric_family
    assert_no_queries_match(%r{0\.6}) do
      TypeVariety.update_in_bulk({
        1 => { col_integer: "5.6", col_smallint: 2.6.to_d, col_bigint: "100.6", col_float: "0.25", col_decimal: "1.25" },
        2 => { col_integer: 3.6.to_d, col_smallint: "1.6", col_bigint: 200.6, col_float: 0.125.to_d, col_decimal: "2.50" }
      }, formulas: { col_integer: :add, col_smallint: :add, col_bigint: :add, col_float: :add, col_decimal: :add })
    end

    assert_model_delta(TypeVariety, {
      1 => { col_integer: 15, col_smallint: 3, col_bigint: 1099511627876, col_float: 1.75, col_decimal: "11.75".to_d },
      2 => { col_integer: 23, col_smallint: 3, col_bigint: 2199023255752, col_float: 2.625, col_decimal: "23.25".to_d }
    })
  end

  def test_typecast_assigns_and_conditions_float_and_decimal
    TypeVariety.update_in_bulk({
      1 => { col_float: "0.5", col_decimal: "99.95" },
      2 => { col_float: "-2.5", col_decimal: 67.89.to_d },
      3 => { col_float: 2.75.to_d, col_decimal: -0.01 }
    })
    TypeVariety.update_in_bulk([
      [{ col_float: 0.5 }, { col_text: "float match 1" }],
      [{ col_float: "-2.5" }, { col_text: "float match 2" }],
      [{ col_float: 2.75.to_d }, { col_text: "float match 3" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_decimal: 99.95 }, { col_char: "decimal 1" }],
      [{ col_decimal: "67.89" }, { col_char: "decimal 2" }],
      [{ col_decimal: "-0.01" }, { col_char: "decimal 3" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_float: 0.5, col_decimal: 99.95.to_d, col_text: "float match 1", col_char: "decimal 1" },
      2 => { col_float: -2.5, col_decimal: 67.89.to_d, col_text: "float match 2", col_char: "decimal 2" },
      3 => { col_float: 2.75, col_decimal: -0.01.to_d, col_text: "float match 3", col_char: "decimal 3" }
    })
  end

  def test_typecast_assigns_and_conditions_binary
    invalid_utf8 = "\xC3\x28".b
    zeros = "\x00\x00\x00".b
    mixed = "A\x00B".b

    TypeVariety.update_in_bulk({
      1 => { col_binary: invalid_utf8 },
      2 => { col_binary: zeros },
      3 => { col_binary: mixed }
    })
    TypeVariety.update_in_bulk([
      [{ col_binary: invalid_utf8 }, { col_text: "bin invalid" }],
      [{ col_binary: zeros }, { col_text: "bin zeros" }],
      [{ col_binary: mixed }, { col_text: "bin mixed" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_binary: invalid_utf8, col_text: "bin invalid" },
      2 => { col_binary: zeros, col_text: "bin zeros" },
      3 => { col_binary: mixed, col_text: "bin mixed" }
    })
  end

  def test_typecast_assigns_and_conditions_database_enum
    skip "Adapter does not support database enums" if sqlite?

    TypeVariety.update_in_bulk({
      1 => { col_enum: "alpha" },
      2 => { col_enum: "beta" },
      3 => { col_enum: "gamma" }
    })

    TypeVariety.update_in_bulk([
      [{ col_enum: "alpha" }, { col_text: "enum alpha" }],
      [{ col_enum: "beta" }, { col_text: "enum beta" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_enum: "alpha", col_text: "enum alpha" },
      2 => { col_enum: "beta", col_text: "enum beta" },
      3 => { col_enum: "gamma" }
    })
  end

  def test_typecast_assigns_and_conditions_postgresql_uuid_inet_cidr_macaddr
    skip "Adapter does not support PostgreSQL advanced types" unless postgres?

    uuid_one = "550e8400-e29b-41d4-a716-446655440000"
    uuid_two = "550e8400-e29b-41d4-a716-446655440001"

    TypeVariety.update_in_bulk({
      1 => { col_uuid: uuid_one.upcase, col_inet: "192.168.0.10", col_cidr: IPAddr.new("10.0.0.0/24"), col_macaddr: "08:00:2B:01:02:03" },
      2 => { col_uuid: uuid_two, col_inet: IPAddr.new("10.20.30.40"), col_cidr: "172.16.0.0/16", col_macaddr: "08:00:2b:01:02:04" }
    })

    TypeVariety.update_in_bulk([
      [{ col_uuid: uuid_one }, { col_text: "uuid condition 1" }],
      [{ col_uuid: uuid_two }, { col_text: "uuid condition 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_inet: IPAddr.new("192.168.0.10") }, { col_char: "inet condition 1" }],
      [{ col_inet: "10.20.30.40" }, { col_char: "inet condition 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_cidr: "10.0.0.0/24" }, { col_varchar: "cidr condition 1" }],
      [{ col_cidr: IPAddr.new("172.16.0.0/16") }, { col_varchar: "cidr condition 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_macaddr: "08:00:2b:01:02:03" }, { col_string: "mac condition 1" }],
      [{ col_macaddr: "08:00:2B:01:02:04" }, { col_string: "mac condition 2" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => {
        col_uuid: uuid_one,
        col_inet: IPAddr.new("192.168.0.10"),
        col_cidr: IPAddr.new("10.0.0.0/24"),
        col_macaddr: "08:00:2b:01:02:03",
        col_text: "uuid condition 1",
        col_char: "inet condition 1",
        col_varchar: "cidr condition 1",
        col_string: "mac condition 1"
      },
      2 => {
        col_uuid: uuid_two,
        col_inet: IPAddr.new("10.20.30.40"),
        col_cidr: IPAddr.new("172.16.0.0/16"),
        col_macaddr: "08:00:2b:01:02:04",
        col_text: "uuid condition 2",
        col_char: "inet condition 2",
        col_varchar: "cidr condition 2",
        col_string: "mac condition 2"
      }
    })
  end

  def test_typecast_assigns_and_conditions_postgresql_jsonb_xml
    skip "Adapter does not support PostgreSQL advanced types" unless postgres?

    TypeVariety.update_in_bulk({
      1 => { col_jsonb: { key: "one", "items" => [1, "2"] }, col_xml: "<root><entry>one</entry></root>" },
      2 => { col_jsonb: [{ "key" => "two" }, true], col_xml: "<root><entry>two</entry></root>" }
    })

    TypeVariety.update_in_bulk([
      [{ col_jsonb: { key: "one", items: [1, "2"] } }, { col_text: "jsonb condition 1" }],
      [{ col_jsonb: [{ key: "two" }, true] }, { col_text: "jsonb condition 2" }]
    ])

    assert_equal "key", TypeVariety.find(1).col_jsonb.keys.first
    assert_model_delta(TypeVariety, {
      1 => { col_jsonb: { "key" => "one", "items" => [1, "2"] }, col_xml: "<root><entry>one</entry></root>", col_text: "jsonb condition 1" },
      2 => { col_jsonb: [{ "key" => "two" }, true], col_xml: "<root><entry>two</entry></root>", col_text: "jsonb condition 2" }
    })
  end

  def test_typecast_assigns_and_conditions_postgresql_bit_tsvector_interval
    skip "Adapter does not support PostgreSQL advanced types" unless postgres?

    TypeVariety.update_in_bulk({
      1 => { col_bit: "10101010", col_bit_varying: "1011", col_tsvector: "rails update_in_bulk", col_interval: "P1DT2H3M4S" },
      2 => { col_bit: "01010101", col_bit_varying: "11", col_tsvector: "active record", col_interval: "P2DT10M" }
    })

    TypeVariety.update_in_bulk([
      [{ col_bit: "10101010" }, { col_integer: 111 }],
      [{ col_bit: "01010101" }, { col_integer: 222 }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_bit_varying: "1011" }, { col_smallint: 11 }],
      [{ col_bit_varying: "11" }, { col_smallint: 22 }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_tsvector: "rails update_in_bulk" }, { col_text: "tsvector condition 1" }],
      [{ col_tsvector: "active record" }, { col_text: "tsvector condition 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_interval: "P1DT2H3M4S" }, { col_varchar: "interval cond 1" }],
      [{ col_interval: "P2DT10M" }, { col_varchar: "interval cond 2" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => {
        col_bit: :_modified,
        col_bit_varying: :_modified,
        col_tsvector: "'rails' 'update_in_bulk'",
        col_interval: 1.day + 2.hours + 3.minutes + 4.seconds,
        col_integer: 111,
        col_smallint: 11,
        col_text: "tsvector condition 1",
        col_varchar: "interval cond 1"
      },
      2 => {
        col_bit: :_modified,
        col_bit_varying: :_modified,
        col_tsvector: "'active' 'record'",
        col_interval: 2.days + 10.minutes,
        col_integer: 222,
        col_smallint: 22,
        col_text: "tsvector condition 2",
        col_varchar: "interval cond 2"
      }
    })
  end

  def test_typecast_assigns_and_conditions_postgresql_arrays_and_simple_ranges
    skip "Adapter does not support PostgreSQL advanced types" unless postgres?

    assert_no_queries_match(%r{0\.6}) do
      TypeVariety.update_in_bulk({
        1 => { col_integer_array: ["1", 2, 3.6], col_text_array: ["one", 2, :three], col_daterange: Date.new(2024, 1, 1)...Date.new(2024, 2, 1), col_numrange: "[1.5,2.5)" },
        2 => { col_integer_array: [4, 5.6, 6], col_text_array: ["four", "five"], col_daterange: Date.new(2024, 3, 1)...Date.new(2024, 4, 1), col_numrange: "[3.5,4.5)" }
      })
    end

    TypeVariety.update_in_bulk([
      [{ col_integer_array: [1, 2, 3] }, { col_bigint: 101 }],
      [{ col_integer_array: ["4", 5.6, 6] }, { col_bigint: 202 }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_text_array: ["one", "2", "three"] }, { col_text: "text_array condition 1" }],
      [{ col_text_array: ["four", "five"] }, { col_text: "text_array condition 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_daterange: "[2024-01-01,2024-02-01)" }, { col_date: Date.new(2030, 1, 1) }],
      [{ col_daterange: Date.new(2024, 3, 1)...Date.new(2024, 4, 1) }, { col_date: Date.new(2030, 2, 1) }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_numrange: "[1.5,2.5)" }, { col_char: "numrange cond 1" }],
      [{ col_numrange: "[3.5,4.5)" }, { col_char: "numrange cond 2" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => {
        col_integer_array: [1, 2, 3],
        col_text_array: ["one", "2", "three"],
        col_daterange: Date.new(2024, 1, 1)...Date.new(2024, 2, 1),
        col_numrange: BigDecimal("1.5")...BigDecimal("2.5"),
        col_bigint: 101,
        col_text: "text_array condition 1",
        col_date: Date.new(2030, 1, 1),
        col_char: "numrange cond 1"
      },
      2 => {
        col_integer_array: [4, 5, 6],
        col_text_array: ["four", "five"],
        col_daterange: Date.new(2024, 3, 1)...Date.new(2024, 4, 1),
        col_numrange: BigDecimal("3.5")...BigDecimal("4.5"),
        col_bigint: 202,
        col_text: "text_array condition 2",
        col_date: Date.new(2030, 2, 1),
        col_char: "numrange cond 2"
      }
    })
  end

  def test_typecast_assigns_and_conditions_postgresql_temporal_and_integer_ranges
    skip "Adapter does not support PostgreSQL advanced types" unless postgres?

    TypeVariety.update_in_bulk({
      1 => { col_tsrange: "[2024-01-01 00:00:00,2024-01-02 00:00:00)", col_tstzrange: "[2024-01-01 00:00:00+02,2024-01-02 00:00:00+02)", col_int4range: 1..10, col_int8range: "[10000000000,10000000010]" },
      2 => { col_tsrange: "[2024-03-01 00:00:00,2024-03-02 00:00:00)", col_tstzrange: "[2024-03-01 00:00:00+00,2024-03-02 00:00:00+00)", col_int4range: 20...30, col_int8range: "[20000000000,20000000010)" }
    })

    TypeVariety.update_in_bulk([
      [{ col_tsrange: "[2024-01-01 00:00:00,2024-01-02 00:00:00)" }, { col_text: "tsrange condition 1" }],
      [{ col_tsrange: "[2024-03-01 00:00:00,2024-03-02 00:00:00)" }, { col_text: "tsrange condition 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_tstzrange: "[2024-01-01 00:00:00+02,2024-01-02 00:00:00+02)" }, { col_varchar: "tstzrange cond 1" }],
      [{ col_tstzrange: "[2024-03-01 00:00:00+00,2024-03-02 00:00:00+00)" }, { col_varchar: "tstzrange cond 2" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_int4range: "[1,11)" }, { col_smallint: 11 }],
      [{ col_int4range: 20..29 }, { col_smallint: 22 }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_int8range: "[10000000000,10000000011)" }, { col_bigint: 101 }],
      [{ col_int8range: "[20000000000,20000000009]" }, { col_bigint: 202 }]
    ])

    assert_model_delta(TypeVariety, {
      1 => {
        col_tsrange: Time.utc(2024, 1, 1, 0, 0, 0)...Time.utc(2024, 1, 2, 0, 0, 0),
        col_tstzrange: Time.utc(2023, 12, 31, 22, 0, 0)...Time.utc(2024, 1, 1, 22, 0, 0),
        col_int4range: 1...11,
        col_int8range: 10_000_000_000...10_000_000_011,
        col_text: "tsrange condition 1",
        col_varchar: "tstzrange cond 1",
        col_smallint: 11,
        col_bigint: 101
      },
      2 => {
        col_tsrange: Time.utc(2024, 3, 1, 0, 0, 0)...Time.utc(2024, 3, 2, 0, 0, 0),
        col_tstzrange: Time.utc(2024, 3, 1, 0, 0, 0)...Time.utc(2024, 3, 2, 0, 0, 0),
        col_int4range: 20...30,
        col_int8range: 20_000_000_000...20_000_000_010,
        col_text: "tsrange condition 2",
        col_varchar: "tstzrange cond 2",
        col_smallint: 22,
        col_bigint: 202
      }
    })
  end

  def test_typecast_assigns_and_conditions_rails_enums_and_boolean_enums
    assert_query_sql(values: 4, cases: 0, whens: 0) do
      Book.update_in_bulk({
        1 => { cover: :hard,  status: 0,  boolean_status: false },
        2 => { cover: "soft", status: 2, boolean_status: :enabled },
        3 => { cover: :hard,  status: :written, boolean_status: :disabled }
      }, record_timestamps: false)
    end

    Book.update_in_bulk([
      [{ cover: "hard", status: "proposed", boolean_status: false }, { name: "matched by enum string" }],
      [{ cover: "soft", status: 2, boolean_status: true }, { name: "matched by enum integer" }],
      [{ cover: "hard", status: 1, boolean_status: "0" }, { name: "matched by enum boolean" }]
    ], record_timestamps: false)

    assert_model_delta(Book, {
      1 => { cover: "hard", status: "proposed", boolean_status: "disabled", name: "matched by enum string" },
      2 => { cover: "soft", status: "published", boolean_status: "enabled", name: "matched by enum integer" },
      3 => { status: "written", boolean_status: "disabled", name: "matched by enum boolean" }
    })
  end

  def test_typecast_assigns_complex_jsons
    skip unless ActiveRecord::Base.connection.supports_json?

    User.update_in_bulk({
      1 => { preferences: { color: "blue" } },
      2 => { preferences: { "width" => 1440.25, 100 => 30.to_d } },
      3 => { preferences: [{ "color" => nil, 100 => [200, "300"] }] },
    })

    assert_model_delta(User, {
      1 => { preferences: { "color" => "blue" } },
      2 => { preferences: { "width" => 1440.25, "100" => "30.0" } },
      3 => { preferences: [{ "color" => nil, "100" => [200, "300"] }] }
    })
  end

  def test_typecast_for_primitive_jsons
    skip unless ActiveRecord::Base.connection.supports_json?

    assert_query_sql(values: 2, on_width: 1, cases: 0) do
      User.update_in_bulk({
        1 => { notifications: 1 },
        2 => { notifications: "1" },
        3 => { notifications: nil },
        4 => { notifications: true }
      })
    end

    assert_model_delta(User, {
      1 => { notifications: 1 },
      2 => { notifications: "1" },
      3 => { notifications: nil },
      4 => { notifications: true }
    })
  end

  def test_typecast_for_jsons_is_not_constantized
    values = ActiveRecord::Base.connection.supports_json? ? 2 : 1

    assert_query_sql(values: values, on_width: 1, cases: 0) do
      User.update_in_bulk({
        1 => { notifications: "1" },
        2 => { notifications: "1" }
      })
    end

    assert_model_delta(User, {
      1 => { notifications: "1" },
      2 => { notifications: "1" }
    })

    assert_query_sql(values: values, on_width: 1, cases: 0) do
      User.update_in_bulk({
        1 => { notifications: nil },
        2 => { notifications: nil }
      })
    end

    assert_model_delta(User, { 1 => { notifications: nil }, 2 => { notifications: nil } })
  end

  def test_typecast_assigns_date_and_time
    TypeVariety.update_in_bulk({
      1 => { col_date: "2024-12-25 23:59:59",                     col_datetime: Time.new(2024, 12, 25, 10, 30, 0, "+02:00"),   col_time: Time.new(2024, 12, 25, 14, 45, 30, "+02:00") },
      2 => { col_date: Date.new(2024, 7, 4),                      col_datetime: Time.utc(2024, 7, 4, 20, 0, 25),               col_time: Time.parse("08:15:00") },
      3 => { col_date: Time.new(2024, 11, 3, 1, 45, 0, "+06:00"), col_datetime: DateTime.new(2024, 11, 5, 7, 45, 0, "+02:00"), col_time: "09:45" }
    })
    TypeVariety.update_in_bulk([
      [{ col_date: "2024-12-25 00:00:01" }, { col_text: "date condition 1" }],
      [{ col_date: Date.new(2024, 7, 4) }, { col_text: "date condition 2" }],
      [{ col_date: Time.new(2024, 11, 3, 12, 0, 0, "+06:00") }, { col_text: "date condition 3" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_date: Date.new(2024, 12, 25), col_datetime: Time.utc(2024, 12, 25, 8, 30, 0), col_time: time_eureka("12:45:30"), col_text: "date condition 1" },
      2 => { col_date: Date.new(2024, 7, 4),   col_datetime: Time.utc(2024, 7, 4, 20, 0, 25),  col_time: time_eureka("08:15:00"), col_text: "date condition 2" },
      3 => { col_date: Date.new(2024, 11, 3),  col_datetime: Time.utc(2024, 11, 5, 5, 45, 0),  col_time: time_eureka("09:45:00"), col_text: "date condition 3" }
    })
  end

  def test_typecast_conditions_date_and_time
    TypeVariety.update_in_bulk([
      [{ col_date: "2025-01-15 23:59:59" }, { col_text: "date match 1" }],
      [{ col_date: Date.new(2025, 6, 30) }, { col_text: "date match 2" }],
      [{ col_date: Time.new(2024, 11, 5, 1, 45, 0, "+06:00") }, { col_text: "date match 3" }],
      [{ col_date: "2025-01-16" }, { col_text: "date match 4" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_datetime: Time.new(2025, 1, 15, 11, 0, 0, "+02:00") }, { col_char: "datetime 1" }],
      [{ col_datetime: Time.utc(2025, 6, 30, 18, 30, 0) }, { col_char: "datetime 2" }],
      [{ col_datetime: DateTime.new(2024, 11, 5, 9, 45, 0, "+02:00") }, { col_char: "datetime 3" }],
      [{ col_datetime: "2025-01-15 04:30:00" }, { col_char: "datetime 4" }]
    ])
    TypeVariety.update_in_bulk([
      [{ col_time: Time.new(2025, 1, 15, 11, 0, 0, "+02:00") }, { col_varchar: "time 1" }],
      [{ col_time: Time.parse("18:30:00") }, { col_varchar: "time 2" }],
      [{ col_time: "07:45:00" }, { col_varchar: "time 3" }],
      [{ col_time: "04:30:00" }, { col_varchar: "time 4" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_text: "date match 1", col_char: "datetime 1", col_varchar: "time 1" },
      2 => { col_text: "date match 2", col_char: "datetime 2", col_varchar: "time 2" },
      3 => { col_text: "date match 3", col_char: "datetime 3", col_varchar: "time 3" }
    })
  end

  def test_typecast_assigns_timezoned_columns
    skip "Adapter does not support timezoned columns" if sqlite?

    TypeVariety.update_in_bulk({
      1 => { col_timestampz: Time.new(2024, 12, 25, 10, 30, 0, "+02:00") },
      2 => { col_timestampz: "2024-07-04 20:00:00+02:00" }
    })

    assert_model_delta(TypeVariety, {
      1 => { col_timestampz: Time.utc(2024, 12, 25, 8, 30, 0) },
      2 => { col_timestampz: Time.utc(2024, 7, 4, 18, 0, 0) }
    })
  end

  def test_typecast_conditions_timezoned_columns
    skip "Adapter does not support timezoned columns" if sqlite?

    TypeVariety.update_in_bulk({
      1 => { col_timestampz: Time.new(2024, 12, 25, 10, 30, 0, "+02:00") },
      2 => { col_timestampz: "2024-07-04 20:00:00+02:00" }
    })
    TypeVariety.update_in_bulk([
      [{ col_timestampz: "2024-12-25 10:30:00+02:00" }, { col_text: "timestampz condition 1" }],
      [{ col_timestampz: Time.new(2024, 7, 4, 16, 0, 0, "-02:00") }, { col_text: "timestampz condition 2" }]
    ])

    assert_model_delta(TypeVariety, {
      1 => { col_timestampz: Time.utc(2024, 12, 25, 8, 30, 0), col_text: "timestampz condition 1" },
      2 => { col_timestampz: Time.utc(2024, 7, 4, 18, 0, 0), col_text: "timestampz condition 2" }
    })
  end

  def test_typecast_assigns_geometry
    skip "Adapter does not support geometry" unless TestSupport::Database.mysql?

    TypeVariety.update_in_bulk({
      1 => { col_geometry: Arel.sql("ST_GeomFromText('POINT(1 2)')") },
      2 => { col_geometry: Arel.sql("ST_GeomFromText('POINT(3 4)')") }
    })
    TypeVariety.update_in_bulk([
      [{ col_geometry: Arel.sql("ST_GeomFromText('POINT(1 2)')") }, { col_text: "geometry condition 1" }],
      [{ col_geometry: Arel.sql("ST_GeomFromText('POINT(3 4)')") }, { col_text: "geometry condition 2" }]
    ])

    assert_equal "POINT(1 2)", ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT ST_AsText(col_geometry) FROM type_varieties WHERE id = 1
    SQL
    assert_equal "POINT(3 4)", ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT ST_AsText(col_geometry) FROM type_varieties WHERE id = 2
    SQL
    assert_model_delta(TypeVariety, {
      1 => { col_geometry: :_modified, col_text: "geometry condition 1" },
      2 => { col_geometry: :_modified, col_text: "geometry condition 2" }
    })
  end

  private
    def time_eureka(time)
      time = Time.parse(time)
      Time.utc(2000, 1, 1, time.hour, time.min, time.sec)
    end
end
