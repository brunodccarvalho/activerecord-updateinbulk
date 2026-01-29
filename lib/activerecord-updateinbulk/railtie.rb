# frozen_string_literal: true

require "rails/railtie"

module ActiveRecord
  module UpdateInBulk
    class Railtie < Rails::Railtie
      config.active_record_update_in_bulk = ActiveSupport::OrderedOptions.new

      initializer "active_record_update_in_bulk.values_table_alias", after: :load_config_initializers do |app|
        if (bulk_alias = app.config.active_record_update_in_bulk.values_table_alias)
          unless bulk_alias.instance_of?(String) && !bulk_alias.empty?
            raise ArgumentError, "values_table_alias must be a non-empty String"
          end
          ActiveRecord::UpdateInBulk::Builder.values_table_name = bulk_alias
        end
      end
    end
  end
end
