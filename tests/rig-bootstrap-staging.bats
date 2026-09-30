#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  FAKE_BIN=$BATS_TEST_TMPDIR/bin
  CALL_LOG=$BATS_TEST_TMPDIR/calls
  mkdir -p "$CONFIG_HOME" "$TEST_HOME" "$FAKE_BIN"

  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$1" in
  install)
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

[category.core]
name = "Core"
purpose = "Exercise declared prerequisite ordering"

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

@test "apply dry-run plans declared manager prerequisites without mutation" {
  run_rig apply --dry-run

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'mise\thomebrew\tplanned\t-' || false
  rig_test_report_contains "$output" $'node\tmise\tplanned\t-' || false
  rig_test_report_contains "$output" $'typescript\tnpm\tplanned\t-' || false
  [ ! -e "$CALL_LOG" ]
  [ ! -e "$FAKE_BIN/mise" ]
  [ ! -e "$FAKE_BIN/npm" ]
}

@test "apply installs declared managers once before their consumers without Bundle" {
  run_rig apply

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [ "$(sed -n '1p' "$CALL_LOG")" = $'brew\tinstall --formula mise' ]
  [ "$(sed -n '2p' "$CALL_LOG")" = $'mise\tinstall node' ]
  [ "$(sed -n '3p' "$CALL_LOG")" = $'npm\tinstall --global typescript' ]
  [ "$(wc -l <"$CALL_LOG" | tr -d ' ')" -eq 3 ]
  ! grep -Fq bundle "$CALL_LOG" || false
}

@test "apply refuses a missing manager without an explicit selected prerequisite" {
  sed '/requires = \["mise"\]/d' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/without-dependency"
  mv "$CONFIG_HOME/without-dependency" "$CONFIG_HOME/rig.toml"

  run_rig apply --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'mise' executable is unavailable"* ]] || false
  [ ! -e "$CALL_LOG" ]
}

@test "targeted apply includes only absent declared prerequisites" {
  run_rig apply --target typescript

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  grep -Fqx $'brew\tinstall --formula mise' "$CALL_LOG"
  grep -Fqx $'mise\tinstall node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
  rig_test_report_contains "$output" $'mise\thomebrew\tcompleted\t-\tdependency' || false
  rig_test_report_contains "$output" $'typescript\tnpm\tcompleted\t-\ttarget' || false
}

@test "failed declared manager blocks consumers before they execute" {
  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
exit 3
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  run_rig apply

  [ "$status" -eq 1 ]
  rig_test_report_contains "$output" $'mise\thomebrew\tfailed\texit:3' || false
  rig_test_report_contains "$output" $'node\tmise\tskipped\tblocked-by:mise' || false
  rig_test_report_contains "$output" $'typescript\tnpm\tskipped\tblocked-by:node' || false
  [ "$(wc -l <"$CALL_LOG" | tr -d ' ')" -eq 1 ]
  [ ! -e "$FAKE_BIN/mise" ]
  [ ! -e "$FAKE_BIN/npm" ]
}

@test "successful prerequisite must make its manager executable available" {
  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
exit 0
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  run_rig apply

  [ "$status" -eq 1 ]
  rig_test_report_contains "$output" $'mise\thomebrew\tcompleted\t-' || false
  rig_test_report_contains "$output" $'node\tmise\tfailed\texit:1' || false
  [ "$(wc -l <"$CALL_LOG" | tr -d ' ')" -eq 1 ]
  [ ! -e "$FAKE_BIN/npm" ]
}

@test "apply preflights unrelated missing executables before manager mutation" {
  sed 's/install.provider = "npm"/install.provider = "uv"/; s/install.kind = "global"/install.kind = "tool"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unavailable-provider"
  mv "$CONFIG_HOME/unavailable-provider" "$CONFIG_HOME/rig.toml"

  run_rig apply

  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'uv' executable is unavailable"* ]] || false
  [ ! -e "$CALL_LOG" ]
}

@test "failed apply does not defer missing managers in a later sourceable preflight" {
  sed 's/install.provider = "npm"/install.provider = "uv"/; s/install.kind = "global"/install.kind = "tool"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unavailable-provider"
  mv "$CONFIG_HOME/unavailable-provider" "$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=fixture \
    RIG_TEST_LOG="$CALL_LOG" FAKE_BIN="$FAKE_BIN" bash -c '
      source "$1"
      rig_command_apply_impl --dry-run >/dev/null 2>&1
      printf "apply-status=%s\n" "$?"
      printf "deferred-providers=%s deferred-skills=%s\n" "$RIG_APPLY_ALLOW_DEFERRED_PROVIDERS" "$RIG_APPLY_ALLOW_DEFERRED_SKILLS"
      rig_plan_index node || exit
      index=$RIG_INDEX
      rig_preflight_provider node "${RIG_PLAN_BINDINGS[$index]}" "${RIG_PLAN_PROVIDERS[$index]}" >/dev/null 2>&1
      printf "later-preflight-status=%s\n" "$?"
    ' _ "$RIG"

  [ "$status" -eq 0 ]
  [[ "$output" == *'apply-status=2'* ]] || false
  [[ "$output" == *'deferred-providers=0 deferred-skills=0'* ]] || false
  [[ "$output" == *'later-preflight-status=2'* ]] || false
  [ ! -e "$CALL_LOG" ]
}
