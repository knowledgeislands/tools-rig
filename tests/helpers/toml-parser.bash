# Locate an interpreter that can parse TOML.
#
# A handful of tests parse a fixture with a real TOML parser to prove Rig's
# configuration grammar is interoperable rather than Rig-specific. That parser
# is test infrastructure, not a Rig dependency: the executable itself must need
# nothing beyond Bash, which the restricted-PATH run asserts separately.
#
# macOS ships Python 3.9, and `tomllib` arrived in 3.11, so the system
# interpreter cannot answer. RIG_TEST_PYTHON names one that can.

rig_toml_parser() {
  local candidate

  for candidate in "${RIG_TEST_PYTHON:-}" python3 python3.14 python3.13 python3.12 python3.11; do
    [ -n "$candidate" ] || continue
    if "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
      # shellcheck disable=SC2034  # read by the tests that call require_toml_parser
      RIG_TOML_PARSER=$candidate
      return 0
    fi
  done

  return 1
}

require_toml_parser() {
  rig_toml_parser ||
    skip 'no interpreter with tomllib on PATH or named by RIG_TEST_PYTHON'
}
