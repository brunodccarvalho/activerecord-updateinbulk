# frozen_string_literal: true

module Arel::Nodes
  class ValuesTable < Arel::Nodes::Node
    attr_reader :name, :width, :rows, :columns
    alias :table_alias :name

    def initialize(name, rows, columns: nil)
      @name = name.to_s
      @width = rows.first.size
      @rows = rows
      @columns = columns&.map(&:to_s)
    end

    # Pick engine-independent default names so that :[] works
    # and always produces the same column names without aliases
    def column_aliases_or_default_names
      @column_aliases_or_default_names ||= @columns || (1..@width).map { |i| "column#{i}" }
    end

    def [](name, table = self)
      name = column_aliases_or_default_names[name] if name.is_a?(Integer)
      name = name.name if name.is_a?(Symbol)
      Arel::Attribute.new(table, name)
    end

    def from(table = name)
      Arel::SelectManager.new(table ? self.alias(table) : grouping(self))
    end

    def alias(table = name)
      Arel::Nodes::TableAlias.new(grouping(self), table)
    end
    delegate :to_cte, to: :alias

    def hash
      [@name, @rows, @columns].hash
    end

    def eql?(other)
      @name == other.name && @rows == other.rows && @columns == other.columns
    end
    alias :== :eql?
  end
end
