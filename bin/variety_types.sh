#!/usr/bin/env bash

for adapter in sqlite3 postgresql mysql2; do
  echo "Adapter: $adapter"
  ARCONN="$adapter" "$(dirname "$0")/console" -e "puts JSON.pretty_generate TypeVariety.columns.index_by(&:name).transform_values { |c| [c.sql_type, c.type].join(' | ') }; exit 0"
done
