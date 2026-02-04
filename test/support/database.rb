# frozen_string_literal: true

require "erb"
require "yaml"

module TestSupport
  module Database
    module_function

    def adapter
      @adapter ||= ENV["ARADAPTER"] || "sqlite3"
    end

    def current_adapter?(*types)
      types.any? do |type|
        ActiveRecord::ConnectionAdapters.const_defined?(type) &&
        ActiveRecord::Base.connection_pool.db_config.adapter_class <= ActiveRecord::ConnectionAdapters.const_get(type)
      end
    end

    def mysql? = current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def postgres? = current_adapter?(:PostgreSQLAdapter)
    def sqlite? = current_adapter?(:SQLite3Adapter)

    def config
      path = File.expand_path("../database.yml", __dir__)
      yaml = ERB.new(File.read(path)).result
      YAML.safe_load(yaml, aliases: true).fetch(adapter)
    end

    def apply_schema!
      ActiveRecord::Migration.verbose = false
      load File.expand_path("../schema.rb", __dir__)
    end
  end
end
