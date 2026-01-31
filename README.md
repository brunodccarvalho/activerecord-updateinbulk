# ActiveRecord Update in Bulk

Introduces ``Relation#update_in_bulk``, a method to update many records in a table with different values in a single SQL statement,
something traditionally performed with either $N$ consecutive updates or a series of repetitive `CASE` statements.

The method generates a single `UPDATE` query with an inner join to a handcrafted `VALUES` table constructor holding both row matching _conditions_ and the values to assign to each set of rows matched.
This construct is available on the latest versions of all databases supported by rails.

Similar to `update_all`, it returns the number of affected rows, and bumps update timestamps by default.

Tested on Ruby 3.4 and Rails 8 for all builtin databases on latest versions.

## Usage

```ruby
# Indexed format: hash of primary key => attributes to update.
Employee.update_in_bulk({
  1 => { salary: 75_000, title: "Software engineer" },
  2 => { title: "Claude prompter" },
  3 => { salary: 68_000 }
})

# Composite primary keys work as well.
FlightSeat.update_in_bulk({
  ["AA100", "12A"] => { passenger: "Alice" },
  ["AA100", "12B"] => { passenger: "Bob" }
})

# Paired format: array of [conditions, assigns] pairs.
# Conditions don't have to be primary keys, they can refer to any columns in the target table.
Employee.update_in_bulk([
  [{ department: "Sales" },       { bonus: 2500 }],
  [{ department: "Engineering" }, { bonus: 500 }]
])

# Separated format: parallel arrays of conditions and assigns.
# Primary key conditions can be given in their natural form.
Employee.update_in_bulk(
  [1, 2, { id: 3 }],
  [{ salary: 75_000, title: "Software engineer" }, { title: "Claude prompter" }, { salary: 68_000 }]
)
```

### Relation scoping

Relation constraints are preserved, including joins:

```ruby
# Only adjust salaries for currently active employees.
Employee.where(active: true).update_in_bulk([
  [{ department: "Sales" },       { bonus: 2500 }],
  [{ department: "Engineering" }, { bonus: 500 }]
])

# Joins work too - update orders that have at least one shipped item.
Order.joins(:items).where(items: { status: :shipped }).update_in_bulk({
  10 => { status: :fulfilled },
  11 => { status: :fulfilled }
})
```

### Record timestamps

By default `update_in_bulk` implicitly bumps update timestamps similar to `upsert_all`.
- If the model has `updated_at`/`updated_on`, these are bumped *iff the row actually changed*.
- Passing `record_timestamps: false` can disable bumping the update timestamps for the query.
- The `updated_at` columns can also be manually assigned, this disables the implicit bump behaviour.

```ruby
Employee.update_in_bulk({
  1 => { department: "Engineering" },
  2 => { department: "Sales" }
}, record_timestamps: false)
```

Note: On MySQL [assignments are processed in series](https://dev.mysql.com/doc/refman/9.0/en/update.html), so there is no real guarantee that the timestamps are actually updated.

### Formulas (computed assignments)

In all examples so far the queries simply assign predetermined values to rows matched, irrespective of their previous values.

Formulas can augment this in the predictable way of letting you set a custom expression for the assignment, where the new value can be based on the state of current row, the incoming value(s) for that row, and even values in other tables joined in.

```ruby
# Fulfill an order: subtract different quantities from each product stock in one statement.
Inventory.update_in_bulk({
  "Christmas balls" => { quantity: 73 },
  "Christmas tree"  => { quantity: 1 }
}, formulas: { quantity: :subtract })
# Generates: inventories.quantity = inventories.quantity - t.column2
```

Built-in formulas:
- `:add :subtract :min :max :concat_append :concat_prepend`

Custom formulas are supported by providing a `Proc`. The proc takes `(lhs,rhs,model)` and must return an **Arel node**.
Here `lhs` and `rhs` are instances of `Arel::Attribute` corresponding to the target table and values table respectively.

```ruby
# Restock some products, but cap inventory at some maximum amount.
# LEAST(metadata.max_stock, inventories.quantity + t.quantity)
add_capped = proc |lhs, rhs| do
  Arel::Nodes::Least.new([Arel::Attribute.new("metadata", "max_stock"), lhs + rhs])
end
Inventory.joins(:metadata).update_in_bulk({
  "Christmas balls" => { quantity: 300 },
  "Christmas tree"  => { quantity: 10 }
}, formulas: { quantity: add_capped })
```

## Notes

Running `EXPLAIN` on the database engines indicates they do run these queries as one would expect, using the correct index based on the join condition, but there are no tests or benchmarks for this yet.

Given the nature of the query being an inner join with the condition columns, all conditions must use the same keys, and they should not have _NULL_ values, which won't match any rows.

Conditions and assigns must reference actual columns on the target table. Virtual columns for use with formulas are not implemented (requires explicit casting interface to be usable in postgres).

The `UPDATE` is single-shot in any compliant database:
- Either all rows matched are updated or none are.
- Errors may occur for any of the usual reasons: a calculation error, or a check/unique constraint violation.
- This can be used to design a query that updates zero rows if it fails to update any of them, something which usually requires a transaction.
- Rows earlier in the statement do not affect later rows - the row updates are not 'sequenced'.

## Limitations

There is no support for `ORDER BY`, `LIMIT`, `OFFSET`, `GROUP` or `HAVING` clauses in the relation.

The implementation does not automatically batch (nor reject) impermissibly large queries. The size of the values table is `rows * columns` when all rows assign to the same columns, or `rows * (distinct_columns + 1)` when the assign columns are not uniform (an extra bitmask indicator column is used).

## Examples

The query's skeleton looks like this:
```sql
--- postgres
UPDATE "books" SET "name" = "t"."column2"
FROM "books" JOIN (VALUES (1, 'C++'), (2, 'Web'), ...) "t" ON "books"."id" = "t"."column1"
WHERE ...
```

Example use cases:
- Offset `position` in a set of many ordered records after an element is added or removed from the middle of the list.
- Decrement (or increment) `stock` or `balance` simultaneously in multiple rows by different amounts, noop-ing if any value would go outside permissible bounds. => add/subtract formula with database types or check constraints


## Testing & Development

It is important to test both MariaDB and MySQL: their values table semantics differ significantly.

```bash
# setup local test databases
bundle exec rake db:prepare:postgresql
bundle exec rake db:prepare:mysql2

# run on local databases, force rebuilds schemas
bundle exec rake test:sqlite3
bundle exec rake test:postgresql
bundle exec rake test:mysql2

# run on docker-compose databases
bin/test-docker sqlite3
bin/test-docker postgresql
bin/test-docker mysql2
bin/test-docker mariadb

bundle exec rubocop -a
```
