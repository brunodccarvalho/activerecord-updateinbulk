# frozen_string_literal: true

require "active_record/connection_adapters/postgresql_adapter"

module ActiveRecord::UpdateInBulk
  module PostgreSQLAdapter
    SAFE_TYPES_FOR_VALUES_TABLE = [:integer, :string, :text, :boolean].freeze


    def typecast_values_table(values_table, columns)
      types = columns.map.with_index do |column, index|
        case column
        when ActiveRecord::ConnectionAdapters::PostgreSQL::Column
          if SAFE_TYPES_FOR_VALUES_TABLE.exclude?(column.type) ||
              column.array ||
              values_table.rows.all? { |row| row[index].nil? }
            column.sql_type_metadata.sql_type
          end
        when Arel::Nodes::SqlLiteral, nil
          column
        else
          raise ArgumentError, "Unexpected column type: #{column.class.name}"
        end
      end

      return values_table if types.all?(&:nil?)

      aliases = values_table.columns
      default_columns = values_table_default_column_names(values_table.width)
      values_table = Arel::Nodes::ValuesTable.new(values_table.name, values_table.rows, default_columns)

      # from("t") is not required in postgres 16+, can be from(nil)
      values_table.from("t").project((0...values_table.width).map do |index|
        proj = Arel::Nodes::UnqualifiedColumn.new(values_table[index])
        proj = proj.cast(proj, Arel.sql(types[index])) if types[index]
        proj = proj.as(Arel::Nodes::UnqualifiedColumn.new(aliases[index])) if aliases[index] != default_columns[index]
        proj
      end)
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(ActiveRecord::UpdateInBulk::PostgreSQLAdapter)
