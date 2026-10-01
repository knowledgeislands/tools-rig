#!/usr/bin/env bats

load 'helpers/isolate.bash'

setup() {
  rig_test_isolate
  export RIG_TEST_PYTHON=${RIG_TEST_PYTHON:-/usr/bin/python3}
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  DOCK_STATE=$BATS_TEST_TMPDIR/dock.list
  DOCK_SNAPSHOT=$BATS_TEST_TMPDIR/dock.plist
  NATIVE_LOG=$BATS_TEST_TMPDIR/native.log
  PLUTIL_LOG=$BATS_TEST_TMPDIR/plutil.log
  DEFAULTS_FAKE=$BATS_TEST_TMPDIR/defaults-fixture
  DOCKUTIL_FAKE=$BATS_TEST_TMPDIR/dockutil-fixture
  PLUTIL_FAKE=$BATS_TEST_TMPDIR/plutil-fixture
  mkdir -p "$CONFIG_HOME"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "defaults %s\n" "$*" >>"$NATIVE_LOG"' \
    '[ "$*" = "export com.apple.dock -" ] || exit 99' \
    'cat "$DOCK_SNAPSHOT"; exit "${DOCK_EXPORT_STATUS:-0}"' >"$DEFAULTS_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "dockutil %s\n" "$*" >>"$NATIVE_LOG"' \
    '[ "$*" = --list ] || exit 99' 'cat "$DOCK_STATE"' >"$DOCKUTIL_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' 'exec "$RIG_TEST_PYTHON" "$DOCK_PLUTIL_HELPER" "$@"' >"$PLUTIL_FAKE"
  chmod +x "$DEFAULTS_FAKE" "$DOCKUTIL_FAKE" "$PLUTIL_FAKE"
  export DOCK_PLUTIL_HELPER="$BATS_TEST_DIRNAME/helpers/dock-plutil.py"
  export RIG_DEFAULTS="$DEFAULTS_FAKE" RIG_DOCKUTIL="$DOCKUTIL_FAKE" RIG_PLUTIL="$PLUTIL_FAKE"
  export RIG_CONFIG_HOME="$CONFIG_HOME" RIG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export NATIVE_LOG DOCK_STATE DOCK_SNAPSHOT DOCK_PLUTIL_LOG="$PLUTIL_LOG"
  write_config grid folder
  printf 'Documents\t/fixture/Documents\tothers\n' >"$DOCK_STATE"
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"showas":2,"displayas":1}}]}'
}

write_config() {
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'docks = ["main"]' \
    '[dock.main]' 'name = "Main"' 'purpose = "Navigation"' 'rationale = "Predictable order"' \
    'provider = "macos-dock"' 'platforms = ["macos"]' 'items = ["documents"]' \
    '[dock-item.documents]' 'kind = "folder"' 'path = "/fixture/Documents"' >"$CONFIG_HOME/rig.toml"
  [ -z "$1" ] || printf 'view = "%s"\n' "$1" >>"$CONFIG_HOME/rig.toml"
  [ -z "$2" ] || printf 'display = "%s"\n' "$2" >>"$CONFIG_HOME/rig.toml"
}

snapshot() {
  printf '%s' "$1" | "$RIG_TEST_PYTHON" "$DOCK_PLUTIL_HELPER" --fixture "${2:-}" >"$DOCK_SNAPSHOT"
}

observe() {
  run "$RIG" status --format json
}

assert_observation() {
  [[ "$output" == *"\"state\":\"$1\""* ]] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *"\"detail\":\"$2\""* ]] || { printf '%s\n' "$output" >&3; false; }
}

assert_read_only() {
  ! grep -Eq 'defaults (write|delete)|dockutil (--add|--remove)|killall' "$NATIVE_LOG" || false
  [ ! -e "$RIG_STATE_HOME" ] || false
}

@test "Dock native view and display encodings agree in XML and binary snapshots" {
  local view index display display_index encoding
  index=0
  for view in auto fan grid list; do
    display_index=0
    for display in stack folder; do
      write_config "$view" "$display"
      for encoding in '' --binary; do
        snapshot "{\"persistent-others\":[{\"tile-type\":\"directory-tile\",\"tile-data\":{\"file-data\":{\"_CFURLString\":\"file:///fixture/Documents/\",\"_CFURLStringType\":15},\"showas\":$index,\"displayas\":$display_index}}]}" "$encoding"
        observe
        [ "$status" -eq 0 ] || false
        assert_observation present -
      done
      display_index=$((display_index + 1))
    done
    index=$((index + 1))
  done
  assert_read_only
}

@test "Dock proven view and display drift are item qualified" {
  write_config list folder
  observe
  [ "$status" -eq 1 ] || false
  assert_observation drifted view:documents
  write_config grid stack
  observe
  [ "$status" -eq 1 ] || false
  assert_observation drifted display:documents
  assert_read_only
}

@test "Dock order drift wins without reading a snapshot" {
  printf '/fixture/Other\n' >"$DOCK_STATE"
  observe
  assert_observation drifted order
  [ ! -e "$PLUTIL_LOG" ] || false
  [ "$(wc -l <"$NATIVE_LOG")" -eq 1 ] || false
  assert_read_only
}

@test "Dock omitted attributes remain unconstrained and need no snapshot" {
  write_config '' ''
  observe
  [ "$status" -eq 0 ] || false
  assert_observation present -
  [ ! -e "$PLUTIL_LOG" ] || false
  [ "$(wc -l <"$NATIVE_LOG")" -eq 1 ] || false
  assert_read_only
}

@test "Dock failures and malformed snapshots are unavailable evidence" {
  export DOCK_EXPORT_STATUS=7
  observe
  assert_observation unknown view-unobservable:documents
  unset DOCK_EXPORT_STATUS
  printf 'not a plist' >"$DOCK_SNAPSHOT"
  observe
  assert_observation unknown view-unobservable:documents
  export RIG_PLUTIL="$BATS_TEST_TMPDIR/missing-plutil"
  observe
  assert_observation unknown view-unobservable:documents
  assert_read_only
}

@test "Dock wrong array type, missing matches and duplicate matches never imply agreement" {
  local spec tile
  tile='{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"showas":2,"displayas":1}}'
  for spec in '{"persistent-others":{}}' '{"persistent-others":[]}' "{\"persistent-others\":[$tile,$tile]}"; do
    snapshot "$spec"
    observe
    assert_observation unknown view-unobservable:documents
  done
  assert_read_only
}

@test "Dock unsupported field types and encodings are unknown" {
  local fields
  for fields in '"showas":"2","displayas":1' '"showas":true,"displayas":1' '"showas":99,"displayas":1' '"displayas":1'; do
    snapshot "{\"persistent-others\":[{\"tile-type\":\"directory-tile\",\"tile-data\":{\"file-data\":{\"_CFURLString\":\"/fixture/Documents\",\"_CFURLStringType\":0},$fields}}]}"
    observe
    assert_observation unknown view-unobservable:documents
  done
  assert_read_only
}

@test "Dock unsupported URL types and remote or malformed URLs are unknown" {
  local path url_type
  for path in 'file://remote/fixture/Documents' 'file:///fixture/%XX' 'file:///fixture/%00' 'https://example.test/Documents'; do
    snapshot "{\"persistent-others\":[{\"tile-type\":\"directory-tile\",\"tile-data\":{\"file-data\":{\"_CFURLString\":\"$path\",\"_CFURLStringType\":15},\"showas\":2,\"displayas\":1}}]}"
    observe
    assert_observation unknown view-unobservable:documents
  done
  for url_type in 99 '"0"'; do
    snapshot "{\"persistent-others\":[{\"tile-type\":\"directory-tile\",\"tile-data\":{\"file-data\":{\"_CFURLString\":\"/fixture/Documents\",\"_CFURLStringType\":$url_type},\"showas\":2,\"displayas\":1}}]}"
    observe
    assert_observation unknown view-unobservable:documents
  done
  assert_read_only
}

@test "Dock native literal trailing controls are not lost to command substitution" {
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents\n","_CFURLStringType":0},"showas":2,"displayas":1}}]}'
  observe
  assert_observation unknown view-unobservable:documents
  assert_read_only
}

@test "Dock raw percent paths stay literal and local file URLs decode once" {
  local native url_type
  sed 's|/fixture/Documents|/fixture/A%20B|' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/replacement"
  mv "$CONFIG_HOME/replacement" "$CONFIG_HOME/rig.toml"
  printf 'Folder\t/fixture/A%%20B\tothers\n' >"$DOCK_STATE"
  for native in '/fixture/A%20B' 'file:///fixture/A%2520B' 'file://localhost/fixture/A%2520B/'; do
    url_type=15
    [ "$native" != '/fixture/A%20B' ] || url_type=0
    snapshot "{\"persistent-others\":[{\"tile-type\":\"directory-tile\",\"tile-data\":{\"file-data\":{\"_CFURLString\":\"$native\",\"_CFURLStringType\":$url_type},\"showas\":2,\"displayas\":1}}]}"
    observe
    assert_observation present -
  done
  assert_read_only
}

@test "Dock one unavailable attribute does not hide a proven mismatch" {
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"displayas":0}}]}'
  observe
  assert_observation drifted display:documents
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"showas":3}}]}'
  observe
  assert_observation drifted view:documents
  assert_read_only
}

@test "Dock escaped file URLs match full declared paths without label guessing" {
  sed 's|/fixture/Documents|/fixture/A \\"quote\\" \& café|' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/replacement"
  mv "$CONFIG_HOME/replacement" "$CONFIG_HOME/rig.toml"
  printf 'Unrelated label\t/fixture/A "quote" & café\tothers\n' >"$DOCK_STATE"
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-label":"Documents","file-data":{"_CFURLString":"file:///fixture/A%20%22quote%22%20%26%20caf%C3%A9","_CFURLStringType":15},"showas":2,"displayas":1}}]}'
  observe
  assert_observation present -
  assert_read_only
}

@test "Dock view precedence spans all folders and shares one snapshot" {
  sed 's/items = \["documents"\]/items = ["documents", "downloads"]/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/replacement"
  mv "$CONFIG_HOME/replacement" "$CONFIG_HOME/rig.toml"
  printf '%s\n' '[dock-item.downloads]' 'kind = "folder"' 'path = "/fixture/Downloads"' 'view = "grid"' >>"$CONFIG_HOME/rig.toml"
  printf 'Downloads\t/fixture/Downloads\tothers\n' >>"$DOCK_STATE"
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"showas":2,"displayas":0}},{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Downloads","_CFURLStringType":0},"showas":3}}]}'
  observe
  assert_observation drifted view:downloads
  [ "$(grep -c '^defaults export' "$NATIVE_LOG")" -eq 1 ] || false
  assert_read_only
}

@test "Dock proven mismatch survives a different folder with incomplete attributes" {
  sed 's/items = \["documents"\]/items = ["documents", "downloads"]/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/replacement"
  mv "$CONFIG_HOME/replacement" "$CONFIG_HOME/rig.toml"
  printf '%s\n' '[dock-item.downloads]' 'kind = "folder"' 'path = "/fixture/Downloads"' 'view = "grid"' >>"$CONFIG_HOME/rig.toml"
  printf 'Downloads\t/fixture/Downloads\tothers\n' >>"$DOCK_STATE"
  snapshot '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"showas":2,"displayas":0}},{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Downloads","_CFURLStringType":0}}}]}'
  observe
  assert_observation drifted display:documents
  [ "$(grep -c '^defaults export' "$NATIVE_LOG")" -eq 1 ] || false
  assert_read_only
}

@test "Dock repeated sourced main commands take fresh snapshots" {
  NEXT_SNAPSHOT=$BATS_TEST_TMPDIR/next.plist
  printf '%s' '{"persistent-others":[{"tile-type":"directory-tile","tile-data":{"file-data":{"_CFURLString":"/fixture/Documents","_CFURLStringType":0},"showas":3,"displayas":1}}]}' |
    "$RIG_TEST_PYTHON" "$DOCK_PLUTIL_HELPER" --fixture >"$NEXT_SNAPSHOT"
  run /bin/bash -c '
    source "$1"
    main status --format json || exit
    cp "$2" "$DOCK_SNAPSHOT"
    main status --format json
  ' _ "$RIG" "$NEXT_SNAPSHOT"
  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  assert_observation present -
  assert_observation drifted view:documents
  [ "$(grep -c '^defaults export' "$NATIVE_LOG")" -eq 2 ] || false
  assert_read_only
}

@test "Dock doctor reports incomplete observation without any native mutation" {
  snapshot '{"persistent-others":[]}'
  run "$RIG" doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'view-unobservable:documents'* ]] || false
  assert_read_only
}
