#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$CONFIG_HOME"
}

write_fixture_catalogue() {
  local provider kind locator
  provider=$1
  kind=$2
  locator=$3
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "default"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Provider observation fixture"' \
    '[tool.sample]' \
    'name = "Sample"' \
    'category = "core"' \
    'purpose = "Exercise a native provider"' \
    'rationale = "Keep manager observations independent of the runner"' \
    'platforms = ["macos", "linux"]' \
    "install.provider = \"$provider\"" \
    "install.kind = \"$kind\"" \
    "install.locator = \"$locator\"" \
    '[profile.default]' \
    'name = "Default"' \
    'tools = ["sample"]' >"$CONFIG_HOME/rig.toml"
}

add_fixture_install_line() {
  local line catalogue
  line=$1
  catalogue=$CONFIG_HOME/rig.toml
  awk -v extra="$line" '{ print } /^install\.locator = / { print extra }' "$catalogue" >"$catalogue.new"
  mv "$catalogue.new" "$catalogue"
}

@test "provider fixture controls Homebrew observation on both platforms" {
  local platform
  write_fixture_catalogue homebrew formula sample
  rig_test_provider brew
  for platform in macos linux; do
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response brew 'list --formula --versions sample' 0 'sample 1.0'
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [ "$status" -eq 0 ] || false
    [[ "$output" =~ sample[[:space:]]+homebrew[[:space:]]+present[[:space:]]+- ]] || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response brew 'list --formula --versions sample' 1 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+homebrew[[:space:]]+missing[[:space:]]+- ]] || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response brew 'list --formula --versions sample' 7 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+homebrew[[:space:]]+unknown[[:space:]]+exit:7 ]] || false
  done
  grep -Fqx 'brew|list --formula --versions sample' "$RIG_TEST_PROVIDER_LOG" || false
}

@test "provider fixture distinguishes uv absence and chezmoi drift" {
  local platform
  rig_test_provider uv
  rig_test_provider chezmoi
  for platform in macos linux; do
    write_fixture_catalogue uv tool sample
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response uv 'tool list' 0 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+uv[[:space:]]+missing[[:space:]]+- ]] || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response uv 'tool list' 0 'sample v1.0'
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+uv[[:space:]]+present[[:space:]]+- ]] || false
    write_fixture_catalogue chezmoi target /tmp/rig-fixture-target
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response chezmoi 'status --path-style=absolute -- /tmp/rig-fixture-target' 0 ' M /tmp/rig-fixture-target'
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+chezmoi[[:space:]]+drifted[[:space:]]+- ]] || false
  done
}

@test "capability-unavailable never invokes a native manager" {
  write_fixture_catalogue homebrew formula sample
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" status
  [[ "$output" =~ sample[[:space:]]+homebrew[[:space:]]+unavailable[[:space:]]+executable-unavailable ]] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "mise and npm observations use declared fixture responses" {
  local platform
  rig_test_provider mise
  rig_test_provider npm
  for platform in macos linux; do
    write_fixture_catalogue mise tool sample
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response mise 'which sample' 0 /tmp/rig-fixture-sample
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+present[[:space:]]+- ]] || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response mise 'which sample' 1 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+missing[[:space:]]+- ]] || false
    write_fixture_catalogue npm global sample
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response npm 'list --global --depth=0 sample' 0 'sample@1.0'
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+npm[[:space:]]+present[[:space:]]+- ]] || false
  done
}

@test "unlisted fixture invocation fails visibly and records argv" {
  write_fixture_catalogue homebrew formula sample
  rig_test_provider brew
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" status
  [[ "$output" =~ sample[[:space:]]+homebrew[[:space:]]+unknown[[:space:]]+exit:99 ]] || false
  grep -Fqx 'brew|list --formula --versions sample' "$RIG_TEST_PROVIDER_LOG" || false
}

@test "mise observes each declared executable and installs the locator" {
  local platform
  rig_test_provider mise
  for platform in macos linux; do
    write_fixture_catalogue mise tool rust
    add_fixture_install_line 'install.executables = ["rustc", "cargo"]'
    : >"$RIG_TEST_PROVIDER_TABLE"
    : >"$RIG_TEST_PROVIDER_LOG"
    rig_test_provider_response mise 'which rustc' 0 /tmp/rig-fixture-rustc
    rig_test_provider_response mise 'which cargo' 0 /tmp/rig-fixture-cargo
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+present[[:space:]]+- ]] || false
    grep -Fqx 'mise|which rustc' "$RIG_TEST_PROVIDER_LOG" || false
    grep -Fqx 'mise|which cargo' "$RIG_TEST_PROVIDER_LOG" || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response mise 'which rustc' 0 /tmp/rig-fixture-rustc
    rig_test_provider_response mise 'which cargo' 1 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+missing[[:space:]]+missing-executable:cargo ]] || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response mise 'which rustc' 1 -
    rig_test_provider_response mise 'which cargo' 1 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+missing[[:space:]]+missing-executable:rustc ]] || false
    : >"$RIG_TEST_PROVIDER_TABLE"
    rig_test_provider_response mise 'which rustc' 4 -
    run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="$platform" "$RIG" status
    [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+unknown[[:space:]]+exit:4 ]] || false
  done
  ! grep -Fqx 'mise|which rust' "$RIG_TEST_PROVIDER_LOG" || false
}

@test "mise cargo backend observes its executable and applies the full locator" {
  rig_test_provider mise
  write_fixture_catalogue mise tool cargo:cargo-nextest
  add_fixture_install_line 'install.executables = ["cargo-nextest"]'
  rig_test_provider_response mise 'which cargo-nextest' 1 -
  rig_test_provider_response mise 'install cargo:cargo-nextest' 0 -
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" status
  [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+missing[[:space:]]+missing-executable:cargo-nextest ]] || false
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" apply
  grep -Fqx 'mise|which cargo-nextest' "$RIG_TEST_PROVIDER_LOG" || false
  grep -Fqx 'mise|install cargo:cargo-nextest' "$RIG_TEST_PROVIDER_LOG" || false
  ! grep -Fq 'which cargo:' "$RIG_TEST_PROVIDER_LOG" || false
  [ "$(wc -l <"$RIG_TEST_PROVIDER_LOG")" -eq "$(grep -Fxc -e 'mise|which cargo-nextest' -e 'mise|install cargo:cargo-nextest' "$RIG_TEST_PROVIDER_LOG")" ] || false
}

@test "mise default observation strips only a locator version" {
  rig_test_provider mise
  write_fixture_catalogue mise tool node@22
  rig_test_provider_response mise 'which node' 0 /tmp/rig-fixture-node
  rig_test_provider_response mise 'install node@22' 0 -
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" status
  [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+present[[:space:]]+- ]] || false
  grep -Fqx 'mise|which node' "$RIG_TEST_PROVIDER_LOG" || false
  write_fixture_catalogue mise tool npm:@scope/name@1.2
  : >"$RIG_TEST_PROVIDER_TABLE"
  : >"$RIG_TEST_PROVIDER_LOG"
  rig_test_provider_response mise 'which npm:@scope/name' 1 -
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" status
  [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+missing[[:space:]]+- ]] || false
  grep -Fqx 'mise|which npm:@scope/name' "$RIG_TEST_PROVIDER_LOG" || false
  write_fixture_catalogue mise tool npm:@scope/name
  : >"$RIG_TEST_PROVIDER_TABLE"
  : >"$RIG_TEST_PROVIDER_LOG"
  rig_test_provider_response mise 'which npm:@scope/name' 0 /tmp/rig-fixture-name
  run env RIG_CONFIG_HOME="$CONFIG_HOME" "$RIG" status
  [[ "$output" =~ sample[[:space:]]+mise[[:space:]]+present[[:space:]]+- ]] || false
  grep -Fqx 'mise|which npm:@scope/name' "$RIG_TEST_PROVIDER_LOG" || false
}
