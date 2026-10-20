#!/usr/bin/env bats

load 'helpers/isolate.bash'

setup() {
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  DOMAINS=$BATS_TEST_TMPDIR/domains
  NATIVE_LOG=$BATS_TEST_TMPDIR/native.log
  DEFAULTS_FAKE=$BATS_TEST_TMPDIR/defaults-fixture
  mkdir -p "$CONFIG_HOME" "$DOMAINS"
  : >"$NATIVE_LOG"
  # Each domain file holds what `defaults read DOMAIN` prints; an absent file
  # is a domain defaults cannot read. Anything other than a read is refused.
  # shellcheck disable=SC2016
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "defaults %s\n" "$*" >>"$NATIVE_LOG"' \
    '[ "$#" -eq 2 ] && [ "$1" = read ] || exit 99' \
    '[ -f "$DOMAINS/$2" ] || exit 1' \
    'cat "$DOMAINS/$2"' >"$DEFAULTS_FAKE"
  chmod +x "$DEFAULTS_FAKE"
  export RIG_DEFAULTS="$DEFAULTS_FAKE" DOMAINS NATIVE_LOG
  export RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  write_config
  domain com.apple.controlcenter \
    '"NSStatusItem Preferred Position Sound" = 325;' \
    '"NSStatusItem VisibleCC Sound" = 1;' \
    '"NSStatusItem Preferred Position WiFi" = 460;' \
    '"NSStatusItem VisibleCC WiFi" = 0;'
  domain com.getdropbox.dropbox \
    '"NSStatusItem Preferred Position Item-0" = "736.5";' \
    'SUEnableAutomaticChecks = 1;'
}

write_tool() {
  printf '%s\n' "[tool.$1]" "name = \"$1\"" 'category = "apps"' "purpose = \"Run $1\"" \
    'rationale = "Menu bar fixture"' "platforms = [\"${2:-any}\"]"
}

# Declared left to right: Dropbox, then Sound, with Wi-Fi hidden.
write_config() {
  {
    printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "laptop"' \
      '[category.apps]' 'name = "Apps"' 'purpose = "Applications"'
    write_tool dropbox
    write_tool studio-only
    write_tool linux-only linux
    printf '%s\n' \
      '[profile.laptop]' 'name = "Laptop"' 'purpose = "Laptop intent"' 'kind = "complete"' \
      'tools = ["dropbox"]' 'menu-bars = ["main"]' \
      '[profile.studio]' 'name = "Studio"' 'purpose = "Studio intent"' 'kind = "complete"' \
      'tools = ["dropbox", "studio-only"]' 'menu-bars = ["main"]' \
      '[menu-bar.main]' 'name = "Main menu bar"' 'purpose = "One shared order"' \
      'rationale = "Machines differ only by membership"' 'provider = "macos-menu-bar"' \
      'platforms = ["macos"]' \
      "items = [${ITEMS-\"dropbox\", \"studio-only\", \"linux-only\", \"sound\", \"wifi\"}]" \
      '[menu-bar-item.dropbox]' 'domain = "com.getdropbox.dropbox"' 'autosave = "Item-0"' 'tool = "dropbox"' \
      '[menu-bar-item.studio-only]' 'domain = "com.example.studio"' 'autosave = "Item-0"' 'tool = "studio-only"' \
      '[menu-bar-item.linux-only]' 'domain = "com.example.linux"' 'autosave = "Item-0"' 'tool = "linux-only"' \
      '[menu-bar-item.sound]' 'domain = "com.apple.controlcenter"' 'autosave = "Sound"' \
      '[menu-bar-item.wifi]' 'domain = "com.apple.controlcenter"' 'autosave = "WiFi"' 'visible = false'
    [ -z "${EXTRA:-}" ] || printf '%s\n' "$EXTRA"
  } >"$CONFIG_HOME/rig.toml"
}

domain() {
  local name

  name=$1
  shift
  { printf '{\n'; printf '    %s\n' "$@"; printf '}\n'; } >"$DOMAINS/$name"
}

observe() {
  run "$RIG" status --format json "$@"
}

assert_observation() {
  [[ "$output" == *"\"kind\":\"menu-bar\""*"\"state\":\"$1\""* ]] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *"\"detail\":\"$2\""* ]] || { printf '%s\n' "$output" >&3; false; }
}

assert_read_only() {
  ! grep -Ev '^defaults read [A-Za-z0-9._-]+$' "$NATIVE_LOG" || false
  [ ! -s "$BATS_TEST_TMPDIR/isolated-killall.log" ] || false
  [ ! -s "$BATS_TEST_TMPDIR/isolated-defaults.log" ] || false
}

@test "menu bar in declared order with hidden items hidden is present and reads each domain once" {
  observe
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  assert_observation present -
  [ "$(grep -c 'read com.apple.controlcenter' "$NATIVE_LOG")" -eq 1 ] || false
  [ "$(grep -c 'read com.getdropbox.dropbox' "$NATIVE_LOG")" -eq 1 ] || false
  ! grep -q 'com.example' "$NATIVE_LOG" || false
  assert_read_only
}

@test "menu bar order drift names the first declared pair out of order" {
  domain com.getdropbox.dropbox '"NSStatusItem Preferred Position Item-0" = 300;'
  observe
  [ "$status" -ne 0 ] || false
  assert_observation drifted order:dropbox-before-sound
  domain com.getdropbox.dropbox '"NSStatusItem Preferred Position Item-0" = 325;'
  observe
  assert_observation drifted order:dropbox-before-sound
  domain com.getdropbox.dropbox '"NSStatusItem Preferred Position Item-0" = 325.25;'
  observe
  [ "$status" -eq 0 ] || false
  assert_observation present -
  assert_read_only
}

@test "a hidden item takes no part in the order" {
  domain com.apple.controlcenter \
    '"NSStatusItem Preferred Position Sound" = 325;' \
    '"NSStatusItem Preferred Position WiFi" = 9999;' \
    '"NSStatusItem VisibleCC WiFi" = 0;'
  observe
  [ "$status" -eq 0 ] || false
  assert_observation present -
  assert_read_only
}

@test "menu bar visibility drift is item qualified in both directions" {
  domain com.apple.controlcenter \
    '"NSStatusItem Preferred Position Sound" = 325;' \
    '"NSStatusItem VisibleCC Sound" = 0;' \
    '"NSStatusItem VisibleCC WiFi" = 0;'
  observe
  assert_observation drifted visibility:sound
  domain com.apple.controlcenter \
    '"NSStatusItem Preferred Position Sound" = 325;' \
    '"NSStatusItem Preferred Position WiFi" = 460;'
  observe
  assert_observation drifted visibility:wifi
  assert_read_only
}

@test "an unplaced item is missing and outranks visibility and order drift" {
  domain com.getdropbox.dropbox 'SUEnableAutomaticChecks = 1;'
  domain com.apple.controlcenter \
    '"NSStatusItem Preferred Position Sound" = 325;' \
    '"NSStatusItem Preferred Position WiFi" = 460;'
  observe
  [ "$status" -ne 0 ] || false
  assert_observation missing menu-bar-item-unplaced:dropbox
  assert_read_only
}

@test "an unreadable domain is unknown evidence" {
  rm "$DOMAINS/com.getdropbox.dropbox"
  observe
  assert_observation unknown domain-unreadable:com.getdropbox.dropbox
  export RIG_DEFAULTS=$BATS_TEST_TMPDIR/isolated-defaults
  observe
  assert_observation unknown domain-unreadable:com.getdropbox.dropbox
  [ -s "$BATS_TEST_TMPDIR/isolated-defaults.log" ] || false
  ! grep -qv '^read ' "$BATS_TEST_TMPDIR/isolated-defaults.log" || false
}

@test "profile and platform exclusion keeps unselected items out of observation" {
  domain com.example.studio 'SUEnableAutomaticChecks = 1;'
  observe --profile studio
  assert_observation missing menu-bar-item-unplaced:studio-only
  grep -q 'read com.example.studio' "$NATIVE_LOG" || false
  ! grep -q 'com.example.linux' "$NATIVE_LOG" || false
  run "$RIG" show menu-bar:main
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *$'apply=observe-only\n'* ]] || false
  [[ "$output" == *$'menu-bar-profile=laptop\nmenu-bar-platform=macos\nmenu-bar-selected=yes\n'* ]] || false
  [[ "$output" == *$'menu-bar-item.1.tool=dropbox\nmenu-bar-item.1.position=1\n'* ]] || false
  [[ "$output" == *'menu-bar-item.2.excluded=profile'* ]] || false
  [[ "$output" == *'menu-bar-item.3.excluded=platform'* ]] || false
  [[ "$output" == *$'menu-bar-item.5.visible=false\nmenu-bar-item.5.position=3'* ]] || false
  run "$RIG" show --format json
  [[ "$output" == *'"kind":"menu-bar","name":"Main menu bar","provider":"macos-menu-bar","apply":"observe-only","items":["dropbox","sound","wifi"]'* ]] ||
    { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'"excluded_items":[{"id":"studio-only","reason":"profile"},{"id":"linux-only","reason":"platform"}]'* ]] || false
  run "$RIG" show
  [[ "$output" == *'Menu bar layouts (observe-only): 1'* ]] || false
  assert_read_only
}

@test "apply never writes a menu bar value and does not fail the run" {
  run "$RIG" apply --dry-run --target menu-bar:main
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'main\tmenu-bar\tmacos-menu-bar\tskipped\tobserve-only' || false
  run "$RIG" apply --target menu-bar:main
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'rig: menu-bar.main: observe-only; reorder by Command-dragging the icons'* ]] || false
  rig_test_report_contains "$output" $'main\tmenu-bar\tmacos-menu-bar\tskipped\tobserve-only' || false
  run "$RIG" apply
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [ ! -s "$NATIVE_LOG" ] || false
  assert_read_only
}

@test "menu bar validation rejects malformed layouts before any native call" {
  local case_config expected
  for case_config in \
    'ITEMS="\"ghost\"" EXTRA=' \
    'ITEMS="\"sound\", \"sound\"" EXTRA=' \
    'ITEMS="" EXTRA=' \
    'ITEMS="\"bad\"" EXTRA="[menu-bar-item.bad]
domain = \"com.example/bad\"
autosave = \"Item-0\""' \
    'ITEMS="\"bad\"" EXTRA="[menu-bar-item.bad]
domain = \"com.example.bad\"
autosave = \"\""' \
    'ITEMS="\"bad\"" EXTRA="[menu-bar-item.bad]
domain = \"com.example.bad\"
autosave = \"Item-0\"
visible = \"no\""' \
    'ITEMS="\"bad\"" EXTRA="[menu-bar-item.bad]
domain = \"com.example.bad\"
autosave = \"Item-0\"
tool = \"ghost\""'; do
    eval "$case_config"
    write_config
    run "$RIG" status --format json
    [ "$status" -ne 0 ] || { printf '%s\n' "$case_config" "$output" >&3; false; }
  done
  ITEMS='"ghost"' EXTRA='' write_config
  run "$RIG" status
  [[ "$output" == *"references unknown menu bar item 'ghost'"* ]] || false
  ITEMS='"sound", "sound"' EXTRA='' write_config
  run "$RIG" status
  [[ "$output" == *"repeats menu bar item 'sound'"* ]] || false
  unset ITEMS EXTRA
  write_config
  sed 's/macos-menu-bar/macos-dock/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edited.toml"
  mv "$CONFIG_HOME/edited.toml" "$CONFIG_HOME/rig.toml"
  run "$RIG" status
  expected="provider must be 'macos-menu-bar'"
  [[ "$output" == *"$expected"* ]] || false
  [ ! -s "$NATIVE_LOG" ] || false
  assert_read_only
}
