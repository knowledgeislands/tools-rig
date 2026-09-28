# Isolate one test from the machine that runs it.
#
# A person's shell exports XDG_CONFIG_HOME and XDG_STATE_HOME, so an invocation
# that names neither RIG_CONFIG_HOME nor RIG_STATE_HOME reads the runner's own
# catalogue and reconciliation receipt. The launchd adapter then defaults to
# /bin/launchctl in gui/<uid>, which is the runner's live user domain. A test
# that forgets one override therefore reconciles the machine it is testing on,
# and an apply retires the resources it finds there.
#
# Call rig_test_isolate as the first statement of every setup. It removes the
# inherited base directories, moves HOME into the test's own tree, and points
# the launchd adapter at an inert stub in a domain no machine owns. An explicit
# override on a single invocation still wins, so a test that stubs launchctl
# itself is unaffected.
rig_test_isolate() {
  local stub

  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
  unset RIG_CONFIG_HOME RIG_DATA_HOME RIG_STATE_HOME RIG_CACHE_HOME

  RIG_TEST_ISOLATED_HOME=$BATS_TEST_TMPDIR/isolated-home
  mkdir -p "$RIG_TEST_ISOLATED_HOME"
  export HOME=$RIG_TEST_ISOLATED_HOME

  # The stub reports every label absent and accepts every mutation, so a
  # forgotten override fails the assertion it belongs to rather than the
  # runner's launchd domain.
  stub=$BATS_TEST_TMPDIR/isolated-launchctl
  # The stub defers its own expansion to the shell that runs it.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'case "${1:-}" in' \
    '  print) exit 113 ;;' \
    'esac' \
    'exit 0' >"$stub"
  chmod +x "$stub"
  export RIG_LAUNCHCTL=$stub
  export RIG_LAUNCHD_DOMAIN=gui/rig-test
}
