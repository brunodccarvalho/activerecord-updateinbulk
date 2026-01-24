# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module AbstractAdapter
    def supports_values_tables?
      true
    end

    def values_table_row_prefix
      ""
    end

    # If the defaults' names are column1, column2, ... then aliases are not required.
    def values_table_requires_aliasing?
      true
    end

    # This is meant to be implemented by the adapters that want to typecast the tables.
    def typecast_values_table(values_table, _columns)
      values_table
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include(ActiveRecord::UpdateInBulk::AbstractAdapter)
