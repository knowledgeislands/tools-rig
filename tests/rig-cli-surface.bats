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

@test "status rejects repeated options before discovery" {
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/absent
  for arguments in '--profile default --profile default' '--problems --problems' '--unmanaged --unmanaged' '--retired --retired' '--profile=default --profile default'; do
    read -r -a words <<< "$arguments"
    run "$RIG" status "${words[@]}"
    [ "$status" -eq 2 ] || false
    [[ "$output" == *'usage: rig status'* ]] || false
    [[ "$output" != *'no configuration sources'* ]] || false
  done
}

@test "remove keeps an option-like profile value verbatim" {
  for value in --format --json; do
    run "$RIG" remove --profile "$value" --format json
    [ "$status" -ne 0 ]
    [[ "$output" == *"profile '$value'"* ]] || false
    [[ "$output" != *'usage: rig remove'* ]] || false
  done
  run "$RIG" remove --profile=--format
  [ "$status" -ne 0 ]
  [[ "$output" == *"profile '--format'"* ]] || false
  run "$RIG" remove -- --format json
  [ "$status" -eq 2 ]
}

# JSON output stamps its observation time, so comparisons drop that field.
without_time() {
  sed 's/"observed_at":"[^"]*"//'
}

@test "long option values accept the equals form" {
  for pair in '--format=json|--format json' '--profile=default --category=core --format=json|--profile default --category core --format json' '--category=extra --all --format=json|--category extra --all --format json'; do
    read -r -a equals <<< "${pair%|*}"
    read -r -a separate <<< "${pair#*|}"
    run "$RIG" show "${equals[@]}"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | without_time)" = "$("$RIG" show "${separate[@]}" | without_time)" ] || false
  done
  run "$RIG" status --format=json
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | without_time)" = "$("$RIG" status --format json | without_time)" ] || false
  run "$RIG" status --profile=default --problems
  [ "$status" -eq 0 ]
  [ "$output" = "$("$RIG" status --profile default --problems)" ] || false
  run "$RIG" apply --dry-run --scope=tools --target=selected --target=other --format=json
  separate_output=$output
  separate_status=$status
  run "$RIG" apply --dry-run --scope tools --target selected --target other --format json
  [ "$status" -eq "$separate_status" ] || false
  [ "$output" = "$separate_output" ] || false
}

@test "json flag equals the json format" {
  for command in show status doctor; do
    run "$RIG" "$command" --json
    json_status=$status
    json_output=$(printf '%s\n' "$output" | without_time)
    run "$RIG" "$command" --format json
    [ "$status" -eq "$json_status" ] || false
    [ "$(printf '%s\n' "$output" | without_time)" = "$json_output" ] || false
  done
  run "$RIG" show --json
  printf '%s\n' "$output" | /usr/bin/python3 -c 'import json,sys; assert json.load(sys.stdin)["command"] == "show"' || false
}

@test "option grammar violations exit with usage" {
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/absent
  for arguments in 'init --dry-run=x' 'show --all=yes' 'show --json=yes' 'show --json --format text' 'status --format text --json' 'show -n' 'status -n' 'status -- x' 'diag -- x' 'show --format=yaml'; do
    read -r -a words <<< "$arguments"
    run "$RIG" "${words[@]}"
    [ "$status" -eq 2 ] || false
    [[ "$output" == *"usage: rig ${words[0]}"* ]] || false
    [[ "$output" != *'no configuration sources'* ]] || false
  done
  run "$RIG" show --profile=
  [ "$status" -eq 2 ] || false
}

@test "short dry run previews like the long form" {
  local config
  config=$RIG_CONFIG_HOME
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/fresh
  run "$RIG" init -n
  [ "$status" -eq 0 ]
  [[ "$output" == *'Would create:'* ]] || false
  [ ! -e "$RIG_CONFIG_HOME/rig.toml" ] || false
  [ "$output" = "$("$RIG" init --dry-run)" ] || false

  export RIG_CONFIG_HOME=$config
  printf '%s\n' \
    '[rig]' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.selected]' 'name = "Selected"' 'category = "core"' \
    'purpose = "Selected purpose"' 'rationale = "Selected rationale"' 'platforms = ["any"]' \
    'install.provider = "homebrew"' 'install.kind = "formula"' 'install.locator = "selected"' \
    '[profile.default]' 'tools = ["selected"]' >"$RIG_CONFIG_HOME/rig.toml"
  rig_test_provider brew
  rig_test_provider_response brew 'list --formula --versions selected' 1 -
  for command in apply remove upgrade; do
    run "$RIG" "$command" -n
    short_status=$status
    short_output=$output
    run "$RIG" "$command" --dry-run
    [ "$status" -eq "$short_status" ] || false
    [ "$output" = "$short_output" ] || false
  done
  run "$RIG" apply -n
  [ "$status" -eq 0 ]
  [[ "$output" == *'selected'* ]] || false
  ! grep -Fq 'install' "$RIG_TEST_PROVIDER_LOG" || false
}

@test "a value option takes the next word verbatim" {
  run "$RIG" show --profile -n
  [ "$status" -ne 0 ]
  [[ "$output" == *"-n"* ]] || false
  [[ "$output" != *'Would'* ]] || false
  [[ "$output" != *'usage: rig show'* ]] || false
}

@test "double dash ends option processing" {
  run "$RIG" show -- selected
  [ "$status" -eq 0 ]
  [ "$output" = "$("$RIG" show selected)" ] || false

  run "$RIG" show -- --all
  [ "$status" -ne 0 ]
  [[ "$output" != *'Other'* ]] || false
  [[ "$output" != *'usage: rig show'* ]] || false

  run "$RIG" show -- selected other
  [ "$status" -eq 2 ]

  run "$RIG" status --
  [ "$status" -eq 0 ]
  [ "$output" = "$("$RIG" status)" ] || false

  run "$RIG" help -- apply
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: rig apply'* ]] || false
  run "$RIG" help -- --help
  [ "$status" -eq 2 ]

  run "$RIG" completion -- bash
  [ "$status" -eq 0 ]
  [[ "$output" == *'complete -F _rig rig'* ]] || false
  run "$RIG" completion -- --help
  [ "$status" -eq 2 ]
}

@test "help and completion expose the short dry run and the json flag" {
  run "$RIG" apply --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: rig apply '*'[-n|--dry-run]'*'[--json]'* ]] || false
  [[ "$output" == *'  -n, --dry-run '* ]] || false
  [[ "$output" == *'  --json '* ]] || false
  run "$RIG" completion bash
  [[ "$output" == *'init) COMPREPLY=($(compgen -W "-h --help --dry-run -n"'* ]] || false
  [[ "$output" == *'show) COMPREPLY=($(compgen -W "-h --help --profile --all --category --format --json'* ]] || false
  run "$RIG" completion zsh
  [[ "$output" == *"'(-n --dry-run)'{-n,--dry-run}"* ]] || false
  [[ "$output" == *"'--json[Print JSON output; the same as --format json.]'"* ]] || false
  run zsh -f -c 'eval "$("$1" completion zsh)"; (( $+functions[_rig] ))' _ "$RIG"
  [ "$status" -eq 0 ]
}
