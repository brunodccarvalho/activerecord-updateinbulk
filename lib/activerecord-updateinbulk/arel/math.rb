# frozen_string_literal: true

module Arel
  module Math
    def least(other)
      Arel::Nodes::Least.new([self, other])
    end

    def greatest(other)
      Arel::Nodes::Greatest.new([self, other])
    end
  end
end
