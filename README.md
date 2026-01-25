# ActiveRecord Update in Bulk

`ActiveRecord::Relation#update_in_bulk` updates many records with different values in *one* SQL UPDATE statement.
It avoids N individual UPDATEs and avoids large CASE-based statements by joining against a `VALUES` table
that carries both the matching keys used in the inner join and the new values.

Like `update_all`, it returns the total number of rows affected.

Tested with Ruby 3.4 and Rails 8 for all its builtin databases on latest versions.

## Installation

```ruby
gem "activerecord-updateinbulk"
```

## Usage

### Formats (interchangeable)

```ruby
# Indexed format: Standard syntax when updating records by primary key. Entries can target different columns.
Book.update_in_bulk({
  1 => { revision: 10 },
  2 => { status: :draft },
  3 => { featured: true }
})
Car.update_in_bulk({
  ["Toyota", "Camry"] => { owner: "Albert" },
  ["Honda", "Civic"] => { owenr: "Bernard" }
})

# Paired format: array of pairs [match keys, assigns]
Book.update_in_bulk([
  [{ author_id: 1 }, { featured: true }],
  [{ author_id: 2 }, { featured: false }]
])

# Separated format: parallel arrays for match keys and assign values
Book.update_in_bulk(
  [1, 2],
  [{ name: "Revised Volume One" }, { name: "Revised Volume Two" }]
)
```

The matching keys (_conditions_) can be given in compressed formats when they refer to the primary key:
- `[id1, id2, ...]` (implicit primary key)
- `[[id1p1, id1p2], [id2p1, id2p2], ...]` (implicit composite primary key)
- `[{ id: id1 }, { id: id2 }, ...]` (explicit conditions, not necessarily primary keys)

### Relation scoping

Relation constraints are preserved, including joins:

```ruby
# Make books 1 and 2 featured - but only if they're already published
Book.joins(:publication_issues).where(published: true).update_in_bulk({
  1 => { featured: true },
  2 => { featured: true }
})
```

### Record timestamps

By default `update_in_bulk` implicitly bumps update timestamps similar to `upsert_all`.
- If the model has `updated_at`/`updated_on`, these are bumped **iff the row actually changed**.
- Passing `record_timestamps: false` can disable bumping the update timestamps for the query.
- The `updated_at` columns can also be manually assigned, this disables the implicit bump behaviour.

```ruby
Book.where(published: true).update_in_bulk([
  [{ author_id: 1 }, { featured: true }],
  [{ author_id: 2 }, { featured: false }]
], record_timestamps: false)
```

### Formulas (computed assignments)

In all examples so far the columns are appended with a simple assignment of the value provided.
Formulas can augment this and compute the new value based on the current row and the incoming value(s) for that row.

```ruby
# Subtract 5/3 quantity from two product_stocks rows simultaneously.
ProductStock.update_in_bulk({
  12 => { quantity: 5 },
  34 => { quantity: 3 }
}, formulas: { quantity: :subtract })
# Generates SQL like: product_stocks.quantity = product_stocks.quantity - values.quantity
```

Built-in formulas:
- `:add :subtract :min :max :concat_append :concat_prepend`

Custom formulas are supported by providing a `Proc`. The proc takes `(lhs,rhs,model)` and must return an **Arel node**.
Here `lhs` and `rhs` are instances of `Arel::Attribute` and corresponds to the target table and values table respectively.
You can read other values in each table for example like `lhs.relation["other"]`

```ruby
# Add some product stock, but don't let it go over 1000.
# Library adds Arel::Nodes::Least and Arel::Nodes::Greatest to implement builtin :add and :subtract formulas.
add_capped = lambda do |lhs, rhs, model|
  Arel::Nodes::Least.new([1000, lhs + rhs])
end

ProductStock.update_in_bulk({
  12 => { quantity: 5 },
  34 => { quantity: 3 }
}, formulas: { quantity: add_capped })
```

## Notes and limitations

- All conditions must use the same keys since they are used in inner join of the query with simple equality.
- For the same reason the conditions should not have NULL values, which won't match any rows.
- Each entry must assign at least one column; empty assigns are discarded.
- Conditions and assigns must reference real columns on the target table. Virtual assign columns (for use with formulas) are not implemented.
- The update is single-shot in any compliant database:
  - either all rows matched are updated or none are (which may occur if there is a calculation error, or a check/unique constraint violation).
  - rows earlier in the statement do not affect later rows.
- The implementation does not automatically batch unreasonably large `UPDATE` queries.
  - The size of the `VALUES` table is `rows * columns` when all rows assign to the same columns,
    or `rows * (distinct_columns + 1)` when the assign columns are not uniform (an extra bitmask indicator column is used).

## Testing & Development

It is important to test both MariaDB and MySQL: their `VALUES` table semantics differ significantly.

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
