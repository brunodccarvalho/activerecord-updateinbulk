# frozen_string_literal: true

require "active_record/fixtures"
require "active_record/testing/query_assertions"
require "logger"
require "stringio"
require "active_support/test_case"
require_relative "assertions_helper"
require_relative "suite_callbacks"

class TestCase < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  include ActiveRecord::Assertions::QueryAssertions
  include TestSupport::AssertionsHelper
  include TestSupport::SuiteCallbacks

  self.fixture_paths = [File.expand_path("../fixtures", __dir__)]
  self.use_transactional_tests = true
  class_attribute :fixture_table_baseline, instance_writer: false, default: nil

  before_suite do
    Arel::Table.engine = nil # should not rely on the global Arel::Table.engine
    self.class.fixture_table_baseline = ActiveRecord::Base.descendants.index_by(&:name).transform_values! do |model|
      snapshot_model(model)
    end.freeze
  end

  after_suite do
    self.class.fixture_table_baseline = nil
  end

  delegate :current_adapter?, :mysql?, :postgres?, :sqlite?, to: TestSupport::Database

  def assert_model_delta(model, differences)
    original = self.class.fixture_table_baseline.fetch(model.name)
    assert_model_snapshot_delta(model, original, snapshot_model(model), differences)
  end

  def prepared_statements_enabled?
    if mysql?
      ActiveRecord::Base.connection.prepared_statements?
    else
      true
    end
  end
end
