#!/bin/sh
# List the regression tests defined in Faust test files.
#
# Usage:
#   scripts/extract_tests.sh FILE.dsp [FILE.dsp ...]
#
# For each file, prints one line per test, in file order:
#
#   tests/filters_butterworth_tests.dsp:lowpass_test
#
# A test is a top-level definition whose name ends in `_test`, written at the
# start of a line (leading spaces allowed): `name_test = ...`. Commented lines
# (`// name_test = ...`, as in the #### Test sections of the .lib files) and
# definitions nested in expressions are not listed. Files that do not exist
# are skipped silently; no argument prints nothing.
#
# The Makefile calls it on tests/*.dsp to build TEST_SPECS, the list behind
# `make reference`, `make check` and `make bench`: each `file:name` pair
# becomes one tests/reference/<name>.ref and one tests/output/<name>.out, and
# `faust -pn <name> <file>` compiles that test alone. Test names must
# therefore be unique across all test files (see AGENTS.md, rule 1).
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
