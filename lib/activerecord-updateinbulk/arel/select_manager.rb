# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module SelectManager # :nodoc:
    def alias(name) # :nodoc:
      Arel::Nodes::TableAlias.new(self, name)
    end
  end
end

Arel::SelectManager.include(ActiveRecord::UpdateInBulk::SelectManager)
