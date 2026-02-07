# frozen_string_literal: true

module ActiveRecord::UpdateInBulk
  module Relation
    # Updates multiple groups of records in the current relation using a single
    # SQL UPDATE statement. This does not instantiate models and does not
    # trigger Active Record callbacks or validations. However, values passed
    # through still use Active Record's normal type casting and serialization.
    # Returns the number of rows affected.
    #
    # Three equivalent input formats are supported:
    #
    # *Indexed format* — a hash mapping primary keys to attribute updates:
    #
    #   Book.update_in_bulk({
    #     1 => { title: "Agile", price: 10.0 },
    #     2 => { title: "Rails" }
    #   })
    #
    # Composite primary keys are supported:
    #
    #   FlightSeat.update_in_bulk({
    #     ["AA100", "12A"] => { passenger: "Alice" },
    #     ["AA100", "12B"] => { passenger: "Bob" }
    #   })
    #
    # *Paired format* — an array of <tt>[conditions, assigns]</tt> pairs.
    # Conditions do not need to be primary keys; they may reference any columns in
    # the target table. All pairs must specify the same set of condition
    # columns:
    #
    #   Employee.update_in_bulk([
    #     [{ department: "Sales" },       { bonus: 2500 }],
    #     [{ department: "Engineering" }, { bonus: 500 }]
    #   ])
    #
    # *Separated format* — parallel arrays of conditions and assigns:
    #
    #   Employee.update_in_bulk(
    #     [1, 2, { id: 3 }],
    #     [{ salary: 75_000 }, { salary: 80_000 }, { salary: 68_000 }]
    #   )
    #
    # ==== Options
    #
    # [:record_timestamps]
    #   By default, automatic setting of timestamp columns is controlled by
    #   the model's <tt>record_timestamps</tt> config, matching typical
    #   behavior. Timestamps are only bumped when the row actually changes.
    #
    #   To override this and force automatic setting of timestamp columns one
    #   way or the other, pass <tt>:record_timestamps</tt>.
    #
    #   Pass <tt>record_timestamps: :always</tt> to always assign timestamp
    #   columns to the current database timestamp (without change-detection
    #   CASE logic).
    #
    # [:formulas]
    #   A hash of column names to formula identifiers or Procs. Instead of
    #   a simple assignment, the column is set to an expression that can
    #   reference both the current selected row value and the incoming value.
    #
    #   Built-in formulas: <tt>:add</tt>, <tt>:subtract</tt>, <tt>:min</tt>,
    #   <tt>:max</tt>, <tt>:concat_append</tt>, <tt>:concat_prepend</tt>.
    #
    #     Inventory.update_in_bulk({
    #       "Christmas balls" => { quantity: 73 },
    #       "Christmas tree"  => { quantity: 1 }
    #     }, formulas: { quantity: :subtract })
    #
    #   Custom formulas are supported via a Proc that takes
    #   <tt>(lhs, rhs)</tt> or <tt>(lhs, rhs, model)</tt> and returns an
    #   Arel node:
    #
    #     add_capped = ->(lhs, rhs) { lhs.least(lhs + rhs) }
    #     Inventory.update_in_bulk(updates, formulas: { quantity: add_capped })
    #
    # ==== Examples
    #
    #   # Migration to combine two columns into one for all entries in a table.
    #   Book.update_in_bulk([
    #     [{ written: false, published: false }, { status: :proposed }],
    #     [{ written: true,  published: false }, { status: :written }],
    #     [{ written: true,  published: true },  { status: :published }]
    #   ], record_timestamps: false)
    #
    #   # Relation scoping is preserved.
    #   Employee.where(active: true).update_in_bulk({
    #     1 => { department: "Engineering" },
    #     2 => { department: "Sales" }
    #   })
    #
    def update_in_bulk(updates, values = nil, record_timestamps: nil, formulas: nil)
      unless limit_value.nil? && offset_value.nil? && group_values.empty? && having_clause.empty?
        raise NotImplementedError, "No support to update relations with offset, limit, group, or having clauses"
      end
      if order_values.any? && !Builder.ignore_scope_order
        raise NotImplementedError, "No support to update ordered relations (order clause)"
      end

      conditions, assigns = Builder.normalize_updates(model, updates, values)
      return 0 if @none || conditions.empty?

      model.with_connection do |c|
        unless c.supports_values_tables?
          raise ArgumentError, "#{c.class} does not support VALUES table constructors"
        end

        arel = eager_loading? ? apply_join_dependency.arel : arel()
        arel.source.left = table
        arel.ast.orders = [] if Builder.ignore_scope_order

        values_table, conditions, set_assignments = Builder.new(
          self,
          c,
          conditions,
          assigns,
          record_timestamps:,
          formulas:
        ).build_arel
        if values_table
          arel = arel.join(values_table).on(*conditions)
        else
          conditions.each { |condition| arel.where(condition) }
        end

        key = if model.composite_primary_key?
          primary_key.map { |pk| table[pk] }
        else
          table[primary_key]
        end
        stmt = arel.compile_update(set_assignments, key)
        c.update(stmt, "#{model} Update in Bulk").tap { reset }
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecord::UpdateInBulk::Relation)
