#!/usr/bin/env bats

load helpers/isolate

setup() {
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  ROOT=$(cd "$BATS_TEST_TMPDIR" && pwd -P)
  export HOME=$ROOT/isolated-home
  export RIG_CONFIG_HOME=$ROOT/config
  export RIG_STATE_HOME=$ROOT/state
  export RETIRED_NATIVE_LOG=$ROOT/native.log
  export RETIRED_APP=$ROOT/Example.app
  export RETIRED_PLUTIL_VALUE=org.example.retired
  export RETIRED_MDLS_VALUE='2025-05-01 12:30:00 +0000'
  export RIG_PLUTIL=$ROOT/plutil RIG_MDLS=$ROOT/mdls
  mkdir -p "$RIG_CONFIG_HOME" "$HOME"
  : >"$RETIRED_NATIVE_LOG"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "plutil %s\n" "$*" >>"$RETIRED_NATIVE_LOG"' \
    '[ "$#" -eq 6 ] && [ "$1" = -extract ] && [ "$2" = CFBundleIdentifier ] && [ "$3" = raw ] && [ "$4" = -o ] && [ "$5" = - ] || exit 99' \
    'printf "%s\n" "$RETIRED_PLUTIL_VALUE"' 'exit "${RETIRED_PLUTIL_EXIT:-0}"' >"$RIG_PLUTIL"
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "mdls %s\n" "$*" >>"$RETIRED_NATIVE_LOG"' \
    '[ "$#" -eq 4 ] && [ "$1" = -raw ] && [ "$2" = -name ] && [ "$3" = kMDItemLastUsedDate ] || exit 99' \
    'printf "%s\n" "$RETIRED_MDLS_VALUE"' 'exit "${RETIRED_MDLS_EXIT:-0}"' >"$RIG_MDLS"
  chmod +x "$RIG_PLUTIL" "$RIG_MDLS"
  write_base
}

write_base() {
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'name = "Default"' '[profile.other]' 'name = "Other"' \
    '[profile.public]' 'name = "Public"' 'kind = "view"' >"$RIG_CONFIG_HOME/rig.toml"
}

add_retired() {
  printf '%s\n' "[retired-application.${1:-example}]" 'name = "Retired Example"' \
    "bundle-id = \"${2:-org.example.retired}\"" "application-paths = [\"$RETIRED_APP\"]" \
    >>"$RIG_CONFIG_HOME/rig.toml"
}

make_application() {
  mkdir -p "$RETIRED_APP/Contents"
  : >"$RETIRED_APP/Contents/Info.plist"
}

json_check() {
  run python3 -c 'import json,sys; data=json.loads(sys.argv[1]); exec(sys.argv[2])' "$output" "$1"
  [ "$status" -eq 0 ] || false
}

@test "retired declarations report exact matched identity and qualified last-used metadata" {
  add_retired
  make_application
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check '
app=data["retired_applications"][0]
assert app["id"]=="example" and app["bundle_id"]=="org.example.retired"
assert app["state"]=="observed"
row=app["evidence"][0]
assert row["kind"]=="application" and row["state"]=="matched"
assert row["source"]=="declared"
assert row["last_used"]["state"]=="available"
assert row["last_used"]["value"]=="2025-05-01 12:30:00 +0000"
assert row["last_used"]["source"]=="mdls:kMDItemLastUsedDate"
assert "not proof" in row["last_used"]["caveat"]
assert data["healthy"] is True
'
  [ "$(wc -l <"$RETIRED_NATIVE_LOG" | tr -d ' ')" -eq 2 ] || false
}

@test "retired application names never substitute for exact bundle identity" {
  add_retired
  make_application
  run env RETIRED_PLUTIL_VALUE=org.example.retired.similar "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'row=data["retired_applications"][0]["evidence"][0]; assert row["state"]=="mismatched"; assert row["last_used"]["state"]=="unavailable"'
  ! grep -q '^mdls ' "$RETIRED_NATIVE_LOG" || false
}

@test "absent applications and retained data remain informational and explicitly attributed" {
  add_retired
  printf '%s\n' 'data-paths = ["~/Private Data"]' 'package-paths = ["$HOME/Package Store"]' >>"$RIG_CONFIG_HOME/rig.toml"
  mkdir -p "$HOME/Private Data" "$HOME/Package Store" "$HOME/Library/Caches/org.example.retired"
  run "$RIG" status --retired --problems --format json
  [ "$status" -eq 0 ] || false
  json_check '
rows=data["retired_applications"][0]["evidence"]
assert rows[0]["state"]=="missing"
package=next(r for r in rows if r["kind"]=="package")
assert package["state"]=="present" and package["source"]=="declared"
assert "unverified" in package["reason"]
candidate=next(r for r in rows if "/Caches/" in r["detail"])
assert candidate["state"]=="present" and candidate["source"]=="bundle-id-candidate"
assert "ownership" in candidate["reason"]
assert data["healthy"] is True
'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired paths stay inside the established redactable detail boundary" {
  add_retired
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check '
def redact(x):
    if isinstance(x,dict): return {k:redact(v) for k,v in x.items() if k not in ("detail","findings","information")}
    if isinstance(x,list): return [redact(v) for v in x]
    return x
assert "/Example.app" in json.dumps(data)
assert "/Example.app" not in json.dumps(redact(data))
assert "/Library/" not in json.dumps(redact(data))
'
}

@test "retired declaration and evidence ordering is deterministic across profile selections" {
  add_retired zebra org.example.zebra
  add_retired alpha org.example.alpha
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  local first=$output
  run "$RIG" status --profile other --retired --format json
  [ "$status" -eq 0 ] || false
  run python3 -c 'import json,sys; a=json.loads(sys.argv[1])["retired_applications"]; b=json.loads(sys.argv[2])["retired_applications"]; assert a==b; assert [x["id"] for x in a]==["zebra","alpha"]' "$first" "$output"
  [ "$status" -eq 0 ] || false
}

@test "retired native identity probe absent failing and malformed results remain unavailable" {
  add_retired
  make_application
  run env RIG_PLUTIL="$ROOT/not-a-command" "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["state"]=="unavailable"'
  run env RETIRED_PLUTIL_EXIT=7 "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["state"]=="unavailable"'
  run env RETIRED_PLUTIL_VALUE=$'org.example.retired\norg.example.other' "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["state"]=="unavailable"'
  ! grep -q '^mdls ' "$RETIRED_NATIVE_LOG" || false
}

@test "retired last-used absent failed null and malformed metadata never imply never-used" {
  add_retired
  make_application
  local value
  for value in '(null)' '' 'not-a-date' $'2025-05-01 12:30:00 +0000\nextra' \
    '2025-99-99 99:99:99 +9999' '2025-02-29 12:00:00 +0000' '2025-04-31 12:00:00 +0000' \
    '2025-05-01 12:30:00 +2359' '2025-05-01 12:30:00 +1401'; do
    run env RETIRED_MDLS_VALUE="$value" "$RIG" status --retired --format json
    [ "$status" -eq 0 ] || false
    json_check 'row=data["retired_applications"][0]["evidence"][0]; assert row["state"]=="matched"; assert row["last_used"]["state"]=="unavailable"; assert "never-used" not in json.dumps(row)'
  done
  run env RETIRED_MDLS_EXIT=9 "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["last_used"]["state"]=="unavailable"'
  run env RIG_MDLS="$ROOT/not-a-command" "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["last_used"]["state"]=="unavailable"'
  run env RETIRED_MDLS_VALUE='2024-02-29 12:00:00 +0000' "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'usage=data["retired_applications"][0]["evidence"][0]["last_used"]; assert usage["state"]=="available" and usage["value"]=="2024-02-29 12:00:00 +0000"'
}

@test "retired symlink leaves and ancestors are not followed even when targets are absent" {
  add_retired
  mkdir -p "$ROOT/external"
  ln -s "$ROOT/external" "$RETIRED_APP"
  ln -s "$ROOT/missing" "$HOME/Linked"
  printf '%s\n' 'data-paths = ["~/Linked/child", "~/Linked"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'rows=data["retired_applications"][0]["evidence"]; assert rows[0]["state"]=="symlink"; assert all(r["state"]=="symlink" for r in rows if "/Linked" in r["detail"])'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired application metadata symlink is not inspected" {
  add_retired
  mkdir -p "$RETIRED_APP/Contents"
  : >"$ROOT/external-plist"
  ln -s "$ROOT/external-plist" "$RETIRED_APP/Contents/Info.plist"
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["state"]=="symlink"'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired application metadata ancestor link and missing metadata stay uncertain" {
  add_retired
  mkdir -p "$RETIRED_APP" "$ROOT/ExternalContents"
  : >"$ROOT/ExternalContents/Info.plist"
  ln -s "$ROOT/ExternalContents" "$RETIRED_APP/Contents"
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][0]["evidence"][0]["state"]=="symlink"'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
  # A second declaration names a present but metadata-free bundle.
  RETIRED_APP=$ROOT/NoMetadata.app
  mkdir -p "$RETIRED_APP"
  add_retired empty org.example.empty
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"][1]["evidence"][0]["state"]=="unavailable"'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired candidate paths are unique and explicit package associations take precedence" {
  add_retired
  printf '%s\n' 'data-paths = ["~/Library/Caches/org.example.retired", "$HOME/Library/Caches/org.example.retired"]' \
    'package-paths = ["~/Library/Containers/org.example.retired"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check '
rows=data["retired_applications"][0]["evidence"]
assert len(rows)==6
assert len({r["detail"] for r in rows})==6
assert rows[0]["kind"]=="application" and rows[1]["kind"]=="package"
assert next(r for r in rows if "/Caches/" in r["detail"])["source"]=="declared"
assert next(r for r in rows if "/Containers/" in r["detail"])["kind"]=="package"
'
}

@test "retired inaccessible ancestry differs from missing paths" {
  add_retired
  mkdir -p "$HOME/Locked"
  printf '%s\n' 'data-paths = ["~/Locked/unknown", "~/Absent/unknown"]' >>"$RIG_CONFIG_HOME/rig.toml"
  chmod 000 "$HOME/Locked"
  if [ -x "$HOME/Locked" ]; then chmod 700 "$HOME/Locked"; skip 'runner bypasses directory permissions'; fi
  run "$RIG" status --retired --format json
  local result=$status
  chmod 700 "$HOME/Locked"
  [ "$result" -eq 0 ] || false
  json_check 'rows=data["retired_applications"][0]["evidence"]; assert next(r for r in rows if "/Locked/" in r["detail"])["state"]=="inaccessible"; assert next(r for r in rows if "/Absent/" in r["detail"])["state"]=="missing"'
}

@test "retired observation on Linux reports unsupported without native probes" {
  add_retired
  make_application
  run env RIG_PLATFORM=linux "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'app=data["retired_applications"][0]; assert app["state"]=="unavailable"; assert "unsupported" in app["detail"].lower(); assert all(r["state"]=="unavailable" for r in app["evidence"])'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired schema requires identity name and at least one application location" {
  local field
  for field in name bundle-id application-paths; do
    write_base
    printf '%s\n' '[retired-application.example]' >>"$RIG_CONFIG_HOME/rig.toml"
    [ "$field" = name ] || printf '%s\n' 'name = "Example"' >>"$RIG_CONFIG_HOME/rig.toml"
    [ "$field" = bundle-id ] || printf '%s\n' 'bundle-id = "org.example.retired"' >>"$RIG_CONFIG_HOME/rig.toml"
    [ "$field" = application-paths ] || printf '%s\n' "application-paths = [\"$RETIRED_APP\"]" >>"$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" status --retired
    [ "$status" -eq 2 ] || false
    [[ "$output" == *"$field"* ]] || false
  done
  write_base
  printf '%s\n' '[retired-application.example]' 'name = "Example"' 'bundle-id = "org.example.retired"' 'application-paths = []' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --retired
  [ "$status" -eq 2 ] || false
  write_base
  printf '%s\n' '[retired-application.example]' 'name = ""' 'bundle-id = "org.example.retired"' \
    "application-paths = [\"$RETIRED_APP\"]" >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --retired
  [ "$status" -eq 2 ] || false
}

@test "retired schema rejects duplicate identity and install or profile fields" {
  add_retired first
  add_retired second
  run "$RIG" status --retired
  [ "$status" -eq 2 ] || false
  local field
  for field in install.provider profile tools; do
    write_base
    add_retired
    printf '%s\n' "$field = \"anything\"" >>"$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" status --retired
    [ "$status" -eq 2 ] || false
    [[ "$output" == *"$field"* ]] || false
  done
}

@test "retired unsafe paths are rejected without evaluating shell syntax" {
  local path
  for path in '/' '~/' '$HOME/' 'relative/path' '/a/../b' '/a/./b' '/a//b' '/a/' '/a/*' '/a/?' '/a/[ab]' '/a/$USER' '/a/`id`' '/a/$(id)'; do
    write_base
    printf '%s\n' '[retired-application.example]' 'name = "Example"' 'bundle-id = "org.example.retired"' \
      "application-paths = [\"$path\"]" >>"$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" status --retired
    [ "$status" -eq 2 ] || false
  done
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired identity rejects path-like and malformed bundle identifiers" {
  local identity
  for identity in '../outside' 'org/example/app' 'org.example.*' 'org.example app' '$HOME' ''; do
    write_base
    printf '%s\n' '[retired-application.example]' 'name = "Example"' "bundle-id = \"$identity\"" \
      "application-paths = [\"$RETIRED_APP\"]" >>"$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" status --retired
    [ "$status" -eq 2 ] || false
  done
}

@test "retired declarations do not alter ordinary status doctor or public export" {
  run "$RIG" status
  [ "$status" -eq 0 ] || false
  local original_status=$output
  run "$RIG" export --profile public --output "$ROOT/export-before"
  [ "$status" -eq 0 ] || false
  add_retired
  make_application
  run "$RIG" status
  [ "$status" -eq 0 ] || false
  [ "$output" = "$original_status" ] || false
  run "$RIG" export --profile public --output "$ROOT/export-after"
  [ "$status" -eq 0 ] || false
  diff -r "$ROOT/export-before" "$ROOT/export-after" || false
  run "$RIG" doctor --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" != *'org.example.retired'* ]] || false
  [[ "$output" != *'Retired Example'* ]] || false
  json_check 'assert data["healthy"] is True'
  run "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert "retired_applications" not in data'
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired status and dry-run plans do not change retained files or write state" {
  add_retired
  make_application
  printf '%s\n' 'data-paths = ["~/Retained/file"]' >>"$RIG_CONFIG_HOME/rig.toml"
  mkdir -p "$HOME/Retained"
  printf '%s\n' 'private retained bytes' >"$HOME/Retained/file"
  cp "$HOME/Retained/file" "$ROOT/expected"
  run "$RIG" status --retired
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'Retired Example'* ]] || false
  [[ "$output" == *'org.example.retired'* ]] || false
  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ] || false
  [[ "$output" != *'Retired Example'* ]] || false
  run "$RIG" upgrade --dry-run
  [ "$status" -eq 0 ] || false
  [[ "$output" != *'Retired Example'* ]] || false
  cmp "$HOME/Retained/file" "$ROOT/expected" || false
  [ -f "$RETIRED_APP/Contents/Info.plist" ] || false
  [ ! -e "$RIG_STATE_HOME" ] || false
  [ ! -s "$RIG_TEST_PROVIDER_LOG" ] || false
}

@test "retired empty catalogue emits an empty opt-in array and other commands reject the flag" {
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  json_check 'assert data["retired_applications"]==[]'
  run "$RIG" doctor --retired
  [ "$status" -eq 2 ] || false
  run "$RIG" apply --retired --dry-run
  [ "$status" -eq 2 ] || false
}

@test "retired human rows stay bounded while JSON retains complete long identities and paths" {
  local long_name long_path
  long_name=$(printf '%180s' x | tr ' ' x)
  long_path=$HOME/$(printf '%180s' y | tr ' ' y)
  printf '%s\n' '[retired-application.example]' "name = \"$long_name\"" \
    'bundle-id = "org.example.retired"' "application-paths = [\"$long_path\"]" >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --retired
  [ "$status" -eq 0 ] || false
  printf '%s\n' "$output" | awk 'length($0) > 120 { exit 1 }' || false
  run "$RIG" status --retired --format json
  [ "$status" -eq 0 ] || false
  run python3 -c 'import json,sys; app=json.loads(sys.argv[1])["retired_applications"][0]; assert app["name"]==sys.argv[2]; assert app["evidence"][0]["detail"]==sys.argv[3]' "$output" "$long_name" "$long_path"
  [ "$status" -eq 0 ] || false
}

@test "retired control-bearing names are rejected before terminal output" {
  local name
  for name in 'line\nbreak' 'line\rreturn' 'line\bbackspace' $'line\033escape'; do
    write_base
    printf '%s\n' '[retired-application.example]' "name = \"$name\"" \
      'bundle-id = "org.example.retired"' "application-paths = [\"$RETIRED_APP\"]" >>"$RIG_CONFIG_HOME/rig.toml"
    run "$RIG" status --retired
    [ "$status" -eq 2 ] || false
  done
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}

@test "retired informational evidence coexists with real status problems without changing their verdict" {
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "%s\n" "$*" >>"$RIG_TEST_PROVIDER_LOG"' \
    '[ "$1" = rig-provider-v1 ] && [ "$2" = observe ] || exit 99' \
    'printf "%s\n" missing' >"$ROOT/observer"
  chmod +x "$ROOT/observer"
  printf '%s\n' '[category.core]' 'name = "Core"' 'purpose = "Fixture"' \
    '[tool.active]' 'name = "Active"' 'category = "core"' 'purpose = "Fixture"' \
    'rationale = "Keep findings independent"' 'platforms = ["any"]' \
    'install.provider = "observer"' 'install.kind = "package"' 'install.locator = "active"' \
    '[provider.observer]' 'adapter = "custom"' "executable = \"$ROOT/observer\"" 'capabilities = ["observe"]' \
    >"$RIG_CONFIG_HOME/active.toml"
  mkdir -p "$RIG_CONFIG_HOME/conf.d"
  mv "$RIG_CONFIG_HOME/active.toml" "$RIG_CONFIG_HOME/conf.d/active.toml"
  # The default complete profile selects all active tools but no retired entry.
  add_retired
  run "$RIG" status --problems --format json
  [ "$status" -eq 1 ] || false
  local ordinary=$output
  run "$RIG" status --retired --problems --format json
  [ "$status" -eq 1 ] || false
  run python3 -c 'import json,sys; a=json.loads(sys.argv[1]); b=json.loads(sys.argv[2]); assert a["summary"]==b["summary"]; assert a["tools"]==b["tools"]; assert a["healthy"] is b["healthy"] is False; assert b["retired_applications"][0]["id"]=="example"' "$ordinary" "$output"
  [ "$status" -eq 0 ] || false
  [ ! -s "$RETIRED_NATIVE_LOG" ] || false
}
