#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  APP_PATH=$RIG_APPLICATION_ROOTS/Example.app
  PROVIDER=$BATS_TEST_TMPDIR/surveyor
  mkdir -p "$CONFIG_HOME" "$APP_PATH/Contents"
  : >"$APP_PATH/Contents/Info.plist"
  APP_REAL=$(cd "${APP_PATH%/*}" && pwd -P)/${APP_PATH##*/}
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'name = "Default"' >"$CONFIG_HOME/rig.toml"
}

add_inventory_provider() {
  # The provider may overlap the built-in app scan or report another identity.
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$*" >>"$RIG_TEST_PROVIDER_LOG"' \
    'printf "%s\n" "$RIG_TEST_INVENTORY_OUTPUT"' >"$PROVIDER"
  chmod +x "$PROVIDER"
  printf '%s\n' '[provider.surveyor]' 'adapter = "custom"' \
    "executable = \"$PROVIDER\"" 'capabilities = ["inventory"]' \
    >>"$CONFIG_HOME/rig.toml"
}

@test "macOS application baseline runs with no declared providers" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos "$RIG" status --unmanaged --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"\"id\":\"$APP_REAL\",\"provider\":\"macos-applications\""* ]] || false
}

@test "an unrelated inventory provider does not suppress the application baseline" {
  add_inventory_provider
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_INVENTORY_OUTPUT=other-identity "$RIG" status --unmanaged --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"id":"other-identity","provider":"surveyor"'* ]] || false
  [[ "$output" == *"\"id\":\"$APP_REAL\",\"provider\":\"macos-applications\""* ]] || false
}

@test "two inventories of the same application path produce one row" {
  add_inventory_provider
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_TEST_INVENTORY_OUTPUT="$APP_REAL" "$RIG" status --unmanaged --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"\"id\":\"$APP_REAL\",\"provider\":\"surveyor\""* ]] || false
  [[ "$output" != *"$APP_REAL"*"$APP_REAL"* ]] || false
}

@test "unavailable application scan is reported rather than treated as empty" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_PLUTIL="$BATS_TEST_TMPDIR/absent-plutil" "$RIG" status --unmanaged
  [[ "$output" == *'macos-applications'*'unavailable'*'executable-unavailable'* ]] || false
  [[ "$output" != *"$APP_PATH"* ]] || false
}

@test "failed application scan is reported rather than treated as empty" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_APPLICATION_ROOTS=":$RIG_APPLICATION_ROOTS" "$RIG" status --unmanaged
  [[ "$output" == *'macos-applications'*'unknown'*'exit:1'* ]] || false
  [[ "$output" != *"$APP_REAL"* ]] || false
}

@test "application baseline does not run on Linux" {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=linux "$RIG" status --unmanaged --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"unmanaged":[]'* ]] || false
  [[ "$output" != *'macos-applications'* ]] || false
}
