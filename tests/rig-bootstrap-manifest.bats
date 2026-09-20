#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  STATE_HOME=$BATS_TEST_TMPDIR/state
  BREW_FAKE=$BATS_TEST_TMPDIR/brew
  BREW_LOG=$BATS_TEST_TMPDIR/brew.log
  MANIFEST=$BATS_TEST_TMPDIR/'Brew file = personal'
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME" "$STATE_HOME"
  : >"$MANIFEST"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "CALL" >>"$BREW_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$BREW_LOG"; done' \
    'printf "\n" >>"$BREW_LOG"' \
    '[ "${1:-}" != bundle ] || exit "${BREW_BUNDLE_STATUS:-0}"' \
    '[ "${1:-}" != list ] || exit 1' >"$BREW_FAKE"
  chmod +x "$BREW_FAKE"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' 'bootstrap-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.alpha]' 'name = "Alpha"' 'category = "core"' 'purpose = "Test bootstrap"' \
    'rationale = "Exercise manifest staging"' 'platforms = ["macos"]' \
    'install.provider = "homebrew"' 'install.kind = "formula"' 'install.locator = "example/alpha"' \
    '[profile.default]' 'tools = ["alpha"]' \
    '[provider.homebrew]' "executable = \"$BREW_FAKE\"" "manifest = \"$MANIFEST\"" >"$CONFIG_HOME/rig.toml"
}

run_rig() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$STATE_HOME" \
    RIG_PLATFORM=macos BREW_LOG="$BREW_LOG" "$RIG" "$@"
}

@test "bootstrap dry-run exposes Homebrew manifest stage without invocation" {
  run_rig bootstrap --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'MANAGER\tPROVIDER\tRESULT\tDETAIL'* ]]
  [[ "$output" == *$'manifest\thomebrew\tplanned\tbundle:'"$MANIFEST"* ]]
  [[ "$output" == *$'alpha\thomebrew\tplanned\t-'* ]]
  [ ! -e "$BREW_LOG" ]
}

@test "bootstrap applies Homebrew manifest exactly once before tools" {
  run_rig bootstrap
  [ "$status" -eq 0 ]
  [ "$(grep -c '^CALL <bundle>' "$BREW_LOG")" -eq 1 ]
  [ "${lines[0]}" = $'MANAGER\tPROVIDER\tRESULT\tDETAIL' ]
  [ "$(sed -n '1p' "$BREW_LOG")" = "CALL <bundle> <--file=$MANIFEST>" ]
  [ "$(sed -n '2p' "$BREW_LOG")" = 'CALL <install> <--formula> <example/alpha>' ]
}

@test "bootstrap preserves manifest failure and aborts later mutation" {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$STATE_HOME" \
    RIG_PLATFORM=macos BREW_LOG="$BREW_LOG" BREW_BUNDLE_STATUS=7 "$RIG" bootstrap
  [ "$status" -eq 7 ]
  [[ "$output" == *$'manifest\thomebrew\tfailed\texit:7'* ]]
  [ "$(wc -l <"$BREW_LOG" | tr -d ' ')" -eq 1 ]
  grep -F "CALL <bundle> <--file=$MANIFEST>" "$BREW_LOG"
}

@test "bootstrap preflights missing manifest before any mutation" {
  rm "$MANIFEST"
  run_rig bootstrap
  [ "$status" -ne 0 ]
  [[ "$output" == *"manifest is not a readable regular file: $MANIFEST"* ]]
  [ ! -e "$BREW_LOG" ]
}

@test "apply reconciles tools without implicitly applying provider manifest" {
  run_rig apply
  [ "$status" -eq 0 ]
  ! grep -F '<bundle>' "$BREW_LOG"
  grep -F 'CALL <install> <--formula> <example/alpha>' "$BREW_LOG"
}

@test "bootstrap preflights later providers before manifest mutation" {
  sed 's/tools = \["alpha"\]/tools = ["alpha", "beta"]/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/extended.toml"
  printf '%s\n' \
    '[tool.beta]' 'name = "Beta"' 'category = "core"' 'purpose = "Fail preflight"' \
    'rationale = "Prove complete preflight"' 'platforms = ["macos"]' \
    'install.provider = "runner"' 'install.kind = "package"' 'install.locator = "beta"' \
    '[provider.runner]' 'adapter = "custom"' 'executable = "/missing/rig-provider"' \
    'capabilities = ["apply"]' >>"$CONFIG_HOME/extended.toml"
  mv "$CONFIG_HOME/extended.toml" "$CONFIG_HOME/rig.toml"

  run_rig bootstrap
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider 'runner' executable unavailable: /missing/rig-provider"* ]]
  [ ! -e "$BREW_LOG" ]
}
