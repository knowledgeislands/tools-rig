#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  UV_FAKE=$BATS_TEST_TMPDIR/uv
  UV_LOG=$BATS_TEST_TMPDIR/uv.log
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "CALL" >>"$UV_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$UV_LOG"; done' \
    'printf "\n" >>"$UV_LOG"' \
    'if [ "$1 $2" = "tool list" ]; then printf "%s\n" "headroom-ai v1.0.0"; fi' >"$UV_FAKE"
  chmod +x "$UV_FAKE"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.headroom]' 'name = "Headroom"' 'category = "core"' 'purpose = "Manage context"' \
    'rationale = "Exercise uv extras"' 'platforms = ["macos"]' \
    'install.provider = "uv"' 'install.kind = "tool"' 'install.locator = "headroom-ai[all]"' \
    '[profile.default]' 'tools = ["headroom"]' \
    '[provider.uv]' "executable = \"$UV_FAKE\"" >"$CONFIG_HOME/rig.toml"
}

output_has_table_row() {
  local expected

  expected=$1
  printf '%s\n' "$output" | awk -v expected="$expected" '
    { gsub(/  +/, "\t"); if ($0 == expected) found = 1 }
    END { exit !found }
  '
}

@test "uv extras locator observes base distribution as present" {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    UV_LOG="$UV_LOG" "$RIG" status
  [ "$status" -eq 0 ]
  output_has_table_row $'headroom\tuv\tpresent\t-'
  grep -F 'CALL <tool> <list>' "$UV_LOG"
}

@test "uv apply preserves authored extras locator" {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    UV_LOG="$UV_LOG" "$RIG" apply
  [ "$status" -eq 0 ]
  grep -F 'CALL <tool> <install> <headroom-ai[all]>' "$UV_LOG"
}
