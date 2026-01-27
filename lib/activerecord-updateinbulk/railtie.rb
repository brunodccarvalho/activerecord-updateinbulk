# frozen_string_literal: true

require "rails/railtie"

module ActiveRecord
  module UpdateInBulk
    class Railtie < Rails::Railtie
      config.active_record_update_in_bulk = ActiveSupport::OrderedOptions.new

      initializer "active_record_update_in_bulk.configure" do |app|
        options = app.config.active_record_update_in_bulk

        if (bulk_alias = options.values_table_alias)
          unless bulk_alias.instance_of?(String) && !bulk_alias.empty?
            raise ArgumentError, "values_table_alias must be a non-empty String"
          end
          ActiveRecord::UpdateInBulk::Builder.values_table_name = bulk_alias
        end

        if options.typecasting_strategy
          strategy = options.typecasting_strategy.to_sym
          unless %i[auto all].include?(strategy)
            raise ArgumentError, "Invalid typecasting_strategy #{strategy.inspect}"
          end
          ActiveRecord::UpdateInBulk::Builder.typecasting_strategy = strategy
        end
      end
    end
  end
end
