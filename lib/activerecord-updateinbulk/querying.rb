# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module Querying
    def update_in_bulk(...)
      all.update_in_bulk(...)
    end
  end
end

ActiveRecord::Querying.prepend(ActiveRecord::UpdateInBulk::Querying)
