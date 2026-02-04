# frozen_string_literal: true

require "test_helper"
require "models"

class UpdateInBulkTest < TestCase
  fixtures :all

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
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
      ["Toyota", "Camry"] => { year: 2001 },
      ["Honda", "Civic"]  => { year: 2002 },
      ["Ford", "Civic"]   => { year: 2003 },
      ["Toyota", "Prius"] => { year: 2004 }
    })

    assert_equal 2001, Car.find(["Toyota", "Camry"]).year
    assert_equal 2002, Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Car.find(["Ford", "Mustang"]).year
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
    Car.update_in_bulk [
      [{ make: "Toyota", model: "Prius" }, { year: 2001 }],
      [{ make: "Toyota", model: "Camry" }, { year: 2002 }],
      [{ make: "Honda", model: "Civic" },  { year: 2003 }],
      [{ make: "Ford", model: "Civic" },   { year: 2004 }]
    ]

    assert_equal 2002, Car.find(["Toyota", "Camry"]).year
    assert_equal 2003, Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Car.find(["Ford", "Mustang"]).year
  end

  def test_performs_a_single_update
    assert_equal "Toyota Camry", Car.find_by!(year: 1982).full_name

    affected_rows = Car.update_in_bulk({
      ["Toyota", "Camry"] => { make: "Nissan", model: "Altima" },
      ["Nissan", "Altima"] => { make: "Chevy", model: "Corvette" }
    })

    # if the updates were "chained" the result would be Chevy Corvette
    car = Car.find_by!(year: 1982)
    assert_equal 1, affected_rows
    assert_equal "Nissan Altima", car.full_name
  end

  def test_errors_with_unknown_attribute_in_conditions
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk [[{ invalid_column: "David" }, { status: :written }]]
    end
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk([{ invalid_column: "David" }], [{ status: :written }])
    end
  end

  def test_errors_with_unknown_attribute_in_values
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

    assert_equal "Scrum Development", Book.find(1).name
    assert_equal "Django for noobies", Book.find(2).name
  end

  def test_returns_number_of_rows_affected_across_all_value_rows
    affected_rows = Comment.update_in_bulk [
      [{ post_id: 1 }, { body: "A" }],
      [{ post_id: 2 }, { body: "B" }],
      [{ post_id: 4 }, { body: "C" }]
    ]

    comments = Comment.where(post_id: [1, 2, 4]).order(:post_id).group(:post_id, :body).pluck(:post_id, :body, Arel.star.count)
    assert_equal 8, affected_rows
    assert_equal [[1, "A", 2], [2, "B", 1], [4, "C", 5]], comments
    assert_equal "go wild", Comment.find(11).body
  end

  def test_with_duplicate_keys_same_format
    Book.update_in_bulk [
      [1, { name: "Reword" }],
      [1, { name: "Peopleware" }]
    ]
    assert_includes ["Reword", "Peopleware"], Book.find(1).name
  end

  def test_with_duplicate_keys_mixed_formats
    Book.update_in_bulk [
      [1, { name: "Reword" }],
      [{ id: 1 }, { name: "Peopleware" }]
    ]
    assert_includes ["Reword", "Peopleware"], Book.find(1).name
  end

  def test_with_no_hits_does_not_error
    affected_rows = Book.update_in_bulk [
      [{ id: 1234 }, { name: "Reword" }],
      [{ id: 4567 }, { name: "Peopleware" }]
    ]

    assert_equal 0, affected_rows
  end

  def test_conditions_are_and_combined
    Comment.update_in_bulk [
      [{ post_id: 4, type: "Comment" },        { body: "A" }],
      [{ post_id: 4, type: "SpecialComment" }, { body: "B" }],
      [{ post_id: 5, type: "SpecialComment" }, { body: "C" }]
    ]

    comments = Comment.where(body: ["A", "B", "C"]).pluck(:id, :body).sort
    assert_equal [[6, "B"], [7, "B"], [8, "A"], [10, "C"]], comments
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
    assert_equal "First comment", Comment.find(1).body
    assert_equal "Second comment", Comment.find(2).body
  end

  def test_supports_non_referential_arel_sql_in_values
    Comment.update_in_bulk([
      [{ id: 1 }, { body: Arel.sql("(SELECT name FROM books WHERE id = 1)") }],
      [{ id: 2 }, { body: "Second comment" }]
    ])
    assert_equal "Agile Web Development with Rails", Comment.find(1).body
    assert_equal "Second comment", Comment.find(2).body
  end

  def test_optional_keys_without_nulls
    Book.update_in_bulk({
      2 => { author_visibility: :invisible, language: :french, font_size: :large },
      3 => { difficulty: :medium, font_size: :medium },
      4 => { cover: "soft", language: :spanish, font_size: :large },
    })

    # initial: [visible english easy hard small]
    books = Book.where(id: 2..4).order(:id).to_a
    assert_equal %[invisible french easy hard large], books[0].parameters
    assert_equal %[visible english medium hard medium], books[1].parameters
    assert_equal %[visible spanish easy soft large], books[2].parameters
  end

  def test_optional_keys_with_nulls
    Book.update_in_bulk({
      2 => { author_visibility: :invisible, language: nil, font_size: :large },
      3 => { difficulty: nil, font_size: :medium },
      4 => { cover: "soft", language: :spanish, font_size: nil },
    })

    # initial: [visible english easy hard small]
    books = Book.where(id: 2..4).order(:id).to_a
    assert_equal %[invisible - easy hard large], books[0].parameters
    assert_equal %[visible english - hard medium], books[1].parameters
    assert_equal %[visible spanish easy soft -], books[2].parameters
  end

  def test_optional_keys_with_arel_sql_null
    Book.update_all(format: "default")

    Book.update_in_bulk({
      2 => { name: "Second book" },
      3 => { format: Arel.sql("NULL") }
    })

    assert_equal "default", Book.find(2).format
    assert_nil Book.find(3).format
  end

  def test_resets_relation
    author = Author.create!(id: 1, name: "Albert")
    author.books.load

    assert_changes "author.books.loaded?", from: true, to: false do
      author.books.update_in_bulk({ 1 => { name: "updated" } })
    end
  end

  def test_does_not_reset_relation_if_updates_is_empty
    author = Author.create!(id: 1, name: "Albert")
    author.books.load

    assert_no_changes "author.books.loaded?" do
      author.books.update_in_bulk({})
    end
  end

  def test_resets_relation_even_when_affected_rows_is_zero
    author = Author.create!(id: 1, name: "Albert")
    author.books.load

    assert_changes "author.books.loaded?", from: true, to: false do
      author.books.update_in_bulk({ 1337 => { name: "updated" } })
    end
  end

  def test_on_has_many_relation
    author = Author.create!(id: 123, name: "Jimmy")
    author.books.insert_all! [
      { id: 10, name: "Apple 1", status: :proposed },
      { id: 11, name: "Apple 2", status: :written },
      { id: 12, name: "Apple 3", status: :published }
    ]

    affected_rows = author.books.update_in_bulk [
      [{ status: :proposed }, { name: "Banana 1" }],
      [{ status: :written }, { name: "Banana 2" }]
    ]
    assert_equal 2, affected_rows
    assert_equal ["Ruby for Rails", "proposed"], Book.find(2).values_at(:name, :status)
    assert_equal ["Banana 1", "Banana 2", "Apple 3"], author.books.sort_by(&:id).map(&:name)
  end

  def test_with_group_by
    minimum_comments_count = 2
    good_post = Post.joins(:comments).group("posts.id").having("count(comments.id) < #{minimum_comments_count}").first.id
    bad_post = Post.joins(:comments).group("posts.id").having("count(comments.id) >= #{minimum_comments_count}").first.id

    assert_raises(NotImplementedError) do
      Post.most_commented(minimum_comments_count).update_in_bulk({
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
  end

  def test_with_sti_can_override_sti_type
    assert_equal 0, Category.count

    Category.insert_all! [
      { id: 1, name: "First", type: "SpecialCategory" },
      { id: 2, name: "Second", type: "SpecialCategory" },
      { id: 3, name: "Third", type: "Category" }
    ]
    SpecialCategory.update_in_bulk({
      1 => { name: "1st", type: "SpecialCategory" },
      2 => { name: "2nd", type: "Category" },
      3 => { name: "3rd", type: "SpecialCategory" } # not updated
    })

    assert_equal ["1st", "2nd", "Third"], Category.order(:id).pluck(:name)
    assert_equal ["SpecialCategory", "Category", "Category"], Category.order(:id).pluck(:type)
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
  end

  def test_with_left_outer_joins
    pets = Pet.left_outer_joins(:toys).where(toys: { name: ["Bone", nil] })

    assert_equal true, pets.exists?
    assert_equal 2, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" },
      3 => { name: "Rex" }
    })
  end

  def test_with_includes
    pets = Pet.includes(:toys).where(toys: { name: "Bone" })

    assert_equal true, pets.exists?
    assert_equal 1, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" }
    })
  end

  def test_same_column_as_condition_and_assign
    Comment.update_in_bulk([
      [{ post_id: 1 }, { post_id: 2 }]
    ])

    assert_equal [2], Comment.where(id: [1, 2]).pluck(:post_id).uniq
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_when_table_name_contains_database
      database_name = Book.connection_db_config.database
      Book.table_name = "#{database_name}.books"

      assert_nothing_raised do
        Book.update_in_bulk [[{ id: 1 }, { name: "Rework" }]]
      end
    ensure
      Book.table_name = "books"
    end
  end

  def test_constant_condition_column_is_inlined
    assert_queries_match(/ON .?comments...post_id.? = (?:CAST\()?4/i) do
      assert_queries_match(/\('SpecialComment', 'inline B'\)/) do
        Comment.update_in_bulk([
          [{ post_id: 4, type: "Comment" },        { body: "inline A" }],
          [{ post_id: 4, type: "SpecialComment" }, { body: "inline B" }]
        ])
      end
    end

    assert_equal "inline A", Comment.find(8).body  # Comment, post_id=4
    assert_equal "inline B", Comment.find(6).body  # SpecialComment, post_id=4
    assert_equal "inline B", Comment.find(7).body  # SpecialComment, post_id=4
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

    books = Book.where(id: 1..3).order(:id).to_a
    assert_equal %w[Book-A Book-B Book-C], books.map(&:name)
    assert_equal %w[written written written], books.map(&:status)
  end

  def test_formula_prevents_assign_inlining
    ProductStock.update_in_bulk({
      "Tree" => { quantity: 5 },
      "Wreath" => { quantity: 5 }
    }, formulas: { quantity: :add })

    assert_equal 15, ProductStock.find("Tree").quantity
    assert_equal 55, ProductStock.find("Wreath").quantity
  end

  def test_constant_assign_with_mixed_types_is_inlined
    assert_queries_match(/SET.+status. = (?:CAST\()?1\b/i) do
      Book.update_in_bulk({
        1 => { name: "Book A", status: :written },
        2 => { name: "Book B", status: "written" }
      })
    end

    books = Book.where(id: [1, 2]).order(:id).to_a
    assert_equal %w[Book\ A Book\ B], books.map(&:name)
    assert_equal %w[written written], books.map(&:status)
  end

  def test_mixed_constant_and_variable_columns
    Book.update_in_bulk({
      1 => { name: "Updated-1", status: :written, cover: "soft" },
      2 => { name: "Updated-2", status: :written, cover: "hard" }
    })

    books = Book.where(id: [1, 2]).order(:id).to_a
    assert_equal %w[Updated-1 Updated-2], books.map(&:name)
    assert_equal %w[written written], books.map(&:status)
    assert_equal %w[soft hard], books.map(&:cover)
  end

  def test_all_columns_constant_skips_optimization
    Book.update_in_bulk({ 1 => { name: "Solo" } })
    assert_equal "Solo", Book.find(1).name

    # Multi-row where everything is identical
    Book.update_in_bulk({
      1 => { status: :published },
      2 => { status: :published }
    })
    assert_equal %w[published published], Book.where(id: [1, 2]).order(:id).pluck(:status)
  end

  def test_single_row_without_formulas_uses_simple_update_without_values_table
    capture_log_output do |output|
      Book.update_in_bulk({ 1 => { name: "Simple Update" } })
      sql_log = output.string
      assert_match(/\bUPDATE\b/i, sql_log)
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_equal "Simple Update", Book.find(1).name
  end

  def test_single_row_with_multiple_conditions_uses_simple_update_without_values_table
    capture_log_output do |output|
      Book.update_in_bulk([[{ id: 1, status: :published }, { name: "Simple Conditions" }]])
      sql_log = output.string
      assert_match(/\bUPDATE\b/i, sql_log)
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_equal "Simple Conditions", Book.find(1).name
  end

  def test_single_row_with_formulas_does_not_use_simple_update_optimization
    capture_log_output do |output|
      ProductStock.update_in_bulk({ "Tree" => { quantity: 1 } }, formulas: { quantity: :add })
      sql_log = output.string
      assert_match(/\bJOIN \((VALUES|SELECT) /i, sql_log)
    end

    assert_equal 11, ProductStock.find("Tree").quantity
  end

  def test_single_row_simple_update_no_formulas
    capture_log_output do |output|
      Book.update_in_bulk([{ id: 2 }], [{ name: "Separated Simple" }])
      sql_log = output.string
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_equal "Separated Simple", Book.find(2).name
  end

  def test_single_row_simple_update_with_timestamps
    capture_log_output do |output|
      Book.update_in_bulk([{ id: 2 }], [{ name: "Separated Simple" }], record_timestamps: true)
      sql_log = output.string
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_equal "Separated Simple", Book.find(2).name
  end

  def test_single_row_simple_update_with_explicit_nil_assign
    capture_log_output do |output|
      Book.update_in_bulk({ 2 => { format: nil } })
      sql_log = output.string
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_nil Book.find(2).format
    assert_equal "hardcover", Book.find(3).format
  end

  def test_single_row_simple_update_with_explicit_hash_conditions
    Book.update_in_bulk([[{ id: 1, status: :proposed }, { name: "Should Not Change" }]])
    assert_equal "Agile Web Development with Rails", Book.find(1).name

    capture_log_output do |output|
      Book.update_in_bulk([[{ id: 1, status: :published }, { name: "Hash Conditions" }]])
      sql_log = output.string
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_equal "Hash Conditions", Book.find(1).name
    assert_equal "Ruby for Rails", Book.find(2).name
  end

  def test_single_row_simple_update_with_composite_primary_key
    capture_log_output do |output|
      Car.update_in_bulk({ ["Toyota", "Camry"] => { year: 2001 } })
      sql_log = output.string
      assert_no_match(/\bVALUES\b/i, sql_log)
      assert_no_match(/\bJOIN\b/i, sql_log)
    end

    assert_equal 2001, Car.find(["Toyota", "Camry"]).year
    assert_equal 1972, Car.find(["Honda", "Civic"]).year
    assert_equal 1964, Car.find(["Ford", "Mustang"]).year
  end

  def test_arel_sql_prevents_assign_inlining
    subquery = "(SELECT name FROM books WHERE id = 1)"
    Post.update_in_bulk([
      [{ id: 1 }, { title: subquery }],
      [{ id: 2 }, { title: Arel.sql(subquery) }],
      [{ id: 3 }, { title: subquery }]
    ])

    assert_equal subquery, Post.find(1).title
    assert_equal "Agile Web Development with Rails", Post.find(2).title
  end

  def test_arel_sql_prevents_condition_inlining
    subquery = "(SELECT 'Welcome to the weblog')"
    Post.update_in_bulk([
      [{ title: subquery }, { body: "A" }],
      [{ title: Arel.sql(subquery) }, { body: "B" }],
      [{ title: subquery }, { body: "C" }]
    ])

    assert_includes ["A", "C"], Post.find(7).body
    assert_equal "B", Post.find(1).body
  end

  def test_constant_condition_and_constant_assign_together
    Comment.update_in_bulk([
      [{ post_id: 4, type: "Comment" },        { body: "same body" }],
      [{ post_id: 4, type: "SpecialComment" }, { body: "same body" }]
    ])

    assert_equal "same body", Comment.find(8).body   # Comment, post_id=4
    assert_equal "same body", Comment.find(6).body   # SpecialComment, post_id=4
    assert_equal "Don't think too hard", Comment.find(3).body  # post_id=2 (untouched)
  end
end
