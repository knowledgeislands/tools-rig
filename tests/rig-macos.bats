#!/usr/bin/env bats

setup() {
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  TEST_HOME=$BATS_TEST_TMPDIR/home
  MACOS_LOG=$BATS_TEST_TMPDIR/native.log
  DEFAULTS_STATE=$BATS_TEST_TMPDIR/defaults.state
  DOCK_STATE=$BATS_TEST_TMPDIR/dock.state
  DEFAULTS_FAKE=$BATS_TEST_TMPDIR/defaults
  DOCKUTIL_FAKE=$BATS_TEST_TMPDIR/dockutil
  KILLALL_FAKE=$BATS_TEST_TMPDIR/killall
  mkdir -p "$CONFIG_HOME/conf.d" "$TEST_HOME/Applications/Alpha.app" "$TEST_HOME/Documents"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "defaults" >>"$MACOS_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$MACOS_LOG"; done; printf "\n" >>"$MACOS_LOG"' \
    'case "$1" in read) [ -f "$DEFAULTS_STATE" ] || exit 1; cat "$DEFAULTS_STATE" ;; write) printf "%s\n" "$5" >"$DEFAULTS_STATE" ;; esac' >"$DEFAULTS_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "dockutil" >>"$MACOS_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$MACOS_LOG"; done; printf "\n" >>"$MACOS_LOG"' \
    '[ "$1" != --list ] || { [ ! -f "$DOCK_STATE" ] || cat "$DOCK_STATE"; }' >"$DOCKUTIL_FAKE"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "killall <%s>\n" "$1" >>"$MACOS_LOG"' >"$KILLALL_FAKE"
  chmod +x "$DEFAULTS_FAKE" "$DOCKUTIL_FAKE" "$KILLALL_FAKE"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'settings = ["dark-mode"]' 'docks = ["main"]' \
    '[setting.dark-mode]' 'name = "Dark mode"' 'purpose = "Use a dark appearance"' \
    'rationale = "Reduce glare"' 'provider = "macos-defaults"' 'domain = "NSGlobalDomain"' \
    'key = "AppleInterfaceStyleSwitchesAutomatically"' 'value-type = "bool"' 'value = "true"' \
    'platforms = ["macos"]' \
    '[dock.main]' 'name = "Main Dock"' 'purpose = "Keep frequent destinations ordered"' \
    'rationale = "Make navigation predictable"' 'provider = "macos-dock"' 'platforms = ["macos"]' \
    'items = ["alpha", "documents"]' \
    '[dock-item.alpha]' 'kind = "application"' 'path = "~/Applications/Alpha.app"' \
    '[dock-item.documents]' 'kind = "folder"' 'path = "$HOME/Documents"' 'view = "grid"' \
    'display = "folder"' >"$CONFIG_HOME/rig.toml"
}

output_has_table_row() {
  local expected

  expected=$1
  printf '%s\n' "$output" | awk -v expected="$expected" '
    { gsub(/  +/, "\t"); if ($0 == expected) found = 1 }
    END { exit !found }
  '
}

run_rig() {
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" \
    RIG_DEFAULTS="$DEFAULTS_FAKE" RIG_DOCKUTIL="$DOCKUTIL_FAKE" RIG_KILLALL="$KILLALL_FAKE" \
    MACOS_LOG="$MACOS_LOG" DEFAULTS_STATE="$DEFAULTS_STATE" DOCK_STATE="$DOCK_STATE" "$RIG" "$@"
}

@test "typed macOS resources query and dry-run deterministically" {
  run_rig show
  [ "$status" -eq 0 ]
  [[ "$output" == *$'Settings: 1\nID\tNAME\tPROVIDER\tVALUE\ndark-mode\tDark mode\tmacos-defaults\ttrue'* ]] || false
  [[ "$output" == *$'Dock layouts: 1\nID\tNAME\tPROVIDER\tITEMS\nmain\tMain Dock\tmacos-dock\t2'* ]] || false
  run_rig explain setting:dark-mode
  [ "$status" -eq 0 ]
  [[ "$output" == *'provider=macos-defaults'* ]] || false
  run_rig apply --scope resources --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *$'main\tdock\tmacos-dock\tplanned'* ]] || false
  [[ "$output" == *$'dark-mode\tsetting\tmacos-defaults\tplanned'* ]] || false
  [ ! -e "$MACOS_LOG" ]
}

@test "typed macOS resources observe and apply through native command fakes" {
  printf '%s\n' true >"$DEFAULTS_STATE"
  printf 'Alpha\t%s\tapplications\nDocuments\t%s\tothers\n' \
    "$TEST_HOME/Applications/Alpha.app" "$TEST_HOME/Documents" >"$DOCK_STATE"
  run_rig status
  [ "$status" -eq 0 ]
  output_has_table_row $'main\tdock\tmacos-dock\tpresent\t-'
  output_has_table_row $'dark-mode\tsetting\tmacos-defaults\tpresent\t-'
  : >"$MACOS_LOG"
  run_rig apply --scope resources
  [ "$status" -eq 0 ]
  grep -F 'defaults <write> <NSGlobalDomain> <AppleInterfaceStyleSwitchesAutomatically> <-bool> <true>' "$MACOS_LOG"
  grep -F "dockutil <--add> <$TEST_HOME/Applications/Alpha.app> <--no-restart>" "$MACOS_LOG"
  grep -F "dockutil <--add> <$TEST_HOME/Documents> <--view> <grid> <--display> <folder> <--no-restart>" "$MACOS_LOG"
  grep -F 'killall <Dock>' "$MACOS_LOG"
}

@test "typed macOS schema rejects invalid values before invocation" {
  sed 's/value-type = "bool"/value-type = "number"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/invalid.toml"
  mv "$CONFIG_HOME/invalid.toml" "$CONFIG_HOME/rig.toml"
  run_rig status
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported value-type 'number'"* ]] || false
  [ ! -e "$MACOS_LOG" ]
}

@test "string settings expand only bounded home forms" {
  mkdir -p "$TEST_HOME/Downloads"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "defaults" >>"$MACOS_LOG"' \
    'for argument in "$@"; do printf " <%s>" "$argument" >>"$MACOS_LOG"; done; printf "\n" >>"$MACOS_LOG"' \
    'case "$1:$3" in read:CapturePath) printf "%s\n" "$HOME/Downloads" ;; read:HomeURL) printf "file://%s/\n" "$HOME" ;; read:Literal) printf "%s\n" "prefix-\$HOME/x" ;; esac' \
    >"$DEFAULTS_FAKE"
  chmod +x "$DEFAULTS_FAKE"
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'settings = ["capture-path", "home-url", "literal"]' \
    '[setting.capture-path]' 'name = "Capture path"' 'purpose = "Store captures"' \
    'rationale = "Keep captures together"' 'provider = "macos-defaults"' \
    'domain = "example.capture"' 'key = "CapturePath"' 'value-type = "string"' \
    'value = "$HOME/Downloads"' 'platforms = ["macos"]' \
    '[setting.home-url]' 'name = "Home URL"' 'purpose = "Open home"' \
    'rationale = "Keep a stable home shortcut"' 'provider = "macos-defaults"' \
    'domain = "example.finder"' 'key = "HomeURL"' 'value-type = "string"' \
    'value = "file://$HOME/"' 'platforms = ["macos"]' \
    '[setting.literal]' 'name = "Literal"' 'purpose = "Preserve text"' \
    'rationale = "Do not interpolate embedded variables"' 'provider = "macos-defaults"' \
    'domain = "example.literal"' 'key = "Literal"' 'value-type = "string"' \
    'value = "prefix-$HOME/x"' 'platforms = ["macos"]' >"$CONFIG_HOME/rig.toml"

  run_rig status
  [ "$status" -eq 0 ]
  output_has_table_row $'capture-path\tsetting\tmacos-defaults\tpresent\t-'
  output_has_table_row $'home-url\tsetting\tmacos-defaults\tpresent\t-'
  output_has_table_row $'literal\tsetting\tmacos-defaults\tpresent\t-'

  : >"$MACOS_LOG"
  run_rig apply --scope resources
  [ "$status" -eq 0 ]
  grep -F "defaults <write> <example.capture> <CapturePath> <-string> <$TEST_HOME/Downloads>" "$MACOS_LOG"
  grep -F "defaults <write> <example.finder> <HomeURL> <-string> <file://$TEST_HOME/>" "$MACOS_LOG"
  grep -F 'defaults <write> <example.literal> <Literal> <-string> <prefix-$HOME/x>' "$MACOS_LOG"

  : >"$MACOS_LOG"
  run env -u HOME RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_STATE_HOME="$BATS_TEST_TMPDIR/state" RIG_DEFAULTS="$DEFAULTS_FAKE" \
    RIG_DOCKUTIL="$DOCKUTIL_FAKE" RIG_KILLALL="$KILLALL_FAKE" \
    MACOS_LOG="$MACOS_LOG" "$RIG" apply --scope resources --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *'HOME is required'* ]] || false
  [ ! -s "$MACOS_LOG" ]
}

@test "resource-local preflight failure does not block independent resources" {
  printf '%s\n' \
    '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'settings = ["dark-mode"]' 'docks = ["main"]' \
    '[setting.dark-mode]' 'name = "Dark mode"' 'purpose = "Use a dark appearance"' \
    'rationale = "Reduce glare"' 'provider = "macos-defaults"' 'domain = "NSGlobalDomain"' \
    'key = "AppleInterfaceStyleSwitchesAutomatically"' 'value-type = "bool"' 'value = "true"' \
    'platforms = ["macos"]' \
    '[dock.main]' 'name = "Main Dock"' 'purpose = "Keep destinations ordered"' \
    'rationale = "Make navigation predictable"' 'provider = "macos-dock"' 'platforms = ["macos"]' \
    'items = ["missing"]' \
    '[dock-item.missing]' 'kind = "folder"' 'path = "$HOME/Missing"' \
    >"$CONFIG_HOME/rig.toml"

  run_rig apply --scope resources --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *$'main\tdock\tmacos-dock\tfailed\tpreflight:dock-item-path-missing:'"$TEST_HOME/Missing"* ]] || false
  [[ "$output" == *$'dark-mode\tsetting\tmacos-defaults\tplanned'* ]] || false
  [ ! -e "$MACOS_LOG" ]

  run_rig apply --scope resources
  [ "$status" -eq 1 ]
  [[ "$output" == *$'main\tdock\tmacos-dock\tfailed\tpreflight:dock-item-path-missing:'"$TEST_HOME/Missing"* ]] || false
  [[ "$output" == *$'dark-mode\tsetting\tmacos-defaults\tcompleted'* ]] || false
  grep -F 'defaults <write> <NSGlobalDomain> <AppleInterfaceStyleSwitchesAutomatically> <-bool> <true>' "$MACOS_LOG"
  ! grep -F 'dockutil <--remove>' "$MACOS_LOG"
  ! grep -F 'killall <Dock>' "$MACOS_LOG"
  [ ! -e "$BATS_TEST_TMPDIR/state/resources/macos.tsv" ]
}

@test "built-in application inventory excludes wrapped mobile bundles" {
  APP_ROOT=$BATS_TEST_TMPDIR/apps
  PLUTIL_FAKE=$BATS_TEST_TMPDIR/plutil
  mkdir -p "$APP_ROOT/Native.app/Contents" "$APP_ROOT/Mobile.app/Wrapper/Mobile.app"
  : >"$APP_ROOT/Native.app/Contents/Info.plist"
  : >"$APP_ROOT/Mobile.app/Wrapper/Mobile.app/Info.plist"
  printf '%s\n' '#!/usr/bin/env bash' 'case "$2" in DTPlatformName) echo macosx ;; LSRequiresIPhoneOS) exit 1 ;; CFBundleSupportedPlatforms) echo "[\"MacOSX\"]" ;; esac' >"$PLUTIL_FAKE"
  chmod +x "$PLUTIL_FAKE"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' '[profile.default]' >"$CONFIG_HOME/rig.toml"
  run env HOME="$TEST_HOME" RIG_CONFIG_HOME="$CONFIG_HOME" RIG_PLATFORM=macos \
    RIG_APPLICATION_ROOTS="$APP_ROOT" RIG_PLUTIL="$PLUTIL_FAKE" "$RIG" status --unmanaged
  [ "$status" -eq 0 ]
  [[ "$output" == *'/Native.app'*'macos-applications'*'unmanaged'*'native'* ]] || false
  [[ "$output" != *'Mobile.app'* ]] || false
}
