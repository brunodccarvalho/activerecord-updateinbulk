# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module SelectManager
    def alias(name)
      Arel::Nodes::TableAlias.new(self, name)
    end
  end
end

Arel::SelectManager.include(ActiveRecord::UpdateInBulk::SelectManager)
