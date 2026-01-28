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

    def values_table_default_column_names(width)
      if mariadb?
        (1..width).map { |i| "column#{i}" } # convention
      else
        (0...width).map { |i| "column_#{i}" }
      end
    end

    # MariaDB always requires aliasing since there are no fixed column names
    def values_table_requires_aliasing?
      mariadb?
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.include(ActiveRecord::UpdateInBulk::AbstractMysqlAdapter)
