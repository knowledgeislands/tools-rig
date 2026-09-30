#!/usr/bin/env bats

source "$BATS_TEST_DIRNAME/helpers/isolate.bash"

setup() {
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME/conf.d"
  printf '%s\n' '[publication.legacy]' >"$RIG_CONFIG_HOME/conf.d/10-bad.toml"
  export RIG_CONFIG_HOME
}

@test "doctor diagnoses a retired configuration section and retains machine checks" {
  run "$RIG" doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'Rig doctor: findings'* ]] || false
  [[ "$output" == *'Configuration findings:'* ]] || false
  [[ "$output" == *'10-bad.toml:1: [publication.legacy] is retired; export a view profile with rig export --profile'* ]] || false
  [[ "$output" == *'Platform: macos'* ]] || false
  [[ "$output" == *"config path: $RIG_CONFIG_HOME"* ]] || false
  [[ "$output" == *'brew: unavailable; owner=environment; action=none'* ]] || false
  [[ "$output" == *'Summary: findings=1 present=0 catalogue-only=0 incompatible-platform=0'* ]] || false
}

@test "doctor projects the same configuration finding as JSON" {
  run "$RIG" doctor --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == '{"schema":1,'* ]] || false
  [[ "$output" == *'"healthy":false'* ]] || false
  [[ "$output" == *'"configuration":["'*'10-bad.toml:1: [publication.legacy] is retired'* ]] || false
  [[ "$output" == *'"information":["config path: '* ]] || false
  [[ "$output" == *'"brew: unavailable; owner=environment; action=none"'* ]] || false
}

@test "status and apply still reject the unusable configuration" {
  run "$RIG" status
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'10-bad.toml:1: [publication.legacy] is retired'* ]] || false

  run "$RIG" apply --dry-run
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'10-bad.toml:1: [publication.legacy] is retired'* ]] || false
}

@test "doctor still rejects invalid syntax before loading configuration" {
  run "$RIG" doctor --format invalid
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'Usage:'* ]] || false
  [[ "$output" != *'Configuration findings:'* ]] || false
}
