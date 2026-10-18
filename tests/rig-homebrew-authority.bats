#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  BREW_LOG=$BATS_TEST_TMPDIR/brew.log
  export BREW_LOG
  mkdir -p "$CONFIG_HOME"
  rig_test_provider brew
  rig_test_provider_response brew 'install --formula example/alpha' 0 -
  rig_test_provider_response brew 'upgrade --formula example/alpha' 0 -
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.alpha]' 'name = "Alpha"' 'category = "core"' 'purpose = "Test intent"' \
    'rationale = "Rig is the package authority"' 'platforms = ["macos"]' \
    'install.provider = "homebrew"' 'install.kind = "formula"' 'install.locator = "example/alpha"' \
    '[profile.default]' 'kind = "complete"' >"$CONFIG_HOME/rig.toml"
}

run_rig() {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" "$@"
}

@test "Homebrew apply and upgrade use declarations without a Brewfile" {
  run_rig apply
  [ "$status" -eq 0 ]
  run_rig upgrade
  [ "$status" -eq 0 ]
  grep -Fx 'brew|install --formula example/alpha' "$RIG_TEST_PROVIDER_LOG"
  grep -Fx 'brew|upgrade --formula example/alpha' "$RIG_TEST_PROVIDER_LOG"
  ! grep -E 'bundle|cleanup|autoupdate|uninstall' "$RIG_TEST_PROVIDER_LOG"
}

@test "Homebrew retired manifest rejects before provider invocation" {
  printf '%s\n' '[provider.homebrew]' 'manifest = "~/Brewfile"' >>"$CONFIG_HOME/rig.toml"
  run_rig apply --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *'manifest'*'retired'* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "Homebrew timer policy rejects without changing its native agent" {
  printf '%s\n' '[provider.homebrew]' 'autoupdate-interval = 86400' >>"$CONFIG_HOME/rig.toml"
  run_rig apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'autoupdate policy'*'retired'* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "Homebrew apply preflights unrelated selected providers before mutation" {
  printf '%s\n' \
    '[tool.beta]' 'name = "Beta"' 'category = "core"' 'purpose = "Fail preflight"' \
    'rationale = "Prove complete preflight"' 'platforms = ["macos"]' \
    'install.provider = "runner"' 'install.kind = "package"' 'install.locator = "beta"' \
    '[provider.runner]' 'adapter = "custom"' 'executable = "/missing/rig-provider"' \
    'capabilities = ["apply"]' >>"$CONFIG_HOME/rig.toml"
  run_rig apply
  [ "$status" -eq 2 ]
  [[ "$output" == *"provider 'runner' executable is unavailable"* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "Homebrew dry-run invokes no provider and never plans Bundle work" {
  run_rig apply --dry-run
  [ "$status" -eq 0 ]
  rig_test_report_contains "$output" $'alpha\thomebrew\tplanned' || false
  [[ "$output" != *'bundle'* ]] || false
  run_rig upgrade --dry-run
  [ "$status" -eq 0 ]
  rig_test_report_contains "$output" $'alpha\thomebrew\tplanned' || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
}

@test "doctor names missing or outdated Command Line Tools once for Homebrew work" {
  local fake

  rig_test_provider_response brew 'list --versions --formula example/alpha' 0 'alpha 1.0'
  fake=$BATS_TEST_TMPDIR/clt
  mkdir -p "$fake"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$CLT_LOG"' '[ -z "${CLT_PATH:-}" ] && exit 2' 'printf "%s\n" "$CLT_PATH"' >"$fake/xcode-select"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$CLT_LOG"' 'printf "%s\n" "package-id: com.apple.pkg.CLTools_Executables" "version: $CLT_VERSION"' >"$fake/pkgutil"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >>"$CLT_LOG"' 'printf "%s\n" "$MACOS_VERSION"' >"$fake/sw_vers"
  chmod +x "$fake"/*
  export CLT_LOG=$BATS_TEST_TMPDIR/clt.log RIG_XCODE_SELECT=$fake/xcode-select RIG_PKGUTIL=$fake/pkgutil RIG_SW_VERS=$fake/sw_vers

  CLT_PATH= CLT_VERSION=27.0 MACOS_VERSION=27.0.1 run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *$'Tool findings:\n  command-line-tools: missing (homebrew-items-fail-until-installed); owner=environment; action=run-xcode-select-install'* ]] || {
    printf '%s\n' "$output" >&3; false; }

  CLT_PATH=/Library/Developer/CommandLineTools CLT_VERSION=26.6.0.0.1 MACOS_VERSION=27.0.1 run_rig doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'command-line-tools: outdated (installed:26.6.0.0.1;macos:27.0.1;homebrew-items-fail-until-updated); owner=environment; action=update-command-line-tools'* ]] || false

  CLT_PATH=/Library/Developer/CommandLineTools CLT_VERSION=27.0 MACOS_VERSION=27.0.1 run_rig doctor --format json
  [[ "$output" != *'command-line-tools'* ]] || false
  CLT_PATH=/Applications/Xcode.app/Contents/Developer CLT_VERSION=26.0 MACOS_VERSION=27.0.1 run_rig doctor
  [[ "$output" != *'command-line-tools'* ]] || false
  ! grep -Ev '^(-p|--pkg-info=com.apple.pkg.CLTools_Executables|-productVersion)$' "$CLT_LOG" || false

  : >"$CLT_LOG"
  sed 's/^install.provider = "homebrew"$/install.provider = "runner"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edited.toml"
  printf '%s\n' '[provider.runner]' 'adapter = "custom"' 'executable = "/missing/rig-provider"' 'capabilities = ["observe"]' >>"$CONFIG_HOME/edited.toml"
  mv "$CONFIG_HOME/edited.toml" "$CONFIG_HOME/rig.toml"
  CLT_PATH= run_rig doctor
  [[ "$output" != *'command-line-tools'* ]] || false
  [ ! -s "$CLT_LOG" ] || false
}
