# frozen_string_literal: true

require "rails/railtie"

module ActiveRecord
  module UpdateInBulk
    class Railtie < Rails::Railtie
      config.active_record_update_in_bulk = ActiveSupport::OrderedOptions.new

      initializer "active_record_update_in_bulk.values_table_alias" do |app|
        if (bulk_alias = app.config.active_record_update_in_bulk.values_table_alias)
          unless bulk_alias.instance_of?(String) && !bulk_alias.empty?
            raise ArgumentError, "values_table_alias must be a non-empty String"
          end
          ActiveRecord::UpdateInBulk::Builder.values_table_name = bulk_alias
        end
      end

      initializer "active_record_update_in_bulk.typecasting_strategy" do |app|
        if (strategy = app.config.active_record_update_in_bulk.typecasting_strategy)
          strategy = strategy.to_sym
          unless %i[auto all].include?(strategy)
            raise ArgumentError, "Invalid typecasting_strategy #{strategy.inspect}"
          end
          ActiveRecord::UpdateInBulk::Builder.typecasting_strategy = strategy
        end
      end
    end
  end
end
