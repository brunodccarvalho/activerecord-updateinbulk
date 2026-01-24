# frozen_string_literal: true

require_relative "database_config"

module TestSupport
  module SchemaLoader
    module_function

    def apply_schema!(adapter: DatabaseConfig.adapter)
      test_dir = File.expand_path("..", __dir__)
      schema_files = []

      schema_files << File.join(test_dir, "schema", "schema.rb")

      adapter_schema = File.join(test_dir, "schema", "#{adapter}_schema.rb")
      schema_files << adapter_schema if File.exist?(adapter_schema)

      ActiveRecord::Migration.verbose = false
      schema_files.each { |file| load file }
    end
  end
end
