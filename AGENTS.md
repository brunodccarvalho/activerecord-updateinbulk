# Agent Guidance

This file provides guidance to coding agents when working with code in this repository.
Use the guidance below when making changes.

This repository maintains a Ruby gem that adds `ActiveRecord::Relation#update_in_bulk`, a method to update
many records in a SQL table with possibly different values using a single SQL statement, rooted on an inner join
with a `VALUES` table constructor that holds both the update values and the keys used to match records.
There is database-specific SQL generation and a dedicated test suite.

## Examples

### update_in_bulk formats

`update_in_bulk` accepts multiple input formats that are interchangeable. Currently implemented formats:

- Indexed format (keys are primary keys):
  `Book.update_in_bulk({ 1 => { name: "Agil" }, 2 => { name: "Web" } }, ...)`
- Paired format (each element is `[conditions, assigns]`):
  `Book.update_in_bulk([[1, { name: "Agil" }], [2, { name: "Web" }]], ...)`
- Separated format:
  `Book.update_in_bulk([1, 2], [{ name: "Agil" }, { name: "Web" }], ...)`

Conditions may be specified in multiple ways as well. For example for the separated format:
- `[id1, id2, ...]` (implicit primary key)
- `[[id1p1, id1p2], [id2p1, id2p2], ...]` (implicit composite primary key)
- `[{ id: id1 }, { id: id2 }, ...]` (explicit conditions, not necessarily primary key)

`Builder#normalize_updates` normalizes to the separated format, which is certainly the most efficient format.
Normalization filters out rows with blank assigns early, so downstream logic can assume non-empty value hashes.

The Builder's validations apply equally to all formats:
- all conditions must have consistent keys
- in every entry at least one column must be assigned, otherwise the entry is discarded
- all condition and assign keys must be existing columns in the target table.

### Query shape (illustrative)

```sql
--- mysql
UPDATE `books` INNER JOIN (SELECT 1 `column1`, 'Scrum Development' `column2` UNION ALL VALUES ROW(2, 'Django for noobies'), ROW(3, 'Data-Driven Design')) `t` ON `books`.`id` = `t`.`column1` SET `books`.`name` = `t`.`column2`;

--- mariadb
UPDATE `books` INNER JOIN (SELECT 1 `column1`, 'Scrum Development' `column2` UNION ALL VALUES (2, 'Django for noobies'), (3, 'Data-Driven Design')) `t` ON `books`.`id` = `t`.`column1` SET `books`.`name` = `t`.`column2`;

--- postgresql
UPDATE "books" "alias" SET "name" = "t"."column2" FROM "books" INNER JOIN (VALUES (1, 'Scrum Development'), (2, 'Django for noobies'), (3, 'Data-Driven Design')) "t" ON "books"."id" = "t"."column1" WHERE "books"."id" = "alias"."id";

--- sqlite3
UPDATE "books" AS "__active_record_update_alias" SET "name" = "t"."column2" FROM "books" INNER JOIN (VALUES (1, 'Scrum Development'), (2, 'Django for noobies'), (3, 'Data-Driven Design')) AS "t" ON "books"."id" = "t"."column1" WHERE "books"."id" = "__active_record_update_alias"."id";
```

## Important observations specific to the problem the project solves

The VALUES table constructor has slightly different behaviour and syntax across the databases:
- postgres/sqlite3: column names are `column1 column2 ...` and syntax is `VALUES (1,2), (3,4), ...`
- mariadb: column names are effectively unknown, syntax is `VALUES (1,2), (3,4), ...` again.
- mysql: column names are `column_0 column_1` and syntax is `VALUES ROW(1,2), ROW(3,4), ...`

Rails uses the same adapters for MySQL and MariaDB, but the big difference in their behaviour between the databases means both must be dully considered and tested individually.

At the `Arel` layer, the convention was made that the column names of `Arel::ValuesTable` are `column1 column2 ...` unless explicitly aliased in the constructor.
This implies column renaming is always required during SQL generation for mariadb and mysql.

To rename columns the implementation extracts the first row into a `SELECT`, as follows:
`VALUES (1,2), (3,4), (5,6)` ==> `SELECT 1 AS a, 2 AS b UNION ALL VALUES (3,4), (5,6)`

The project _does not implement_ CTE or derived table column aliasing.

PostgreSQL has a strongly-typed database architecture, and the other databases are loosely typed.
This means the `VALUES` table usually needs to be explicitly typed in postgres and does not need to be explicitly typed in the other databases (for `update_in_bulk`).

To type columns the implementation extracts the first row into a `SELECT`, as follows:
`VALUES (1,2), (3,4), (5,6)` ==> `SELECT CAST(1 AS UNSIGNED), CAST(2 AS UNSIGNED) UNION ALL VALUES (3,4), (5,6)`
The explicit `CAST` in the `SELECT` effectively propagates to the entire values table.

The implementation can combine column renaming and column typing, as it does in postgres's `typecast_values_table`.
`VALUES (1,2), (3,4), (5,6)` ==> `SELECT CAST(1 AS UNSIGNED) a, CAST(2 AS UNSIGNED) b UNION ALL VALUES (3,4), (5,6)`

Explicit column type casting should follow the same SELECT + UNION ALL pattern across adapters.
Explicit type values are the same as currently accepted by `typecast_values_table` (e.g. SQL type strings).

The rhs of assignments can be augmented using *column formulas* from the simple assignment to an SQL expression
that can read all current row values and new values in the corresponding row of the `VALUES` table.
Builtin formulas include adding and subtracting (`stock = stock + values_table.stock` instead of `stock = values_table.stock`),
concatenating strings and computing minimums and maximums, and the user can construct their own custom formulas as a function.

Formulas are applied in the Builder (Arel) before optional-key handling (CASE/COALESCE), and are adapter-independent

## Project Overview
- Entry point: `lib/activerecord-updateinbulk.rb`.
- Core arel building logic: `lib/activerecord-updateinbulk/builder.rb`.
- Relation extension and method: `lib/activerecord-updateinbulk/relation.rb`
- Core rails extensions:
  - Adapters: `lib/activerecord-updateinbulk/adapters/**.rb`.
  - Arel: `lib/activerecord-updateinbulk/arel/**.rb` - custom `ValuesTable` node
- Tests: `test/` (minitest)

**Requirements:** Ruby 3.4+, Rails 8+

## Test Architecture

- Adapters supported: sqlite3, postgresql, mysql2, trilogy (all from rails)
- Databases: sqlite3, postgres, mysql, mariadb
- Combinations (for `bin/test-docker`): sqlite3, postgresql, mysql, trilogy-mysql, mariadb, trilogy-mariadb

- Test cases: `test/cases/`
- Database configuration: `test/database.yml`
- Schema loading: `test/schema/schema.rb` (always) + `test/schema/<adapter>_schema.rb` (when present)
- Fixtures in `test/fixtures/`, models in `test/models.rb`
- Three high-level mechanisms to invoke tests:
  - Local development: `bundle exec rake test:$adapter` - uses local machine databases
  - Docker compose: `docker-compose up -d; bin/test-docker $database` - uses servers running on docker-compose
  - Github CI: `bundle exec rake test:$adapter` - individual job and service for each tested database

## Development Commands

```bash
# Docker-based tests (start containers first: docker-compose up -d)
bundle exec rake test:sqlite3 # PREFERRED: For quick verification of adapter-independent code changes run
bundle exec rake test:mysql2
bundle exec rake test:postgresql
...

# Linting
bundle exec rubocop
bundle exec rubocop --autocorrect
```

## How to work in this repo
- Prefer minimal, surgical changes.
- Avoid rewriting large sections unless asked.
- Avoid duplicating large blocks of code. Prefer proactively factoring out the duplicated code.
- Prefer writing optimized code that avoids instantiating too many objects and arrays.
- Freely add new models and fixtures for new tests, but only if the tests cannot easily be implemented with existing models and fixtures.
- Keep changes database-agnostic (sqlite3/postgresql/mysql/mariadb) unless the task is database-specific.
- Update or add tests when changing query behavior.
- Always lint and test the code after performing non-trivial changes.
- Do not add new runtime or development dependencies without first asking.
- Follow rails code style lightly: prefer double quotes for strings.
- Keep Ruby 3.4 / Rails 8 compatibility in mind.


## When making plans
- The plan structure should include a list of actionable items.
- The plan should provide context about the problem it is trying to solve.
- The plan should also provide context about how the solution works to solve the problem.
- The plan should elaborate on tests to be added that confirm the solution works as thoroughly as possible.
