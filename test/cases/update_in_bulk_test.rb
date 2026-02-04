# frozen_string_literal: true

require "test_helper"
require "models"

class UpdateInBulkTest < TestCase
  fixtures :all

  def setup
    Book.record_timestamps = false
  end

  def teardown
    Book.record_timestamps = true
  end

  def test_paired_format
    Book.update_in_bulk [
      [{ id: 1 }, { name: "Scrum Development" }],
      [2, { name: "Django for noobies" }],
      [[3], { name: "Data-Driven Design" }]
    ]

    assert_equal "Scrum Development", Book.find(1).name
    assert_equal "Django for noobies", Book.find(2).name
    assert_equal "Data-Driven Design", Book.find(3).name
    assert_equal "Thoughtleadering", Book.find(4).name
  end

  def test_hash_format
    Book.update_in_bulk({
      1 => { name: "Scrum Development" },
      [2] => { name: "Django for noobies" }
    })

    assert_equal "Scrum Development", Book.find(1).name
    assert_equal "Django for noobies", Book.find(2).name
    assert_equal "Domain-Driven Design", Book.find(3).name
    assert_equal "Thoughtleadering", Book.find(4).name
  end

  def test_separated_format
    Book.update_in_bulk(
      [1, [2], { id: 3 }],
      [{ name: "Scrum Development" }, { name: "Django for noobies" }, { name: "Data-Driven Design" }]
    )

    assert_equal "Scrum Development", Book.find(1).name
    assert_equal "Django for noobies", Book.find(2).name
    assert_equal "Data-Driven Design", Book.find(3).name
    assert_equal "Thoughtleadering", Book.find(4).name
  end

  def test_paired_format_composite
    Car.all.update_in_bulk(
      [["Toyota", "Camry"], { make: "Honda", model: "Civic" }],
      [{ year: 2001 }, { year: 2002 }]
    )

    assert_equal 2001, Car.find(["Toyota", "Camry"]).year
    assert_equal 2002, Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Car.find(["Ford", "Mustang"]).year
  end

  def test_hash_format_composite
    Car.all.update_in_bulk({
      ["Toyota", "Camry"]  => { year: 2001 },
      ["Honda", "Civic"]   => { year: 2002 },
      ["Ford", "Civic"]    => { year: 2003 },
      ["Model 3", "Tesla"] => { year: 2004 }, # wrong order
      ["Toyota", "Prius"]  => { year: 2005 }
    })

    assert_equal 2001, Car.find(["Toyota", "Camry"]).year
    assert_equal 2002, Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Car.find(["Ford", "Mustang"]).year
    assert_equal 2017, Car.find(["Tesla", "Model 3"]).year
  end

  def test_separated_format_composite
    Car.all.update_in_bulk(
      [["Toyota", "Camry"], ["Honda", "Civic"]],
      [{ year: 2001 }, { year: 2002 }]
    )

    assert_equal 2001, Car.find(["Toyota", "Camry"]).year
    assert_equal 2002, Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Car.find(["Ford", "Mustang"]).year
  end

  def test_length_mismatch_separated_format
    assert_raises(ArgumentError) do
      Book.update_in_bulk([1, 2], [{ name: "Scrum Development" }])
    end
  end

  def test_without_conditions
    assert_raises(ArgumentError) do
      Book.update_in_bulk({ [] => { name: "Scrum Development" } })
    end
    assert_raises(ArgumentError) do
      Book.update_in_bulk [[{}, { name: "Scrum Development" }]]
    end
    assert_raises(ArgumentError) do
      Book.update_in_bulk([{}], [{ name: "Scrum Development" }])
    end
  end

  def test_without_values_or_assigns
    assert_no_queries do
      assert_equal 0, Book.update_in_bulk([])
      assert_equal 0, Book.update_in_bulk({})
      assert_equal 0, Book.update_in_bulk({ 1 => {} })
      assert_equal 0, Book.update_in_bulk([[{ id: 1 }, {}]])
      assert_equal 0, Book.update_in_bulk([1], [{}])
    end
  end

  def test_with_multiple_conditions_ands_them
    assert_query_sql(values: 3, on_width: 2) do
      Car.update_in_bulk [
        [{ make: "Toyota", model: "Prius" }, { year: 2001 }],
        [{ make: "Toyota", model: "Camry" }, { year: 2002 }],
        [{ make: "Honda", model: "Civic" },  { year: 2003 }],
        [{ make: "Ford", model: "Civic" },   { year: 2004 }]
      ]
    end
    assert_model_delta(Car, {
      ["Toyota", "Camry"] => { year: 2002 },
      ["Honda", "Civic"] => { year: 2003 }
    })
  end

  def test_performs_a_single_update
    assert_equal "Toyota Camry", Car.find_by!(year: 1982).full_name

    assert_equal 1, Car.update_in_bulk({
      ["Toyota", "Camry"] => { make: "Nissan", model: "Altima" },
      ["Nissan", "Altima"] => { make: "Chevy", model: "Corvette" }
    })

    # if the updates were "chained" the result would be Chevy Corvette
    car = Car.find_by!(year: 1982)
    assert_equal "Nissan Altima", car.full_name
    assert_model_delta(Car, {
      ["Toyota", "Camry"] => :deleted,
      ["Nissan", "Altima"] => :created
    })
  end

  def test_errors_with_unknown_attribute_in_conditions
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk [[{ invalid_column: "David" }, { status: :written }]]
    end
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk([{ invalid_column: "David" }], [{ status: :written }])
    end
  end

  def test_errors_with_unknown_attribute_in_assigns
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk [[{ id: 1 }, { invalid_column: "Invalid" }]]
    end
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk([{ id: 1 }], [{ invalid_column: "Invalid" }])
    end
  end

  def test_cannot_reference_joined_tables_in_conditions
    # This could be supported in the future
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.joins(:author).update_in_bulk [[{ "author.nick": "David" }, { status: :written }]]
    end
  end

  def test_with_aliased_attributes
    Book.update_in_bulk [
      [1, { title: "Scrum Development" }],
      [2, { title: "Django for noobies" }]
    ]

    assert_model_delta(Book, {
      1 => { name: "Scrum Development" },
      2 => { name: "Django for noobies" }
    })
  end

  def test_returns_number_of_rows_affected_across_all_value_rows
    assert_equal 8, Comment.update_in_bulk([
      [{ post_id: 1 }, { body: "A" }],
      [{ post_id: 2 }, { body: "B" }],
      [{ post_id: 4 }, { body: "C" }]
    ])

    assert_model_delta(Comment, {
      1 => { body: "A", updated_at: :_modified },
      2 => { body: "A", updated_at: :_modified },
      3 => { body: "B", updated_at: :_modified },
      5 => { body: "C", updated_at: :_modified },
      6 => { body: "C", updated_at: :_modified },
      7 => { body: "C", updated_at: :_modified },
      8 => { body: "C", updated_at: :_modified },
      12 => { body: "C", updated_at: :_modified }
    })
  end

  def test_with_duplicate_keys_same_format
    Book.update_in_bulk [
      [1, { name: "Reword" }],
      [1, { name: "Peopleware" }]
    ]
    assert_includes ["Reword", "Peopleware"], Book.find(1).name
    assert_model_delta(Book, { 1 => { name: :_modified } })
  end

  def test_with_duplicate_keys_mixed_formats
    Book.update_in_bulk [
      [1, { name: "Reword" }],
      [{ id: 1 }, { name: "Peopleware" }]
    ]
    assert_includes ["Reword", "Peopleware"], Book.find(1).name
    assert_model_delta(Book, { 1 => { name: :_modified } })
  end

  def test_with_no_hits_does_not_error
    assert_equal 0, Book.update_in_bulk([
      [{ id: 1234 }, { name: "Reword" }],
      [{ id: 4567 }, { name: "Peopleware" }]
    ])

    assert_model_delta(Book, {})
  end

  def test_conditions_are_and_combined
    assert_query_sql(values: 3, on_width: 2) do
      Comment.update_in_bulk [
        [{ post_id: 4, type: "Comment" },        { body: "A" }],
        [{ post_id: 4, type: "SpecialComment" }, { body: "B" }],
        [{ post_id: 5, type: "SpecialComment" }, { body: "C" }]
      ]
    end

    assert_model_delta(Comment, {
      6 => { body: "B", updated_at: :_modified },
      7 => { body: "B", updated_at: :_modified },
      8 => { body: "A", updated_at: :_modified },
      10 => { body: "C", updated_at: :_modified }
    })
  end

  def test_does_not_support_referential_arel_sql_in_conditions
    assert_raises(ActiveRecord::StatementInvalid) do
      Comment.update_in_bulk([
        [{ parent_id: 1 }, { body: "Normal comment" }],
        [{ parent_id: Arel.sql("comments.post_id") }, { body: "Root comment" }]
      ])
    end
  end

  def test_does_not_support_referential_arel_sql_in_values
    assert_raises(ActiveRecord::StatementInvalid) do
      Book.update_in_bulk([
        [{ id: 1 }, { name: "Joao" }],
        [{ id: 2 }, { name: Arel.sql("UPPER(name)") }]
      ])
    end
  end

  def test_supports_non_referential_arel_sql_in_conditions
    Comment.update_in_bulk([
      [{ id: 2 }, { body: "Second comment" }],
      [{ id: Arel.sql("(SELECT id FROM books ORDER BY id ASC LIMIT 1)") }, { body: "First comment" }]
    ])
    assert_model_delta(Comment, {
      1 => { body: "First comment", updated_at: :_modified },
      2 => { body: "Second comment", updated_at: :_modified }
    })
  end

  def test_supports_non_referential_arel_sql_in_values
    Comment.update_in_bulk([
      [{ id: 1 }, { body: Arel.sql("(SELECT name FROM books WHERE id = 1)") }],
      [{ id: 2 }, { body: "Second comment" }]
    ])
    assert_model_delta(Comment, {
      1 => { body: "Agile Web Development with Rails", updated_at: :_modified },
      2 => { body: "Second comment", updated_at: :_modified }
    })
  end

  def test_optional_keys_without_nulls
    Book.update_in_bulk({
      2 => { author_visibility: :invisible, language: :french, font_size: :large },
      3 => { difficulty: :medium, font_size: :medium, last_read: :forgotten },
      4 => { cover: "soft", language: :spanish, font_size: :large },
    })

    # initial: [visible english easy hard small]
    assert_model_delta(Book, {
      2 => { author_visibility: "invisible", language: "french", font_size: "large" },
      3 => { difficulty: "medium", font_size: "medium" },
      4 => { cover: "soft", language: "spanish", font_size: "large" }
    })
  end

  def test_optional_keys_with_nulls
    Book.update_in_bulk({
      2 => { author_visibility: :invisible, language: nil, font_size: :large },
      3 => { difficulty: nil, font_size: :medium },
      4 => { cover: "soft", language: :spanish, font_size: nil },
    })

    # initial: [visible english easy hard small]
    assert_model_delta(Book, {
      2 => { author_visibility: "invisible", language: nil, font_size: "large" },
      3 => { difficulty: nil, font_size: "medium" },
      4 => { cover: "soft", language: "spanish", font_size: nil }
    })
  end

  def test_optional_keys_with_arel_sql_null
    Book.update_all(format: "default")

    Book.update_in_bulk({
      2 => { name: "Second book" },
      3 => { format: Arel.sql("NULL") }
    })

    assert_model_delta(Book, {
      1 => { format: "default" },
      2 => { name: "Second book", format: "default" },
      3 => { format: nil },
      4 => { format: "default" }
    })
  end

  def test_resets_relation
    author = Author.find(1)
    author.books.load

    assert_changes "author.books.loaded?", from: true, to: false do
      author.books.update_in_bulk({ 1 => { name: "updated" } })
    end
    assert_model_delta(Book, { 1 => { name: "updated" } })
  end

  def test_does_not_reset_relation_if_updates_is_empty
    author = Author.find(1)
    author.books.load

    assert_no_changes "author.books.loaded?" do
      author.books.update_in_bulk({})
    end
    assert_model_delta(Book, {})
  end

  def test_resets_relation_even_when_affected_rows_is_zero
    author = Author.find(1)
    author.books.load

    assert_changes "author.books.loaded?", from: true, to: false do
      author.books.update_in_bulk({ 1337 => { name: "updated" } })
    end
    assert_model_delta(Book, {})
  end

  def test_on_has_many_relation
    author = Author.find(123)
    author.books.insert_all! [
      { id: 10, name: "Apple 1", status: :proposed },
      { id: 11, name: "Apple 2", status: :written },
      { id: 12, name: "Apple 3", status: :published }
    ]

    assert_equal 2, author.books.update_in_bulk([
      [{ status: :proposed }, { name: "Banana 1" }],
      [{ status: :written }, { name: "Banana 2" }]
    ])
    assert_equal ["Ruby for Rails", "proposed"], Book.find(2).values_at(:name, :status)
    assert_equal ["Banana 1", "Banana 2", "Apple 3"], author.books.sort_by(&:id).map(&:name)
  end

  def test_with_group_by
    cnt = 2
    good_post = Post.joins(:comments).group("posts.id").having("count(comments.id) < ?", cnt).first.id
    bad_post = Post.joins(:comments).group("posts.id").having("count(comments.id) >= ?", cnt).first.id

    assert_raises(NotImplementedError) do
      Post.joins(:comments).group("posts.id").having("count(comments.id) >= ?", cnt).update_in_bulk({
        good_post => { title: "ig" },
        bad_post => { title: "ig" }
      })
    end
  end

  def test_with_order_limit_offset
    assert_raises(NotImplementedError) do
      Post.where(id: 1..6).order(id: :desc).limit(3).offset(2).update_in_bulk([
        [{ author_id: 0 }, { body: "ig0" }],
        [{ author_id: 1 }, { body: "ig1" }]
      ])
    end
  end

  def test_with_nil_condition
    assert_raises(NotImplementedError, match: /NULL condition/) do
      Book.update_in_bulk [
        [{ id: 4 }, { name: "Reword" }],
        [{ id: nil }, { name: "Peopleware" }]
      ]
    end
  end

  def test_with_nil_composite_primary_key
    assert_raises(NotImplementedError, match: /NULL condition/) do
      Car.update_in_bulk({
        ["Toyota", "Camry"] => { year: 1024 },
        ["Honda", nil]      => { year: 1025 }
      })
    end
    assert_model_delta(Car, {})
  end

  def test_with_sti_can_override_sti_type
    SpecialCategory.update_in_bulk({
      1 => { name: "1st", type: "SpecialCategory" },
      2 => { name: "2nd", type: "Category" },
      3 => { name: "3rd", type: "SpecialCategory" } # not updated
    })

    assert_model_delta(Category, {
      1 => { name: "1st" },
      2 => { name: "2nd", type: "Category" },
    })
  end

  def test_logs_message_including_model_name
    capture_log_output do |output|
      Book.update_in_bulk({
        1 => { name: "Scrum Development" },
        2 => { name: "Django for noobies" }
      })
      assert_match "Book Update in Bulk", output.string
    end
  end

  def test_with_left_joins
    pets = Pet.left_joins(:toys).where(toys: { name: ["Bone", nil] })

    assert_equal true, pets.exists?
    assert_equal 2, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" },
      3 => { name: "Rex" }
    })
    assert_model_delta(Pet, {
      1 => { name: "Rex", updated_at: :_modified },
      3 => { name: "Rex", updated_at: :_modified }
    })
  end

  def test_with_includes
    pets = Pet.includes(:toys).where(toys: { name: "Bone" })

    assert_equal true, pets.exists?
    assert_equal 1, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" }
    })
    assert_model_delta(Pet, { 1 => { name: "Rex", updated_at: :_modified } })
  end

  def test_same_column_as_condition_and_assign
    Comment.update_in_bulk([
      [{ post_id: 1 }, { post_id: 2 }]
    ])

    assert_model_delta(Comment, {
      1 => { post_id: 2, updated_at: :_modified },
      2 => { post_id: 2, updated_at: :_modified }
    })
  end

  def test_when_table_name_contains_database
    skip unless current_adapter?(:Mysql2Adapter, :TrilogyAdapter)

    begin
      database_name = Book.connection_db_config.database
      Book.table_name = "#{database_name}.books"

      assert_nothing_raised do
        Book.update_in_bulk [[{ id: 1 }, { name: "Rework" }]]
      end
    ensure
      Book.table_name = "books"
    end
  end

  def test_constant_assign_column_is_inlined
    assert_queries_match(/SET.+status. = (?:CAST\()?1\b/i) do
      assert_queries_match(/\(2, 'Book-B'\)/) do
        Book.update_in_bulk({
          1 => { name: "Book-A", status: :written },
          2 => { name: "Book-B", status: :written },
          3 => { name: "Book-C", status: :written }
        })
      end
    end

    assert_model_delta(Book, {
      1 => { name: "Book-A", status: "written" },
      2 => { name: "Book-B", status: "written" },
      3 => { name: "Book-C", status: "written" }
    })
  end

  def test_formula_prevents_assign_inlining
    assert_query_sql(values: 2, on_width: 1, cases: 0) do
      ProductStock.update_in_bulk({
        "Tree" => { quantity: 5 },
        "Wreath" => { quantity: 5 }
      }, formulas: { quantity: :add })
    end

    assert_model_delta(ProductStock, {
      "Tree" => { quantity: 15 },
      "Wreath" => { quantity: 55 }
    })
  end

  def test_constant_assign_with_mixed_types_is_not_inlined
    assert_query_sql(values: 3, cases: 0) do
      Book.update_in_bulk({
        1 => { name: "Book A", status: :written },
        2 => { name: "Book B", status: "written" }
      })
    end

    assert_model_delta(Book, {
      1 => { name: "Book A", status: "written" },
      2 => { name: "Book B", status: "written" }
    })
  end

  def test_mixed_constant_and_variable_columns
    Book.update_in_bulk({
      1 => { name: "Updated-1", status: :written, cover: "hard" },
      2 => { name: "Updated-2", status: :written, cover: "hard" }
    })

    assert_model_delta(Book, {
      1 => { name: "Updated-1", status: "written", cover: "hard" },
      2 => { name: "Updated-2", status: "written" }
    })
  end

  def test_single_row_without_formulas_uses_simple_update_without_values_table
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk({ 1 => { name: "Simple Update" } })
    end

    assert_model_delta(Book, { 1 => { name: "Simple Update" } })
  end

  def test_single_row_with_multiple_conditions_uses_simple_update_without_values_table
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([[{ id: 1, status: :published }, { name: "Simple Conditions" }]])
    end

    assert_model_delta(Book, { 1 => { name: "Simple Conditions" } })
  end

  def test_single_row_with_formulas_does_not_use_simple_update_optimization
    assert_query_sql(values: 2, on_width: 1) do
      ProductStock.update_in_bulk({ "Tree" => { quantity: 1 } }, formulas: { quantity: :add })
    end

    assert_model_delta(ProductStock, { "Tree" => { quantity: 11 } })
  end

  def test_single_row_simple_update_no_formulas
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([{ id: 2 }], [{ name: "Separated Simple" }])
    end

    assert_model_delta(Book, { 2 => { name: "Separated Simple" } })
  end

  def test_single_row_simple_update_with_timestamps
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([{ id: 2 }], [{ name: "Separated Simple" }], record_timestamps: true)
    end

    assert_model_delta(Book, { 2 => { name: "Separated Simple", updated_at: :_modified } })
  end

  def test_single_row_simple_update_with_explicit_nil_assign
    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk({ 2 => { format: nil } })
    end

    assert_model_delta(Book, { 2 => { format: nil } })
  end

  def test_single_row_simple_update_with_explicit_hash_conditions
    assert_equal 0, Book.update_in_bulk([[{ id: 1, status: :proposed }, { name: "Should Not Change" }]])

    assert_query_sql(values: false, on_width: 0) do
      Book.update_in_bulk([[{ id: 1, status: :published }, { name: "Hash Conditions" }]])
    end

    assert_model_delta(Book, { 1 => { name: "Hash Conditions" } })
  end

  def test_single_row_simple_update_with_composite_primary_key
    assert_query_sql(values: false, on_width: 0) do
      Car.update_in_bulk({ ["Toyota", "Camry"] => { year: 2001 } })
    end

    assert_model_delta(Car, { ["Toyota", "Camry"] => { year: 2001 } })
  end

  def test_arel_sql_prevents_assign_inlining
    subquery = "(SELECT name FROM books WHERE id = 1)"
    Post.update_in_bulk([
      [{ id: 1 }, { title: subquery }],
      [{ id: 2 }, { title: Arel.sql(subquery) }],
      [{ id: 3 }, { title: subquery }]
    ])

    assert_model_delta(Post, {
      1 => { title: subquery },
      2 => { title: "Agile Web Development with Rails" },
      3 => { title: subquery }
    })
  end

  def test_arel_sql_prevents_condition_inlining
    subquery = "(SELECT 'Welcome to the weblog')"
    Post.update_in_bulk([
      [{ title: subquery }, { body: "A" }],
      [{ title: Arel.sql(subquery) }, { body: "B" }],
      [{ title: subquery }, { body: "C" }]
    ])

    assert_model_delta(Post, {
      1 => { body: "B" },
      7 => { body: :_modified }
    })
  end
end
