# frozen_string_literal: true

module TestSupport
  module AdapterHelper
    def current_adapter?(*types)
      types.any? do |type|
        ActiveRecord::ConnectionAdapters.const_defined?(type) &&
        ActiveRecord::Base.connection_pool.db_config.adapter_class <= ActiveRecord::ConnectionAdapters.const_get(type)
      end
    end

    def check_constraint_violation_type
      if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        ActiveRecord::StatementInvalid
      else
        ActiveRecord::CheckViolation
      end
    end

    def value_too_long_violation_type
      if ActiveRecord::Base.connection.adapter_name == "SQLite"
        ActiveRecord::CheckViolation
      else
        ActiveRecord::ValueTooLong
      end
    end
  end
end
