#!/usr/bin/env bats

load 'helpers/isolate.bash'

setup() {
  rig_test_isolate
  export RIG_TEST_PYTHON=${RIG_TEST_PYTHON:-/usr/bin/python3}
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  MACOS_LOG=$BATS_TEST_TMPDIR/native.log
  DOCK_STATE=$BATS_TEST_TMPDIR/dock.state
  DOCK_SNAPSHOT=$BATS_TEST_TMPDIR/dock.plist
  PLUTIL_FAKE=$BATS_TEST_TMPDIR/dock-plutil
  DEFAULTS_FAKE=$BATS_TEST_TMPDIR/defaults
  DOCKUTIL_FAKE=$BATS_TEST_TMPDIR/dockutil
  KILLALL_FAKE=$BATS_TEST_TMPDIR/killall
  mkdir -p "$CONFIG_HOME" "$TEST_HOME/Applications" "$TEST_HOME/Downloads"
  for app in System Shared Laptop Studio; do mkdir -p "$TEST_HOME/Applications/$app.app"; done
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "defaults" >>"$MACOS_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$MACOS_LOG"; done; printf "\n" >>"$MACOS_LOG"' \
    'case "$1" in export) cat "$DOCK_SNAPSHOT" ;; esac' >"$DEFAULTS_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "dockutil" >>"$MACOS_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$MACOS_LOG"; done; printf "\n" >>"$MACOS_LOG"' \
    '[ "$1" != --list ] || { [ ! -f "$DOCK_STATE" ] || cat "$DOCK_STATE"; }' >"$DOCKUTIL_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "killall <%s>\n" "$1" >>"$MACOS_LOG"' >"$KILLALL_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' 'exec "$RIG_TEST_PYTHON" "$DOCK_PLUTIL_HELPER" "$@"' >"$PLUTIL_FAKE"
  chmod +x "$DEFAULTS_FAKE" "$DOCKUTIL_FAKE" "$KILLALL_FAKE" "$PLUTIL_FAKE"
  printf '{"persistent-others":[]}' |
    "$RIG_TEST_PYTHON" "$BATS_TEST_DIRNAME/helpers/dock-plutil.py" --fixture >"$DOCK_SNAPSHOT"
  write_central_fixture
}

run_rig() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM="${PLATFORM:-macos}" \
    RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RIG_DEFAULTS="$DEFAULTS_FAKE" RIG_DOCKUTIL="$DOCKUTIL_FAKE" RIG_KILLALL="$KILLALL_FAKE" \
    RIG_PLUTIL="$PLUTIL_FAKE" DOCK_PLUTIL_HELPER="$BATS_TEST_DIRNAME/helpers/dock-plutil.py" DOCK_SNAPSHOT="$DOCK_SNAPSHOT" \
    MACOS_LOG="$MACOS_LOG" DOCK_STATE="$DOCK_STATE" "$RIG" "$@"
}

write_tool() {
  printf '%s\n' "[tool.$1]" "name = \"$1\"" 'category = "apps"' "purpose = \"Run $1\"" \
    'rationale = "Dock fixture"' "platforms = [\"${2:-any}\"]"
  [ -z "${3:-}" ] || printf '%s\n' "$3"
}

write_dock() {
  printf '%s\n' \
    '[dock.main]' 'name = "Main Dock"' 'purpose = "One shared order"' \
    'rationale = "Machines differ only by membership"' 'provider = "macos-dock"' \
    'platforms = ["macos"]' 'items = ["system", "shared", "laptop-only", "studio-only", "downloads"]'
  [ -z "${1:-}" ] || printf '%s\n' "$1"
  printf '%s\n' \
    '[dock-item.system]' 'kind = "application"' 'path = "~/Applications/System.app"' \
    '[dock-item.shared]' 'kind = "application"' 'path = "~/Applications/Shared.app"' 'tool = "shared"' \
    '[dock-item.laptop-only]' 'kind = "application"' 'path = "~/Applications/Laptop.app"' 'tool = "laptop-only"' \
    '[dock-item.studio-only]' 'kind = "application"' 'path = "~/Applications/Studio.app"' 'tool = "studio-only"' \
    '[dock-item.downloads]' 'kind = "folder"' 'path = "~/Downloads"' 'view = "grid"'
}

# Tool IDs sort studio-only before shared and laptop-only, so catalogue order cannot leak into the Dock.
write_central_fixture() {
  {
    printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "laptop"' \
      '[category.apps]' 'name = "Apps"' 'purpose = "Applications"'
    write_tool shared
    write_tool laptop-only
    write_tool studio-only
    printf '%s\n' \
      '[profile.core]' 'name = "Core"' 'purpose = "Shared intent"' 'kind = "complete"' \
      'tools = ["shared"]' 'docks = ["main"]' \
      '[profile.laptop]' 'name = "Laptop"' 'purpose = "Laptop intent"' 'kind = "complete"' \
      'inherits = ["core"]' 'tools = ["laptop-only"]' \
      '[profile.studio]' 'name = "Studio"' 'purpose = "Studio intent"' 'kind = "complete"' \
      'inherits = ["core"]' 'tools = ["studio-only"]'
    write_dock
  } >"$CONFIG_HOME/rig.toml"
}

write_item_fixture() {
  {
    printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "laptop"' \
      '[category.apps]' 'name = "Apps"' 'purpose = "Applications"'
    write_tool shared any 'profiles = ["core"]'
    write_tool laptop-only any 'profiles = ["laptop"]'
    write_tool studio-only any 'profiles = ["studio"]'
    printf '%s\n' \
      '[profile.core]' 'name = "Core"' 'purpose = "Shared intent"' 'kind = "complete"' \
      '[profile.laptop]' 'name = "Laptop"' 'purpose = "Laptop intent"' 'kind = "complete"' \
      'inherits = ["core"]' \
      '[profile.studio]' 'name = "Studio"' 'purpose = "Studio intent"' 'kind = "complete"' \
      'inherits = ["core"]'
    write_dock 'profiles = ["core"]'
  } >"$CONFIG_HOME/rig.toml"
}

replace_config() {
  sed "$1" "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edited.toml"
  mv "$CONFIG_HOME/edited.toml" "$CONFIG_HOME/rig.toml"
}

assert_filtered() {
  local profile included excluded

  profile=$1
  included=$2
  excluded=$3
  run_rig show dock:main --profile "$profile"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *"dock-profile=$profile"$'\n'"dock-platform=macos"$'\n'"dock-selected=yes"* ]] || false
  [[ "$output" == *$'dock-item.1.id=system\n'*$'dock-item.1.position=1\n'* ]] || false
  [[ "$output" == *$'dock-item.2.tool=shared\ndock-item.2.position=2\n'* ]] || false
  [[ "$output" == *"dock-item.$included.position=3"* ]] || false
  [[ "$output" == *"dock-item.$excluded.excluded=profile"* ]] || false
  [[ "$output" == *$'dock-item.5.view=grid\ndock-item.5.position=4'* ]] || false
}

assert_read_only() {
  [ ! -e "$MACOS_LOG" ] || ! grep -Eq 'defaults (<write>|<delete>)|dockutil (<--add>|<--remove>)|killall' "$MACOS_LOG" || false
}

@test "Dock items follow central profile membership in declared order" {
  assert_filtered laptop 3 4
  assert_filtered studio 4 3
  run_rig show --profile studio
  [ "$status" -eq 0 ]
  [[ "$output" == *'4 of 5'* ]] || false
  run_rig show --profile studio --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"items":["system","shared","studio-only","downloads"],"excluded_items":[{"id":"laptop-only","reason":"profile"}]'* ]] || false
  assert_read_only
}

@test "Dock items follow item-owned tool membership in declared order" {
  write_item_fixture
  assert_filtered laptop 3 4
  assert_filtered studio 4 3
}

@test "transitively selected tools include their Dock items" {
  replace_config 's/^tools = \["laptop-only"\]$/tools = ["shared"]/'
  replace_config '/^\[tool.shared\]$/,/^\[tool.laptop-only\]$/s/^platforms = \["any"\]$/platforms = ["any"]\
requires = ["laptop-only"]/'
  run_rig show dock:main --profile laptop
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'dock-item.3.position=3'* ]] || false
  [[ "$output" == *'dock-item.4.excluded=profile'* ]] || false
}

@test "unlinked Dock items keep the complete declared list" {
  replace_config '/^tool = /d'
  run_rig show dock:main --profile studio
  [ "$status" -eq 0 ]
  [[ "$output" == *'dock-item.5.position=5'* ]] || false
  [[ "$output" != *'.excluded='* ]] || false
  [[ "$output" != *'.tool='* ]] || false
}

@test "Dock show uses the default profile and explains an unselected layout" {
  run_rig show dock:main
  [ "$status" -eq 0 ]
  [[ "$output" == *$'dock-profile=laptop\n'* ]] || false
  [[ "$output" == *'dock-item.4.excluded=profile'* ]] || false

  run_rig show dock:main --profile core --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'dock-selected=yes'* ]] || false
  [[ "$output" == *'dock-item.3.excluded=profile'* ]] || false
  [[ "$output" == *'dock-item.4.excluded=profile'* ]] || false

  replace_config 's/^docks = \["main"\]$/docks = []/'
  run_rig show dock:main --profile studio
  [ "$status" -eq 0 ]
  [[ "$output" == *'dock-selected=no'* ]] || false
  assert_read_only

  run_rig show tool:shared --profile studio
  [ "$status" -eq 2 ]
}

@test "a tool unsupported on the platform is excluded with a platform reason" {
  replace_config '/^\[tool.studio-only\]$/,/^\[profile.core\]$/s/^platforms = \["any"\]$/platforms = ["linux"]/'
  replace_config 's/^tools = \["studio-only"\]$/tools = []/'
  run_rig show dock:main --profile studio
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'dock-item.4.excluded=platform'* ]] || false
  [[ "$output" == *'dock-item.3.excluded=profile'* ]] || false
}

@test "Dock item tool links are validated before any native invocation" {
  local link
  for link in 'tool = "ghost"' 'tool = ""' 'tool = "Bad Id"' 'tool = ["shared"]'; do
    write_central_fixture
    replace_config "s/^tool = \"studio-only\"\$/$link/"
    run_rig status
    [ "$status" -eq 2 ] || { printf '%s: %s\n' "$link" "$output" >&3; false; }
    [ ! -e "$MACOS_LOG" ] || false
  done
  write_central_fixture
  replace_config 's/^tool = "studio-only"$/profiles = ["studio"]/'
  run_rig status
  [ "$status" -eq 2 ] || false
  [ ! -e "$MACOS_LOG" ] || false
}

@test "dry-run and apply add only included items in declared order" {
  run_rig apply --scope resources --dry-run --format json
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'item=system'*'item=shared'*'item=laptop-only'*'excluded-item=studio-only (profile)'*'item=downloads'* ]] || false
  assert_read_only

  run_rig apply --scope resources
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [ "$(grep -F 'dockutil <--add>' "$MACOS_LOG")" = "$(printf '%s\n' \
    "dockutil <--add> <$TEST_HOME/Applications/System.app> <--no-restart>" \
    "dockutil <--add> <$TEST_HOME/Applications/Shared.app> <--no-restart>" \
    "dockutil <--add> <$TEST_HOME/Applications/Laptop.app> <--no-restart>" \
    "dockutil <--add> <$TEST_HOME/Downloads> <--view> <grid> <--no-restart>")" ] || {
    cat "$MACOS_LOG" >&3; false; }
  ! grep -F 'Studio.app' "$MACOS_LOG" || false
  grep -F 'killall <Dock>' "$MACOS_LOG"
}

@test "a missing excluded app succeeds and a missing included app fails before mutation" {
  rm -rf "$TEST_HOME/Applications/Studio.app"
  run_rig apply --scope resources
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }

  : >"$MACOS_LOG"
  run_rig apply --scope resources --profile studio --dry-run --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"preflight:dock-item-path-missing:$TEST_HOME/Applications/Studio.app"* ]] || false

  run_rig apply --scope resources --profile studio
  [ "$status" -eq 1 ] || false
  ! grep -Eq 'dockutil (<--add>|<--remove>)|killall' "$MACOS_LOG" || false
}

@test "status reports a filtered Dock present and a missing included app drifted" {
  printf 'System\t%s\tapplications\nShared\t%s\tapplications\nLaptop\t%s\tapplications\nDownloads\t%s\tothers\n' \
    "$TEST_HOME/Applications/System.app" "$TEST_HOME/Applications/Shared.app" \
    "$TEST_HOME/Applications/Laptop.app" "$TEST_HOME/Downloads" >"$DOCK_STATE"
  printf '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"%s/Downloads","_CFURLStringType":0},"showas":2,"displayas":0}}]}' "$TEST_HOME" |
    "$RIG_TEST_PYTHON" "$BATS_TEST_DIRNAME/helpers/dock-plutil.py" --fixture >"$DOCK_SNAPSHOT"
  run_rig status --format json
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'"state":"present"'* ]] || false

  rm -rf "$TEST_HOME/Applications/Laptop.app"
  run_rig status --format json
  [[ "$output" == *'"state":"drifted"'* ]] || false
  [[ "$output" == *'dock-item-path-missing:laptop-only'* ]] || false
  run_rig doctor
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'dock-item-path-missing:laptop-only'* ]] || { printf '%s\n' "$output" >&3; false; }
  assert_read_only
}

@test "status and doctor report a missing unlinked app drifted" {
  printf 'System\t%s\tapplications\nShared\t%s\tapplications\nLaptop\t%s\tapplications\nDownloads\t%s\tothers\n' \
    "$TEST_HOME/Applications/System.app" "$TEST_HOME/Applications/Shared.app" \
    "$TEST_HOME/Applications/Laptop.app" "$TEST_HOME/Downloads" >"$DOCK_STATE"
  printf '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"%s/Downloads","_CFURLStringType":0},"showas":2,"displayas":0}}]}' "$TEST_HOME" |
    "$RIG_TEST_PYTHON" "$BATS_TEST_DIRNAME/helpers/dock-plutil.py" --fixture >"$DOCK_SNAPSHOT"
  rm -rf "$TEST_HOME/Applications/System.app"

  run_rig status --format json
  [[ "$output" == *'"state":"drifted"'* ]] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'dock-item-path-missing:system'* ]] || false
  run_rig doctor
  [ "$status" -ne 0 ] || false
  [[ "$output" == *'dock-item-path-missing:system'* ]] || { printf '%s\n' "$output" >&3; false; }
  assert_read_only
}

@test "an all-excluded layout applies an empty Dock" {
  replace_config 's/^items = .*/items = ["laptop-only"]/'
  run_rig apply --scope resources --profile studio
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  grep -F 'dockutil <--remove> <all>' "$MACOS_LOG"
  ! grep -F 'dockutil <--add>' "$MACOS_LOG" || false
}
