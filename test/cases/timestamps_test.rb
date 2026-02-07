# frozen_string_literal: true

require "test_helper"
require "models"

class TimestampsTest < TestCase
  fixtures :all

  before_suite do
    Book.record_timestamps = false
  end

  after_suite do
    Book.record_timestamps = true
  end

  def test_timestamps_case_expression_is_grouped
    assert_query_sql(on_width: 0, cases: 2, whens: 2) do
      assert_queries_match(/ = \(CASE/) do
        Book.update_in_bulk({ 1 => { name: "Scrum Development", status: :proposed } }, record_timestamps: true)
      end
    end

    assert_model_delta(Book, {
      1 => { name: "Scrum Development", status: "proposed", updated_at: :_modified, updated_on: Date.today }
    })
  end

  def test_record_timestamps_always_bumps_unchanged
    assert_query_sql(values: 2, on_width: 1, cases: 0, whens: 0) do
      Book.update_in_bulk({
        1 => { name: "Agile Web Development with Rails" },
        2 => { name: "Ruby for Rails 2" }
      }, record_timestamps: :always)
    end

    assert_in_delta Time.now.utc, Book.find(2).updated_at, 0.1
    assert_model_delta(Book, {
      1 => { updated_at: :_modified, updated_on: Date.today },
      2 => { name: "Ruby for Rails 2", updated_at: :_modified, updated_on: Date.today }
    })
  end

  def test_record_timestamps_true_only_bumps_if_changed
    assert_query_sql(values: 2, on_width: 1, cases: 2, whens: 2) do
      Book.update_in_bulk({
        1 => { name: "Agile Web Development with Rails" },
        2 => { name: "Ruby for Rails 2" }
      }, record_timestamps: true)
    end

    assert_in_delta Time.now.utc, Book.find(2).updated_at, 0.1
    assert_model_delta(Book, {
      2 => { name: "Ruby for Rails 2", updated_at: :_modified, updated_on: Date.today }
    })
  end

  def test_record_timestamps_true_only_bumps_changed_optionals
    # cases: 2 timestamps outers + 2 bitmask inner + 1 bitmask assign (description)
    assert_query_sql(values: 5, on_width: 1, cases: 5, whens: 5, coalesce: 3) do
      Book.update_in_bulk({
        1 => { name: "Agile 2", pages: 200 },
        2 => { name: nil, description: "A great book" },
        3 => { name: "Domain-Driven Design", description: nil },
      }, record_timestamps: true)
    end

    assert_model_delta(Book, {
      1 => { name: "Agile 2", pages: 200, updated_at: :_modified, updated_on: Date.today },
      2 => { name: nil, updated_at: :_modified, updated_on: Date.today }
    })
  end

  def test_respects_updated_at_precision_when_touched_implicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet (Edition #{i})" } }, record_timestamps: true)
      Book.find(101).updated_at.usec > 0
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_respects_updated_at_precision_when_touched_explicitly
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]

    # A single update can occur exactly at the seconds boundary (when usec is naturally zero), so try multiple times.
    has_subsecond_precision = (1..100).any? do |i|
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet (Edition #{i})", updated_at: Time.now.utc, updated_on: Time.now.utc } }, record_timestamps: true)
      Book.find(101).updated_at.usec > 0 && Book.find(101).updated_on == Time.now.to_date
    end

    assert has_subsecond_precision, "updated_at should have sub-second precision"
  end

  def test_uses_given_updated_at_over_implicit_updated_at
    updated_at = Time.now.utc - 1.year
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_at: updated_at } }, record_timestamps: true)

    assert_in_delta updated_at, Book.find(101).updated_at, 1
  end

  def test_uses_given_updated_on_over_implicit_updated_on
    updated_on = Time.now.utc.to_date - 30
    Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_on: 5.years.ago }]
    Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8), updated_on: updated_on } }, record_timestamps: true)

    assert_equal updated_on, Book.find(101).updated_on
  end

  def test_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_true_but_overridden
    with_record_timestamps(Book, true) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: false)

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
    end
  end

  def test_does_not_implicitly_set_timestamps_when_model_record_timestamps_is_false
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } })

      assert_in_delta 5.years.ago.year, Book.find(101).updated_at.year
      assert_in_delta 5.years.ago.year, Book.find(101).updated_on.year
    end
  end

  def test_implicitly_sets_timestamps_when_model_record_timestamps_is_false_but_overridden
    with_record_timestamps(Book, false) do
      Book.insert_all [{ id: 101, name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 1), updated_at: 5.years.ago, updated_on: 5.years.ago }]
      Book.update_in_bulk({ 101 => { name: "Out of the Silent Planet", published_on: Date.new(1938, 4, 8) } }, record_timestamps: true)

      assert_in_delta Time.now.utc, Book.find(101).updated_at, 1
      assert_equal Time.now.utc.to_date, Book.find(101).updated_on, 1
    end
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
