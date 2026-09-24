#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  FAKE_BIN=$BATS_TEST_TMPDIR/bin-$BATS_TEST_NUMBER
  CALL_LOG=$BATS_TEST_TMPDIR/calls-$BATS_TEST_NUMBER
  MANIFEST=$BATS_TEST_TMPDIR/Brewfile-$BATS_TEST_NUMBER
  STATE_HOME=$BATS_TEST_TMPDIR/state-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME" "$TEST_HOME" "$FAKE_BIN"
  : >"$MANIFEST"
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

[provider.homebrew]
manifest = "$MANIFEST"

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
purpose = "Exercise manifest task deduplication"
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
rationale = "Chezmoi convergence must not imply update support"
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

@test "mise and npm are implicit built-in installation providers" {
  run run_rig apply --dry-run

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *$'node\tmise\tplanned\t-'* ]] || false
  [[ "$output" == *$'typescript\tnpm\tplanned\t-'* ]] || false

  run run_rig apply

  [ "$status" -eq 0 ]
  grep -Fqx $'mise\tinstall node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
}

@test "update dry-run deduplicates manifest work and reports unsupported providers" {
  run run_rig update --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *$'manifest\thomebrew\tplanned\tupdate'* ]] || false
  [ "$(printf '%s\n' "$output" | grep -Fc $'manifest\thomebrew\tplanned')" -eq 1 ]
  [[ "$output" == *$'ruff\tuv\tplanned\tupdate'* ]] || false
  [[ "$output" == *$'node\tmise\tplanned\tupdate'* ]] || false
  [[ "$output" == *$'typescript\tnpm\tplanned\tupdate'* ]] || false
  [[ "$output" == *$'dotfiles\tchezmoi\tskipped\tunsupported-update'* ]] || false
  [ ! -e "$CALL_LOG" ]
}

@test "update invokes only fixed built-in lifecycle operations" {
  run run_rig update

  [ "$status" -eq 0 ]
  grep -Fqx $'brew\tbundle install --upgrade --file='"$MANIFEST" "$CALL_LOG"
  grep -Fqx $'uv\ttool upgrade ruff' "$CALL_LOG"
  grep -Fqx $'mise\tupgrade node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
  [ "$(grep -Fc $'brew\tbundle install --upgrade' "$CALL_LOG")" -eq 1 ]
}

@test "maintain invokes each supported selected provider once" {
  run run_rig maintain

  [ "$status" -eq 0 ]
  grep -Fqx $'brew\tcleanup' "$CALL_LOG"
  grep -Fq $'brew\tbundle cleanup --force --file='"$MANIFEST" "$CALL_LOG"
  grep -Fqx $'brew\tdoctor' "$CALL_LOG"
  grep -Fqx $'uv\tcache prune' "$CALL_LOG"
  grep -Fqx $'mise\treshim' "$CALL_LOG"
  grep -Fqx $'npm\tcache verify' "$CALL_LOG"
  [[ "$output" == *$'chezmoi\tchezmoi\tskipped\tunsupported-maintain'* ]] || false
}

@test "capture previews and refreshes only explicit Homebrew manifest" {
  run run_rig capture homebrew --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *$'homebrew\tplanned\tcapture'* ]] || false
  [ ! -e "$CALL_LOG" ]

  run run_rig capture homebrew

  [ "$status" -eq 0 ]
  grep -Fq $'brew\tbundle dump --force --no-describe --file='"$MANIFEST" "$CALL_LOG"

  run run_rig capture uv --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'uv' does not support capture"* ]] || false
}

@test "capture rejects unsafe manifest before provider invocation" {
  unsafe_target=$BATS_TEST_TMPDIR/manifest-directory-$BATS_TEST_NUMBER
  mkdir -p "$unsafe_target"
  sed "s#manifest = .*#manifest = \"$unsafe_target\"#" "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/unsafe.toml"
  mv "$CONFIG_HOME/unsafe.toml" "$CONFIG_HOME/rig.toml"

  run run_rig capture homebrew

  [ "$status" -eq 2 ]
  [[ "$output" == *"manifest is not a safe regular-file target"* ]] || false
  [ ! -e "$CALL_LOG" ]
}

@test "update reports an unavailable lifecycle executable and still advances the rest" {
  printf '%s\n' '' '[provider.uv]' "executable = \"$FAKE_BIN/absent-uv\"" >>"$CONFIG_HOME/rig.toml"

  run run_rig update --dry-run

  [ "$status" -eq 1 ]
  [[ "$output" == *$'ruff\tuv\tunavailable\texecutable-unavailable'* ]] || false
  [[ "$output" == *$'manifest\thomebrew\tplanned\tupdate'* ]] || false
  [[ "$output" == *'Summary: planned=3 completed=0 failed=0 unavailable=1 skipped=1'* ]] || false
  [ ! -e "$CALL_LOG" ]

  run run_rig update

  [ "$status" -eq 1 ]
  [[ "$output" == *$'ruff\tuv\tunavailable\texecutable-unavailable'* ]] || false
  [[ "$output" == *'Summary: planned=0 completed=3 failed=0 unavailable=1 skipped=1'* ]] || false
  grep -Fqx $'brew\tbundle install --upgrade --file='"$MANIFEST" "$CALL_LOG"
  grep -Fqx $'mise\tupgrade node' "$CALL_LOG"
  grep -Fqx $'npm\tinstall --global typescript' "$CALL_LOG"
  [ "$(grep -Fc uv "$CALL_LOG")" -eq 0 ]
}

@test "an unattended update never blocks on a question and states the manager it isolated" {
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

  run run_rig update --unattended </dev/null

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  grep -Fqx $'uv-stdin\tend-of-file' "$CALL_LOG"
  grep -Fqx $'brew-noninteractive\t1' "$CALL_LOG"
  [[ "$output" == *$'ruff\tuv\tfailed\texit:3'* ]] || false
  [[ "$output" == *$'node\tmise\tcompleted\tupdate'* ]] || false
}

@test "an unattended run records its outcome where a wrapper can read it" {
  run run_rig update --unattended </dev/null

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  report=$STATE_HOME/last-update
  [ -f "$report" ] || false
  grep -Fqx $'rig-last-run\t1' "$report"
  grep -Fqx $'action\tupdate' "$report"
  grep -Fqx $'profile\tdefault' "$report"
  grep -Fqx $'platform\tfixture' "$report"
  grep -Fqx $'status\t0' "$report"
  grep -Fqx $'result\tsucceeded' "$report"
  grep -Fqx $'summary\tplanned=0 completed=4 failed=0 unavailable=0 skipped=1' "$report"
  grep -Fqx $'TARGET\tPROVIDER\tRESULT\tDETAIL' "$report"
  grep -Fqx $'ruff\tuv\tcompleted\tupdate' "$report"
  grep -Fqx $'dotfiles\tchezmoi\tskipped\tunsupported-update' "$report"
  grep -Eq '^finished\t[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$report"
  [ "$(grep -Fc $'rig-last-run' "$report")" -eq 1 ]
  ! grep -Fq "$MANIFEST" "$report" || false
}

@test "an unattended dry run records nothing and an unsafe report target is left alone" {
  run run_rig update --unattended --dry-run </dev/null

  [ "$status" -eq 0 ]
  [ ! -e "$STATE_HOME/last-update" ] || false

  mkdir -p "$STATE_HOME/last-update"

  run run_rig update --unattended </dev/null

  [ "$status" -eq 0 ]
  [ -d "$STATE_HOME/last-update" ] || false
  [[ "$output" == *'last-run report target is not a regular file'* ]] || false
}

@test "an unattended update reports work needing a person as unavailable" {
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

  run run_rig update --unattended </dev/null

  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *$'store-app\thomebrew\tunavailable\tinteractive-required'* ]] || false
  [[ "$output" == *$'ruff\tuv\tcompleted\tupdate'* ]] || false
  [ "$(grep -Fc mas "$CALL_LOG")" -eq 0 ]
  grep -Fqx $'store-app\thomebrew\tunavailable\tinteractive-required' \
    "$STATE_HOME/last-update"

  run run_rig update </dev/null

  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *$'store-app\thomebrew\tcompleted\tupdate'* ]] || false
  grep -Fqx $'mas\tupgrade 497799835' "$CALL_LOG"
}

@test "unattended belongs to update and maintain alone" {
  run run_rig maintain --unattended --dry-run </dev/null

  [ "$status" -eq 0 ]

  run run_rig update --unattended --unattended </dev/null

  [ "$status" -eq 2 ]
  [[ "$output" == *'usage: rig update [--profile NAME] [--dry-run] [--unattended]'* ]] || false

  run run_rig apply --unattended </dev/null

  [ "$status" -eq 2 ]

  run run_rig update --help </dev/null

  [ "$status" -eq 0 ]
  [[ "$output" == 'Usage: rig update [--profile NAME] [--dry-run] [--unattended]' ]] || false
}
