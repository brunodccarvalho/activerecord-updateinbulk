# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  # Extension points mixed into +ActiveRecord::ConnectionAdapters::AbstractAdapter+
  # and consumed by the builder/visitor pipeline.
  #
  # Concrete adapters may override any of these methods to describe their SQL
  # capabilities and VALUES table semantics.
  module AbstractAdapter
    # Whether the database supports the SQL VALUES table constructor.
    # When false, +Relation#update_in_bulk+ raises ArgumentError.
    def supports_values_tables?
      true
    end

    # A string prepended to each row literal in the VALUES table constructor.
    # Empty by default, per the standard. MySQL overrides this to <tt>"ROW"</tt>
    # to produce <tt>VALUES ROW(1, 2), ROW(3, 4)</tt>.
    def values_table_row_prefix
      ""
    end

    # Whether VALUES table serialization must always include explicit column
    # aliases (because defaults are missing or not statically known).
    def values_table_requires_aliasing?
      false
    end

    # Returns an array of +width+ column names used by the database for a
    # VALUES table constructor of the given width. These are the native names
    # assigned to each column position when values_table_requires_aliasing?
    # is false; otherwise they are alias conventions.
    def values_table_default_column_names(width)
      (1..width).map { |i| "column#{i}" }
    end

    # Hook for adapters that add explicit type casts to VALUES table entries
    # so column types are correctly inferred by the database.
    #
    # Receives the +values_table+ (<tt>Arel::Nodes::ValuesTable</tt>) and
    # +columns+ (an array of <tt>ActiveRecord::ConnectionAdapters::Column</tt>).
    #
    # Returns the typecasted Arel node: a new node or +values_table+ itself,
    # possibly modified in place.
    #
    # The default implementation does no explicit type casting.
    def typecast_values_table(values_table, _columns)
      values_table
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include(ActiveRecord::UpdateInBulk::AbstractAdapter)
