#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[category.extra]' 'name = "Extra"' 'purpose = "Additional tools"' \
    '[tool.selected]' 'name = "Selected"' 'category = "core"' \
    'purpose = "Selected purpose"' 'rationale = "Selected rationale"' 'platforms = ["any"]' \
    '[tool.other]' 'name = "Other"' 'category = "extra"' \
    'purpose = "Other purpose"' 'rationale = "Other rationale"' 'platforms = ["any"]' \
    '[profile.default]' 'tools = ["selected"]' >"$RIG_CONFIG_HOME/rig.toml"
}

@test "show selects setup by default and browses catalogue explicitly" {
  run "$RIG" show --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["command"] == "show" and [t["id"] for t in d["tools"]] == ["selected"]' || false

  run "$RIG" show --all --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert [t["id"] for t in d["tools"]] == ["other", "selected"]' || false

  run "$RIG" show --category extra --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["tools"] == []' || false

  run "$RIG" show --all --category extra --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert [t["id"] for t in d["tools"]] == ["other"]' || false
}

@test "show rejects conflicting selectors before configuration discovery" {
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/absent
  for arguments in 'selected --all' 'selected --profile default' 'selected --category core' '--all --profile default' '--all --all' 'selected other'; do
    read -r -a words <<< "$arguments"
    run "$RIG" show "${words[@]}"
    [ "$status" -eq 2 ]
    [[ "$output" == *'usage: rig show [ITEM]'* ]] || false
    [[ "$output" != *'no configuration sources'* ]] || false
  done
}

@test "doctor verbose adds structured diagnostics while retaining findings" {
  run "$RIG" doctor --verbose --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["command"] == "doctor" and d["healthy"] and d["diagnostics"]["configuration"]["status"] == "valid" and d["diagnostics"]["configuration"]["tools"] == 2 and d["profile"] == "default"' || false

  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/absent
  run "$RIG" doctor --verbose --format json
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert not d["healthy"] and d["findings"]["configuration"] and d["diagnostics"]["configuration"]["status"] == "missing"' || false
}

@test "doctor rejects repeated options before discovery" {
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/absent
  for arguments in '--verbose --verbose' '--profile default --profile default' '--format text --format json' '--help unexpected'; do
    read -r -a words <<< "$arguments"
    run "$RIG" doctor "${words[@]}"
    [ "$status" -eq 2 ]
    [[ "$output" == *'usage: rig doctor'* ]] || false
    [[ "$output" != *'no configuration sources'* ]] || false
  done
}
