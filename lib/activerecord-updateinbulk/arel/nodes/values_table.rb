# frozen_string_literal: true

module Arel::Nodes
  # Represents the +VALUES+ table constructor as an Arel node.
  # Mirrors +Arel::Table+ behavior by requiring a name at construction time.
  # Column names are also required because adapter defaults vary; prefer using the
  # default names from <tt>connection.values_table_default_column_names(width)</tt>
  # to keep the generated query simple.
  #
  # This is a private class that may be used by typecasting logic in custom adapters.
  #
  class ValuesTable < Arel::Nodes::Node
    attr_reader :name, :width, :rows, :columns
    alias :table_alias :name

    # +name+    - The table name (required to mirror Arel::Table).
    # +rows+    - An array of arrays; each inner array is one row of values.
    # +columns+ - An array of column name strings, typically from
    #             <tt>connection.values_table_default_column_names(width)</tt>.
    def initialize(name, rows, columns)
      @name = name.to_s
      @width = rows.first.size
      @rows = rows
      @columns = columns.map(&:to_s)
    end

    def [](name, table = self)
      name = columns[name] if name.is_a?(Integer)
      name = name.name if name.is_a?(Symbol)
      Arel::Attribute.new(table, name)
    end

    def from(table = name)
      Arel::SelectManager.new(table ? self.alias(table) : grouping(self))
    end

    def alias(table = name)
      Arel::Nodes::TableAlias.new(grouping(self), table)
    end

    def to_cte
      self.alias.to_cte
    end

    def hash
      [@name, @rows, @columns].hash
    end

    def eql?(other)
      @name == other.name && @rows == other.rows && @columns == other.columns
    end
    alias :== :eql?
  end
end
