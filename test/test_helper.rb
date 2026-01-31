# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "bundler/setup"
require "active_record"
require "activerecord-updateinbulk"
require "active_support/test_case"
require "minitest/autorun"

require_relative "support/compact_helper"
require_relative "support/adapter_helper"
require_relative "support/database_config"
require_relative "support/schema_loader"
require_relative "support/test_case"

adapter = TestSupport::DatabaseConfig.adapter


ActiveRecord::Base.establish_connection(TestSupport::DatabaseConfig.config_for(adapter))
TestSupport::SchemaLoader.apply_schema!

Dir[File.expand_path("models/*.rb", __dir__)].sort.each { |f| require f }
