#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  CLI_TEST_ROOT=$(cd "$BATS_TEST_TMPDIR" && pwd -P)
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$CLI_TEST_ROOT/config
  APP=$CLI_TEST_ROOT/Example.app
  export CLI_TEST_SOURCE=$APP/Contents/Helpers/ExampleCLI
  export CLI_TEST_DESTINATION=$CLI_TEST_ROOT/bin/example
  export CLI_TEST_LOG=$CLI_TEST_ROOT/native.log
  PROVIDER=$CLI_TEST_ROOT/native-brew
  mkdir -p "$CONFIG_HOME" "$APP/Contents/Helpers" "$CLI_TEST_ROOT/bin"
  : >"$CLI_TEST_LOG"
  cat >"$PROVIDER" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CLI_TEST_LOG"
case "$*" in
  'list --cask --versions example') printf 'example 1\n' ;;
  'install --cask vendor/tap/example')
    if [ "${CLI_TEST_INSTALL_SOURCE:-0}" = 1 ]; then
      printf '#!/bin/sh\nexit 0\n' >"$CLI_TEST_SOURCE"
      chmod +x "$CLI_TEST_SOURCE"
    fi
    ;;
  'reinstall --cask vendor/tap/example')
    [ "${CLI_TEST_REPAIR_EXIT:-0}" = 0 ] || exit "$CLI_TEST_REPAIR_EXIT"
    printf '#!/bin/sh\nexit 0\n' >"$CLI_TEST_SOURCE"
    chmod +x "$CLI_TEST_SOURCE"
    if [ "${CLI_TEST_BROKEN_REPAIR:-0}" = 0 ]; then
      [ ! -L "$CLI_TEST_DESTINATION" ] || rm "$CLI_TEST_DESTINATION"
      ln -s "$CLI_TEST_SOURCE" "$CLI_TEST_DESTINATION"
    fi
    ;;
  'upgrade --cask vendor/tap/example')
    if [ "${CLI_TEST_UPGRADE_REMOVES_LINK:-0}" = 1 ]; then rm "$CLI_TEST_DESTINATION"; fi
    ;;
  'install --cask consumer') [ -x "$CLI_TEST_DESTINATION" ] || exit 24 ;;
  *) printf 'unexpected native invocation: %s\n' "$*" >&2; exit 99 ;;
esac
SH
  chmod +x "$PROVIDER"
  create_source
}

create_source() {
  printf '#!/bin/sh\nexit 0\n' >"$CLI_TEST_SOURCE"
  chmod +x "$CLI_TEST_SOURCE"
}

write_config() {
  local owner
  owner=${1:-provider}
  cat >"$CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[category.apps]
name = "Apps"
purpose = "Applications"
[tool.example]
name = "Example"
category = "apps"
purpose = "An application with a companion command"
rationale = "Keep the app and its CLI together"
platforms = ["macos", "linux"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "vendor/tap/example"
cli.example.source = "$CLI_TEST_SOURCE"
cli.example.destination = "$CLI_TEST_DESTINATION"
cli.example.owner = "$owner"
[profile.default]
tools = ["example"]
[provider.homebrew]
executable = "$PROVIDER"
TOML
}

edit_config() {
  sed "$1" "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edit.toml"
  mv "$CONFIG_HOME/edit.toml" "$CONFIG_HOME/rig.toml"
}

rig_run() {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" "$@"
}

@test "missing app CLI is unhealthy in status and doctor even when the cask is installed" {
  write_config
  rig_run status --format json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"state":"missing"'* ]]
  [[ "$output" == *'cli-missing:example'* ]]
  rig_run doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'cli-missing:example'* ]]
  [ ! -e "$CLI_TEST_DESTINATION" ]
  ! grep -q '^(install|reinstall)' "$CLI_TEST_LOG" || false
}

@test "native cask repair restores a missing companion and repeated apply does not repair again" {
  write_config
  rig_run apply --target example --scope tools
  [ "$status" -eq 0 ]
  [ "$(readlink "$CLI_TEST_DESTINATION")" = "$CLI_TEST_SOURCE" ]
  [ "$(sed -n '1p' "$CLI_TEST_LOG")" = 'install --cask vendor/tap/example' ]
  [ "$(sed -n '2p' "$CLI_TEST_LOG")" = 'reinstall --cask vendor/tap/example' ]
  rig_run apply --target example --scope tools
  [ "$status" -eq 0 ]
  [ "$(awk '/^reinstall / {n++} END {print n+0}' "$CLI_TEST_LOG")" -eq 1 ]
  rig_run status
  [ "$status" -eq 0 ]
}

@test "healthy native CLI does not cause a cask reinstall" {
  ln -s "$CLI_TEST_SOURCE" "$CLI_TEST_DESTINATION"
  write_config
  rig_run apply --scope tools
  [ "$status" -eq 0 ]
  ! grep -q '^reinstall' "$CLI_TEST_LOG" || false
}

@test "link companion is materialised only after the application creates its executable" {
  rm "$CLI_TEST_SOURCE"
  export CLI_TEST_INSTALL_SOURCE=1
  write_config link
  rig_run apply --scope tools
  [ "$status" -eq 0 ]
  [ -x "$CLI_TEST_DESTINATION" ]
  [ "$(readlink "$CLI_TEST_DESTINATION")" = "$CLI_TEST_SOURCE" ]
  rig_run apply --scope tools
  [ "$status" -eq 0 ]
  ! grep -q '^reinstall' "$CLI_TEST_LOG" || false
}

@test "dry run previews companion ownership and creates no links or native work" {
  write_config
  rig_run apply --dry-run --scope tools
  [ "$status" -eq 0 ]
  [[ "$output" == *'cli:example:provider'* ]]
  [ ! -e "$CLI_TEST_DESTINATION" ]
  [ ! -s "$CLI_TEST_LOG" ]
}

@test "an expected dangling native link is repaired along with the absent source" {
  ln -s "$CLI_TEST_SOURCE" "$CLI_TEST_DESTINATION"
  rm "$CLI_TEST_SOURCE"
  write_config
  rig_run status
  [ "$status" -eq 1 ]
  [[ "$output" == *'cli-source-unavailable:example'* ]]
  rig_run apply --scope tools
  [ "$status" -eq 0 ]
  [ -x "$CLI_TEST_DESTINATION" ]
}

@test "non executable source is unhealthy even when its companion link exists" {
  chmod -x "$CLI_TEST_SOURCE"
  ln -s "$CLI_TEST_SOURCE" "$CLI_TEST_DESTINATION"
  write_config link
  rig_run status
  [ "$status" -eq 1 ]
  [[ "$output" == *'cli-source-unavailable:example'* ]]
  rig_run apply --scope tools
  [ "$status" -ne 0 ]
  [[ "$output" == *'source is not executable after installation'* ]]
}

@test "wrong target and occupied file or directory are preserved before any installer runs" {
  write_config
  for kind in wrong-link file directory; do
    case "$kind" in
      wrong-link) ln -s "$CLI_TEST_ROOT/other" "$CLI_TEST_DESTINATION" ;;
      file) printf 'keep\n' >"$CLI_TEST_DESTINATION" ;;
      directory) mkdir "$CLI_TEST_DESTINATION" ;;
    esac
    rig_run status
    [ "$status" -eq 1 ]
    : >"$CLI_TEST_LOG"
    rig_run apply --scope tools
    [ "$status" -ne 0 ]
    [ ! -s "$CLI_TEST_LOG" ] || false
    case "$kind" in
      wrong-link) [ "$(readlink "$CLI_TEST_DESTINATION")" = "$CLI_TEST_ROOT/other" ]; rm "$CLI_TEST_DESTINATION" ;;
      file) [ "$(cat "$CLI_TEST_DESTINATION")" = keep ]; rm "$CLI_TEST_DESTINATION" ;;
      directory) [ -d "$CLI_TEST_DESTINATION" ]; rmdir "$CLI_TEST_DESTINATION" ;;
    esac
    : >"$CLI_TEST_LOG"
  done
}

@test "relative native link to the declared executable is healthy" {
  ln -s ../Example.app/Contents/Helpers/ExampleCLI "$CLI_TEST_DESTINATION"
  write_config
  rig_run status
  [ "$status" -eq 0 ]
  rig_run apply --scope tools
  [ "$status" -eq 0 ]
  ! grep -q '^reinstall' "$CLI_TEST_LOG" || false
}

@test "link owned CLI cannot traverse a destination directory symlink" {
  write_config link
  mv "$CLI_TEST_ROOT/bin" "$CLI_TEST_ROOT/physical-bin"
  ln -s "$CLI_TEST_ROOT/physical-bin" "$CLI_TEST_ROOT/bin"
  rig_run status
  [ "$status" -eq 1 ]
  [[ "$output" == *'cli-unsafe-parent:example'* ]]
  : >"$CLI_TEST_LOG"
  rig_run apply --scope tools
  [ "$status" -ne 0 ]
  [ ! -s "$CLI_TEST_LOG" ]
  [ ! -e "$CLI_TEST_ROOT/physical-bin/example" ]
}

@test "native repair failures are reported and a successful but ineffective repair still fails" {
  write_config
  export CLI_TEST_REPAIR_EXIT=23
  rig_run apply --scope tools
  [ "$status" -eq 1 ]
  [[ "$output" == *'exit:23'* ]]
  [ ! -e "$CLI_TEST_DESTINATION" ]
  export CLI_TEST_REPAIR_EXIT=0 CLI_TEST_BROKEN_REPAIR=1
  rig_run apply --scope tools
  [ "$status" -eq 1 ]
  [[ "$output" == *'remains unhealthy after installation'* ]]
}

@test "upgrade restores the companion after native upgrade removes it" {
  write_config
  ln -s "$CLI_TEST_SOURCE" "$CLI_TEST_DESTINATION"
  export CLI_TEST_UPGRADE_REMOVES_LINK=1
  rig_run upgrade
  [ "$status" -eq 0 ]
  [ -x "$CLI_TEST_DESTINATION" ]
  grep -q '^upgrade --cask vendor/tap/example$' "$CLI_TEST_LOG"
  grep -q '^reinstall --cask vendor/tap/example$' "$CLI_TEST_LOG"
}

@test "upgrade dry run creates no companion or provider mutations" {
  write_config link
  rig_run upgrade --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$CLI_TEST_DESTINATION" ]
  [ ! -s "$CLI_TEST_LOG" ]
}

@test "CLI declarations reject partial fields invalid ownership unsafe paths and unsupported native owners" {
  for invalid in partial owner path kind; do
    write_config
    case "$invalid" in
      partial) edit_config '/cli.example.source/d' ;;
      owner) edit_config 's/owner = "provider"/owner = "unknown"/' ;;
      path) edit_config 's@destination = ".*"@destination = "~/../unsafe"@' ;;
      kind) edit_config 's/kind = "cask"/kind = "formula"/' ;;
    esac
    rig_run show example
    [ "$status" -eq 2 ]
    [ ! -s "$CLI_TEST_LOG" ]
  done
}

@test "CLI metadata is explained privately and excluded from public exports" {
  write_config link
  cat >>"$CONFIG_HOME/rig.toml" <<'TOML'
[profile.public]
kind = "view"
tools = ["example"]
TOML
  rig_run show example
  [ "$status" -eq 0 ]
  [[ "$output" == *'CLI: example (owner=link)'* ]]
  rig_run export --profile public --output "$CLI_TEST_ROOT/export"
  [ "$status" -eq 0 ]
  ! grep -q 'ExampleCLI|destination|cli.example|Contents/Helpers' "$CLI_TEST_ROOT/export/rig.json" || false
}

@test "two selected apps cannot claim the same CLI destination" {
  write_config link
  cat >>"$CONFIG_HOME/rig.toml" <<TOML
[tool.other]
name = "Other"
category = "apps"
purpose = "Other application"
rationale = "Collision fixture"
platforms = ["macos"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "other"
cli.other.source = "$CLI_TEST_SOURCE"
cli.other.destination = "$CLI_TEST_DESTINATION"
cli.other.owner = "link"
TOML
  edit_config 's/tools = \["example"\]/tools = ["example", "other"]/'
  rig_run apply --dry-run --scope tools
  [ "$status" -eq 2 ]
  [[ "$output" == *'is shared by'* ]]
  [ ! -s "$CLI_TEST_LOG" ]
}

@test "platform variants select only the current application's companions" {
  write_config link
  edit_config 's/^cli.example./variant.macos.cli.example./'
  edit_config '/^variant.macos.cli.example.source/i\
variant.macos.platforms = ["macos"]\
variant.linux.platforms = ["linux"]\
variant.linux.artifacts = ["/etc"]\
'
  rig_run show example
  [ "$status" -eq 0 ]
  [[ "$output" == *'CLI: example'* ]]
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux "$RIG" show example
  [ "$status" -eq 0 ]
  [[ "$output" != *'CLI: example'* ]]
}

@test "an unwritable companion directory is rejected before installation" {
  write_config link
  chmod 0555 "$CLI_TEST_ROOT/bin"
  rig_run apply --scope tools
  chmod 0755 "$CLI_TEST_ROOT/bin"
  [ "$status" -ne 0 ]
  [[ "$output" == *'destination directory is not writable'* ]]
  [ ! -s "$CLI_TEST_LOG" ]
  [ ! -e "$CLI_TEST_DESTINATION" ]
}

@test "a destination directory arriving during link creation retains no unintended link" {
  write_config link
  cat >"$RIG_TEST_PROVIDER_BIN/ln" <<'SH'
#!/usr/bin/env bash
mkdir "$CLI_TEST_DESTINATION"
printf 'keep\n' >"$CLI_TEST_DESTINATION/marker"
/bin/ln "$@"
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/ln"
  rig_run apply --scope tools
  [ "$status" -eq 1 ]
  [[ "$output" == *'destination changed during link creation'* ]]
  [ "$(cat "$CLI_TEST_DESTINATION/marker")" = keep ]
  [ ! -L "$CLI_TEST_DESTINATION/ExampleCLI" ]
}

@test "whole leading home forms expand without evaluating command-looking path text" {
  export HOME=$CLI_TEST_ROOT
  export CLI_TEST_SOURCE="$CLI_TEST_ROOT/Example.app/Contents/Helpers/space;\$(touch marker)"
  create_source
  write_config link
  edit_config 's@cli.example.source = ".*"@cli.example.source = "~/Example.app/Contents/Helpers/space;$(touch marker)"@'
  edit_config 's@cli.example.destination = ".*"@cli.example.destination = "$HOME/bin/example"@'
  rig_run apply --scope tools
  [ "$status" -eq 0 ]
  [ "$(readlink "$CLI_TEST_DESTINATION")" = "$CLI_TEST_SOURCE" ]
  [ ! -e marker ]
}

@test "targeted consumer includes a present app prerequisite whose companion is missing" {
  write_config
  cat >>"$CONFIG_HOME/rig.toml" <<'TOML'
[tool.consumer]
name = "Consumer"
category = "apps"
purpose = "Consume the app CLI"
rationale = "Require a healthy companion"
platforms = ["macos"]
requires = ["example"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "consumer"
TOML
  edit_config 's/tools = \["example"\]/tools = ["example", "consumer"]/'
  rig_run apply --target consumer --scope tools
  [ "$status" -eq 0 ]
  [ -x "$CLI_TEST_DESTINATION" ]
  [ "$(tail -1 "$CLI_TEST_LOG")" = 'install --cask consumer' ]
}

@test "a destination parent replaced during creation leaves no companion outside its trusted path" {
  write_config link
  mkdir "$CLI_TEST_ROOT/outside-bin"
  printf 'keep\n' >"$CLI_TEST_ROOT/outside-bin/marker"
  export CLI_TEST_ROOT
  cat >"$RIG_TEST_PROVIDER_BIN/ln" <<'SH'
#!/usr/bin/env bash
mv "$CLI_TEST_ROOT/bin" "$CLI_TEST_ROOT/old-bin"
/bin/ln -s "$CLI_TEST_ROOT/outside-bin" "$CLI_TEST_ROOT/bin"
/bin/ln "$@"
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/ln"
  rig_run apply --scope tools
  [ "$status" -eq 1 ]
  [[ "$output" == *'cli-unsafe-parent:example'* ]]
  [ ! -L "$CLI_TEST_ROOT/outside-bin/example" ]
  [ "$(cat "$CLI_TEST_ROOT/outside-bin/marker")" = keep ]
}
