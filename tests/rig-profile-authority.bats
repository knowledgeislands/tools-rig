#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config-$BATS_TEST_NUMBER
  TEST_HOME=$BATS_TEST_TMPDIR/home-$BATS_TEST_NUMBER
  STATE_HOME=$BATS_TEST_TMPDIR/state-$BATS_TEST_NUMBER
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME" "$STATE_HOME"
}

run_rig() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$STATE_HOME" \
    RIG_PLATFORM=macos "$RIG" "$@"
}

write_item_profile_fixture() {
  printf '%s\n' \
    '[rig]' \
    'schema = 1' \
    'default-profile = "workstation"' \
    '[category.core]' \
    'name = "Core"' \
    'purpose = "Core tools"' \
    '[tool.base]' \
    'name = "Base"' \
    'category = "core"' \
    'purpose = "Default tool"' \
    'rationale = "Every complete workstation uses it"' \
    'platforms = ["any"]' \
    '[tool.developer]' \
    'name = "Developer"' \
    'category = "core"' \
    'purpose = "Developer tool"' \
    'rationale = "Only developer profiles use it"' \
    'platforms = ["any"]' \
    'profiles = ["developer"]' \
    '[tool.public]' \
    'name = "Public"' \
    'category = "core"' \
    'purpose = "Public tool"' \
    'rationale = "Safe to publish"' \
    'platforms = ["any"]' \
    'profiles = ["public"]' \
    '[tool.nowhere]' \
    'name = "Nowhere"' \
    'category = "core"' \
    'purpose = "Unselected tool"' \
    'rationale = "Explicit emptiness means no membership"' \
    'platforms = ["any"]' \
    'profiles = []' \
    '[profile.workstation]' \
    'name = "Workstation"' \
    'purpose = "Complete workstation intent"' \
    'kind = "complete"' \
    '[profile.developer]' \
    'name = "Developer"' \
    'purpose = "Development workstation intent"' \
    'kind = "complete"' \
    'inherits = ["workstation"]' \
    '[profile.public]' \
    'name = "Public"' \
    'purpose = "Public projection"' \
    'kind = "view"' >"$CONFIG_HOME/rig.toml"
}

@test "item profiles use configured default explicit inheritance and empty exclusion" {
  write_item_profile_fixture

  run_rig show
  [ "$status" -eq 0 ]
  [[ "$output" == *'base'* ]] || false
  [[ "$output" != *'developer'* ]] || false
  [[ "$output" != *'public'* ]] || false
  [[ "$output" != *'nowhere'* ]] || false

  run_rig show --profile developer
  [ "$status" -eq 0 ]
  [[ "$output" == *'base'* ]] || false
  [[ "$output" == *'developer'* ]] || false
  [[ "$output" != *'public'* ]] || false
  [[ "$output" != *'nowhere'* ]] || false

  run_rig show --profile public
  [ "$status" -eq 0 ]
  [[ "$output" == *'public'* ]] || false
  [[ "$output" != *'base'* ]] || false
  [[ "$output" != *'nowhere'* ]] || false
}

@test "central and item membership cannot be mixed" {
  write_item_profile_fixture
  printf '%s\n' 'tools = ["base"]' >>"$CONFIG_HOME/rig.toml"

  run_rig show
  [ "$status" -eq 2 ]
  [[ "$output" == *'cannot mix central profile members with item profiles'* ]] || false
}

@test "views reject mutation and require explicitly opted-in dependency closure" {
  write_item_profile_fixture
  sed '/^\[tool.public\]$/,/^\[tool.nowhere\]$/s/^platforms = \["any"\]$/platforms = ["any"]\
requires = ["base"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/with-dependency.toml"
  mv "$CONFIG_HOME/with-dependency.toml" "$CONFIG_HOME/rig.toml"

  run_rig show --profile public
  [ "$status" -eq 2 ]
  [[ "$output" == *"view profile 'public' dependency 'base' is not explicitly opted in"* ]] || false

  sed '/^\[tool.base\]$/,/^\[tool.developer\]$/s/^platforms = \["any"\]$/platforms = ["any"]\nprofiles = ["public"]/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/explicit.toml"
  mv "$CONFIG_HOME/explicit.toml" "$CONFIG_HOME/rig.toml"
  printf '%s\n' \
    '[service.daemon]' 'name = "Daemon"' 'purpose = "View action fixture"' \
    'rationale = "Mutating actions require complete intent"' 'provider = "launchd"' \
    'locator = "example.daemon"' 'platforms = ["macos"]' 'desired-state = "running"' \
    'program = ["/usr/bin/true"]' 'profiles = ["public"]' >>"$CONFIG_HOME/rig.toml"

  run_rig apply --profile public --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile 'public' is a non-appliable view"* ]] || false

  run_rig bootstrap --profile public --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile 'public' is a non-appliable view"* ]] || false

  run_rig update --profile public --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile 'public' is a non-appliable view"* ]] || false

  run_rig maintain --profile public --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile 'public' is a non-appliable view"* ]] || false

  sed 's/default-profile = "workstation"/default-profile = "public"/' \
    "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/public-default.toml"
  mv "$CONFIG_HOME/public-default.toml" "$CONFIG_HOME/rig.toml"
  run_rig run launchd restart -- service:daemon
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile 'public' is a non-appliable view"* ]] || false
}

@test "views cannot inherit complete profiles and bootstrap profiles must be appliable" {
  write_item_profile_fixture
  sed '/^kind = "view"$/a\
inherits = ["workstation"]' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/invalid.toml"
  mv "$CONFIG_HOME/invalid.toml" "$CONFIG_HOME/rig.toml"

  run_rig show --profile public
  [ "$status" -eq 2 ]
  [[ "$output" == *"view cannot inherit appliable profile 'workstation'"* ]] || false

  write_item_profile_fixture
  sed '/^default-profile = "workstation"$/a\
bootstrap-profile = "public"' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/invalid.toml"
  mv "$CONFIG_HOME/invalid.toml" "$CONFIG_HOME/rig.toml"

  run_rig show
  [ "$status" -eq 2 ]
  [[ "$output" == *'bootstrap-profile must be appliable'* ]] || false
}

@test "publications require a non-appliable view" {
  write_item_profile_fixture
  printf '%s\n' \
    '[provider.publisher]' 'adapter = "custom"' 'capabilities = ["publish"]' \
    '[publication.site]' 'profile = "workstation"' 'title = "Site"' \
    'base-url = "https://example.test/"' 'publisher = "publisher"' >>"$CONFIG_HOME/rig.toml"

  run_rig show
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile 'workstation' must be a non-appliable view"* ]] || false
}

@test "native target conflicts are checked only in the resolved selection" {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "alpha"' \
    '[service.alpha]' 'name = "Alpha"' 'purpose = "Alpha service"' 'rationale = "Alternative A"' \
    'provider = "launchd"' 'locator = "example.shared"' 'platforms = ["macos"]' \
    'desired-state = "running"' 'program = ["/usr/bin/true"]' 'profiles = ["alpha"]' \
    '[scheduled-job.beta]' 'name = "Beta"' 'purpose = "Beta job"' 'rationale = "Alternative B"' \
    'provider = "launchd"' 'locator = "example.shared"' 'platforms = ["macos"]' \
    'desired-state = "enabled"' 'program = ["/usr/bin/true"]' 'schedule.interval = "60"' \
    'profiles = ["beta"]' \
    '[profile.alpha]' 'kind = "complete"' \
    '[profile.beta]' 'kind = "complete"' \
    '[profile.combined]' 'kind = "complete"' 'inherits = ["alpha", "beta"]' \
    >"$CONFIG_HOME/rig.toml"

  run_rig show --profile alpha
  [ "$status" -eq 0 ]
  run_rig show --profile beta
  [ "$status" -eq 0 ]
  run_rig show --profile combined
  [ "$status" -eq 2 ]
  [[ "$output" == *"conflicts with"*"native target 'launchd:locator:example.shared'"* ]] || false
}

@test "resolved settings and Dock layouts reject contradictory native targets" {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "alpha"' \
    '[setting.alpha]' 'name = "Alpha"' 'purpose = "Alpha setting"' 'rationale = "Alternative A"' \
    'provider = "macos-defaults"' 'domain = "example.shared"' 'key = "Shared"' \
    'value-type = "string"' 'value = "alpha"' 'platforms = ["macos"]' 'profiles = ["alpha"]' \
    '[setting.beta]' 'name = "Beta"' 'purpose = "Beta setting"' 'rationale = "Alternative B"' \
    'provider = "macos-defaults"' 'domain = "example.shared"' 'key = "Shared"' \
    'value-type = "string"' 'value = "beta"' 'platforms = ["macos"]' 'profiles = ["beta"]' \
    '[profile.alpha]' 'kind = "complete"' \
    '[profile.beta]' 'kind = "complete"' \
    '[profile.combined]' 'kind = "complete"' 'inherits = ["alpha", "beta"]' \
    >"$CONFIG_HOME/rig.toml"

  run_rig show --profile alpha
  [ "$status" -eq 0 ]
  run_rig show --profile combined
  [ "$status" -eq 2 ]
  [[ "$output" == *"native target 'macos-defaults:setting:example.shared:Shared'"* ]] || false

  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "alpha"' \
    '[dock.alpha]' 'name = "Alpha"' 'purpose = "Alpha Dock"' 'rationale = "Alternative A"' \
    'provider = "macos-dock"' 'platforms = ["macos"]' 'items = ["alpha"]' 'profiles = ["alpha"]' \
    '[dock.beta]' 'name = "Beta"' 'purpose = "Beta Dock"' 'rationale = "Alternative B"' \
    'provider = "macos-dock"' 'platforms = ["macos"]' 'items = ["beta"]' 'profiles = ["beta"]' \
    '[dock-item.alpha]' 'kind = "application"' 'path = "/Applications/Alpha.app"' \
    '[dock-item.beta]' 'kind = "application"' 'path = "/Applications/Beta.app"' \
    '[profile.alpha]' 'kind = "complete"' \
    '[profile.beta]' 'kind = "complete"' \
    '[profile.combined]' 'kind = "complete"' 'inherits = ["alpha", "beta"]' \
    >"$CONFIG_HOME/rig.toml"

  run_rig show --profile beta
  [ "$status" -eq 0 ]
  run_rig show --profile combined
  [ "$status" -eq 2 ]
  [[ "$output" == *"native target 'macos-dock:dock'"* ]] || false
}

write_lock_fixture() {
  PROVIDER=$BATS_TEST_TMPDIR/provider-$BATS_TEST_NUMBER
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$PROVIDER"
  chmod +x "$PROVIDER"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[provider.runner]' 'adapter = "custom"' "executable = \"$PROVIDER\"" \
    'capabilities = ["resource-observe", "resource-apply", "resource-retire"]' \
    '[service.daemon]' 'name = "Daemon"' 'purpose = "Lock fixture"' 'rationale = "Exercise serialization"' \
    'provider = "runner"' 'locator = "example.daemon"' 'platforms = ["macos"]' \
    'desired-state = "running"' 'program = ["/usr/bin/true"]' \
    '[profile.default]' 'kind = "complete"' >"$CONFIG_HOME/rig.toml"
}

@test "receipt reconciliation reports active and stale lock owners without removing them" {
  write_lock_fixture
  mkdir -p "$STATE_HOME/reconciliation/macos.lock"
  printf 'pid=%s profile=default command=apply\n' "$$" >"$STATE_HOME/reconciliation/macos.lock/owner"

  run_rig apply --scope resources
  [ "$status" -eq 2 ]
  [[ "$output" == *"reconciliation target 'macos' is active; owner=pid=$$ profile=default command=apply"* ]] || false
  [ -d "$STATE_HOME/reconciliation/macos.lock" ]

  printf '%s\n' 'pid=999999 profile=default command=apply' >"$STATE_HOME/reconciliation/macos.lock/owner"
  run_rig apply --scope resources
  [ "$status" -eq 2 ]
  [[ "$output" == *"reconciliation target 'macos' is stale; owner=pid=999999"* ]] || false
  [ -d "$STATE_HOME/reconciliation/macos.lock" ]
}

@test "successful resource apply holds and releases its target lock and discloses scope" {
  write_lock_fixture

  run_rig apply --scope resources
  [ "$status" -eq 0 ]
  [[ "$output" == *'Operation scope: declaration'* ]] || false
  [[ "$output" == *$'daemon\tservice\trunner\tcompleted\treconciled:example.daemon\tdeclaration'* ]] || false
  [ ! -e "$STATE_HOME/reconciliation/macos.lock" ]
  [ -f "$STATE_HOME/resources/macos.tsv" ]
}
