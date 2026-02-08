# frozen_string_literal: true

module TestSupport
  module SuiteCallbacks
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def before_suite(&block)
        own_before_suite_hooks << block
      end

      def after_suite(&block)
        own_after_suite_hooks << block
      end

      def own_before_suite_hooks
        @own_before_suite_hooks ||= []
      end

      def own_after_suite_hooks
        @own_after_suite_hooks ||= []
      end

      def all_before_suite_hooks
        ancestors
          .select { |a| a.respond_to?(:own_before_suite_hooks) }
          .reverse
          .flat_map(&:own_before_suite_hooks)
      end

      def all_after_suite_hooks
        ancestors
          .select { |a| a.respond_to?(:own_after_suite_hooks) }
          .flat_map { |a| a.own_after_suite_hooks.reverse }
      end

      def run_suite(reporter, options = {})
        return super if filter_runnable_methods(options).empty?

        suite_instance = new("suite_callbacks")
        suite_instance.run_before_suite_callbacks
        super
      ensure
        suite_instance&.run_after_suite_callbacks
      end
    end

    def run_before_suite_callbacks
      setup_fixtures
      self.class.all_before_suite_hooks.each { |hook| instance_exec(&hook) }
    end

    def run_after_suite_callbacks
      self.class.all_after_suite_hooks.each { |hook| instance_exec(&hook) }
    ensure
      teardown_fixtures
    end
  end
end
