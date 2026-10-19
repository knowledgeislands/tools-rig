#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME"
}

# laptop configures the editor through a setting and a service; studio selects
# the same tools with only a requires-only setting.
write_config() {
  cat >"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[rig]
default-profile = "laptop"
[category.core]
name = "Core"
purpose = "Fixture"
[profile.laptop]
tools = ["editor", "shell"]
settings = ["editor-theme"]
services = ["editor-daemon"]
[profile.studio]
tools = ["editor", "shell"]
settings = ["shell-prompt"]
[profile.public]
kind = "view"
tools = ["editor", "shell"]
[tool.editor]
name = "Editor"
category = "core"
purpose = "Edit text"
rationale = "Fixture"
platforms = ["macos"]
[tool.shell]
name = "Shell"
category = "core"
purpose = "Run commands"
rationale = "Fixture"
platforms = ["macos"]
[setting.editor-theme]
name = "Editor theme"
purpose = "Fixture"
rationale = "Fixture"
provider = "macos-defaults"
domain = "org.example.Editor"
key = "Theme"
value-type = "string"
value = "dark"
platforms = ["macos"]
tool = "editor"
[setting.shell-prompt]
name = "Shell prompt"
purpose = "Fixture"
rationale = "Fixture"
provider = "macos-defaults"
domain = "org.example.Shell"
key = "Prompt"
value-type = "string"
value = "short"
platforms = ["macos"]
requires = ["shell"]
[service.editor-daemon]
name = "Editor daemon"
purpose = "Fixture"
rationale = "Fixture"
provider = "launchd"
locator = "org.example.editor"
platforms = ["macos"]
desired-state = "running"
program = ["/usr/bin/true"]
tool = "editor"
TOML
}

@test "show JSON reports configured_by per profile and ignores requires-only links" {
  write_config
  run "$RIG" show --profile laptop --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"id":"editor","name":"Editor","category":"core","purpose":"Edit text","configured_by":["service:editor-daemon","setting:editor-theme"]}'* ]] || false
  [[ "$output" == *'"id":"shell","name":"Shell","category":"core","purpose":"Run commands","configured_by":[]}'* ]] || false
  run "$RIG" show --profile studio --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"id":"editor",'*'"configured_by":[]}'* ]] || false
  [[ "$output" == *'"id":"shell",'*'"configured_by":[]}'* ]] || false
}

@test "a subject link pulls its tool into the profile" {
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[profile.settings-only]
settings = ["editor-theme"]
TOML
  run "$RIG" show --profile settings-only --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"tools":[{"id":"editor",'*'"configured_by":["setting:editor-theme"]}]'* ]] || false
}

@test "an unknown subject tool fails validation" {
  write_config
  sed 's/^tool = "editor"$/tool = "missing"/' "$RIG_CONFIG_HOME/rig.toml" >"$BATS_TEST_TMPDIR/rig.toml"
  mv "$BATS_TEST_TMPDIR/rig.toml" "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show --profile laptop
  [ "$status" -ne 0 ]
  [[ "$output" == *'missing'* ]] || false
}

@test "the tool table marks configured tools only when a profile configures one" {
  write_config
  run "$RIG" show --profile laptop
  [ "$status" -eq 0 ]
  [[ "$output" == *'CONFIGURED'* ]] || false
  printf '%s\n' "$output" | /usr/bin/grep -E '^editor +Editor +core +Edit text +yes$'
  printf '%s\n' "$output" | /usr/bin/grep -E '^shell +Shell +core +Run commands *$'
  run "$RIG" show --profile studio
  [ "$status" -eq 0 ]
  [[ "$output" != *'CONFIGURED'* ]] || false
}

@test "show TOOL lists every declared resource that configures it" {
  write_config
  run "$RIG" show editor
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nConfigured by: service:editor-daemon, setting:editor-theme\n'* ]] || false
  run "$RIG" show shell
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\nConfigured by: none\n'* ]] || false
  run "$RIG" show setting:editor-theme
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\ntool=editor' ]] || false
  [[ "$output" != *'requires=editor'* ]] || false
}

@test "public export is byte-identical with and without subject links" {
  write_config
  run "$RIG" export --profile public --output "$BATS_TEST_TMPDIR/with"
  [ "$status" -eq 0 ]
  /usr/bin/sed '/^tool = "editor"$/d' "$RIG_CONFIG_HOME/rig.toml" >"$BATS_TEST_TMPDIR/rig.toml"
  mv "$BATS_TEST_TMPDIR/rig.toml" "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" export --profile public --output "$BATS_TEST_TMPDIR/without"
  [ "$status" -eq 0 ]
  /usr/bin/diff -r "$BATS_TEST_TMPDIR/with" "$BATS_TEST_TMPDIR/without"
}
