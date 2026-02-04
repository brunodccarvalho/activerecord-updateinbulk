# frozen_string_literal: true

require "test_helper"
require "models"

class TimestampsTest < TestCase
  fixtures :all

  def setup
    Book.record_timestamps = false
  end

  def teardown
    Book.record_timestamps = true
  end

  def test_timestamp_case_expression_is_grouped
    assert_query_sql(on_width: 0, cases: 2, whens: 2) do
      assert_queries_match(/ = \(CASE/) do
        Book.update_in_bulk({ 1 => { name: "Scrum Development", status: :proposed } }, record_timestamps: true)
      end
    end
    assert_model_delta(Book, {
      1 => { name: "Scrum Development", status: "proposed", updated_at: :_modified }
    })
  end

  def test_does_not_touch_updated_at_when_values_do_not_change
    created_at = Time.now.utc - 8.years
    updated_at = Time.now.utc - 5.years
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), created_at: created_at, updated_at: updated_at }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1) } }, record_timestamps: true)

    assert_in_delta updated_at, Book.find(101).updated_at, 1
    assert_model_delta(Book, { 101 => :created })
  end

  def test_single_row_noop_does_not_touch_timestamps_or_other_rows
    updated_at_target = Time.now.utc - 5.years
    updated_at_other = Time.now.utc - 4.years
    Book.insert_all!([
      { id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: updated_at_target, updated_on: updated_at_target.to_date },
      { id: 102, name: "Perelandra", published_on: Date.new(1943, 1, 1), updated_at: updated_at_other, updated_on: updated_at_other.to_date }
    ])

    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1) } }, record_timestamps: true)

    assert_in_delta updated_at_target, Book.find(101).updated_at, 1
    assert_equal updated_at_target.to_date, Book.find(101).updated_on
    assert_in_delta updated_at_other, Book.find(102).updated_at, 1
    assert_equal updated_at_other.to_date, Book.find(102).updated_on
    assert_equal "Perelandra", Book.find(102).name
    assert_model_delta(Book, {
      101 => :created,
      102 => :created
    })
  end

  def test_touches_updated_at_and_updated_on_and_not_created_at_when_values_change
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), created_at: 8.years.ago, updated_at: 5.years.ago, updated_on: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: true)

    book = Book.find(101)
    assert_equal 8.years.ago.year, book.created_at.year
    assert_equal Time.now.utc.year, book.updated_at.year
    assert_equal Time.now.utc.year, book.updated_on.year
    assert_model_delta(Book, { 101 => :created })
  end

  def test_respects_updated_at_precision_when_touched_implicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet (Edition #{i})" } }, record_timestamps: true)
      Book.find(101).updated_at.usec > 0
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
    assert_model_delta(Book, { 101 => :created })
  end

  def test_respects_updated_at_precision_when_touched_explicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet (Edition #{i})", updated_at: Time.now.utc, updated_on: Time.now.utc } }, record_timestamps: true)
      Book.find(101).updated_at.usec > 0 && Book.find(101).updated_on == Time.now.to_date
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
    assert_model_delta(Book, { 101 => :created })
  end

  def test_uses_given_updated_at_over_implicit_updated_at
    updated_at = Time.now.utc - 1.year
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_at: updated_at } }, record_timestamps: true)

    assert_in_delta updated_at, Book.find(101).updated_at, 1
    assert_model_delta(Book, { 101 => :created })
  end

  def test_uses_given_updated_on_over_implicit_updated_on
    updated_on = Time.now.utc.to_date - 30
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_on: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_on: updated_on } }, record_timestamps: true)

    assert_equal updated_on, Book.find(101).updated_on
    assert_model_delta(Book, { 101 => :created })
  end

  def test_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_true_but_overridden
    with_record_timestamps(Book, true) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: false)

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
      assert_model_delta(Book, { 101 => :created })
    end
  end

  def test_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_false
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } })

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
      assert_model_delta(Book, { 101 => :created })
    end
  end

  def test_implicitly_sets_timestamps_when_model_record_timestamps_is_false_but_overridden
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: true)

      assert_in_delta Time.now.utc, Book.find(101).updated_at, 1
      assert_equal Time.now.utc.to_date, Book.find(101).updated_on, 1
      assert_model_delta(Book, { 101 => :created })
    end
  end

  def test_timestamps_not_bumped_when_optional_keys_unchanged
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
    assert_model_delta(Book, {
      1 => { difficulty: nil, updated_at: :_modified },
      2 => { difficulty: nil, updated_at: :_modified },
      3 => { difficulty: nil, updated_at: :_modified },
      4 => { difficulty: nil, updated_at: :_modified }
    })
  end

  def test_timestamps_bumped_when_optional_keys_change
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
    assert_model_delta(Book, {
      1 => { difficulty: nil, updated_at: :_modified },
      2 => { difficulty: nil, updated_at: :_modified },
      3 => { difficulty: nil, font_size: nil, updated_at: :_modified },
      4 => { updated_at: :_modified }
    })
  end

  private
    def with_record_timestamps(model, value)
      original = model.record_timestamps
      model.record_timestamps = value
      yield
    ensure
      model.record_timestamps = original
    end
end
