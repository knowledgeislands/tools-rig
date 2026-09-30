# Isolate one test from the machine that runs it.
#
# A person's shell exports XDG_CONFIG_HOME and XDG_STATE_HOME, so an invocation
# that names neither RIG_CONFIG_HOME nor RIG_STATE_HOME reads the runner's own
# catalogue and reconciliation receipt. The launchd adapter then defaults to
# /bin/launchctl in gui/<uid>, which is the runner's live user domain. A test
# that forgets one override therefore reconciles the machine it is testing on,
# and an apply retires the resources it finds there.
#
# The macOS mutators are the same hazard by a different route: defaults,
# dockutil, and killall resolve as bare command names, so an invocation that
# names no override rewrites the runner's own preferences and Dock and signals
# its processes.
#
# Call rig_test_isolate as the first statement of every setup. It removes the
# inherited base directories, moves HOME into the test's own tree, and points
# the launchd adapter and the three macOS mutators at inert stubs in the test's
# own tree, launchd in a domain no machine owns. An explicit override on a
# single invocation still wins, so a test that stubs one of them itself is
# unaffected.
# The focused guard in tests/rig.bats asserts these default boundaries.
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

  # The macOS mutators resolve as bare command names, so an invocation that
  # names no override reaches the runner's real preferences, Dock, and
  # processes. Moving HOME above does not contain defaults: it reaches the user
  # domain through cfprefsd rather than through $HOME, so a run under a
  # sandboxed HOME writes the real domain using the sandboxed path as its
  # value. A read reports the key absent so the assertion fails where it
  # belongs, and every mutation is accepted and discarded. Each stub logs its
  # own argv beside itself, so a test can prove the stub received the call
  # rather than inferring containment from the runner's own values — a key the
  # runner happens not to have set reads as absent either way.
  stub=$BATS_TEST_TMPDIR/isolated-defaults
  # The stub defers its own expansion to the shell that runs it.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\\n" "$*" >>"$0.log"' \
    'case "${1:-}" in' \
    '  read|read-type) exit 1 ;;' \
    'esac' \
    'exit 0' >"$stub"
  chmod +x "$stub"
  export RIG_DEFAULTS=$stub

  # An empty --list reports a Dock with no items; anything else is accepted.
  stub=$BATS_TEST_TMPDIR/isolated-dockutil
  # shellcheck disable=SC2016
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >>"$0.log"' 'exit 0' >"$stub"
  chmod +x "$stub"
  export RIG_DOCKUTIL=$stub

  # Unpinned, this signals the processes of the person running the suite.
  stub=$BATS_TEST_TMPDIR/isolated-killall
  # shellcheck disable=SC2016
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >>"$0.log"' 'exit 0' >"$stub"
  chmod +x "$stub"
  export RIG_KILLALL=$stub
}
