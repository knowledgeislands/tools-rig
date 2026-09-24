#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  FAKE_BIN=$BATS_TEST_TMPDIR/bin
  CALL_LOG=$BATS_TEST_TMPDIR/calls
  MANIFEST=$BATS_TEST_TMPDIR/Brewfile
  mkdir -p "$CONFIG_HOME" "$TEST_HOME" "$FAKE_BIN"
  : >"$MANIFEST"

  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$1" in
  bundle)
    cp "$FAKE_BIN/mise.ready" "$FAKE_BIN/mise"
    chmod +x "$FAKE_BIN/mise"
    ;;
  list) exit 1 ;;
esac
SCRIPT
  cat >"$FAKE_BIN/mise.ready" <<'SCRIPT'
#!/usr/bin/env bash
printf 'mise\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$1:$2" in
  install:node)
    cp "$FAKE_BIN/npm.ready" "$FAKE_BIN/npm"
    chmod +x "$FAKE_BIN/npm"
    ;;
  which:*) exit 1 ;;
esac
SCRIPT
  cat >"$FAKE_BIN/npm.ready" <<'SCRIPT'
#!/usr/bin/env bash
printf 'npm\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$1" in
  list) exit 1 ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  cat >"$CONFIG_HOME/rig.toml" <<EOF
[rig]
schema = 1
default-profile = "default"
bootstrap-profile = "default"

[category.core]
name = "Core"
purpose = "Exercise staged manager bootstrap"

[tool.mise]
name = "mise"
category = "core"
purpose = "Provide runtime management"
rationale = "The selected runtime tools require mise"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "mise"
install.platforms = ["any"]

[tool.node]
name = "Node"
category = "core"
purpose = "Provide npm"
rationale = "The selected global packages require npm"
platforms = ["any"]
requires = ["mise"]
install.provider = "mise"
install.kind = "tool"
install.locator = "node"
install.platforms = ["any"]

[tool.typescript]
name = "TypeScript"
category = "core"
purpose = "Exercise npm installation"
rationale = "The fixture needs one npm global package"
platforms = ["any"]
requires = ["node"]
install.provider = "npm"
install.kind = "global"
install.locator = "typescript"
install.platforms = ["any"]

[profile.default]
tools = ["mise", "node", "typescript"]

[provider.homebrew]
executable = "$FAKE_BIN/brew"
manifest = "$MANIFEST"

[provider.mise]
executable = "$FAKE_BIN/mise"

[provider.npm]
executable = "$FAKE_BIN/npm"
EOF
}

run_rig() {
  run env \
    HOME="$TEST_HOME" \
    RIG_CONFIG_HOME="$CONFIG_HOME" \
    RIG_PLATFORM=fixture \
    RIG_TEST_LOG="$CALL_LOG" \
    FAKE_BIN="$FAKE_BIN" \
    "$RIG" "$@"
}

@test "bootstrap dry-run plans missing built-in manager prerequisites without mutation" {
  run_rig bootstrap --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *$'provider:mise\thomebrew\tplanned\tbootstrap-prerequisite'* ]] || false
  [[ "$output" == *$'provider:npm\tmise\tplanned\tbootstrap-prerequisite'* ]] || false
  [ ! -e "$CALL_LOG" ]
  [ ! -e "$FAKE_BIN/mise" ]
  [ ! -e "$FAKE_BIN/npm" ]
}

@test "bootstrap stages Homebrew then mise then npm global tools" {
  run_rig bootstrap

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$CALL_LOG")" = $'brew\tbundle --file='"$MANIFEST" ]
  [ "$(sed -n '2p' "$CALL_LOG")" = $'mise\tinstall node' ]
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
  [[ "$output" == *$'provider:mise\thomebrew\tcompleted\tavailable'* ]] || false
  [[ "$output" == *$'provider:npm\tmise\tcompleted\tavailable'* ]] || false
}
