#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME"
  APP=$HOME/Applications/Subject.app
  rig_test_provider brew
}

write_config() {
  local policy policy_line
  policy=${1:-self}
  policy_line=
  [ "$policy" = metadata ] || policy_line="updates = \"$policy\""
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[category.core]
name = "Core"
purpose = "Core tools"
[tool.subject]
$policy_line
name = "Subject"
category = "core"
purpose = "Application"
rationale = "Fixture"
platforms = ["macos"]
artifacts = ["$APP"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "subject"
[profile.default]
tools = ["subject"]
TOML
  rig_test_provider_response brew 'list --cask --versions subject' 1 -
  rig_test_provider_response brew '--caskroom subject' 0 "$BATS_TEST_TMPDIR/no-caskroom"
}

healthy_app() {
  mkdir -p "$APP/Contents/MacOS"
  printf '%s\n' '<plist><dict/></plist>' >"$APP/Contents/Info.plist"
  printf '#!/bin/sh\nexit 0\n' >"$APP/Contents/MacOS/Subject"
  chmod +x "$APP/Contents/MacOS/Subject"
}

@test "self-updated foreign app is healthy and apply never invokes its installer" {
  write_config
  healthy_app
  mkdir -p "$APP/Contents/_MASReceipt"
  run "$RIG" doctor --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'self-updating;source-mismatch:app-store-receipt'* ]] || false
  [[ "$output" == *'"healthy":true'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 0 ]
  [[ "$output" == *'skipped'* ]] || false
  ! /usr/bin/grep -E 'install|upgrade' "$RIG_TEST_PROVIDER_LOG"
}

@test "self-updating upgrades visibly skip even when app is absent" {
  write_config
  run "$RIG" upgrade
  [ "$status" -eq 0 ]
  [[ "$output" == *'self-updating'* ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
  run "$RIG" upgrade --unattended
  [ "$status" -eq 0 ]
  [[ "$(cat "$HOME/.local/state/rig/last-upgrade")" == *$'skipped\tself-updating'* ]] || false
}

@test "missing self-updating app installs and doctor reports absence" {
  write_config
  rig_test_provider_response brew 'install --cask subject' 0 -
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'artifact-missing'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 0 ]
  [[ "$(cat "$RIG_TEST_PROVIDER_LOG")" == *'brew|install --cask subject'*  ]] || false
}

@test "damaged app cannot satisfy self updates" {
  write_config
  mkdir -p "$APP/Contents"
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'artifact-damaged-app'* ]] || false
}

@test "managed foreign source drifts and apply skips with failure and manual guidance" {
  write_config managed
  healthy_app
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'source-mismatch:unclassified'* ]] || false
  [[ "$output" == *'App Management'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 1 ]
  ! /usr/bin/grep -E 'install' "$RIG_TEST_PROVIDER_LOG"
}

@test "residual Caskroom is evidence rather than claimed hand installation" {
  write_config
  healthy_app
  mkdir -p "$BATS_TEST_TMPDIR/no-caskroom"
  run "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *'source-mismatch:residual-homebrew-caskroom'* ]] || false
}

@test "cask metadata supplies self policy and managed override avoids metadata" {
  write_config metadata
  healthy_app
  rig_test_provider_response brew 'info --json=v2 --cask subject' 0 '{"casks":[{"auto_updates":true}]}'
  cat >"$RIG_PLUTIL" <<'STUB'
#!/usr/bin/env bash
[ "$*" = '-extract casks.0.auto_updates raw -o - -' ] || exit 99
read -r data
[ "$data" = '{"casks":[{"auto_updates":true}]}' ] || exit 98
printf 'true\n'
STUB
  run "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *'self-updating'* ]] || false
  : >"$RIG_TEST_PROVIDER_LOG"
  write_config managed
  run "$RIG" status
  [ "$status" -eq 1 ]
  ! /usr/bin/grep -E 'info' "$RIG_TEST_PROVIDER_LOG"
}

@test "unreadable metadata is unavailable rather than a guessed managed policy" {
  write_config metadata
  healthy_app
  rig_test_provider_response brew 'info --json=v2 --cask subject' 0 '{}'
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'application-metadata-invalid'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 1 ]
  ! /usr/bin/grep -E 'install' "$RIG_TEST_PROVIDER_LOG"
}

@test "cask metadata reads the API cache and null auto updates need a resolved definition" {
  write_config metadata
  healthy_app
  # Without a local cask tap, Homebrew answers an API-disabled read with a
  # stub whose tap and auto_updates are null.
  # The wrapper keeps the fixture's manager name while checking the read stays local.
  mv "$RIG_TEST_PROVIDER_BIN/brew" "$BATS_TEST_TMPDIR/brew"
  cat >"$RIG_TEST_PROVIDER_BIN/brew" <<STUB
#!/usr/bin/env bash
if [ "\$1" = info ]; then
  [ -z "\${HOMEBREW_NO_INSTALL_FROM_API:-}" ] || exit 97
  [ "\${HOMEBREW_NO_AUTO_UPDATE:-}" = 1 ] || exit 96
fi
exec "$BATS_TEST_TMPDIR/brew" "\$@"
STUB
  chmod +x "$RIG_TEST_PROVIDER_BIN/brew"
  cat >"$RIG_PLUTIL" <<'STUB'
#!/usr/bin/env bash
read -r data
case "$*:$data" in
  '-extract casks.0.auto_updates raw -o - -:'*'"auto_updates":true'*) printf 'true\n' ;;
  '-extract casks.0.auto_updates raw -o - -:'*) exit 1 ;;
  '-type casks.0.auto_updates -o - -:'*'"auto_updates":null'*) printf '(any)\n' ;;
  '-extract casks.0.tap raw -o - -:'*'"tap":"homebrew/cask"'*) printf 'homebrew/cask\n' ;;
  '-extract casks.0.tap raw -o - -:'*) exit 1 ;;
  *) exit 99 ;;
esac
STUB
  chmod +x "$RIG_PLUTIL"
  rig_test_provider_response brew 'info --json=v2 --cask subject' 0 \
    '{"casks":[{"tap":"homebrew/cask","auto_updates":true}]}'
  run "$RIG" status
  [ "$status" -eq 0 ]
  [[ "$output" == *'self-updating'* ]] || false
  : >"$RIG_TEST_PROVIDER_TABLE"
  write_config metadata
  rig_test_provider_response brew 'info --json=v2 --cask subject' 0 \
    '{"casks":[{"tap":"homebrew/cask","auto_updates":null}]}'
  run "$RIG" status
  [ "$status" -eq 1 ]
  [[ "$output" != *'application-metadata'* ]] || false
  [[ "$output" == *'source-mismatch'* ]] || false
  : >"$RIG_TEST_PROVIDER_TABLE"
  write_config metadata
  rig_test_provider_response brew 'info --json=v2 --cask subject' 0 \
    '{"casks":[{"tap":null,"auto_updates":null}]}'
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'application-metadata-unavailable'* ]] || false
  [[ "$output" != *'application-metadata-invalid'* ]] || false
}

@test "self updates reject formulae and absent artifact declarations" {
  write_config
  sed -i.bak 's/install.kind = "cask"/install.kind = "formula"/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *'only macOS cask'* ]] || false
  write_config
  sed -i.bak '/artifacts =/d' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *'requires a declared application artifact'* ]] || false
}

@test "managed foreign copies never receive an upgrade and damaged self copies never reinstall" {
  write_config managed
  healthy_app
  run "$RIG" upgrade
  [ "$status" -eq 1 ]
  [[ "$output" == *'source-mismatch'* ]] || false
  ! /usr/bin/grep -E 'install|upgrade' "$RIG_TEST_PROVIDER_LOG"
  write_config
  rm "$APP/Contents/MacOS/Subject"
  run "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'artifact-damaged-app'* ]] || false
  ! /usr/bin/grep -E 'install|upgrade' "$RIG_TEST_PROVIDER_LOG"
}

@test "self policy rejects Linux and satisfied apps allow dependent installs" {
  write_config
  healthy_app
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<TOML
[tool.consumer]
name = "Consumer"
category = "core"
purpose = "Depends on application"
rationale = "Fixture"
platforms = ["macos"]
requires = ["subject"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "consumer"
TOML
  sed -i.bak 's/tools = \["subject"\]/tools = ["consumer"]/' "$RIG_CONFIG_HOME/rig.toml"
  rig_test_provider_response brew 'install --formula consumer' 0 -
  run "$RIG" apply
  [ "$status" -eq 0 ]
  [[ "$(cat "$RIG_TEST_PROVIDER_LOG")" == *'brew|install --formula consumer'* ]] || false
  sed -i.bak 's/platforms = \["macos"\]/platforms = ["linux"]/' "$RIG_CONFIG_HOME/rig.toml"
  run env RIG_PLATFORM=linux "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *'only macOS'* ]] || false
}

@test "macOS variant updates remain on the selected installation" {
  write_config
  healthy_app
  sed -i.bak 's/updates =/variant.mac.updates =/; s/install\./variant.mac.install./; s/artifacts =/variant.mac.artifacts =/' "$RIG_CONFIG_HOME/rig.toml"
  # Add variant platform alongside its installation; preserve the owning table.
  sed -i.bak 's/variant.mac.updates =/variant.mac.platforms = ["macos"]\
variant.mac.updates =/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *'self-updating'* ]] || false
}

@test "explicit App Store self updates satisfy a healthy app without sign-in or upgrades" {
  write_config
  healthy_app
  sed -i.bak 's/install.provider = "homebrew"/install.provider = "mas"/; s/install.kind = "cask"/install.kind = "app"/; s/install.locator = "subject"/install.locator = "123"/' "$RIG_CONFIG_HOME/rig.toml"
  rig_test_provider mas
  rig_test_provider_response mas 'list' 0 -
  run "$RIG" doctor
  [ "$status" -eq 0 ]
  run "$RIG" upgrade --unattended
  [ "$status" -eq 0 ]
  [[ "$output" == *'self-updating'* ]] || false
  ! /usr/bin/grep -E 'install|upgrade' "$RIG_TEST_PROVIDER_LOG"
}

@test "dry-run apply observes no app providers and missing companion does not reinstall a present self app" {
  write_config
  healthy_app
  sed -i.bak 's@artifacts = .*@artifacts = ["'"$APP"'", "~/missing-companion"]@' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ]
  run "$RIG" apply
  [ "$status" -eq 0 ]
  ! /usr/bin/grep -E 'install' "$RIG_TEST_PROVIDER_LOG"
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'artifact-missing:~/missing-companion'* ]] || false
}
