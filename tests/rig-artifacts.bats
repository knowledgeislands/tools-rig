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

output_has_table_row() {
  local expected

  expected=$1
  printf '%s\n' "$output" | awk -v expected="$expected" '
    { gsub(/  +/, "\t"); if ($0 == expected) found = 1 }
    END { exit !found }
  '
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
  output_has_table_row $'subject\tfixture\tpresent\t-'
}

@test "missing artifact refines provider present state to missing" {
  write_artifact_config '["~/Applications/Missing.app"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tmissing\tartifact-missing:~/Applications/Missing.app'
}

@test "app directory without readable Info plist is drifted" {
  mkdir -p "$TEST_HOME/Applications/Damaged.app/Contents"
  write_artifact_config '["$HOME/Applications/Damaged.app"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tdrifted\tartifact-damaged-app:$HOME/Applications/Damaged.app'
}

@test "a link to a regular file resolves through its relative target" {
  mkdir -p "$TEST_HOME/bundle"
  : >"$TEST_HOME/bundle/real"
  ln -s bundle/real "$TEST_HOME/link"
  write_artifact_config '["~/link"]'

  run_status
  [ "$status" -eq 0 ]
  output_has_table_row $'subject\tfixture\tpresent\t-'
}

@test "a link into a healthy application is observed through its target" {
  mkdir -p "$TEST_HOME/Applications/Healthy.app/Contents/MacOS"
  printf '%s\n' \
    '<plist><dict><key>CFBundleExecutable</key><string>Healthy</string></dict></plist>' \
    >"$TEST_HOME/Applications/Healthy.app/Contents/Info.plist"
  : >"$TEST_HOME/Applications/Healthy.app/Contents/MacOS/Healthy"
  chmod +x "$TEST_HOME/Applications/Healthy.app/Contents/MacOS/Healthy"
  ln -s "$TEST_HOME/Applications/Healthy.app" "$TEST_HOME/linked.app"
  write_artifact_config '["~/linked.app"]'

  run_status
  [ "$status" -eq 0 ]
  output_has_table_row $'subject\tfixture\tpresent\t-'
}

@test "a dangling link is missing and names the target it resolved to" {
  ln -s "$TEST_HOME/Applications/Gone.app" "$TEST_HOME/code"
  write_artifact_config '["~/code"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tmissing\tartifact-missing:~/code->~/Applications/Gone.app'
}

@test "a link into a damaged application drifts exactly as the bundle would" {
  mkdir -p "$TEST_HOME/Damaged.app/Contents"
  ln -s "$TEST_HOME/Damaged.app" "$TEST_HOME/bad.app"
  write_artifact_config '["~/bad.app"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tdrifted\tartifact-damaged-app:~/bad.app->~/Damaged.app'
}

@test "a cyclic link reports failed resolution rather than an unsafe artifact" {
  ln -s "$TEST_HOME/beta" "$TEST_HOME/alpha"
  ln -s "$TEST_HOME/alpha" "$TEST_HOME/beta"
  write_artifact_config '["~/alpha"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tunavailable\tartifact-unresolved-link:~/alpha'
  [[ "$output" != *'artifact-unsafe'* ]] || false
}

@test "resolution never turns an unsupported target into a present artifact" {
  mkfifo "$TEST_HOME/pipe"
  ln -s "$TEST_HOME/pipe" "$TEST_HOME/link"
  write_artifact_config '["~/link"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tunavailable\tartifact-unsafe:~/link->~/pipe'
}

@test "artifact expansion is limited to documented leading home forms" {
  mkdir -p "$TEST_HOME/data"
  : >"$TEST_HOME/data/marker"
  write_artifact_config '["prefix-$HOME/data/marker"]'

  run_status
  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tmissing\tartifact-missing:prefix-$HOME/data/marker'
}

@test "catalogue-only tools do not receive artifact health state" {
  write_artifact_config '["~/missing"]' no

  run_status
  [ "$status" -eq 0 ]
  output_has_table_row $'subject\t-\tunavailable\tcatalogue-only'
  [[ "$output" != *'artifact-missing'* ]] || false
}

@test "macOS app artifact requires its declared nested executable" {
  mkdir -p "$TEST_HOME/Applications/Nested.app/Contents/MacOS"
  printf '%s\n' \
    '<plist><dict><key>CFBundleExecutable</key><string>Nested</string></dict></plist>' \
    >"$TEST_HOME/Applications/Nested.app/Contents/Info.plist"
  write_artifact_config '["$HOME/Applications/Nested.app"]'
  run_status

  [ "$status" -ne 0 ]
  output_has_table_row $'subject\tfixture\tdrifted\tartifact-damaged-app:$HOME/Applications/Nested.app'

  : >"$TEST_HOME/Applications/Nested.app/Contents/MacOS/Nested"
  chmod +x "$TEST_HOME/Applications/Nested.app/Contents/MacOS/Nested"
  run_status

  [ "$status" -eq 0 ]
  output_has_table_row $'subject\tfixture\tpresent\t-'
}
