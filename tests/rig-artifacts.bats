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

write_reconciler_config() {
  local artifacts reconciler platforms provider kind locator

  artifacts=${1:-'["$HOME/Applications/Codex Multi Auth.app"]'}
  reconciler=${2:-codex-multi-auth-app-launcher}
  platforms=${3:-'["macos"]'}
  provider=${4:-npm}
  kind=${5:-global}
  locator=${6:-codex-multi-auth}
  NATIVE_BIN=$BATS_TEST_TMPDIR/native-bin
  LIFECYCLE_LOG=$BATS_TEST_TMPDIR/artifact-lifecycle.log
  mkdir -p "$NATIVE_BIN"

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "npm:%s\n" "$*" >>"$RIG_ARTIFACT_TEST_LOG"' \
    'case "$1" in' \
    '  list) printf "%s\n" "/fixture" "└── codex-multi-auth@1.0.0" ;;' \
    '  install) ;;' \
    '  *) exit 64 ;;' \
    'esac' >"$NATIVE_BIN/npm"
  chmod +x "$NATIVE_BIN/npm"

  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "launcher:%s\n" "$*" >>"$RIG_ARTIFACT_TEST_LOG"' \
    '[ "${RIG_ARTIFACT_TEST_EXIT:-0}" -eq 0 ] || exit "$RIG_ARTIFACT_TEST_EXIT"' \
    'app=$HOME/Applications/Codex\ Multi\ Auth.app' \
    'mkdir -p "$app/Contents/MacOS"' \
    'printf "%s\n" "<plist><dict><key>CFBundleExecutable</key><string>Codex</string></dict></plist>" >"$app/Contents/Info.plist"' \
    ': >"$app/Contents/MacOS/Codex"' \
    'chmod +x "$app/Contents/MacOS/Codex"' >"$NATIVE_BIN/codex-multi-auth-app-launcher"
  chmod +x "$NATIVE_BIN/codex-multi-auth-app-launcher"

  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' 'bootstrap-profile = "default"' \
    '[category.core]' 'name = "Core"' 'purpose = "Core tools"' \
    '[tool.subject]' 'name = "Subject"' 'category = "core"' \
    'purpose = "Test artifact reconciliation"' \
    'rationale = "Exercise the bounded native reconciler"' \
    "platforms = $platforms" >"$CONFIG_HOME/rig.toml"
  if [ "$artifacts" != none ]; then
    printf 'artifacts = %s\n' "$artifacts" >>"$CONFIG_HOME/rig.toml"
  fi
  printf '%s\n' \
    "artifact.reconciler = \"$reconciler\"" \
    "install.provider = \"$provider\"" \
    "install.kind = \"$kind\"" \
    "install.locator = \"$locator\"" \
    'install.platforms = ["macos"]' \
    '[profile.default]' 'tools = ["subject"]' >>"$CONFIG_HOME/rig.toml"
}

run_reconciler() {
  run env \
    HOME="$TEST_HOME" \
    PATH="$NATIVE_BIN:$PATH" \
    RIG_ARTIFACT_TEST_LOG="$LIFECYCLE_LOG" \
    RIG_ARTIFACT_TEST_EXIT="${RIG_ARTIFACT_TEST_EXIT:-0}" \
    RIG_CONFIG_HOME="$CONFIG_HOME" \
    RIG_PLATFORM=macos \
    "$RIG" "$@"
}

@test "artifact reconciler rejects an unknown built-in identity" {
  write_reconciler_config '["$HOME/Applications/Codex Multi Auth.app"]' arbitrary-command

  run_reconciler apply --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"artifact.reconciler"* || "$output" == *"artifact reconciler"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
}

@test "artifact reconciler requires a declared artifact" {
  write_reconciler_config none

  run_reconciler apply --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"artifact"*"requires"* || "$output" == *"requires"*"artifacts"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
}

@test "artifact reconciler rejects the wrong installation tuple" {
  write_reconciler_config '["$HOME/Applications/Codex Multi Auth.app"]' \
    codex-multi-auth-app-launcher '["macos"]' uv tool codex-multi-auth

  run_reconciler apply --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"artifact"*"reconciler"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
}

@test "artifact reconciler rejects an artifact path outside its native contract" {
  write_reconciler_config '["$HOME/Applications/Other.app"]'

  run_reconciler apply --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"artifact"*"reconciler"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
}

@test "artifact reconciler rejects a tool without macOS support" {
  write_reconciler_config '["$HOME/Applications/Codex Multi Auth.app"]' \
    codex-multi-auth-app-launcher '["linux"]'

  run_reconciler apply --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"artifact"*"reconciler"* || "$output" == *"macos"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
}

@test "artifact reconciler apply dry-run reports plan without invocation" {
  write_reconciler_config

  run_reconciler apply --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *$'subject\tnpm\tplanned\t'*"artifact-reconcile:codex-multi-auth-app-launcher"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
  [ ! -e "$TEST_HOME/Applications/Codex Multi Auth.app" ]
}

@test "artifact reconciler apply runs after installation and verifies its app" {
  local lifecycle
  write_reconciler_config

  run_reconciler apply

  [ "$status" -eq 0 ]
  lifecycle=$(<"$LIFECYCLE_LOG")
  [ "$lifecycle" = $'npm:install --global codex-multi-auth\nlauncher:' ]
  [[ "$output" == *$'subject\tnpm\tcompleted\t'*"artifact-reconciled:codex-multi-auth-app-launcher"* ]]
  [ -x "$TEST_HOME/Applications/Codex Multi Auth.app/Contents/MacOS/Codex" ]
}

@test "artifact reconciler failure fails the owning tool" {
  local lifecycle
  write_reconciler_config

  RIG_ARTIFACT_TEST_EXIT=37 run_reconciler apply

  [ "$status" -eq 1 ]
  lifecycle=$(<"$LIFECYCLE_LOG")
  [ "$lifecycle" = $'npm:install --global codex-multi-auth\nlauncher:' ]
  [[ "$output" == *$'subject\tnpm\tfailed\t'*"artifact"*"37"* ]]
}

@test "artifact reconciler is inherited by bootstrap" {
  local lifecycle
  write_reconciler_config

  run_reconciler bootstrap

  [ "$status" -eq 0 ]
  lifecycle=$(<"$LIFECYCLE_LOG")
  [ "$lifecycle" = $'npm:install --global codex-multi-auth\nlauncher:' ]
  [[ "$output" == *"artifact-reconciled:codex-multi-auth-app-launcher"* ]]
}

@test "artifact reconciler update dry-run reports plan without invocation" {
  write_reconciler_config

  run_reconciler update --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *$'subject\tnpm\tplanned\t'*"artifact-reconcile:codex-multi-auth-app-launcher"* ]]
  [ ! -e "$LIFECYCLE_LOG" ]
}

@test "artifact reconciler update runs after package update" {
  local lifecycle
  write_reconciler_config

  run_reconciler update

  [ "$status" -eq 0 ]
  lifecycle=$(<"$LIFECYCLE_LOG")
  [ "$lifecycle" = $'npm:install --global codex-multi-auth\nlauncher:' ]
  [[ "$output" == *"artifact-reconciled:codex-multi-auth-app-launcher"* ]]
}

@test "artifact reconciler update failure fails its lifecycle target" {
  write_reconciler_config

  RIG_ARTIFACT_TEST_EXIT=38 run_reconciler update

  [ "$status" -eq 1 ]
  [[ "$output" == *$'subject\tnpm\tfailed\t'*"artifact"*"38"* ]]
}

@test "explain keeps generated artifacts with their owning tool" {
  write_reconciler_config

  run_reconciler explain subject

  [ "$status" -eq 0 ]
  [[ "$output" == *'Artifacts: $HOME/Applications/Codex Multi Auth.app'* ]]
  [[ "$output" == *'Artifact reconciler: codex-multi-auth-app-launcher'* ]]
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
