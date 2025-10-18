#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
  exit 0
fi

for file in "$@"; do
  if [ -f "$file" ]; then
    grep -E '^[[:space:]]*[A-Za-z0-9_]+_test[[:space:]]*=' "$file" | \
      sed -E 's/^[[:space:]]*([A-Za-z0-9_]+)_test[[:space:]]*=.*/\1_test/' | \
      while read -r test; do
        if [ -n "$test" ]; then
          printf '%s:%s\n' "$file" "$test"
        fi
      done
  fi
done
