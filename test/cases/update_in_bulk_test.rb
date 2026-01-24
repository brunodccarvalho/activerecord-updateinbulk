# frozen_string_literal: true

require "test_helper"
require "models"

class UpdateInBulkTest < ActiveSupport::TestCase
  fixtures :users, :books, :comments, :cars, :posts, :pets, :toys

  def setup
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
    Book.record_timestamps = false
  end

  def teardown
    Book.record_timestamps = true
  end

  def test_update_in_bulk_uniform_array_format
    Book.update_in_bulk [
      [{ id: 1 }, { name: "Updated Book 1" }],
      [{ id: 2 }, { name: "Updated Book 2" }]
    ]

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
    assert_no_match(/Updated Book/, Book.find(3).name)
  end

  def test_update_in_bulk_uniform_hash_format
    Book.update_in_bulk({
      1 => { name: "Updated Book 1" },
      [2] => { name: "Updated Book 2" }
    })

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
    assert_no_match(/Updated Book/, Book.find(3).name)
  end

  def test_update_in_bulk_by_uniform_hash_format_composite
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

  def test_update_in_bulk_without_conditions
    assert_raises(ArgumentError) do
      Book.update_in_bulk({ [] => { name: "Updated Book 1" } })
    end
    assert_raises(ArgumentError) do
      Book.update_in_bulk [[{}, { name: "Updated Book 1" }]]
    end
  end

  def test_update_in_bulk_without_values_or_statements
    assert_no_queries do
      assert_equal 0, Book.update_in_bulk([])
      assert_equal 0, Book.update_in_bulk({})
      assert_equal 0, Book.update_in_bulk({ 1 => {} })
      assert_equal 0, Book.update_in_bulk([[{ id: 1 }, {}]])
    end
  end

  def test_update_in_bulk_with_multiple_conditions
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

  def test_update_in_bulk_performs_a_single_update
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

  def test_update_in_bulk_with_unknown_attribute_in_conditions
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk [[{ invalid_column: "David" }, { status: :written }]]
    end
  end

  def test_update_in_bulk_with_unknown_attribute_in_values
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.update_in_bulk [[{ id: 1 }, { invalid_column: "Invalid" }]]
    end
  end

  def test_update_in_bulk_cannot_reference_joined_tables_in_conditions
    # This could be supported in the future
    assert_raises(ActiveRecord::UnknownAttributeError) do
      Book.joins(:author).update_in_bulk [[{ "author.nick": "David" }, { status: :written }]]
    end
  end

  def test_update_in_bulk_with_aliased_attributes
    Book.update_in_bulk [
      [{ id: 1 }, { title: "Updated Book 1" }],
      [{ id: 2 }, { title: "Updated Book 2" }]
    ]

    assert_equal "Updated Book 1", Book.find(1).name
    assert_equal "Updated Book 2", Book.find(2).name
  end

  def test_update_in_bulk_returns_number_of_rows_affected_across_all_value_rows
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

  def test_update_in_bulk_with_duplicate_keys_does_not_error
    Book.update_in_bulk [
      [{ id: 1 }, { name: "Reword" }],
      [{ id: 1 }, { name: "Peopleware" }]
    ]

    assert_includes ["Reword", "Peopleware"], Book.find(1).name
  end

  def test_update_in_bulk_with_no_hits_does_not_error
    affected_rows = Book.update_in_bulk [
      [{ id: 1234 }, { name: "Reword" }],
      [{ id: 4567 }, { name: "Peopleware" }]
    ]

    assert_equal 0, affected_rows
  end

  def test_update_in_bulk_conditions_are_and_combined
    Comment.update_in_bulk [
      [{ post_id: 4, type: "Comment" },        { body: "A" }],
      [{ post_id: 4, type: "SpecialComment" }, { body: "B" }],
      [{ post_id: 5, type: "SpecialComment" }, { body: "C" }]
    ]

    comments = Comment.where(body: ["A", "B", "C"]).pluck(:id, :body).sort
    assert_equal [[6, "B"], [7, "B"], [8, "A"], [10, "C"]], comments
  end

  def test_update_in_bulk_supports_typecasting_for_rails_enums_and_booleans
    Book.update_in_bulk({
      1 => { cover: :hard,  status: :proposed,  boolean_status: :disabled,  author_id: "2" },
      2 => { cover: "soft", status: :published, boolean_status: :enabled,   author_id: nil }
    })

    books = Book.where(id: 1..2).order(:id).pluck(:cover, :status, :boolean_status, :author_id)
    assert_equal ["hard", "proposed", "disabled", 2], books[0]
    assert_equal ["soft", "published", "enabled", nil], books[1]
  end

  def test_update_in_bulk_supports_typecasting_for_jsons
    skip unless ActiveRecord::Base.connection.supports_json?

    User.update_in_bulk [
      [{ name: "David" }, { preferences: { color: "blue" } }],
      [{ name: "Joao" }, { preferences: { "width" => 1440 } }]
    ]

    assert_equal({ "color" => "blue" }, User.find_by(name: "David").preferences)
    assert_equal({ "width" => 1440 }, User.find_by(name: "Joao").preferences)
  end

  def test_update_in_bulk_does_not_support_referential_arel_sql_in_conditions
    assert_raises(ActiveRecord::StatementInvalid) do
      Comment.update_in_bulk [[{ parent_id: Arel.sql("comments.post_id") }, { body: "Root comment" }]]
    end
  end

  def test_update_in_bulk_does_not_support_referential_arel_sql_in_values
    assert_raises(ActiveRecord::StatementInvalid) do
      Book.update_in_bulk [[{ name: "Joao" }, { name: Arel.sql("UPPER(name)") }]]
    end
  end

  def test_update_in_bulk_supports_non_referential_arel_sql_in_conditions
    Comment.update_in_bulk [[{ id: Arel.sql("(SELECT id FROM books ORDER BY id ASC LIMIT 1)") }, { body: "First comment" }]]
    assert_equal "First comment", Comment.find(1).body
  end

  def test_update_in_bulk_supports_non_referential_arel_sql_in_values
    Comment.update_in_bulk [[{ id: 1 }, { body: Arel.sql("(SELECT name FROM books WHERE id = 1)") }]]
    assert_equal "Agile Web Development with Rails", Comment.find(1).body
  end

  def test_update_in_bulk_timestamp_updates_are_wrapped_in_parentheses
    assert_queries_match(/ = \(CASE/) do
      Book.update_in_bulk({ 1 => { name: "Updated Book 1", status: :proposed } }, record_timestamps: true)
    end
  end

  def test_update_in_bulk_does_not_touch_updated_at_when_values_do_not_change
    created_at = Time.now.utc - 8.years
    updated_at = Time.now.utc - 5.years
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), created_at: created_at, updated_at: updated_at }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1) } }, record_timestamps: true)

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_update_in_bulk_touches_updated_at_and_updated_on_and_not_created_at_when_values_change
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), created_at: 8.years.ago, updated_at: 5.years.ago, updated_on: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: true)

    book = Book.find(101)
    assert_equal 8.years.ago.year, book.created_at.year
    assert_equal Time.now.utc.year, book.updated_at.year
    assert_equal Time.now.utc.year, book.updated_on.year
  end

  def test_update_in_bulk_respects_updated_at_precision_when_touched_implicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet (Edition #{i})" } }, record_timestamps: true)
      Book.find(101).updated_at.usec > 0
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_update_in_bulk_respects_updated_at_precision_when_touched_explicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet (Edition #{i})", updated_at: Time.now.utc, updated_on: Time.now.utc } }, record_timestamps: true)
      Book.find(101).updated_at.usec > 0 && Book.find(101).updated_on == Time.now.to_date
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_update_in_bulk_uses_given_updated_at_over_implicit_updated_at
    updated_at = Time.now.utc - 1.year
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_at: updated_at } }, record_timestamps: true)

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_update_in_bulk_uses_given_updated_on_over_implicit_updated_on
    updated_on = Time.now.utc.to_date - 30
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_on: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_on: updated_on } }, record_timestamps: true)

    assert_equal updated_on, Book.find(101).updated_on
  end

  def test_update_in_bulk_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_true_but_overridden
    with_record_timestamps(Book, true) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: false)

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
    end
  end

  def test_update_in_bulk_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_false
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } })

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
    end
  end

  def test_update_in_bulk_implicitly_sets_timestamps_when_model_record_timestamps_is_false_but_overridden
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: true)

      assert_in_delta Time.now.utc, Book.find(101).updated_at, 1
      assert_equal Time.now.utc.to_date, Book.find(101).updated_on, 1
    end
  end

  def test_update_in_bulk_dynamic_without_nulls
    Book.update_in_bulk({
      2 => { author_visibility: :invisible, language: :french, font_size: :large },
      3 => { difficulty: :medium, font_size: :medium },
      4 => { cover: "soft", language: :spanish, font_size: :large },
    })

    # initial: ["visible", "english", "easy", "hard", "small"]]
    books = Book.where(id: 2..4).order(:id).pluck(:author_visibility, :language, :difficulty, :cover, :font_size)
    assert_equal ["invisible", "french", "easy", "hard", "large"], books[0]
    assert_equal ["visible", "english", "medium", "hard", "medium"], books[1]
    assert_equal ["visible", "spanish", "easy", "soft", "large"], books[2]
  end

  def test_update_in_bulk_dynamic_with_nulls
    Book.update_in_bulk({
      2 => { author_visibility: :invisible, language: nil, font_size: :large },
      3 => { difficulty: nil, font_size: :medium },
      4 => { cover: "soft", language: :spanish, font_size: nil },
    })

    # initial: ["visible", "english", "easy", "hard", "small"]]
    books = Book.where(id: 2..4).order(:id).pluck(:author_visibility, :language, :difficulty, :cover, :font_size)
    assert_equal ["invisible", nil, "easy", "hard", "large"], books[0]
    assert_equal ["visible", "english", nil, "hard", "medium"], books[1]
    assert_equal ["visible", "spanish", "easy", "soft", nil], books[2]
  end

  def test_update_in_bulk_dynamic_with_arel_sql_nulls
    Book.update_all(format: "default")

    Book.update_in_bulk({
      2 => { name: "Second book" },
      3 => { format: Arel.sql("NULL") }
    })

    assert_equal "default", Book.find(2).format
    assert_nil Book.find(3).format
  end

  def test_update_in_bulk_dynamic_updated_at_bump_ignores_coalesce
    updated_at = 2.days.ago.utc
    Book.update_all(difficulty: nil, updated_at: updated_at)

    # update no columns
    Book.update_in_bulk({
      2 => { author_visibility: :visible, language: :english, font_size: :small },
      3 => { difficulty: nil, font_size: :small },
      4 => { cover: "hard", language: :english, font_size: :small },
    }, record_timestamps: true)

    days = Book.where(id: 2..4).order(:id).pluck(:updated_at).map(&:day)
    assert_equal [updated_at.day] * 3, days
  end

  def test_update_in_bulk_dynamic_updated_at_bump_considers_optional_columns
    updated_at = 2.days.ago.utc
    Book.update_all(difficulty: nil, updated_at: updated_at)

    # update 3.font_size and 4.difficulty but not 2
    Book.update_in_bulk({
      2 => { language: :english, font_size: :small }, # identical
      3 => { difficulty: nil, font_size: nil },
      4 => { cover: "hard", difficulty: :easy, font_size: :small },
    }, record_timestamps: true)

    days = Book.where(id: 2..4).order(:id).pluck(:updated_at).map(&:day)
    assert_equal [updated_at.day, Time.now.utc.day, Time.now.utc.day], days
  end

  def test_update_in_bulk_resets_relation
    author = Author.create!(id: 1, name: "Albert")
    author.books.load

    assert_changes "author.books.loaded?", from: true, to: false do
      author.books.update_in_bulk({ 1 => { name: "updated" } })
    end
  end

  def test_update_in_bulk_does_not_reset_relation_if_updates_is_empty
    author = Author.create!(id: 1, name: "Albert")
    author.books.load

    assert_no_changes "author.books.loaded?" do
      author.books.update_in_bulk({})
    end
  end

  def test_update_in_bulk_does_resets_relation_if_affected_rows_is_zero
    author = Author.create!(id: 1, name: "Albert")
    author.books.load

    assert_changes "author.books.loaded?", from: true, to: false do
      author.books.update_in_bulk({ 1337 => { name: "updated" } })
    end
  end

  def test_update_in_bulk_on_has_many_relation
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

  def test_update_in_bulk_with_group_by
    minimum_comments_count = 2
    good_post = Post.joins(:comments).group("posts.id").having("count(comments.id) < #{minimum_comments_count}").first.id
    bad_post = Post.joins(:comments).group("posts.id").having("count(comments.id) >= #{minimum_comments_count}").first.id

    assert_raises(NotImplementedError) do
      Post.most_commented(minimum_comments_count).update_in_bulk({
        good_post => { title: "ig" },
        bad_post => { title: "ig" }
      })
    end
    # assert_equal "ig", Post.find(good_post).title
    # assert_not_equal "ig", Post.find(bad_post).title
  end

  def test_update_in_bulk_with_order_limit_offset
    assert_raises(NotImplementedError) do
      Post.where(id: 1..6).order(id: :desc).limit(3).offset(2).update_in_bulk([
        [{ author_id: 0 }, { body: "ig0" }],
        [{ author_id: 1 }, { body: "ig1" }]
      ])
    end
    # assert_equal "ig0", Post.find(3).body
    # assert_equal "ig1", Post.find(4).body
    # assert_equal "hello", Post.find(5).body
  end

  def test_update_in_bulk_with_nil_condition
    assert_raises(NotImplementedError, match: /NULL condition/) do
      Book.update_in_bulk [
        [{ id: 4 }, { name: "Reword" }],
        [{ id: nil }, { name: "Peopleware" }]
      ]
    end
  end

  def test_update_in_bulk_with_nil_composite_primary_key
    assert_raises(NotImplementedError, match: /NULL condition/) do
      Car.update_in_bulk({
        ["Toyota", "Camry"] => { year: 1024 },
        ["Honda", nil]      => { year: 1025 }
      })
    end
  end

  def test_update_in_bulk_with_sti_can_override_sti_type
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

  def test_update_in_bulk_logs_message_including_model_name
    capture_log_output do |output|
      Book.update_in_bulk({
        1 => { name: "Updated Book 1" },
        2 => { name: "Updated Book 2" }
      })
      assert_match "Book Update Bulk", output.string
    end
  end

  def test_update_in_bulk_with_left_joins
    pets = Pet.left_joins(:toys).where(toys: { name: ["Bone", nil] })

    assert_equal true, pets.exists?
    assert_equal 2, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" },
      3 => { name: "Rex" }
    })
  end

  def test_update_in_bulk_with_left_outer_joins
    pets = Pet.left_outer_joins(:toys).where(toys: { name: ["Bone", nil] })

    assert_equal true, pets.exists?
    assert_equal 2, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" },
      3 => { name: "Rex" }
    })
  end

  def test_update_in_bulk_with_includes
    pets = Pet.includes(:toys).where(toys: { name: "Bone" })

    assert_equal true, pets.exists?
    assert_equal 1, pets.update_in_bulk({
      1 => { name: "Rex" },
      2 => { name: "Rex" }
    })
  end

  # if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
  #   def test_update_in_bulk_when_table_name_contains_database
  #     database_name = Book.connection_db_config.database
  #     Book.table_name = "#{database_name}.books"
  #
  #     assert_nothing_raised do
  #       Book.update_in_bulk [[{ id: 1 }, { name: "Rework" }]]
  #     end
  #   ensure
  #     Book.table_name = "books"
  #   end
  # end

  private
    def with_record_timestamps(model, value)
      original = model.record_timestamps
      model.record_timestamps = value
      yield
    ensure
      model.record_timestamps = original
    end
end
