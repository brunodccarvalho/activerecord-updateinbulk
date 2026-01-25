# frozen_string_literal: true

require "active_record"

module ActiveRecord
  module UpdateInBulk
    ADAPTER_PATH = "activerecord-updateinbulk/adapters"
    ADAPTER_EXTENSION_MAP = {
      "mysql2" => "abstract_mysql",
      "trilogy" => "abstract_mysql",
    }

    def self.require_adapter(adapter)
      adapter = ADAPTER_EXTENSION_MAP.fetch(adapter, adapter)
      require File.join(ADAPTER_PATH, "#{adapter}_adapter")
    end

    def self.load_from_connection_pool(connection_pool)
      require_adapter connection_pool.db_config.adapter
    end
  end
end

require "activerecord-updateinbulk/builder"
require "activerecord-updateinbulk/arel/math"
require "activerecord-updateinbulk/arel/nodes/least"
require "activerecord-updateinbulk/arel/nodes/greatest"
require "activerecord-updateinbulk/arel/nodes/values_table"
require "activerecord-updateinbulk/arel/visitors/to_sql"
require "activerecord-updateinbulk/arel/visitors/sqlite"
require "activerecord-updateinbulk/arel/select_manager"
require "activerecord-updateinbulk/relation"
require "activerecord-updateinbulk/querying"

require "activerecord-updateinbulk/adapters/abstract_adapter"

module ActiveRecord::UpdateInBulk
  module ConnectionHandler
    def establish_connection(*args, **kwargs, &block)
      pool = super(*args, **kwargs, &block)
      ActiveRecord::UpdateInBulk.load_from_connection_pool pool
      pool
    end
  end
end

ActiveRecord::ConnectionAdapters::ConnectionHandler.prepend(ActiveRecord::UpdateInBulk::ConnectionHandler)
