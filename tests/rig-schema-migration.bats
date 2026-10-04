#!/usr/bin/env bats

load helpers/isolate

setup() {
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME/conf.d"
}

write_legacy_config() {
  printf '%s\n' '[rig]' 'schema = 1 # obsolete marker' 'default-profile = "default"' \
    '[profile.default]' 'kind = "complete"' >"$RIG_CONFIG_HOME/rig.toml"
}

@test "init writes an unversioned config and ordinary reads do not add a marker" {
  run "$RIG" init
  [ "$status" -eq 0 ] || false
  ! grep -Fq 'schema =' "$RIG_CONFIG_HOME/rig.toml" || false

  run "$RIG" show
  [ "$status" -eq 0 ] || false
  ! grep -Fq 'schema =' "$RIG_CONFIG_HOME/rig.toml" || false

  run "$RIG" doctor --verbose --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"schema":1'* ]] || false
  [[ "$output" != *'"fragment_count":0,"schema"'* ]] || false
}

@test "legacy repair previews and writes only a reviewed proposal outside active config" {
  write_legacy_config
  cp "$RIG_CONFIG_HOME/rig.toml" "$BATS_TEST_TMPDIR/original.toml"

  run "$RIG" repair
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Would remove the legacy schema field'* ]] || false
  [[ "$output" == *'default-profile = "default"'* ]] || false
  cmp "$RIG_CONFIG_HOME/rig.toml" "$BATS_TEST_TMPDIR/original.toml" || false

  run "$RIG" repair --output "$BATS_TEST_TMPDIR/repaired.toml"
  [ "$status" -eq 0 ] || false
  [ -f "$BATS_TEST_TMPDIR/repaired.toml" ] || false
  ! grep -Fq 'schema =' "$BATS_TEST_TMPDIR/repaired.toml" || false
  grep -Fqx 'default-profile = "default"' "$BATS_TEST_TMPDIR/repaired.toml" || false
  sed '/schema = 1/d' "$BATS_TEST_TMPDIR/original.toml" >"$BATS_TEST_TMPDIR/expected.toml"
  cmp "$BATS_TEST_TMPDIR/repaired.toml" "$BATS_TEST_TMPDIR/expected.toml" || false
  cmp "$RIG_CONFIG_HOME/rig.toml" "$BATS_TEST_TMPDIR/original.toml" || false

  run "$RIG" repair --output "$BATS_TEST_TMPDIR/repaired.toml"
  [ "$status" -eq 2 ] || false
  run "$RIG" repair --output "$RIG_CONFIG_HOME/conf.d/repaired.toml"
  [ "$status" -eq 2 ] || false
  [ ! -e "$RIG_CONFIG_HOME/conf.d/repaired.toml" ] || false
}

@test "unknown or malformed legacy input cannot produce a repair proposal" {
  write_legacy_config
  sed 's/schema = 1/schema = 2/' "$RIG_CONFIG_HOME/rig.toml" >"$RIG_CONFIG_HOME/unknown.toml"
  mv "$RIG_CONFIG_HOME/unknown.toml" "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" repair --output "$BATS_TEST_TMPDIR/repaired.toml"
  [ "$status" -eq 2 ] || false
  [ ! -e "$BATS_TEST_TMPDIR/repaired.toml" ] || false

  write_legacy_config
  printf '%s\n' '[tool.broken]' 'name = "Broken"' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" repair --output "$BATS_TEST_TMPDIR/repaired.toml"
  [ "$status" -eq 2 ] || false
  [ ! -e "$BATS_TEST_TMPDIR/repaired.toml" ] || false
}

@test "repair locates a legacy root declaration in a fragment" {
  write_legacy_config
  mv "$RIG_CONFIG_HOME/rig.toml" "$RIG_CONFIG_HOME/conf.d/10-root.toml"

  run "$RIG" repair
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'conf.d/10-root.toml:2'* ]] || false
  grep -Fq 'schema = 1' "$RIG_CONFIG_HOME/conf.d/10-root.toml" || false

  run "$RIG" repair --output "$BATS_TEST_TMPDIR/repaired.toml"
  [ "$status" -eq 0 ] || false
  ! grep -Fq 'schema =' "$BATS_TEST_TMPDIR/repaired.toml" || false
  grep -Fq 'schema = 1' "$RIG_CONFIG_HOME/conf.d/10-root.toml" || false
}

@test "repair options stay aligned in help and both completions" {
  run "$RIG" repair --help
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Usage: rig repair'* ]] || false
  [[ "$output" == *'--output PATH'* ]] || false

  run "$RIG" completion bash
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'--output'* ]] || false
  run "$RIG" completion zsh
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'--output'* ]] || false
}
