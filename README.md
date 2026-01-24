# ActiveRecord Update in bulk

Introduces ``Relation#update_in_bulk``, a mechanism to update many records in a table with different values in a single SQL statement,
something traditionally implemented with either $N$ consecutive update queries or with a complex series of `CASE` statements for the `SET` clause.

The method generates a single `UPDATE` statement using an internal inner join with a handcrafted `VALUES` table constructor. This is available on all databases supported by the main rails project, though a more recent feature in some databases than others.

Similar to `update_all`, it returns the total number of affected rows in the table.

Tested for ruby 3.4 and rails 8.

## Usage

```ruby
gem "activerecord-updateinbulk"
```

#### Hash syntax

Standard syntax when updating records one-by-one, by their primary key.
The statements do not need to write to the same columns.

```ruby
Book.update_in_bulk({
  1 => { name: "Updated Title 1", status: :published },
  2 => { name: "Updated Title 2", status: :draft },
  3 => { name: "Updated Title 3" }
})
```

```ruby
Cpk::Car.update_in_bulk({
  ["Toyota", "Camry"] => { year: 2024 },
  ["Honda", "Civic"] => { year: 2023 }
})
```

#### Array syntax (custom conditions)

```ruby
Book.update_in_bulk([
  [{ author_id: 1 }, { featured: true }],
  [{ author_id: 2 }, { featured: false }]
])
```

#### Supports relation scoping

Passes on relation constraints to the update, including joins.

```ruby
Book.where(published: true).update_in_bulk({
  1 => { featured: true },
  2 => { featured: true }
})
```

#### Record timestamps

By default bumps record timestamps (`updated_at`) if present, but this can be disabled.

```ruby
Book.update_in_bulk([
  [{ author_id: 1 }, { featured: true }],
  [{ author_id: 2 }, { featured: false }]
], record_timestamps: false)
```

## Performance notice

The implementation does not unroll (or "batch") very large `UPDATE` queries.
The size of the `VALUES` table is `#statements * #columns` if all the statements write the same set of columns, otherwise `#statements * (#distinct-columns + 1)` as an extra virtual column is added to instruct which columns to be updated in which records.

```sql
-- MySQL example
UPDATE books
FROM (VALUES (1, 'Title 1', 0), (2, 'Title 2', 1)) AS values_table(id, name, status)
SET name = values_table.name, status = values_table.status
WHERE books.id = values_table.id
```

## Testing & Development

It is important to test both mariadb and mysql as engines' implementations of values table constructors are very different.

```bash
# Setup databases for local tests
bundle exec rake db:prepare:sqlite3
bundle exec rake db:prepare:mysql2
bundle exec rake db:prepare:postgresql

bundle exec rake test:sqlite3
bundle exec rake test:mysql2
bundle exec rake test:postgresql

bundle exec rubocop -a
```
