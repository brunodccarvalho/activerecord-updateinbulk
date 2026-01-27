# frozen_string_literal: true

module Arel
  module Math
    def least(other)
      lhs = is_a?(Arel::Nodes::Least) ? self.expressions : [self]
      rhs = other.is_a?(Arel::Nodes::Least) ? other.expressions : [other]
      Arel::Nodes::Least.new(lhs + rhs)
    end

    def greatest(other)
      lhs = is_a?(Arel::Nodes::Greatest) ? self.expressions : [self]
      rhs = other.is_a?(Arel::Nodes::Greatest) ? other.expressions : [other]
      Arel::Nodes::Greatest.new(lhs + rhs)
    end
  end
end
