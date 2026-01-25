# frozen_string_literal: true

require "active_record/fixtures"
require "active_record/testing/query_assertions"
require "logger"
require "stringio"
require "active_support/test_case"

class TestCase < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  include ActiveRecord::Assertions::QueryAssertions

  self.fixture_paths = [File.expand_path("../fixtures", __dir__)]
  self.use_transactional_tests = true

  def self.disable_transactional_tests!
    self.use_transactional_tests = false
  end

  def self.enable_transactional_tests!
    self.use_transactional_tests = true
  end

  def capture_log_output
    output = StringIO.new
    logger = Logger.new(output)

    previous_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = logger
    yield output
  ensure
    ActiveRecord::Base.logger = previous_logger
  end
end
