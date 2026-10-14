#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
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

write_executables_model() {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.subject]' 'name = "Subject"' 'category = "core"' 'purpose = "Observe executables"' \
    'rationale = "Binary names differ from the locator"' 'platforms = ["macos"]' \
    "$@" \
    '[profile.default]' 'tools = ["subject"]' >"$CONFIG_HOME/rig.toml"
}

@test "install.executables is valid only on a mise tool with safe names" {
  local name

  write_executables_model 'install.provider = "mise"' 'install.kind = "tool"' \
    'install.locator = "rust"' 'install.executables = ["rustc", "cargo"]'
  run_diag
  [ "$status" -eq 0 ] || false

  write_executables_model 'variant.mac.platforms = ["macos"]' 'variant.mac.install.provider = "mise"' \
    'variant.mac.install.kind = "tool"' 'variant.mac.install.locator = "rust"' \
    'variant.mac.install.executables = ["rustc"]'
  run_diag
  [ "$status" -eq 0 ] || false

  write_executables_model 'install.provider = "homebrew"' 'install.kind = "formula"' \
    'install.locator = "rust"' 'install.executables = ["rustc"]'
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *'install.executables is only valid for mise tool installations'* ]] || false

  write_executables_model 'install.executables = ["rustc"]'
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *'install metadata requires install.provider'* ]] || false

  write_executables_model 'variant.mac.platforms = ["macos"]' 'variant.mac.install.executables = ["rustc"]'
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *"variant 'mac' install metadata requires install.provider"* ]] || false

  for name in '-rustc' 'bin/rustc' 'rust\tc' 'rust\nc'; do
    write_executables_model 'install.provider = "mise"' 'install.kind = "tool"' \
      'install.locator = "rust"' "install.executables = [\"$name\"]"
    run_diag
    [ "$status" -eq 2 ]
    [[ "$output" == *'install.executables has invalid executable name'* ]] || false
  done

  write_executables_model 'install.provider = "mise"' 'install.kind = "tool"' \
    'install.locator = "rust"' 'install.executables = [""]'
  run_diag
  [ "$status" -eq 2 ]
  [[ "$output" == *'array values must not be empty'* ]] || false
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

  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" show dock:main
  [ "$status" -eq 0 ]
  [[ "$output" == *$'dock-item.1.id=alpha\ndock-item.1.kind=application\ndock-item.1.path=/Applications/Alpha.app'* ]] || false
  [[ "$output" == *$'dock-item.2.id=documents\ndock-item.2.kind=folder\ndock-item.2.path=~/Documents\ndock-item.2.view=grid\ndock-item.2.display=folder'* ]] || false
}
