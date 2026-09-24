#!/usr/bin/env bats

setup() {
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
  [[ "$output" == *"diag:"*"budget 5s"* ]] || false
  [[ "$output" == *"show:"*"budget 5s"* ]] || false
  [[ "$output" == *"list:"*"budget 5s"* ]] || false
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
