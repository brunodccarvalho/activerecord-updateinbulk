# frozen_string_literal: true

module TestSupport
  module SchemaLoader
    module_function

    def apply_schema!
      ActiveRecord::Migration.verbose = false
      load File.expand_path("../schema.rb", __dir__)
    end
  end
end
