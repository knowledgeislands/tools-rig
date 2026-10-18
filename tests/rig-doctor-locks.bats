#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/helpers/isolate.bash"

setup() {
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  export RIG_STATE_HOME=$BATS_TEST_TMPDIR/state
  mkdir -p "$RIG_CONFIG_HOME" "$RIG_STATE_HOME"
  cat >"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[rig]
default-profile = "default"
[profile.default]
name = "Fixture"
TOML
}

hold_lock() {
  mkdir -p "$RIG_STATE_HOME/$1/macos.lock"
  [ "$#" -lt 2 ] || printf '%s\n' "$2" >"$RIG_STATE_HOME/$1/macos.lock/owner"
}

state_listing() {
  (cd "$RIG_STATE_HOME" && find . | LC_ALL=C sort && find . -type f -exec cat {} +)
}

@test "doctor without a held lock adds no lock finding and creates no lock" {
  run "$RIG" doctor
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'Verdict: healthy'* ]] || false
  [[ "$output" == *'Coverage: configuration,xdg,tools,resources,ports,skills,apply-history,locks'* ]] || false
  [[ "$output" != *'Lock findings:'* ]] || false
  run "$RIG" doctor --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"locks":[]'* ]] || false
  [ ! -e "$RIG_STATE_HOME/operation" ] || false
  [ ! -e "$RIG_STATE_HOME/reconciliation" ] || false
}

@test "an active lock owner warns without changing the verdict" {
  hold_lock operation "pid=$$ profile=default command=apply"
  run "$RIG" doctor
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'Verdict: healthy'* ]] || false
  [[ "$output" == *'warn=1 fail=0'* ]] || false
  [[ "$output" == *$'Warnings:\n  operation-lock: active (owner-command:apply); owner=rig; action=wait-for-owner'* ]] || false
  [[ "$output" != *'Lock recovery'* ]] || false
  [[ "$output" != *'Lock findings:'* ]] || false
}

@test "stale and unknown locks fail and text alone names the recovery path" {
  hold_lock operation 'pid=999999 profile=default command=remove'
  hold_lock reconciliation
  before=$(state_listing)
  run "$RIG" doctor
  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'Verdict: unhealthy'* ]] || false
  [[ "$output" == *'warn=0 fail=2'* ]] || false
  [[ "$output" == *$'Lock findings:\n  operation-lock: stale (owner-command:remove); owner=rig; action=remove-lock-after-owner-exits\n  reconciliation-lock: unknown (owner-command:unknown); owner=rig; action=remove-lock-after-owner-exits'* ]] || false
  [[ "$output" == *"  operation-lock: rm -r -- $(printf '%q' "$RIG_STATE_HOME/operation/macos.lock")"* ]] || false
  [[ "$output" == *"  reconciliation-lock: rm -r -- $(printf '%q' "$RIG_STATE_HOME/reconciliation/macos.lock")"* ]] || false

  run "$RIG" doctor --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"locks":["operation-lock: stale (owner-command:remove); owner=rig; action=remove-lock-after-owner-exits","reconciliation-lock: unknown (owner-command:unknown); owner=rig; action=remove-lock-after-owner-exits"]'* ]] || false
  [[ "$output" != *'rm -r'* ]] || false
  [[ "$output" != *'.lock'* ]] || false
  [ "$(state_listing)" = "$before" ] || false
}

@test "an unsafe lock path fails without being followed" {
  mkdir -p "$RIG_STATE_HOME/operation" "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$RIG_STATE_HOME/operation/macos.lock"
  run "$RIG" doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'operation-lock: unsafe (not-a-lock-directory); owner=rig; action=inspect-state-directory'* ]] || false
  [[ "$output" != *'Lock recovery'* ]] || false
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/elsewhere")" ] || false
}

@test "doctor reports a stale lock when configuration cannot load" {
  printf '%s\n' '[publication.legacy]' >"$RIG_CONFIG_HOME/rig.toml"
  hold_lock operation 'pid=999999 profile=default command=apply'
  run "$RIG" doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'Configuration findings:'* ]] || false
  [[ "$output" == *'Coverage: configuration,xdg,apply-history,locks'* ]] || false
  [[ "$output" == *'operation-lock: stale (owner-command:apply)'* ]] || false
  [[ "$output" == *'fail=2'* ]] || false
}
