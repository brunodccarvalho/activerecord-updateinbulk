# frozen_string_literal: true

require "active_record/connection_adapters/sqlite3_adapter"

module ActiveRecord::UpdateInBulk
  module SQLite3Adapter
    def values_table_requires_aliasing?
      false
    end
  end
end

ActiveRecord::ConnectionAdapters::SQLite3Adapter.include(ActiveRecord::UpdateInBulk::SQLite3Adapter)
