#!/usr/bin/env bash

# One executable may be linked under each native manager name by the harness.
manager=${0##*/}
printf '%s|%s\n' "$manager" "$*" >>"$RIG_TEST_PROVIDER_LOG"

while IFS='|' read -r expected_manager expected_argv expected_status expected_output; do
  [ "$expected_manager" = "$manager" ] || continue
  [ "$expected_argv" = "$*" ] || continue
  if [ "$expected_output" != - ]; then
    printf '%b\n' "$expected_output"
  fi
  exit "$expected_status"
done <"$RIG_TEST_PROVIDER_TABLE"

printf 'unexpected fixture invocation: %s %s\n' "$manager" "$*" >&2
exit 99
