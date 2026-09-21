#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  PROVIDER=$BATS_TEST_TMPDIR/provider
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '[ "$1" = rig-provider-v1 ] || exit 64' \
    '[ "$2" = observe ] || exit 65' \
    'printf "%s\n" present' >"$PROVIDER"
  chmod +x "$PROVIDER"
}

write_artifact_config() {
  local artifacts installation

  artifacts=$1
  installation=${2:-yes}
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.subject]' 'name = "Subject"' 'category = "core"' 'purpose = "Test artifacts"' \
    'rationale = "Exercise artifact health"' 'platforms = ["macos"]' \
    "artifacts = $artifacts" >"$CONFIG_HOME/rig.toml"
  if [ "$installation" = yes ]; then
    printf '%s\n' 'install.provider = "fixture"' 'install.kind = "package"' \
      'install.locator = "subject"' >>"$CONFIG_HOME/rig.toml"
  fi
  printf '%s\n' '[profile.default]' 'tools = ["subject"]' \
    '[provider.fixture]' 'adapter = "custom"' "executable = \"$PROVIDER\"" \
    'capabilities = ["observe"]' >>"$CONFIG_HOME/rig.toml"
}

run_status() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" status
}

@test "present provider remains present when regular directory and app artifacts are intact" {
  mkdir -p "$TEST_HOME/Applications/Healthy.app/Contents/MacOS" "$TEST_HOME/data"
  printf '%s\n' \
    '<plist><dict><key>CFBundleExecutable</key><string>Healthy</string></dict></plist>' \
    >"$TEST_HOME/Applications/Healthy.app/Contents/Info.plist"
  : >"$TEST_HOME/Applications/Healthy.app/Contents/MacOS/Healthy"
  chmod +x "$TEST_HOME/Applications/Healthy.app/Contents/MacOS/Healthy"
  : >"$TEST_HOME/data/marker"
  write_artifact_config '["~/Applications/Healthy.app", "$HOME/data", "$HOME/data/marker"]'

  run_status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'subject\tfixture\tpresent\t-'* ]]
}

@test "missing artifact refines provider present state to missing" {
  write_artifact_config '["~/Applications/Missing.app"]'

  run_status
  [ "$status" -ne 0 ]
  [[ "$output" == *$'subject\tfixture\tmissing\tartifact-missing:~/Applications/Missing.app'* ]]
}

@test "app directory without readable Info plist is drifted" {
  mkdir -p "$TEST_HOME/Applications/Damaged.app/Contents"
  write_artifact_config '["$HOME/Applications/Damaged.app"]'

  run_status
  [ "$status" -ne 0 ]
  [[ "$output" == *$'subject\tfixture\tdrifted\tartifact-damaged-app:$HOME/Applications/Damaged.app'* ]]
}

@test "unsafe artifact target refines provider present state to unavailable" {
  : >"$TEST_HOME/real"
  ln -s "$TEST_HOME/real" "$TEST_HOME/link"
  write_artifact_config '["~/link"]'

  run_status
  [ "$status" -ne 0 ]
  [[ "$output" == *$'subject\tfixture\tunavailable\tartifact-unsafe:~/link'* ]]
}

@test "artifact expansion is limited to documented leading home forms" {
  mkdir -p "$TEST_HOME/data"
  : >"$TEST_HOME/data/marker"
  write_artifact_config '["prefix-$HOME/data/marker"]'

  run_status
  [ "$status" -ne 0 ]
  [[ "$output" == *$'subject\tfixture\tmissing\tartifact-missing:prefix-$HOME/data/marker'* ]]
}

@test "catalogue-only tools do not receive artifact health state" {
  write_artifact_config '["~/missing"]' no

  run_status
  [ "$status" -eq 0 ]
  [[ "$output" == *$'subject\t-\tunavailable\tcatalogue-only'* ]]
  [[ "$output" != *'artifact-missing'* ]]
}

@test "macOS app artifact requires its declared nested executable" {
  mkdir -p "$TEST_HOME/Applications/Nested.app/Contents/MacOS"
  printf '%s\n' \
    '<plist><dict><key>CFBundleExecutable</key><string>Nested</string></dict></plist>' \
    >"$TEST_HOME/Applications/Nested.app/Contents/Info.plist"
  write_artifact_config '["$HOME/Applications/Nested.app"]'
  run_status

  [ "$status" -ne 0 ]
  [[ "$output" == *$'subject\tfixture\tdrifted\tartifact-damaged-app:$HOME/Applications/Nested.app'* ]]

  : >"$TEST_HOME/Applications/Nested.app/Contents/MacOS/Nested"
  chmod +x "$TEST_HOME/Applications/Nested.app/Contents/MacOS/Nested"
  run_status

  [ "$status" -eq 0 ]
  [[ "$output" == *$'subject\tfixture\tpresent\t-'* ]]
}
