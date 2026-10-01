#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  FAKE_BIN=$BATS_TEST_TMPDIR/bin-$BATS_TEST_NUMBER
  CALL_LOG=$BATS_TEST_TMPDIR/calls-$BATS_TEST_NUMBER
  STATE_HOME=$BATS_TEST_TMPDIR/state-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME" "$TEST_HOME" "$FAKE_BIN"
  write_fake_provider brew
  write_fake_provider uv
  write_fake_provider mise
  write_fake_provider npm
  write_fake_provider chezmoi
  write_lifecycle_config
}

write_fake_provider() {
  local provider=$1
  cat >"$FAKE_BIN/$provider" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\t' "${0##*/}" >>"$RIG_TEST_LOG"
printf '%s\n' "$*" >>"$RIG_TEST_LOG"
case "${0##*/}:$1" in
  mise:which|npm:list) exit 1 ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/$provider"
}

write_lifecycle_config() {
  cat >"$CONFIG_HOME/rig.toml" <<EOF
[rig]
schema = 1
default-profile = "default"

[category.core]
name = "Core"
purpose = "Exercise provider lifecycle"

[tool.brew-one]
name = "Brew One"
category = "core"
purpose = "Exercise Homebrew lifecycle"
rationale = "The fixture needs a first Homebrew tool"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "brew-one"
install.platforms = ["any"]

[tool.brew-two]
name = "Brew Two"
category = "core"
purpose = "Exercise declaration-scoped cask upgrades"
rationale = "The fixture needs a second Homebrew tool"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "brew-two"
install.platforms = ["any"]

[tool.ruff]
name = "Ruff"
category = "core"
purpose = "Exercise uv lifecycle"
rationale = "The fixture covers extras-normalised updates"
platforms = ["any"]
install.provider = "uv"
install.kind = "tool"
install.locator = "ruff[format]"
install.platforms = ["any"]

[tool.node]
name = "Node"
category = "core"
purpose = "Exercise mise lifecycle"
rationale = "The fixture covers native runtime management"
platforms = ["any"]
install.provider = "mise"
install.kind = "tool"
install.locator = "node"
install.platforms = ["any"]

[tool.typescript]
name = "TypeScript"
category = "core"
purpose = "Exercise npm lifecycle"
rationale = "The fixture covers global package management"
platforms = ["any"]
install.provider = "npm"
install.kind = "global"
install.locator = "typescript"
install.platforms = ["any"]
requires = ["node"]

[tool.dotfiles]
name = "Dotfiles"
category = "core"
purpose = "Exercise unsupported lifecycle reporting"
rationale = "Chezmoi convergence must not imply upgrade support"
platforms = ["any"]
install.provider = "chezmoi"
install.kind = "target"
install.locator = ".zshrc"
install.platforms = ["any"]

[profile.default]
tools = ["brew-one", "brew-two", "ruff", "node", "typescript", "dotfiles"]
EOF
}

run_rig() {
  env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$STATE_HOME" \
    RIG_PLATFORM=fixture RIG_TEST_LOG="$CALL_LOG" PATH="$FAKE_BIN:$PATH" "$RIG" "$@"
}

write_mixed_homebrew_fixture() {
  unset NONINTERACTIVE
  cat >"$CONFIG_HOME/rig.toml" <<'EOF'
[rig]
schema = 1
default-profile = "default"

[category.core]
name = "Core"
purpose = "Exercise independent Homebrew upgrade results"

[tool.cask-failure]
name = "Cask Failure"
category = "core"
purpose = "Exercise a native cask failure"
rationale = "The failure must remain distinct from known interactivity"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "failing-cask"

[tool.formula-success]
name = "Formula Success"
category = "core"
purpose = "Exercise an independent formula after the failed cask"
rationale = "One native failure must not mask the next declaration"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "ready-formula"

[tool.store-app]
name = "Store App"
category = "core"
purpose = "Exercise the conservative App Store exclusion"
rationale = "Unattended runs leave App Store interaction to a person"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "mas"
install.locator = "497799835"

[profile.default]
tools = ["store-app", "formula-success", "cask-failure"]
EOF
  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
printf 'brew-noninteractive\t%s\n' "${NONINTERACTIVE:-unset}" >>"$RIG_TEST_LOG"
if IFS= read -r answer; then
  printf 'brew-stdin\t%s\n' "$answer" >>"$RIG_TEST_LOG"
else
  printf 'brew-stdin\tend-of-file\n' >>"$RIG_TEST_LOG"
fi
case "$*" in
  'upgrade --cask failing-cask') exit 7 ;;
  'upgrade --formula ready-formula') exit 0 ;;
  *) exit 99 ;;
esac
SCRIPT
  cat >"$FAKE_BIN/mas" <<'SCRIPT'
#!/usr/bin/env bash
printf 'mas\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$*" in
  'upgrade 497799835') exit 0 ;;
  *) exit 99 ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/brew" "$FAKE_BIN/mas"
}

@test "mise and npm are implicit built-in installation providers" {
  run run_rig apply --dry-run

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'node\tmise\tplanned\t-' || false
  rig_test_report_contains "$output" $'typescript\tnpm\tplanned\t-' || false

  run run_rig apply

  [ "$status" -eq 0 ]
  grep -Fqx $'mise\tinstall node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
}

@test "upgrade dry-run plans each declared installation and reports unsupported providers" {
  run run_rig upgrade --dry-run

  [ "$status" -eq 0 ]
  rig_test_report_contains "$output" $'brew-one\thomebrew\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'brew-two\thomebrew\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'ruff\tuv\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'node\tmise\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'typescript\tnpm\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'dotfiles\tchezmoi\tskipped\tunsupported-upgrade' || false
  [ ! -e "$CALL_LOG" ]
}

@test "upgrade invokes only fixed built-in lifecycle operations" {
  run run_rig upgrade

  [ "$status" -eq 0 ]
  grep -Fqx $'brew\tupgrade --formula brew-one' "$CALL_LOG"
  grep -Fqx $'brew\tupgrade --cask brew-two' "$CALL_LOG"
  grep -Fqx $'uv\ttool upgrade ruff' "$CALL_LOG"
  grep -Fqx $'mise\tupgrade node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
  [ "$(grep -Fc $'brew\tupgrade' "$CALL_LOG")" -eq 2 ]
  ! grep -Eq 'bundle|cleanup' "$CALL_LOG" || false
}

@test "upgrade reports an unavailable lifecycle executable and still advances the rest" {
  printf '%s\n' '' '[provider.uv]' "executable = \"$FAKE_BIN/absent-uv\"" >>"$CONFIG_HOME/rig.toml"

  run run_rig upgrade --dry-run

  [ "$status" -eq 1 ]
  rig_test_report_contains "$output" $'ruff\tuv\tunavailable\texecutable-unavailable' || false
  rig_test_report_contains "$output" $'brew-one\thomebrew\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'brew-two\thomebrew\tplanned\tupgrade' || false
  [[ "$output" == *'Summary: planned=4 completed=0 failed=0 unavailable=1 skipped=1'* ]] || false
  [ ! -e "$CALL_LOG" ]

  run run_rig upgrade

  [ "$status" -eq 1 ]
  rig_test_report_contains "$output" $'ruff\tuv\tunavailable\texecutable-unavailable' || false
  [[ "$output" == *'Summary: planned=0 completed=4 failed=0 unavailable=1 skipped=1'* ]] || false
  grep -Fqx $'brew\tupgrade --formula brew-one' "$CALL_LOG"
  grep -Fqx $'brew\tupgrade --cask brew-two' "$CALL_LOG"
  grep -Fqx $'mise\tupgrade node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
  [ "$(grep -Fc uv "$CALL_LOG")" -eq 0 ]
}

@test "an unattended upgrade gives native stdin EOF and retains the resulting failure" {
  cat >"$FAKE_BIN/uv" <<'SCRIPT'
#!/usr/bin/env bash
printf 'uv\t%s\n' "$*" >>"$RIG_TEST_LOG"
if [ "$1" = tool ] && [ "$2" = upgrade ]; then
  if IFS= read -r answer; then
    printf 'uv-stdin\t%s\n' "$answer" >>"$RIG_TEST_LOG"
  else
    printf 'uv-stdin\tend-of-file\n' >>"$RIG_TEST_LOG"
    exit 3
  fi
fi
SCRIPT
  chmod +x "$FAKE_BIN/uv"
  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
printf 'brew-noninteractive\t%s\n' "${NONINTERACTIVE:-unset}" >>"$RIG_TEST_LOG"
SCRIPT
  chmod +x "$FAKE_BIN/brew"

  run run_rig upgrade --unattended </dev/null

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  grep -Fqx $'uv-stdin\tend-of-file' "$CALL_LOG"
  grep -Fqx $'brew-noninteractive\t1' "$CALL_LOG"
  rig_test_report_contains "$output" $'ruff\tuv\tfailed\texit:3' || false
  rig_test_report_contains "$output" $'node\tmise\tcompleted\tupgrade' || false
}

@test "an unattended run records its outcome where a wrapper can read it" {
  run run_rig upgrade --unattended </dev/null

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  report=$STATE_HOME/last-upgrade
  [ -f "$report" ] || false
  grep -Fqx $'rig-last-run\t1' "$report"
  grep -Fqx $'action\tupgrade' "$report"
  grep -Fqx $'profile\tdefault' "$report"
  grep -Fqx $'platform\tfixture' "$report"
  grep -Fqx $'status\t0' "$report"
  grep -Fqx $'result\tsucceeded' "$report"
  grep -Fqx $'summary\tplanned=0 completed=5 failed=0 unavailable=0 skipped=1' "$report"
  grep -Fqx $'TARGET\tPROVIDER\tRESULT\tDETAIL' "$report"
  grep -Fqx $'ruff\tuv\tcompleted\tupgrade' "$report"
  grep -Fqx $'dotfiles\tchezmoi\tskipped\tunsupported-upgrade' "$report"
  grep -Eq $'^finished\t[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$report"
  [ "$(grep -Fc $'rig-last-run' "$report")" -eq 1 ]
  ! grep -Eq 'bundle|cleanup|manifest' "$report" || false
}

@test "an unattended dry run records nothing and an unsafe report target is left alone" {
  run run_rig upgrade --unattended --dry-run </dev/null

  [ "$status" -eq 0 ]
  [ ! -e "$STATE_HOME/last-upgrade" ] || false

  mkdir -p "$STATE_HOME/last-upgrade"

  run run_rig upgrade --unattended </dev/null

  [ "$status" -eq 0 ]
  [ -d "$STATE_HOME/last-upgrade" ] || false
  [[ "$output" == *'last-run report target is not a regular file'* ]] || false
}

@test "an unattended upgrade reports work needing a person as unavailable" {
  cat >"$CONFIG_HOME/rig.toml" <<EOF
[rig]
schema = 1
default-profile = "default"

[category.core]
name = "Core"
purpose = "Exercise provider lifecycle"

[tool.store-app]
name = "Store App"
category = "core"
purpose = "Exercise a Mac App Store lifecycle"
rationale = "An App Store upgrade needs a person signed in"
platforms = ["any"]
install.provider = "homebrew"
install.kind = "mas"
install.locator = "497799835"
install.platforms = ["any"]

[tool.ruff]
name = "Ruff"
category = "core"
purpose = "Exercise uv lifecycle"
rationale = "The fixture proves independent work still advances"
platforms = ["any"]
install.provider = "uv"
install.kind = "tool"
install.locator = "ruff"
install.platforms = ["any"]

[profile.default]
tools = ["store-app", "ruff"]
EOF

  write_fake_provider mas

  run run_rig upgrade --unattended </dev/null

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'store-app\thomebrew\tunavailable\tinteractive-required' || false
  rig_test_report_contains "$output" $'ruff\tuv\tcompleted\tupgrade' || false
  [ "$(grep -Fc mas "$CALL_LOG")" -eq 0 ]
  grep -Fqx $'store-app\thomebrew\tunavailable\tinteractive-required' \
    "$STATE_HOME/last-upgrade"

  run run_rig upgrade </dev/null

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'store-app\thomebrew\tcompleted\tupgrade' || false
  grep -Fqx $'mas\tupgrade 497799835' "$CALL_LOG"
}

@test "mixed unattended Homebrew outcomes remain independent and persist every row" {
  write_mixed_homebrew_fixture

  run run_rig upgrade --unattended <<< 'caller input must not reach native upgrades'

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'cask-failure\thomebrew\tfailed\texit:7' || false
  rig_test_report_contains "$output" $'formula-success\thomebrew\tcompleted\tupgrade' || false
  rig_test_report_contains "$output" $'store-app\thomebrew\tunavailable\tinteractive-required' || false
  [[ "$output" == *'Summary: planned=0 completed=1 failed=1 unavailable=1 skipped=0'* ]] || false
  [ "$(grep -c $'^brew\tupgrade' "$CALL_LOG")" -eq 2 ] || false
  [ "$(grep -Fc $'brew-stdin\tend-of-file' "$CALL_LOG")" -eq 2 ] || false
  [ "$(grep -Fc $'brew-noninteractive\t1' "$CALL_LOG")" -eq 2 ] || false
  [ "$(grep $'^brew\tupgrade' "$CALL_LOG")" = $'brew\tupgrade --cask failing-cask\nbrew\tupgrade --formula ready-formula' ] || false
  ! grep -Eq 'bundle|cleanup|^mas' "$CALL_LOG" || false
  ! grep -Fq 'caller input' "$CALL_LOG" || false

  report=$STATE_HOME/last-upgrade
  [ -f "$report" ] || false
  grep -Fqx $'status\t1' "$report"
  grep -Fqx $'result\tincomplete' "$report"
  grep -Fqx $'summary\tplanned=0 completed=1 failed=1 unavailable=1 skipped=0' "$report"
  grep -Fqx $'cask-failure\thomebrew\tfailed\texit:7' "$report"
  grep -Fqx $'formula-success\thomebrew\tcompleted\tupgrade' "$report"
  grep -Fqx $'store-app\thomebrew\tunavailable\tinteractive-required' "$report"
  [ "$(grep -Ec '^(cask-failure|formula-success|store-app)' "$report")" -eq 3 ] || false
  ! grep -Eq 'bundle|cleanup|manifest' "$report" || false
}

@test "mixed unattended dry-run invokes nothing and preserves the prior report" {
  write_mixed_homebrew_fixture
  mkdir -p "$STATE_HOME"
  printf '%s\n' 'previous report remains authoritative' >"$STATE_HOME/last-upgrade"

  run run_rig upgrade --unattended --dry-run <<< 'unused caller input'

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'cask-failure\thomebrew\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'formula-success\thomebrew\tplanned\tupgrade' || false
  rig_test_report_contains "$output" $'store-app\thomebrew\tunavailable\tinteractive-required' || false
  [[ "$output" == *'Summary: planned=2 completed=0 failed=0 unavailable=1 skipped=0'* ]] || false
  [ ! -e "$CALL_LOG" ] || false
  [ "$(cat "$STATE_HOME/last-upgrade")" = 'previous report remains authoritative' ] || false
}

@test "mixed interactive upgrade dispatches the App Store target and retains native failure" {
  write_mixed_homebrew_fixture

  run run_rig upgrade <<< 'interactive caller input'

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'cask-failure\thomebrew\tfailed\texit:7' || false
  rig_test_report_contains "$output" $'formula-success\thomebrew\tcompleted\tupgrade' || false
  rig_test_report_contains "$output" $'store-app\thomebrew\tcompleted\tupgrade' || false
  grep -Fqx $'mas\tupgrade 497799835' "$CALL_LOG"
  grep -Fqx $'brew-stdin\tinteractive caller input' "$CALL_LOG"
  [ "$(grep -Fc $'brew-noninteractive\tunset' "$CALL_LOG")" -eq 2 ] || false
  ! grep -Eq 'bundle|cleanup' "$CALL_LOG" || false
  [ ! -e "$STATE_HOME/last-upgrade" ] || false
}

@test "unattended belongs to upgrade alone" {
  run run_rig upgrade --unattended --dry-run </dev/null

  [ "$status" -eq 0 ]

  run run_rig upgrade --unattended --unattended </dev/null

  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig upgrade [--profile NAME] [--dry-run] [--unattended]'* ]] || false

  run run_rig apply --unattended </dev/null

  [ "$status" -eq 2 ]

  run run_rig upgrade --help </dev/null

  [ "$status" -eq 0 ]
  [[ "$output" == *'Usage: rig upgrade [--profile NAME] [--dry-run] [--unattended]'* ]] || false
}
