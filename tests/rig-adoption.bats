#!/usr/bin/env bats

load helpers/isolate

setup() {
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
}

adoption_config() {
  mkdir -p "$RIG_CONFIG_HOME"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'kind = "complete"' '[profile.other]' 'kind = "complete"' \
    '[category.cli]' 'name = "CLI"' 'purpose = "Command line tools"' >"$RIG_CONFIG_HOME/rig.toml"
  rig_test_provider brew
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'jq'
  rig_test_provider_response brew 'list --cask --full-name' 0 'firefox'
}

@test "init dry run does not create config and real init validates an empty profile" {
  run "$RIG" init --dry-run
  [ "$status" -eq 0 ] || false
  [ ! -e "$RIG_CONFIG_HOME" ] || false
  [[ "$output" == *'default-profile = "default"'* ]] || false
  run "$RIG" init
  [ "$status" -eq 0 ] || false
  [ -f "$RIG_CONFIG_HOME/rig.toml" ] || false
  run "$RIG" show
  [ "$status" -eq 0 ] || false
  run "$RIG" init
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'will not overwrite'* ]] || false
}

@test "init refuses root symlinks directory symlinks and existing fragments" {
  mkdir -p "$RIG_CONFIG_HOME"
  ln -s "$BATS_TEST_TMPDIR/missing" "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" init
  [ "$status" -eq 2 ] || false
  [ ! -e "$BATS_TEST_TMPDIR/missing" ] || false
  rm "$RIG_CONFIG_HOME/rig.toml"
  mkdir -p "$RIG_CONFIG_HOME/conf.d"
  printf '# retained\n' >"$RIG_CONFIG_HOME/conf.d/existing.toml"
  run "$RIG" init
  [ "$status" -eq 2 ] || false
  [ ! -e "$RIG_CONFIG_HOME/rig.toml" ] || false
  ln -s "$RIG_CONFIG_HOME" "$BATS_TEST_TMPDIR/link"
  run env RIG_CONFIG_HOME="$BATS_TEST_TMPDIR/link" "$RIG" init
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'must not be a symlink'* ]] || false
  run env RIG_CONFIG_HOME="$BATS_TEST_TMPDIR/link//./" "$RIG" init
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'must not be a symlink'* ]] || false
}

@test "capture discovery only invokes read-only native inventory" {
  adoption_config
  run "$RIG" capture
  [ "$status" -eq 0 ] || false
  rig_test_report_contains "$output" $'homebrew\tformula:jq\tunmanaged' || false
  rig_test_report_contains "$output" $'homebrew\tcask:firefox\tunmanaged' || false
  [[ "$output" == *'dependency-only formulae are excluded'* ]] || false
  [ "$(wc -l <"$RIG_TEST_PROVIDER_LOG" | tr -d ' ')" -eq 2 ] || false
  ! grep -E 'install|bundle|upgrade' "$RIG_TEST_PROVIDER_LOG" | grep -v 'installed-on-request' || false
  [ ! -d "$RIG_CONFIG_HOME/conf.d" ] || false
}

@test "capture shared table preserves long identities for exact subsequent selection" {
  local locator
  adoption_config
  locator=vendor-with-a-long-name/tap-with-a-long-name/tool-with-an-intentionally-long-identity-that-must-remain-complete-for-copying-and-selection
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 "$locator"
  rig_test_provider_response brew 'list --cask --full-name' 0 '-'
  run "$RIG" capture
  [ "$status" -eq 0 ] || false
  rig_test_report_contains "$output" $'PROVIDER\tIDENTITY\tSTATE' || false
  rig_test_report_contains "$output" $'homebrew\tformula:'"$locator"$'\tunmanaged' || false
  [[ "$output" != *$'homebrew\t'* ]] || false
  [[ "$output" == *'--------'* ]] || false
}

@test "capture preserves configured provider arguments as literal values" {
  adoption_config
  printf '%s\n' '[provider.homebrew]' 'arguments = ["--debug", "literal value"]' >>"$RIG_CONFIG_HOME/rig.toml"
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew '--debug literal value list --formula --installed-on-request --full-name' 0 'jq'
  rig_test_provider_response brew '--debug literal value list --cask --full-name' 0 '-'
  run "$RIG" capture jq
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'formula:jq'* ]] || false
}

@test "capture requires human metadata and emits quoted additive TOML without writes" {
  adoption_config
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON'
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Discovery only'* ]] || false
  [[ "$output" != *'[tool.'* ]] || false
  run "$RIG" capture jq --profile other --category cli --purpose $'Inspect "JSON"\ncarefully' \
    --rationale 'Keep \ paths' --output "$BATS_TEST_TMPDIR/proposal.toml" --dry-run
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'profiles = ["other"]'* ]] || false
  [[ "$output" == *'purpose = "Inspect \"JSON\"\ncarefully"'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/proposal.toml" ] || false
  run "$RIG" capture jq --profile other --category cli --purpose $'Inspect "JSON"\ncarefully' \
    --rationale 'Keep \ paths' --output "$BATS_TEST_TMPDIR/proposal.toml"
  [ "$status" -eq 0 ] || false
  mkdir "$RIG_CONFIG_HOME/conf.d"
  cp "$BATS_TEST_TMPDIR/proposal.toml" "$RIG_CONFIG_HOME/conf.d/adopted.toml"
  run "$RIG" show --profile other
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'homebrew-formula-jq'* ]] || false
}

@test "capture deduplicates declared provider identities across all profiles" {
  adoption_config
  printf '%s\n' '[tool.existing]' 'name = "Existing jq"' 'category = "cli"' \
    'purpose = "Inspect JSON"' 'rationale = "Required elsewhere"' 'profiles = ["other"]' \
    'platforms = ["macos"]' 'install.provider = "homebrew"' 'install.kind = "formula"' \
    'install.locator = "homebrew/core/jq"' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/proposal.toml"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'already declared'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/proposal.toml" ] || false
}

@test "capture permits central-selection discovery but rejects incompatible proposals" {
  adoption_config
  printf '%s\n' '[profile.central]' 'tools = ["existing"]' \
    '[tool.existing]' 'name = "Existing"' 'category = "cli"' 'purpose = "Existing tool"' \
    'rationale = "Keep it"' 'platforms = ["macos"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" capture jq --profile central
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Discovery only'* ]] || false
  run "$RIG" capture jq --profile central --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/proposal.toml"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'require item-owned profile membership'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/proposal.toml" ] || false
}

@test "capture output refuses overwrite symlinks and active config aliases" {
  adoption_config
  mkdir "$RIG_CONFIG_HOME/conf.d"
  ln -s "$RIG_CONFIG_HOME/conf.d" "$BATS_TEST_TMPDIR/config-alias"
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/config-alias/proposal.toml"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'outside active Rig configuration'* ]] || false
  printf 'retained\n' >"$BATS_TEST_TMPDIR/existing"
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/existing"
  [ "$status" -eq 2 ] || false
  [ "$(cat "$BATS_TEST_TMPDIR/existing")" = retained ] || false
  ln -s "$BATS_TEST_TMPDIR/missing" "$BATS_TEST_TMPDIR/output-link"
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/output-link"
  [ "$status" -eq 2 ] || false
  [ ! -e "$BATS_TEST_TMPDIR/missing" ] || false
}

@test "capture rejects absent ambiguous and colliding identities before proposal writes" {
  adoption_config
  run "$RIG" capture absent --category cli --purpose 'Inspect JSON' --rationale 'Keep it'
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'not in supported installed inventory'* ]] || false
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'jq'
  rig_test_provider_response brew 'list --cask --full-name' 0 'jq'
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it'
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'ambiguous'* ]] || false
  run "$RIG" capture formula:jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it'
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'install.kind = "formula"'* ]] || false
  printf '%s\n' '[tool.homebrew-formula-jq]' 'name = "Other"' 'category = "cli"' \
    'purpose = "Other"' 'rationale = "Other"' 'platforms = ["macos"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" capture formula:jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it'
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'conflicts with existing or proposed intent'* ]] || false
}

@test "capture native failure cannot leave a partial proposal" {
  adoption_config
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'jq'
  rig_test_provider_response brew 'list --cask --full-name' 1 '-'
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/proposal.toml"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'could not read Homebrew inventory'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/proposal.toml" ] || false
}

@test "capture rejects unsupported metadata controls without writing a proposal" {
  adoption_config
  run "$RIG" capture jq --category cli --purpose $'Invalid\001metadata' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/proposal.toml"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'unsupported control character'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/proposal.toml" ] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "capture rejects malformed provider identities and colliding generated ids" {
  adoption_config
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'bad;identity'
  rig_test_provider_response brew 'list --cask --full-name' 0 '-'
  run "$RIG" capture
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'could not read Homebrew inventory'* ]] || false
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'tool@1\ntool-1'
  rig_test_provider_response brew 'list --cask --full-name' 0 '-'
  run "$RIG" capture tool@1 tool-1 --category cli --purpose 'Version tools' --rationale 'Keep both' \
    --output "$BATS_TEST_TMPDIR/proposal.toml"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'conflicts with existing or proposed intent'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/proposal.toml" ] || false
}

@test "capture rejects output in an external symlinked active fragments directory" {
  adoption_config
  mkdir "$BATS_TEST_TMPDIR/fragments"
  ln -s "$BATS_TEST_TMPDIR/fragments" "$RIG_CONFIG_HOME/conf.d"
  run "$RIG" capture jq --category cli --purpose 'Inspect JSON' --rationale 'Keep it' \
    --output "$BATS_TEST_TMPDIR/fragments/proposal.toml"
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'outside active Rig configuration fragments'* ]] || false
  [ ! -e "$BATS_TEST_TMPDIR/fragments/proposal.toml" ] || false
}

@test "capture flags unqualified existing bindings before adopting a third party tap" {
  adoption_config
  : >"$RIG_TEST_PROVIDER_TABLE"
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'vendor/tap/jq'
  rig_test_provider_response brew 'list --cask --full-name' 0 '-'
  printf '%s\n' '[tool.existing]' 'name = "jq"' 'category = "cli"' \
    'purpose = "Inspect JSON"' 'rationale = "Existing tool"' 'platforms = ["macos"]' \
    'install.provider = "homebrew"' 'install.kind = "formula"' \
    'install.locator = "jq"' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" capture vendor/tap/jq --category cli --purpose 'Inspect JSON' --rationale 'Third party'
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'may match an unqualified declaration'* ]] || false
}

@test "status discovers implicit Homebrew without a provider declaration" {
  adoption_config
  run "$RIG" status --unmanaged
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'formula:jq'* ]] || false
  [[ "$output" == *'cask:firefox'* ]] || false
}

@test "capture does not conflate third party tap namespaces with default packages" {
  adoption_config
  printf '%s\n' '[tool.existing]' 'name = "Other jq"' 'category = "cli"' \
    'purpose = "Inspect JSON"' 'rationale = "Third party build"' 'platforms = ["macos"]' \
    'install.provider = "homebrew"' 'install.kind = "formula"' \
    'install.locator = "vendor/tap/jq"' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" capture formula:jq --category cli --purpose 'Inspect JSON' --rationale 'Default build'
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'[tool.homebrew-formula-jq]'* ]] || false
}

@test "schema rejects retired bootstrap Homebrew manifest and autoupdate with migration advice" {
  adoption_config
  printf '%s\n' '[provider.homebrew]' 'manifest = "/unused/Brewfile"' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'manifest is retired'* ]] || false
  sed -i.bak 's|manifest = "/unused/Brewfile"|autoupdate-interval = 86400|' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'autoupdate policy is retired'* ]] || false
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' 'bootstrap-profile = "default"' \
    '[profile.default]' 'kind = "complete"' >"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'bootstrap-profile is retired'* ]] || false
}

@test "schema retains native chezmoi configuration and custom provider actions" {
  adoption_config
  printf '%s\n' '[provider.chezmoi]' 'executable = "/unused/chezmoi"' \
    '[provider.runner]' 'adapter = "custom"' 'executable = "/unused/runner"' \
    'capabilities = ["observe", "apply", "inspect"]' \
    '[action.runner.inspect]' 'mode = "observe"' 'description = "Inspect native state"' \
    'arguments = ["inspect"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 0 ] || false
}
