# frozen_string_literal: true

require "active_record"

module ActiveRecord
  module UpdateInBulk
    ADAPTER_PATH = "activerecord-updateinbulk/adapters"
    ADAPTER_EXTENSION_MAP = {
      "mysql2" => "abstract_mysql",
      "trilogy" => "abstract_mysql",
    }

    def self.require_adapter(adapter) # :nodoc:
      adapter = ADAPTER_EXTENSION_MAP.fetch(adapter, adapter)
      require File.join(ADAPTER_PATH, "#{adapter}_adapter")
    end

    def self.load_from_connection_pool(connection_pool) # :nodoc:
      require_adapter connection_pool.db_config.adapter
    end

    def self.register_formula(name, &formula)
      Builder.register_formula(name, &formula)
    end

    def self.unregister_formula(name)
      Builder.unregister_formula(name)
    end

    def self.registered_formula?(name)
      Builder.registered_formula?(name)
    end
  end
end

require "activerecord-updateinbulk/builder"
require "activerecord-updateinbulk/arel/nodes/values_table"
require "activerecord-updateinbulk/arel/visitors/to_sql"
require "activerecord-updateinbulk/arel/select_manager"
require "activerecord-updateinbulk/relation"
require "activerecord-updateinbulk/querying"

require "activerecord-updateinbulk/adapters/abstract_adapter"

module ActiveRecord::UpdateInBulk
  module ConnectionHandler # :nodoc:
    def establish_connection(*args, **kwargs, &block) # :nodoc:
      pool = super(*args, **kwargs, &block)
      ActiveRecord::UpdateInBulk.load_from_connection_pool pool
      pool
    end
  end
end

ActiveRecord::ConnectionAdapters::ConnectionHandler.prepend(ActiveRecord::UpdateInBulk::ConnectionHandler)
