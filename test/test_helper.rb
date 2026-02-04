# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "bundler/setup"
require "active_record"
require "activerecord-updateinbulk"
require "active_support/test_case"
require "minitest/autorun"

require_relative "support/compact_helper"
require_relative "support/database"
require_relative "support/test_case"

ActiveRecord::Base.establish_connection(TestSupport::Database.config)
TestSupport::Database.apply_schema!
