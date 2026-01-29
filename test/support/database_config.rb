# frozen_string_literal: true

require "erb"
require "yaml"

module TestSupport
  module DatabaseConfig
    module_function

    def adapter
      @adapter ||= ENV["ARADAPTER"] || "sqlite3"
    end

    def config_for(adapter_name)
      path = File.expand_path("../database.yml", __dir__)
      yaml = ERB.new(File.read(path)).result
      YAML.safe_load(yaml, aliases: true).fetch(adapter_name)
    end
  end
end
