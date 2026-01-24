# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "active_support/test_case"
require "minitest/autorun"

require_relative "support/database_config"
require_relative "support/schema_loader"
require_relative "support/test_case"

adapter = TestSupport::DatabaseConfig.adapter

require "activerecord-updateinbulk"

ActiveRecord::Base.establish_connection(TestSupport::DatabaseConfig.config_for(adapter))

TestSupport::SchemaLoader.apply_schema!(adapter: adapter)

Dir[File.expand_path("models/*.rb", __dir__)].sort.each { |f| require f }
