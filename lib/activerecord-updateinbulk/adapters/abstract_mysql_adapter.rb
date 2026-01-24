# frozen_string_literal: true

require "active_record/connection_adapters/abstract_mysql_adapter"

module ActiveRecord::UpdateInBulk
  module AbstractMysqlAdapter
    def supports_values_tables?
      mariadb? ? database_version >= "10.3.3" : database_version >= "8.0.19"
    end

    def values_table_row_prefix
      mariadb? ? "" : "ROW"
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.include(ActiveRecord::UpdateInBulk::AbstractMysqlAdapter)
