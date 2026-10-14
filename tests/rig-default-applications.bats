#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME"
  export APP=$HOME/Applications/Editor.app
  export RIG_HANDLER_FIXTURE_STATE=$BATS_TEST_TMPDIR/handlers
  export RIG_HANDLER_FIXTURE_LOG=$BATS_TEST_TMPDIR/handler-log
  export RIG_HANDLER_FIXTURE_BUNDLE=org.example.Editor
  export RIG_HANDLER_FIXTURE_BEHAVIOUR=normal
  mkdir -p "$RIG_HANDLER_FIXTURE_STATE"
  : >"$RIG_HANDLER_FIXTURE_LOG"
  cat >"$RIG_PLUTIL" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$0.log"
[ "$1" = -extract ] && [ "$3" = raw ] && [ "$4" = -o ] && [ "$5" = - ] || exit 99
case "$2" in
  CFBundleExecutable) printf 'Editor\n' ;;
  CFBundleIdentifier) printf '%s\n' "$RIG_HANDLER_FIXTURE_BUNDLE" ;;
  *) exit 99 ;;
esac
SH
  cat >"$RIG_OSASCRIPT" <<'SH'
#!/usr/bin/env bash
[ "$#" = 10 ] && [ "$1" = -l ] && [ "$2" = JavaScript ] && [ "$3" = -e ] && [ "$5" = -- ] || exit 99
case "$4" in *LSRegisterURL*LSSetDefaultHandlerForURLScheme*LSSetDefaultRoleHandlerForContentType*) ;; *) exit 99 ;; esac
printf '%s|%s|%s|%s|%s\n' "$6" "$7" "$8" "$9" "${10}" >>"$RIG_HANDLER_FIXTURE_LOG"
[ -x "${10}/Contents/MacOS/Editor" ] || exit 99
key=$RIG_HANDLER_FIXTURE_STATE/$7-$8
case "$6" in
  observe)
    [ "$RIG_HANDLER_FIXTURE_BEHAVIOUR" != observe-fail ] || exit 9
    [ "$RIG_HANDLER_FIXTURE_BEHAVIOUR" != invalid ] || { printf 'invalid handler response\n'; exit 0; }
    if [ -f "$key" ]; then cat "$key"; else printf 'org.legacy.Editor\n'; fi ;;
  apply)
    [ "$RIG_HANDLER_FIXTURE_BEHAVIOUR" != apply-fail ] || exit 9
    [ "$RIG_HANDLER_FIXTURE_BEHAVIOUR" = decline ] || printf '%s\n' "$9" >"$key"
    printf 'assigned\n' ;;
  *) exit 99 ;;
esac
SH
  chmod +x "$RIG_PLUTIL" "$RIG_OSASCRIPT"
}

write_config() {
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[category.core]
name = "Core"
purpose = "Fixture"
[profile.default]
default-applications = ["notes"]
[profile.other]
name = "Other"
[tool.editor]
name = "Editor"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
artifacts = ["$APP"]
[default-application.notes]
name = "Notes handler"
purpose = "Fixture"
rationale = "Fixture"
provider = "macos-handlers"
tool = "editor"
bundle-id = "org.example.Editor"
kind = "uti"
value = "org.example.notes"
platforms = ["macos"]
TOML
}

healthy_app() {
  mkdir -p "$APP/Contents/MacOS"
  printf '<plist><dict/></plist>\n' >"$APP/Contents/Info.plist"
  printf '#!/bin/sh\nexit 0\n' >"$APP/Contents/MacOS/Editor"
  chmod +x "$APP/Contents/MacOS/Editor"
}

@test "doctor reports handler drift and apply verifies effective UTI assignment" {
  write_config
  healthy_app
  run "$RIG" doctor --format json
  [ "$status" -eq 1 ]
  [[ "$output" == *'handler-mismatch:current:org.legacy.Editor:expected:org.example.Editor'* ]] || false
  ! /usr/bin/grep '^apply|' "$RIG_HANDLER_FIXTURE_LOG"
  run "$RIG" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_HANDLER_FIXTURE_STATE/uti-org.example.notes")" = org.example.Editor ]
  run "$RIG" doctor --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"healthy":true'* ]] || false
}

@test "correct default handler is a no-op and dry run never calls native handlers" {
  write_config
  healthy_app
  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  printf 'org.example.Editor\n' >"$RIG_HANDLER_FIXTURE_STATE/uti-org.example.notes"
  run "$RIG" apply
  [ "$status" -eq 0 ]
  ! /usr/bin/grep '^apply|' "$RIG_HANDLER_FIXTURE_LOG"
}

@test "extension and URL scheme declarations use literal normalised native arguments" {
  write_config
  healthy_app
  /usr/bin/sed -i.bak 's/kind = "uti"/kind = "extension"/;s/value = "org.example.notes"/value = ".note"/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --target default-application:notes
  [ "$status" -eq 0 ]
  [[ "$(cat "$RIG_HANDLER_FIXTURE_LOG")" == *'apply|extension|note|org.example.Editor|'* ]] || false
  /usr/bin/sed -i.bak 's/kind = "extension"/kind = "scheme"/;s/value = ".note"/value = "example+notes"/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --scope resources
  [ "$status" -eq 0 ]
  [[ "$(cat "$RIG_HANDLER_FIXTURE_LOG")" == *'apply|scheme|example+notes|org.example.Editor|'* ]] || false
}

@test "missing damaged and mismatched applications never query or change handlers" {
  write_config
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'application:artifact-missing'* ]] || false
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  mkdir -p "$APP/Contents"
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'artifact-damaged-app'* ]] || false
  healthy_app
  export RIG_HANDLER_FIXTURE_BUNDLE=org.other.Editor
  run "$RIG" doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *'application-bundle-id-mismatch'* ]] || false
  run "$RIG" apply
  [ "$status" -eq 1 ]
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
}

@test "native observation failure and malformed responses remain unknown without mutation" {
  write_config
  healthy_app
  for behaviour in observe-fail invalid; do
    export RIG_HANDLER_FIXTURE_BEHAVIOUR=$behaviour
    run "$RIG" doctor --format json
    [ "$status" -eq 1 ]
    [[ "$output" == *'unknown'* ]] || false
    run "$RIG" apply
    [ "$status" -eq 1 ]
    ! /usr/bin/grep '^apply|' "$RIG_HANDLER_FIXTURE_LOG"
  done
}

@test "native failure and ineffective assignment keep apply incomplete" {
  write_config
  healthy_app
  for behaviour in apply-fail decline; do
    export RIG_HANDLER_FIXTURE_BEHAVIOUR=$behaviour
    run "$RIG" apply
    [ "$status" -eq 1 ]
    [ ! -f "$RIG_HANDLER_FIXTURE_STATE/uti-org.example.notes" ]
  done
  [[ "$output" == *'native confirmation may be required'* ]] || false
}

@test "application installation precedes handler assignment and failed install blocks it" {
  write_config
  cat >"$RIG_TEST_PROVIDER_BIN/installer" <<'SH'
#!/usr/bin/env bash
[ "$1" = rig-provider-v1 ] || exit 99
case "$2" in
  observe) if [ -d "$APP" ]; then printf 'present\n'; else printf 'missing\n'; fi ;;
  apply)
    printf 'INSTALL\n' >>"$RIG_HANDLER_FIXTURE_LOG"
    [ "$RIG_HANDLER_FIXTURE_BEHAVIOUR" != install-fail ] || exit 7
    mkdir -p "$APP/Contents/MacOS"
    printf '<plist><dict/></plist>\n' >"$APP/Contents/Info.plist"
    printf '#!/bin/sh\nexit 0\n' >"$APP/Contents/MacOS/Editor"
    chmod +x "$APP/Contents/MacOS/Editor" ;;
  *) exit 99 ;;
esac
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/installer"
  # Add installation fields to their existing owning table, not handler metadata.
  /usr/bin/sed -i.bak '/artifacts = /a\
install.provider = "installer"\
install.kind = "executable"\
install.locator = "fixture"\
' "$RIG_CONFIG_HOME/rig.toml"
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<TOML
[provider.installer]
adapter = "custom"
executable = "$RIG_TEST_PROVIDER_BIN/installer"
capabilities = ["observe", "apply"]
TOML
  run "$RIG" apply --target default-application:notes
  [ "$status" -eq 0 ]
  [ "$(head -1 "$RIG_HANDLER_FIXTURE_LOG")" = INSTALL ]
  [[ "$(cat "$RIG_HANDLER_FIXTURE_LOG")" == *'apply|uti|org.example.notes|org.example.Editor|'* ]] || false
  : >"$RIG_HANDLER_FIXTURE_LOG"
  export RIG_HANDLER_FIXTURE_BEHAVIOUR=install-fail
  run "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'blocked-by:editor'* ]] || false
  ! /usr/bin/grep '^apply|' "$RIG_HANDLER_FIXTURE_LOG"
}

@test "profile exclusion remains private and Linux reports unsupported without native calls" {
  write_config
  healthy_app
  run "$RIG" doctor --profile other
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  run env RIG_PLATFORM=linux "$RIG" doctor --format json
  [ "$status" -eq 1 ]
  [[ "$output" == *'unsupported-platform'* ]] || false
  run env RIG_PLATFORM=linux "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'unsupported-platform'* ]] || false
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
}

@test "conflicting selected handler targets fail before native work" {
  write_config
  healthy_app
  /usr/bin/sed -i.bak 's/default-applications = \["notes"\]/default-applications = ["notes", "conflict"]/' "$RIG_CONFIG_HOME/rig.toml"
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[default-application.conflict]
name = "Conflicting choice"
purpose = "Fixture"
rationale = "Fixture"
provider = "macos-handlers"
tool = "editor"
bundle-id = "org.other.Editor"
kind = "uti"
value = "org.example.notes"
platforms = ["macos"]
TOML
  run "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'conflicts with'* ]] || false
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
}

@test "invalid handlers and owners fail closed without native work" {
  for invalid in 'kind = "role"' 'tool = "missing"' 'bundle-id = "invalid"' 'provider = "custom"' 'platforms = ["linux"]'; do
    write_config
    key=${invalid%% =*}
    /usr/bin/sed -i.bak "/^$key = /c\\
$invalid
" "$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" show
    [ "$status" -eq 2 ]
    [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  done
}

@test "item profiles and selected platform artifacts retain handler ownership" {
  write_config
  healthy_app
  /usr/bin/sed -i.bak '/default-applications = /d;s/^artifacts = /variant.macos.artifacts = /' "$RIG_CONFIG_HOME/rig.toml"
  /usr/bin/sed -i.bak '/variant.macos.artifacts = /a\
variant.macos.platforms = ["macos"]\
' "$RIG_CONFIG_HOME/rig.toml"
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
profiles = ["other"]
TOML
  run "$RIG" doctor --profile default
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  run "$RIG" apply --profile other
  [ "$status" -eq 0 ]
  [[ "$(cat "$RIG_HANDLER_FIXTURE_LOG")" == *'apply|uti|org.example.notes|org.example.Editor|'* ]] || false
}

@test "handler declarations are described offline and excluded from public export" {
  write_config
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[profile.public]
kind = "view"
tools = ["editor"]
TOML
  run "$RIG" show default-application:notes
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool=editor'* ]] || false
  [[ "$output" == *'bundle-id=org.example.Editor'* ]] || false
  run "$RIG" show --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"handler_kind":"uti"'* ]] || false
  run "$RIG" export --profile public --output "$BATS_TEST_TMPDIR/public"
  [ "$status" -eq 0 ]
  ! /usr/bin/grep -R -E 'org.example.Editor|org.example.notes|default-application|Editor.app' "$BATS_TEST_TMPDIR/public"
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
}

@test "deselection never resets handlers or creates a retirement receipt" {
  write_config
  healthy_app
  run "$RIG" apply
  [ "$status" -eq 0 ]
  before=$(wc -l <"$RIG_HANDLER_FIXTURE_LOG")
  run "$RIG" apply --profile other
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$RIG_HANDLER_FIXTURE_LOG")" = "$before" ]
  [ "$(cat "$RIG_HANDLER_FIXTURE_STATE/uti-org.example.notes")" = org.example.Editor ]
  ! /usr/bin/grep -R 'default-application' "$HOME/.local/state/rig/resources"
}

@test "missing native adapter and missing owned artifact fail without handler calls" {
  write_config
  healthy_app
  run env RIG_OSASCRIPT="$BATS_TEST_TMPDIR/not-installed" "$RIG" doctor --format json
  [ "$status" -eq 1 ]
  [[ "$output" == *'handler-executable-unavailable'* ]] || false
  run env RIG_OSASCRIPT="$BATS_TEST_TMPDIR/not-installed" "$RIG" apply
  [ "$status" -eq 1 ]
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  /usr/bin/sed -i.bak '/artifacts = /d' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *'requires a declared .app artifact'* ]] || false
}

@test "normalised duplicate extensions conflict only inside their selected profile" {
  write_config
  healthy_app
  /usr/bin/sed -i.bak 's/kind = "uti"/kind = "extension"/;s/value = "org.example.notes"/value = ".note"/' "$RIG_CONFIG_HOME/rig.toml"
  cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[default-application.alternate]
name = "Alternate"
purpose = "Fixture"
rationale = "Fixture"
provider = "macos-handlers"
tool = "editor"
bundle-id = "org.other.Editor"
kind = "extension"
value = "note"
platforms = ["macos"]
TOML
  run "$RIG" show
  [ "$status" -eq 0 ]
  /usr/bin/sed -i.bak 's/default-applications = \["notes"\]/default-applications = ["notes", "alternate"]/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply
  [ "$status" -eq 2 ]
  [[ "$output" == *'conflicts with'* ]] || false
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
}

@test "embedded bridge compiles and native API symbols exist without handler access" {
  [ -x /usr/bin/osascript ] || skip 'native JavaScript bridge is macOS only'
  script=$(bash -c 'source "$1"; printf "%s" "$RIG_DEFAULT_HANDLER_SCRIPT"' _ "$RIG")
  # Compile the body without running it. Framework reflection only checks symbol
  # availability: no handler copy/set/register function is invoked here.
  run /usr/bin/osascript -l JavaScript -e 'function run(argv) {
    new Function("ObjC", "$", argv[0]);
    ObjC.import("CoreServices");
    return JSON.stringify([typeof $.LSCopyDefaultRoleHandlerForContentType,
      typeof $.LSSetDefaultRoleHandlerForContentType,
      typeof $.LSCopyDefaultHandlerForURLScheme,
      typeof $.LSSetDefaultHandlerForURLScheme,
      typeof $.UTTypeCreatePreferredIdentifierForTag,
      typeof $.LSRegisterURL]);
  }' -- "$script"
  [ "$status" -eq 0 ]
  [ "$output" = '["function","function","function","function","function","function"]' ]
  [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
}

@test "embedded bridge observation returns a bundle ID or absence, never a native reference" {
  [ -x /usr/bin/osascript ] || skip 'native JavaScript bridge is macOS only'
  script=$(bash -c 'source "$1"; printf "%s" "$RIG_DEFAULT_HANDLER_SCRIPT"' _ "$RIG")
  # Observation only copies the current handler; nothing is registered or set.
  run /usr/bin/osascript -l JavaScript -e "$script" -- observe scheme rig-unregistered-scheme - -
  [ "$status" -eq 0 ]
  [ "$output" = - ]
  run /usr/bin/osascript -l JavaScript -e "$script" -- observe scheme https - -
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || false
}

@test "absent native handler is drifted and assignments remain explicit" {
  write_config
  healthy_app
  printf -- '-\n' >"$RIG_HANDLER_FIXTURE_STATE/uti-org.example.notes"
  run "$RIG" doctor --format json
  [ "$status" -eq 1 ]
  [[ "$output" == *'handler-mismatch:current:-:expected:org.example.Editor'* ]] || false
  ! /usr/bin/grep '^apply|' "$RIG_HANDLER_FIXTURE_LOG"
  run "$RIG" apply
  [ "$status" -eq 0 ]
}

@test "unsafe selector values never reach the native bridge" {
  for fixture in 'uti|not-a-uti' 'extension|../escape' 'scheme|https:'; do
    write_config
    kind=${fixture%%|*}
    value=${fixture#*|}
    /usr/bin/sed -i.bak "s/kind = \"uti\"/kind = \"$kind\"/;s|value = \"org.example.notes\"|value = \"$value\"|" "$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" show
    [ "$status" -eq 2 ]
    [ ! -s "$RIG_HANDLER_FIXTURE_LOG" ]
  done
}
