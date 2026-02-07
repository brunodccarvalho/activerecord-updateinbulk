# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module Querying # :nodoc:
    def update_in_bulk(...) # :nodoc:
      all.update_in_bulk(...)
    end
  end
end

ActiveRecord::Querying.prepend(ActiveRecord::UpdateInBulk::Querying)
