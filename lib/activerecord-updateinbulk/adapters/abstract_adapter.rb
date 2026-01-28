# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module AbstractAdapter
    def supports_values_tables?
      true
    end

    def values_table_row_prefix
      ""
    end

    def values_table_default_column_names(width)
      (1..width).map { |i| "column#{i}" }
    end

    # Whether the VALUES table sql serialization always requires aliasing.
    def values_table_requires_aliasing?
      false
    end

    # This is meant to be implemented by the adapters that want to typecast the tables.
    def typecast_values_table(values_table, _columns)
      values_table
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include(ActiveRecord::UpdateInBulk::AbstractAdapter)
