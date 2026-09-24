#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
}

write_empty_model() {
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' '[profile.default]' >"$CONFIG_HOME/rig.toml"
}

run_diag() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" show
}

@test "reserved built-in providers reject adapter and capability declarations" {
  write_empty_model
  printf '%s\n' '[provider.homebrew]' 'adapter = "homebrew"' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *'reserved built-in provider cannot declare adapter'* ]] || false

  write_empty_model
  printf '%s\n' '[provider.homebrew]' 'capabilities = ["observe"]' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *'reserved built-in provider cannot declare capabilities'* ]] || false

  write_empty_model
  printf '%s\n' '[provider.homebrew]' 'command = "brew"' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *"field 'command' is not supported"* ]] || false
}

@test "external providers require the custom adapter" {
  write_empty_model
  printf '%s\n' '[provider.alias]' 'adapter = "homebrew"' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *"external provider adapter must be 'custom'"* ]] || false

  write_empty_model
  printf '%s\n' '[provider.alias]' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires field 'adapter'"* ]] || false

  write_empty_model
  printf '%s\n' '[provider.alias]' 'adapter = "custom"' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires field 'capabilities'"* ]] || false

  write_empty_model
  printf '%s\n' '[provider.alias]' 'adapter = "custom"' 'capabilities = ["observe"]' \
    'manifest = "/tmp/manifest"' >>"$CONFIG_HOME/rig.toml"
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *'external provider cannot declare manifest'* ]] || false
}

@test "resource-only built-ins reject tool installation bindings" {
  local provider

  for provider in launchd macos-applications macos-defaults macos-dock; do
    printf '%s\n' \
      '[rig]' 'schema = 1' 'default-profile = "default"' \
      '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
      '[tool.subject]' 'name = "Subject"' 'category = "core"' 'purpose = "Reject binding"' \
      'rationale = "Provider is resource-only"' 'platforms = ["macos"]' \
      "install.provider = \"$provider\"" 'install.kind = "tool"' 'install.locator = "subject"' \
      '[profile.default]' 'tools = ["subject"]' >"$CONFIG_HOME/rig.toml"
    run_diag
    [ "$status" -eq 2 ]
    [[ "$output" == *"adapter '$provider' cannot install tools"* ]] || false
  done
}

@test "action tables reject built-in providers including launchd" {
  local provider

  for provider in homebrew launchd; do
    write_empty_model
    printf '%s\n' "[action.$provider.status]" 'mode = "observe"' 'description = "Status"' >>"$CONFIG_HOME/rig.toml"
    run_diag
    [ "$status" -eq 2 ]
    [[ "$output" == *'actions require a custom provider'* ]] || false
  done
}

@test "dock explanation expands ordered semantic item details" {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'docks = ["main"]' \
    '[dock.main]' 'name = "Main"' 'purpose = "Order destinations"' 'rationale = "Predictable access"' \
    'provider = "macos-dock"' 'platforms = ["macos"]' 'items = ["alpha", "documents"]' \
    '[dock-item.alpha]' 'kind = "application"' 'path = "/Applications/Alpha.app"' \
    '[dock-item.documents]' 'kind = "folder"' 'path = "~/Documents"' 'view = "grid"' \
    'display = "folder"' >"$CONFIG_HOME/rig.toml"

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" explain dock:main
  [ "$status" -eq 0 ]
  [[ "$output" == *$'dock-item.1.id=alpha\ndock-item.1.kind=application\ndock-item.1.path=/Applications/Alpha.app'* ]] || false
  [[ "$output" == *$'dock-item.2.id=documents\ndock-item.2.kind=folder\ndock-item.2.path=~/Documents\ndock-item.2.view=grid\ndock-item.2.display=folder'* ]] || false
}
