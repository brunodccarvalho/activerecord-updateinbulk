# frozen_string_literal: true

require "active_record/connection_adapters/sqlite3_adapter"

module ActiveRecord::UpdateInBulk
  module SQLite3Adapter
  end
end

ActiveRecord::ConnectionAdapters::SQLite3Adapter.include(ActiveRecord::UpdateInBulk::SQLite3Adapter)
