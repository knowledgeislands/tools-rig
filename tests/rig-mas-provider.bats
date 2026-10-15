#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  CONFIG_HOME=$BATS_TEST_TMPDIR/config
  FAKE_BIN=$BATS_TEST_TMPDIR/bin
  CALL_LOG=$BATS_TEST_TMPDIR/calls
  mkdir -p "$CONFIG_HOME" "$FAKE_BIN"
  write_fake_mas
  write_fake_brew
}

write_fake_mas() {
  cat >"$FAKE_BIN/mas" <<'SCRIPT'
#!/usr/bin/env bash
printf 'mas\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$1" in
  list) printf '%s\n' '11111 Present App (1.0)' ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/mas"
}

# The Homebrew fixture installs the mas executable, so a plan can prove that
# an earlier mas formula satisfies a later App Store consumer.
write_fake_brew() {
  cat >"$FAKE_BIN/brew" <<'SCRIPT'
#!/usr/bin/env bash
printf 'brew\t%s\n' "$*" >>"$RIG_TEST_LOG"
case "$1" in
  install)
    cp "$FAKE_BIN/mas.ready" "$FAKE_BIN/mas"
    chmod +x "$FAKE_BIN/mas"
    ;;
  list) exit 1 ;;
esac
SCRIPT
  chmod +x "$FAKE_BIN/brew"
}

# write_config PROVIDER KIND declares one present and one missing App Store app.
write_config() {
  cat >"$CONFIG_HOME/rig.toml" <<EOF
[rig]
schema = 1
default-profile = "default"

[category.core]
name = "Core"
purpose = "Exercise the App Store provider"

[tool.present-app]
name = "Present App"
category = "core"
purpose = "An installed App Store application"
rationale = "Observation fixture"
platforms = ["macos"]
install.provider = "$1"
install.kind = "$2"
install.locator = "11111"

[tool.missing-app]
name = "Missing App"
category = "core"
purpose = "An absent App Store application"
rationale = "Installation fixture"
platforms = ["macos"]
install.provider = "$1"
install.kind = "$2"
install.locator = "22222"

[profile.default]
tools = ["present-app", "missing-app"]
EOF
}

run_rig() {
  run env RIG_CONFIG_HOME="$CONFIG_HOME" RIG_TEST_LOG="$CALL_LOG" \
    FAKE_BIN="$FAKE_BIN" PATH="$FAKE_BIN:$PATH" "$RIG" "$@"
}

@test "the mas provider observes and installs App Store applications through mas" {
  write_config mas app

  run_rig status </dev/null
  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'present-app\tmas\tpresent' || false
  rig_test_report_contains "$output" $'missing-app\tmas\tmissing' || false
  ! grep -Fq homebrew <<<"$output" || false

  : >"$CALL_LOG"
  run_rig apply </dev/null
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  grep -Fqx $'mas\tinstall 22222' "$CALL_LOG"
  ! grep -q '^brew' "$CALL_LOG" || false
  ! grep -Fq homebrew <<<"$output" || false

  run_rig doctor </dev/null
  ! grep -Fq 'Warnings:' <<<"$output" || false
  [[ "$output" == *' warn=0'* ]] || false
}

@test "the deprecated homebrew mas alias runs mas and names the mas provider" {
  write_config homebrew mas

  run_rig status </dev/null
  [ "$status" -eq 1 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'present-app\tmas\tpresent' || false
  rig_test_report_contains "$output" $'missing-app\tmas\tmissing' || false
  ! grep -Fq homebrew <<<"$output" || false

  : >"$CALL_LOG"
  run_rig apply </dev/null
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  grep -Fqx $'mas\tinstall 22222' "$CALL_LOG"
  ! grep -q '^brew' "$CALL_LOG" || false
  ! grep -Fq homebrew <<<"$output" || false
}

@test "doctor warns once for each deprecated homebrew mas declaration without changing the verdict" {
  write_config mas app
  run_rig doctor </dev/null
  native_status=$status
  native_verdict=$(grep '^Verdict:' <<<"$output")

  write_config homebrew mas
  run_rig doctor </dev/null
  [ "$status" -eq "$native_status" ] || { printf '%s\n' "$output" >&3; false; }
  [ "$(grep '^Verdict:' <<<"$output")" = "$native_verdict" ] || false
  [[ "$output" == *'Warnings:'* ]] || false
  [[ "$output" == *'  tool.present-app: deprecated (homebrew-mas-alias); owner=configuration; action=declare-provider-mas-kind-app'* ]] || false
  [[ "$output" == *'  tool.missing-app: deprecated (homebrew-mas-alias); owner=configuration; action=declare-provider-mas-kind-app'* ]] || false
  [[ "$output" == *' warn=2'* ]] || false

  run_rig doctor --format json </dev/null
  [ "$status" -eq "$native_status" ] || false
  [[ "$output" == *'"warn":2'* ]] || false
  [[ "$output" == *'"warnings":["tool.present-app: deprecated (homebrew-mas-alias); owner=configuration; action=declare-provider-mas-kind-app","tool.missing-app: deprecated (homebrew-mas-alias)'* ]] || false
}

@test "doctor names a deprecated variant and removal declaration" {
  cat >"$CONFIG_HOME/rig.toml" <<'EOF'
[rig]
schema = 1
default-profile = "default"

[category.core]
name = "Core"
purpose = "Exercise the App Store provider"

[tool.editor]
name = "Editor"
category = "core"
purpose = "An application with an App Store variant"
rationale = "Variant fixture"
platforms = ["macos", "linux"]
variant.native.install.provider = "uv"
variant.native.install.kind = "tool"
variant.native.install.locator = "editor"
variant.native.platforms = ["linux"]
variant.store.install.provider = "homebrew"
variant.store.install.kind = "mas"
variant.store.install.locator = "33333"
variant.store.platforms = ["macos"]

[remove.obsolete]
name = "Obsolete"
provider = "homebrew"
kind = "mas"
locator = "44444"
platforms = ["macos"]

[profile.default]
tools = ["editor"]
EOF

  run_rig doctor </dev/null
  [[ "$output" == *'  tool.editor variant store: deprecated (homebrew-mas-alias)'* ]] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'  remove.obsolete: deprecated (homebrew-mas-alias)'* ]] || false
  [[ "$output" == *' warn=2'* ]] || false
  ! grep -Fq 'tool.editor:' <<<"$output" || false

  run_rig remove </dev/null
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  rig_test_report_contains "$output" $'obsolete\tmas' || false
  ! grep -Fq homebrew <<<"$output" || false
}

@test "the mas provider rejects another kind, a non-numeric locator, Linux and a declared adapter" {
  write_config mas formula
  run_rig status </dev/null
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'mas'*'kind'* ]] || { printf '%s\n' "$output" >&3; false; }
  [ ! -e "$CALL_LOG" ] || false

  write_config mas app
  sed 's/"22222"/"missing-app"/' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edited"
  mv "$CONFIG_HOME/edited" "$CONFIG_HOME/rig.toml"
  run_rig status </dev/null
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'mas locator must be a numeric App Store application identity'* ]] || false
  [ ! -e "$CALL_LOG" ] || false

  write_config mas app
  sed '/^install.locator = "22222"/a\
install.platforms = ["linux"]' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edited"
  mv "$CONFIG_HOME/edited" "$CONFIG_HOME/rig.toml"
  run_rig status </dev/null
  [ "$status" -eq 2 ] || false
  [[ "$output" == *'mas installs App Store applications only on macOS'* ]] || { printf '%s\n' "$output" >&3; false; }
  [ ! -e "$CALL_LOG" ] || false

  write_config mas app
  printf '%s\n' '[provider.mas]' 'adapter = "custom"' >>"$CONFIG_HOME/rig.toml"
  run_rig status </dev/null
  [ "$status" -eq 2 ] || false
  [ ! -e "$CALL_LOG" ] || false
}

@test "an earlier Homebrew mas formula satisfies the mas executable in one apply" {
  mv "$FAKE_BIN/mas" "$FAKE_BIN/mas.ready"
  write_config mas app
  cat >>"$CONFIG_HOME/rig.toml" <<'EOF'

[tool.mas]
name = "mas"
category = "core"
purpose = "Mac App Store command line"
rationale = "The App Store provider runs mas"
platforms = ["macos"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "mas"
EOF
  sed -e 's/^tools = .*/tools = ["mas", "present-app", "missing-app"]/' \
    -e '/^install.locator = "11111"/a\
requires = ["mas"]' -e '/^install.locator = "22222"/a\
requires = ["mas"]' "$CONFIG_HOME/rig.toml" >"$CONFIG_HOME/edited"
  mv "$CONFIG_HOME/edited" "$CONFIG_HOME/rig.toml"

  run_rig apply </dev/null
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; cat "$CALL_LOG" >&3; false; }
  [ "$(sed -n 1p "$CALL_LOG")" = $'brew\tinstall --formula mas' ] || false
  grep -Fqx $'mas\tinstall 22222' "$CALL_LOG"
  rig_test_report_contains "$output" $'mas\thomebrew\tcompleted' || false
  rig_test_report_contains "$output" $'missing-app\tmas\tcompleted' || false
}
