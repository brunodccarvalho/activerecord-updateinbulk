# Changelog

## Changes in 0.2.0

- Removed built-in formula identifiers `:min` and `:max`.
- Removed custom compatibility Arel nodes and visitors for `LEAST`/`GREATEST`.
  Custom formulas remain supported via user-provided Procs returning Arel nodes.
- Added `config.active_record_update_in_bulk.ignore_scope_order` config option.
