#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  mkdir -p "$RIG_CONFIG_HOME"
  export RIG_SUDO_REFRESH_SECONDS=1
  export RIG_TEST_SUDO_LOG=$BATS_TEST_TMPDIR/sudo-log
  export RIG_TEST_TASK_LOG=$BATS_TEST_TMPDIR/task-log
  export RIG_TEST_SLEEP_LOG=$BATS_TEST_TMPDIR/sleep-log
  export RIG_TEST_SUDO_BEHAVIOUR=grant
  export RIG_TEST_TASK_BEHAVIOUR=complete
  : >"$RIG_TEST_SUDO_LOG"
  : >"$RIG_TEST_TASK_LOG"
  : >"$RIG_TEST_SLEEP_LOG"
  STDOUT=$BATS_TEST_TMPDIR/stdout
  STDERR=$BATS_TEST_TMPDIR/stderr
  export TERM=xterm-256color
  cat >"$RIG_SUDO" <<'SH'
#!/usr/bin/env bash
printf '%s|%s\n' "$PPID" "$*" >>"$RIG_TEST_SUDO_LOG"
case "$*" in
  -v) printf 'NATIVE sudo validation\n' >&2; [ "$RIG_TEST_SUDO_BEHAVIOUR" != refuse ]; exit $? ;;
  '-n -v')
    [ "$RIG_TEST_SUDO_BEHAVIOUR" != unusable ] || exit 1
    if [ "$RIG_TEST_SUDO_BEHAVIOUR" = expire ]; then
      [ ! -e "$0.validated" ] || exit 1
      : >"$0.validated"
    fi
    exit 0 ;;
  *) exit 99 ;;
esac
SH
  cat >"$RIG_TEST_PROVIDER_BIN/sleep" <<'SH'
#!/usr/bin/env bash
printf '%s|%s\n' "$$" "$PPID" >>"$RIG_TEST_SLEEP_LOG"
exec /bin/sleep "$@"
SH
  chmod +x "$RIG_SUDO" "$RIG_TEST_PROVIDER_BIN/sleep"
}

write_config() {
  local resource_members
  resource_members=
  [ "${1:-}" != resource ] || resource_members='settings = ["fixture"]'
  cat >"$RIG_TEST_PROVIDER_BIN/fixture" <<'SH'
#!/usr/bin/env bash
[ "$1" = rig-provider-v1 ] || exit 99
case "$2" in
  observe) printf 'present\n' ;;
  apply)
    printf '%s\n' "$4" >>"$RIG_TEST_TASK_LOG"
    if [ "$4" = first ]; then
      case "$RIG_TEST_TASK_BEHAVIOUR" in
        complete) /bin/sleep 1.4 ;;
        fail) exit 7 ;;
        HUP|INT|TERM|KILL) kill -"$RIG_TEST_TASK_BEHAVIOUR" "$PPID"; /bin/sleep 0.2 ;;
      esac
    fi
    ;;
  *) exit 99 ;;
esac
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/fixture"
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[category.core]
name = "Core"
purpose = "Fixture"
[profile.default]
tools = ["first", "second"]
$resource_members
[tool.first]
name = "First"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
install.provider = "fixture"
install.kind = "executable"
install.locator = "first"
[tool.second]
name = "Second"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
install.provider = "fixture"
install.kind = "executable"
install.locator = "second"
[provider.fixture]
adapter = "custom"
executable = "$RIG_TEST_PROVIDER_BIN/fixture"
capabilities = ["observe", "apply"]
TOML
  if [ "${1:-}" = resource ]; then
    cat >>"$RIG_CONFIG_HOME/rig.toml" <<'TOML'
[setting.fixture]
name = "Fixture"
purpose = "Fixture"
rationale = "Fixture"
provider = "macos-defaults"
domain = "org.rig.fixture"
key = "Fixture"
value-type = "bool"
value = "true"
platforms = ["macos"]
TOML
  fi
}

terminal() {
  run /usr/bin/python3 "$BATS_TEST_DIRNAME/helpers/tty-progress.py" \
    --stdout "$STDOUT" --stderr "$STDERR" --reply unused -- "$RIG" "$@"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'"restored": true'* ]] || false
}

assert_stopped() {
  local pid ignored before
  before=$(wc -l <"$RIG_TEST_SUDO_LOG")
  /bin/sleep 1.1
  [ "$(wc -l <"$RIG_TEST_SUDO_LOG")" = "$before" ]
  while IFS='|' read -r pid ignored; do
    ! kill -0 "$pid" 2>/dev/null || false
  done <"$RIG_TEST_SLEEP_LOG"
}

@test "attended sudo validates once refreshes noninteractively and cleans up normally" {
  write_config resource
  export RIG_PROGRESS=auto
  terminal apply --sudo
  [[ "$output" == *'"native_full": true'* ]] || false
  [[ "$output" == *'"status": 0'* ]] || false
  [ "$(/usr/bin/grep -c '|-v$' "$RIG_TEST_SUDO_LOG")" = 1 ]
  [ "$(/usr/bin/grep -c '|-n -v$' "$RIG_TEST_SUDO_LOG")" -ge 2 ]
  [ "$(cat "$RIG_TEST_TASK_LOG")" = $'first\nsecond' ]
  [ ! -d "$HOME/.local/state/rig/reconciliation/macos.lock" ]
  assert_stopped
}

@test "sudo refusal and unusable native grant dispatch no tasks" {
  write_config
  for behaviour in refuse unusable; do
    export RIG_TEST_SUDO_BEHAVIOUR=$behaviour
    terminal apply --sudo
    [[ "$output" == *'"status": 1'* ]] || false
    [ ! -s "$RIG_TEST_TASK_LOG" ]
    [ ! -s "$RIG_TEST_SLEEP_LOG" ]
  done
}

@test "sudo requires an attended terminal and never authenticates redirected runs" {
  write_config
  run "$RIG" apply --sudo </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *'requires an attended terminal'* ]] || false
  [ ! -s "$RIG_TEST_SUDO_LOG" ]
  [ ! -s "$RIG_TEST_TASK_LOG" ]
}

@test "dry run ordinary apply and empty selection never acquire a sudo grant" {
  write_config
  run "$RIG" apply --sudo --dry-run
  [ "$status" -eq 0 ]
  run "$RIG" apply
  [ "$status" -eq 0 ]
  [ ! -s "$RIG_TEST_SUDO_LOG" ]
  printf '[rig]\ndefault-profile = "default"\n[profile.default]\nname = "Empty"\n' >"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --sudo
  [ "$status" -eq 0 ]
  [[ "$output" == *'no prompt needed'* ]] || false
  [ ! -s "$RIG_TEST_SUDO_LOG" ]
}

@test "refresh failure settles inflight work then stops further dispatch and cleans up" {
  write_config resource
  export RIG_TEST_SUDO_BEHAVIOUR=expire
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [ "$(cat "$RIG_TEST_TASK_LOG")" = first ]
  [[ "$(cat "$STDERR")" == *'no further tasks dispatched'* ]] || false
  [ ! -d "$HOME/.local/state/rig/reconciliation/macos.lock" ]
  assert_stopped
}

@test "native failure cleans up the owned keeper and retains an incomplete outcome" {
  write_config
  export RIG_TEST_TASK_BEHAVIOUR=fail
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [[ "$(cat "$STDOUT")" == *'exit:7'* ]] || false
  assert_stopped
}

@test "HUP INT and TERM stop refresh and release reconciliation ownership" {
  write_config resource
  for signal in HUP INT TERM; do
    export RIG_TEST_TASK_BEHAVIOUR=$signal
    : >"$RIG_TEST_TASK_LOG"
    : >"$RIG_TEST_SLEEP_LOG"
    terminal apply --sudo
    case "$signal" in HUP) expected=129 ;; INT) expected=130 ;; TERM) expected=143 ;; esac
    [[ "$output" == *"\"status\": $expected"* ]] || false
    [ "$(cat "$RIG_TEST_TASK_LOG")" = first ]
    [ ! -d "$HOME/.local/state/rig/reconciliation/macos.lock" ]
    [ ! -d "$HOME/.local/state/rig/operation/macos.lock" ]
    assert_stopped
  done
}

@test "sudo refresh interval rejects invalid input before native authentication" {
  write_config
  export RIG_SUDO_REFRESH_SECONDS=0
  terminal apply --sudo
  [[ "$output" == *'"status": 2'* ]] || false
  [ ! -s "$RIG_TEST_SUDO_LOG" ]
  [ ! -s "$RIG_TEST_TASK_LOG" ]
  run "$RIG" upgrade --sudo
  [ "$status" -eq 2 ]
}

@test "healthy self-updating applications require no sudo session" {
  rig_test_provider brew
  APP=$HOME/Applications/Subject.app
  mkdir -p "$APP/Contents/MacOS"
  printf '<plist><dict/></plist>\n' >"$APP/Contents/Info.plist"
  printf '#!/bin/sh\nexit 0\n' >"$APP/Contents/MacOS/Subject"
  chmod +x "$APP/Contents/MacOS/Subject"
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[profile.default]
tools = ["subject"]
[category.core]
name = "Core"
purpose = "Fixture"
[tool.subject]
name = "Subject"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
updates = "self"
artifacts = ["$APP"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "subject"
TOML
  rig_test_provider_response brew 'list --cask --versions subject' 1 -
  rig_test_provider_response brew '--caskroom subject' 0 "$BATS_TEST_TMPDIR/absent"
  run "$RIG" apply --sudo
  [ "$status" -eq 0 ]
  [[ "$output" == *'no prompt needed'* ]] || false
  [ ! -s "$RIG_TEST_SUDO_LOG" ]
}

@test "keeper stops when its backend owner dies without a catchable exit" {
  write_config
  export RIG_TEST_TASK_BEHAVIOUR=KILL
  terminal apply --sudo
  [[ "$output" == *'"status": 137'* ]] || false
  [ "$(cat "$RIG_TEST_TASK_LOG")" = first ]
  assert_stopped
}
