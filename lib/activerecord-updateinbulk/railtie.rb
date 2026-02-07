# frozen_string_literal: true

require "rails/railtie"

module ActiveRecord
  module UpdateInBulk
    # Railtie integration for configuration values consumed by this gem.
    #
    # ==== Configuration
    #
    # Configure these in a Rails initializer (for example
    # <tt>config/initializers/update_in_bulk.rb</tt>):
    #
    #   Rails.application.config.active_record_update_in_bulk.values_table_alias = "vals"
    #   Rails.application.config.active_record_update_in_bulk.ignore_scope_order = true
    #
    # [config.active_record_update_in_bulk.values_table_alias]
    #   Optional string alias to use for the generated VALUES table.
    #   Defaults to <tt>"t"</tt>.
    #
    # [config.active_record_update_in_bulk.ignore_scope_order]
    #   Whether <tt>Relation#update_in_bulk</tt> should ignore any ORDER BY scope
    #   on the input relation. Necessary for invoking the method on scope-ordered
    #   associations, or models with a default scope that includes an order.
    #
    #   * <tt>true</tt> (default): ORDER BY scopes are stripped.
    #   * <tt>false</tt>: ordered relations raise NotImplementedError.
    class Railtie < Rails::Railtie
      config.active_record_update_in_bulk = ActiveSupport::OrderedOptions.new
      config.active_record_update_in_bulk.ignore_scope_order = true

      initializer "active_record_update_in_bulk.values_table_alias", after: :load_config_initializers do |app|
        if (bulk_alias = app.config.active_record_update_in_bulk.values_table_alias)
          unless bulk_alias.instance_of?(String) && !bulk_alias.empty?
            raise ArgumentError, "values_table_alias must be a non-empty String"
          end
          ActiveRecord::UpdateInBulk::Builder.values_table_name = bulk_alias
        end
      end

      initializer "active_record_update_in_bulk.ignore_scope_order", after: :load_config_initializers do |app|
        ignore_scope_order = app.config.active_record_update_in_bulk.ignore_scope_order
        unless ignore_scope_order == true || ignore_scope_order == false
          raise ArgumentError, "ignore_scope_order must be true or false"
        end
        ActiveRecord::UpdateInBulk::Builder.ignore_scope_order = ignore_scope_order
      end
    end
  end
end
