#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME" "$TEST_HOME"
  source "$BATS_TEST_DIRNAME/helpers/large-catalogue-fixture.bash"
}

output_has_table_row() {
  local expected

  expected=$1
  printf '%s\n' "$output" | awk -v expected="$expected" '
    { gsub(/  +/, "\t"); if ($0 == expected) found = 1 }
    END { exit !found }
  '
}

@test "representative catalogue stays within the portable query guard" {
  # A shared runner's timing is not evidence: the same measurement that takes
  # three seconds on a workstation took nine against an eight-second budget on
  # a hosted macOS runner. The budget is asserted where the machine is known.
  [ -z "${CI:-}" ] ||
    skip 'shared runner timing is not evidence; run scripts/benchmark-rig locally'

  run env RIG_BENCHMARK_BUDGET_SECONDS=5 "$BATS_TEST_DIRNAME/../scripts/benchmark-rig"

  [ "$status" -eq 0 ]
  [[ "$output" == *"show-item:"*"budget 5s"* ]] || false
  [[ "$output" == *"show:"*"budget 5s"* ]] || false
  [[ "$output" == *"show-all:"*"budget 5s"* ]] || false
  [[ "$output" == *"status:"*"budget 8s"* ]] || false
}

@test "equivalent built-in observations share one native snapshot" {
  local fake_uv invocation_log
  fake_uv=$BATS_TEST_TMPDIR/uv
  invocation_log=$BATS_TEST_TMPDIR/uv.log
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$*" >>"$RIG_TEST_LOG"' \
    'printf "%s\n" "ruff v1.0" "black v2.0"' >"$fake_uv"
  chmod +x "$fake_uv"
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Core tools"' \
    '[tool.ruff]' \
    'name = "Ruff"' \
    'category = "core"' \
    'purpose = "Lint Python"' \
    'rationale = "Keep Python consistent"' \
    'platforms = ["any"]' \
    'install.provider = "uv"' \
    'install.kind = "tool"' \
    'install.locator = "ruff"' \
    '[tool.black]' \
    'name = "Black"' \
    'category = "core"' \
    'purpose = "Format Python"' \
    'rationale = "Keep Python readable"' \
    'platforms = ["any"]' \
    'install.provider = "uv"' \
    'install.kind = "tool"' \
    'install.locator = "black"' \
    '[profile.default]' \
    'tools = ["ruff", "black"]' \
    '[provider.uv]' \
    "executable = \"$fake_uv\"" >"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_LOG="$invocation_log" "$RIG" status

  [ "$status" -eq 0 ]
  output_has_table_row $'ruff\tuv\tpresent\t-'
  output_has_table_row $'black\tuv\tpresent\t-'
  [ "$(wc -l <"$invocation_log" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$invocation_log")" = "tool list" ]
}

@test "assembled runtime drift check fails closed" {
  local drifted_runtime
  drifted_runtime=$BATS_TEST_TMPDIR/rig
  cp "$RIG" "$drifted_runtime"
  printf '\n# drift\n' >>"$drifted_runtime"

  run env RIG_ASSEMBLY_OUTPUT="$drifted_runtime" "$BATS_TEST_DIRNAME/../scripts/assemble-rig" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/rig differs from its authored modules"* ]] || false
}

write_targeted_catalogue_fixture() {
  local index tool

  {
    printf '%s\n' \
      '[rig]' 'schema = 1' 'default-profile = "laptop"' \
      '[category.core]' 'name = "Core"' 'purpose = "Core tools"'
    index=1
    while [ "$index" -le 24 ]; do
      printf -v tool 'tool-%02d' "$index"
      printf '%s\n' "[tool.$tool]" "name = \"Tool $index\"" 'category = "core"' \
        'purpose = "Exercise targeted planning"' 'rationale = "Keep unrelated work out of a target"' \
        'platforms = ["macos"]' 'install.provider = "homebrew"' 'install.kind = "formula"' \
        "install.locator = \"example/$tool\""
      # Every fourth tool waits on its predecessor, as a real catalogue's
      # requirements interleave with independent tools.
      [ $((index % 4)) -ne 0 ] || printf 'requires = ["tool-%02d"]\n' "$((index - 1))"
      # An early name waiting on a later one exercises out-of-order planning.
      [ "$index" -ne 2 ] || printf '%s\n' 'requires = ["tool-09"]'
      index=$((index + 1))
    done
    for tool in morning evening; do
      printf '%s\n' "[scheduled-job.$tool]" "name = \"$tool\"" 'purpose = "Exercise targeted planning"' \
        'rationale = "Keep unrelated work out of a target"' 'provider = "launchd"' \
        "locator = \"example.test.$tool\"" 'platforms = ["macos"]' 'desired-state = "enabled"' \
        'program = ["/usr/bin/true"]' 'schedule.calendar = ["hour=8,minute=0"]' \
        'run-policy = "scheduled-only"' 'priority = "background"'
    done
    printf '%s\n' 'requires = ["tool-08"]'
    printf '%s\n' '[profile.core]' 'kind = "complete"' 'tools = ['
    index=24
    while [ "$index" -ge 1 ]; do
      printf '  "tool-%02d",\n' "$index"
      index=$((index - 1))
    done
    printf '%s\n' ']' '[profile.laptop]' 'kind = "complete"' 'inherits = ["core"]' \
      'scheduled-jobs = ["morning", "evening"]'
  } >"$CONFIG_HOME/rig.toml"
}

@test "targeted apply observes only the target and its dependency closure" {
  local launchd_log
  launchd_log=$BATS_TEST_TMPDIR/launchctl.log
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$RIG_TEST_LAUNCHD_LOG"' \
    'case "${1:-}" in print) exit 113 ;; esac' 'exit 0' >"$BATS_TEST_TMPDIR/launchctl"
  chmod +x "$BATS_TEST_TMPDIR/launchctl"
  rig_test_provider brew
  rig_test_provider_response brew 'list --formula --versions tool-07' 1 -
  rig_test_provider_response brew 'list --formula --versions tool-08' 1 -
  write_targeted_catalogue_fixture

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_LAUNCHCTL="$BATS_TEST_TMPDIR/launchctl" \
    RIG_TEST_LAUNCHD_LOG="$launchd_log" "$RIG" apply --dry-run --profile laptop \
    --target scheduled-job:evening --target scheduled-job:evening

  [ "$status" -eq 0 ]
  rig_test_report_contains "$output" $'tool-07\thomebrew\tplanned\t-\tdependency
tool-08\thomebrew\tplanned\t-\tdependency
evening\tscheduled-job\tlaunchd\tplanned\treconcile:example.test.evening\ttarget
Summary: planned=3 completed=0 failed=0 skipped=0'
  [[ "$output" != *morning* ]] || false
  # Only the closure reaches the native manager; any other observation is an
  # undeclared stub call that fails with status 99.
  [ "$(sort "$RIG_TEST_PROVIDER_LOG")" = $'brew|list --formula --versions tool-07\nbrew|list --formula --versions tool-08' ]
  [ ! -s "$launchd_log" ] || [ "$(grep -cv 'example.test.evening' "$launchd_log")" -eq 0 ]
}

@test "dependency-ordered plan keeps the lowest ready tool first" {
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$RIG_TEST_PROVIDER_BIN/brew"
  chmod +x "$RIG_TEST_PROVIDER_BIN/brew"
  write_targeted_catalogue_fixture

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" apply --dry-run --profile laptop --scope tools

  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | awk '/^tool-/ { printf "%s ", $1 }')" = \
    'tool-01 tool-03 tool-04 tool-05 tool-06 tool-07 tool-08 tool-09 tool-02 tool-10 tool-11 tool-12 tool-13 tool-14 tool-15 tool-16 tool-17 tool-18 tool-19 tool-20 tool-21 tool-22 tool-23 tool-24 ' ]
}
