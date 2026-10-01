#!/usr/bin/env bats

load helpers/isolate

setup() {
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  export RIG_DATA_HOME=$BATS_TEST_TMPDIR/data
  export RIG_STATE_HOME=$BATS_TEST_TMPDIR/state
  export RIG_CACHE_HOME=$BATS_TEST_TMPDIR/cache
  export CONTRACT_PROVIDER_LOG=$BATS_TEST_TMPDIR/provider.log
  export CONTRACT_PROVIDER_EXIT=0
  export RIG_OUTCOME=always
  export RIG_PROGRESS=never
  CONTRACT_PAIR=0
  CONTRACT_PROVIDER=$BATS_TEST_TMPDIR/contract-provider
  CONTRACT_WRAPPER=$BATS_TEST_TMPDIR/contract-terminal
  CONTRACT_PYTHON=${RIG_TEST_PYTHON:-/usr/bin/python3}
  mkdir -p "$RIG_CONFIG_HOME" "$RIG_DATA_HOME" "$RIG_STATE_HOME" "$RIG_CACHE_HOME"
  cat >"$RIG_TEST_PROVIDER_BIN/date" <<'SH'
#!/usr/bin/env bash
case "$*" in
  '-u +%Y-%m-%dT%H:%M:%SZ') printf '2024-01-01T00:00:00Z\n' ;;
  '-u +%s') printf '1704067200\n' ;;
  *) exit 99 ;;
esac
SH
  cat >"$CONTRACT_PROVIDER" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CONTRACT_PROVIDER_LOG"
case "$2" in
  observe) printf 'present\n' ;;
  inventory) printf 'alpha-fixture\tinstalled\n' ;;
  apply|update)
    printf 'native-stdout-sentinel\n'
    printf '\033[33mnative-stderr-no-final-LF\033[0m' >&2
    exit "$CONTRACT_PROVIDER_EXIT" ;;
  *) exit 99 ;;
esac
SH
  cat >"$CONTRACT_WRAPPER" <<'SH'
#!/usr/bin/env bash
# Only stderr stays on the PTY; stdout and actual status are separate artifacts.
[ -t 2 ] || exit 98
stty rows 24 cols 100 </dev/tty || exit 98
stty size </dev/tty >"$CONTRACT_GEOMETRY" || exit 98
export TERM=xterm-256color COLUMNS=100 LINES=24 RIG_PROGRESS=${CONTRACT_PROGRESS_MODE:-auto}
"$@" >"$CONTRACT_STDOUT"
code=$?
printf '%s\n' "$code" >"$CONTRACT_STATUS"
exit 0
SH
  chmod +x "$RIG_TEST_PROVIDER_BIN/date" "$CONTRACT_PROVIDER" "$CONTRACT_WRAPPER"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'kind = "complete"' '[profile.public]' 'kind = "view"' \
    '[category.core]' 'name = "Core"' 'purpose = "Output fixtures"' \
    '[tool.alpha]' 'name = "Alpha"' 'category = "core"' 'purpose = "Exercise reports"' \
    'rationale = "Keep terminal decoration separate"' 'platforms = ["any"]' \
    'profiles = ["default", "public"]' 'install.provider = "runner"' \
    'install.kind = "executable"' 'install.locator = "alpha-fixture"' \
    '[tool.notes]' 'name = "Notes"' 'category = "core"' 'purpose = "Catalogue only"' \
    'rationale = "No native operation"' 'platforms = ["any"]' 'profiles = ["default"]' \
    '[provider.runner]' 'adapter = "custom"' "executable = \"$CONTRACT_PROVIDER\"" \
    'capabilities = ["observe", "apply", "update", "inventory"]' >"$RIG_CONFIG_HOME/rig.toml"
  rig_test_provider brew
  rig_test_provider_response brew 'list --formula --installed-on-request --full-name' 0 'jq'
  rig_test_provider_response brew 'list --cask --full-name' 0 'firefox'
}

run_contract_terminal() {
  # Unlike script, a direct fixture PTY does not inject an EOT display when
  # the suite receives /dev/null. Keep its raw bytes outside Bats' merged output.
  run "$CONTRACT_PYTHON" -c '
import errno, os, pty, select, signal, sys, time
pid, master = pty.fork()
if pid == 0:
    os.execv("/bin/bash", ["/bin/bash"] + sys.argv[2:])
deadline = time.monotonic() + 30
prompt = os.environ.get("CONTRACT_PROMPT_SENTINEL", "").encode()
reply = os.environ.get("CONTRACT_PROMPT_REPLY", "").encode()
pending = b""
answered = False
try:
    with open(sys.argv[1], "wb") as transcript:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                os.killpg(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                sys.exit(124)
            if not select.select([master], [], [], min(remaining, 0.2))[0]:
                continue
            try:
                data = os.read(master, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    break
                raise
            if not data:
                break
            transcript.write(data)
            if prompt and not answered:
                pending = (pending + data)[-65536:]
                if prompt in pending:
                    os.write(master, reply + b"\n")
                    answered = True
    _, result = os.waitpid(pid, 0)
    if prompt and not answered:
        sys.exit(96)
    sys.exit(os.WEXITSTATUS(result) if os.WIFEXITED(result) else 128 + os.WTERMSIG(result))
finally:
    os.close(master)
' "$CONTRACT_TTY_STDERR" "$CONTRACT_WRAPPER" "$RIG" "$@"
}

assert_terminal_outcome() {
  "$CONTRACT_PYTHON" - "$BATS_TEST_DIRNAME/helpers/tty-progress.py" \
    "$CONTRACT_BASE_STDERR" "$CONTRACT_TTY_STDERR" "$1" "$2" <<'PY'
import importlib.util
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("rig_terminal_fixture", sys.argv[1])
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
baseline = Path(sys.argv[2]).read_bytes()
terminal = Path(sys.argv[3]).read_bytes()
pattern = (rb"rig: " + re.escape(sys.argv[4].encode()) + rb" [a-z-]+: status "
           + re.escape(sys.argv[5].encode()) + rb"(?: \([^\r\n]*\))?\n\Z")
match = re.search(pattern, baseline)
assert match is not None, "baseline lacks the exact final outcome and status"
outcome = match.group(0)
# Quiet cleanup may put CUP immediately before the outcome, with no preceding
# LF. Require the unchanged outcome bytes at the tail, then prove their visible
# placement instead of mistaking a raw newline boundary for a terminal row.
assert terminal.endswith(outcome[:-1] + b"\r\n"), "terminal has changed or trailing outcome output"
screen = fixture.Screen(24, 100)
screen.feed(terminal)
expected = fixture.Screen(24, 100)
expected.feed(outcome[:-1] + b"\r\n")
visible = ["".join(row).rstrip() for row in screen.cells if "".join(row).strip()]
expected_rows = ["".join(row).rstrip() for row in expected.cells if "".join(row).strip()]
assert visible[-len(expected_rows):] == expected_rows, "outcome is not the final visible output"
PY
}

compare_command() {
  local expected code command last
  expected=$1
  shift
  command=$1
  CONTRACT_PAIR=$((CONTRACT_PAIR + 1))
  CONTRACT_BASE_STDOUT=$BATS_TEST_TMPDIR/base-$CONTRACT_PAIR.out
  CONTRACT_BASE_STDERR=$BATS_TEST_TMPDIR/base-$CONTRACT_PAIR.err
  export CONTRACT_STDOUT=$BATS_TEST_TMPDIR/tty-$CONTRACT_PAIR.out
  export CONTRACT_STATUS=$BATS_TEST_TMPDIR/tty-$CONTRACT_PAIR.status
  export CONTRACT_GEOMETRY=$BATS_TEST_TMPDIR/tty-$CONTRACT_PAIR.geometry
  CONTRACT_TTY_STDERR=$BATS_TEST_TMPDIR/tty-$CONTRACT_PAIR.err
  if env RIG_PROGRESS=never "$RIG" "$@" >"$CONTRACT_BASE_STDOUT" 2>"$CONTRACT_BASE_STDERR"; then
    code=0
  else
    code=$?
  fi
  [ "$code" -eq "$expected" ] || {
    cat "$CONTRACT_BASE_STDOUT" "$CONTRACT_BASE_STDERR" >&3; false;
  }
  # Repeat creations at the same exact fixture path, not a differently named
  # path whose confirmation would legitimately differ between the two runs.
  if [ "${CONTRACT_RESET_INIT:-0}" -eq 1 ]; then
    [ "$RIG_CONFIG_HOME" = "$BATS_TEST_TMPDIR/init-config" ] || return 1
    rm "$RIG_CONFIG_HOME/rig.toml"
    rmdir "$RIG_CONFIG_HOME"
  fi
  if [ "${CONTRACT_RESET_PROPOSAL:-0}" -eq 1 ]; then
    cp "$BATS_TEST_TMPDIR/proposal.toml" "$BATS_TEST_TMPDIR/proposal-before.toml"
    rm "$BATS_TEST_TMPDIR/proposal.toml"
  fi
  run_contract_terminal "$@"
  [ "$status" -eq 0 ] || { cat "$CONTRACT_TTY_STDERR" >&3; false; }
  [ -f "$CONTRACT_STATUS" ] || { cat "$CONTRACT_TTY_STDERR" >&3; false; }
  [ "$(<"$CONTRACT_STATUS")" -eq "$expected" ] || false
  [ "$(<"$CONTRACT_GEOMETRY")" = '24 100' ] || false
  cmp "$CONTRACT_BASE_STDOUT" "$CONTRACT_STDOUT" || {
    cat "$CONTRACT_BASE_STDOUT" "$CONTRACT_STDOUT" >&3; false;
  }
  ! LC_ALL=C grep -q $'\033' "$CONTRACT_STDOUT" || false
  ! LC_ALL=C grep -q $'\r' "$CONTRACT_STDOUT" || false
  case "$command" in
    help|completion)
      [ ! -s "$CONTRACT_BASE_STDERR" ] || false
      [ ! -s "$CONTRACT_TTY_STDERR" ] || false
      ;;
    *)
      if [ "$expected" -ne 2 ]; then
        last=$(tr -d '\r' <"$CONTRACT_BASE_STDERR" | tail -n 1)
        # Existing never mode may append the outcome to unterminated native
        # stderr. Preserve that boundary, but require the outcome to be last.
        [[ "$last" == *"rig: $command "*": status $expected" ||
          "$last" == *"rig: $command "*": status $expected ("*")" ]] || false
        assert_terminal_outcome "$command" "$expected" || {
          cat "$CONTRACT_TTY_STDERR" >&3; false;
        }
      fi
      ;;
  esac
}

assert_json() {
  "$CONTRACT_PYTHON" -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data["command"] == sys.argv[2]; assert data["observed_at"] == "2024-01-01T00:00:00Z"' \
    "$CONTRACT_STDOUT" "$1" || false
}

assert_native_diagnostics() {
  local diagnostic
  for diagnostic in "$CONTRACT_BASE_STDERR" "$CONTRACT_TTY_STDERR"; do
    grep -q 'native-stdout-sentinel' "$diagnostic" || false
    grep -q 'native-stderr-no-final-LF' "$diagnostic" || false
    "$CONTRACT_PYTHON" -c 'import sys; assert b"\x1b[33mnative-stderr-no-final-LF\x1b[0m" in open(sys.argv[1], "rb").read()' "$diagnostic" || false
  done
  ! grep -q 'native-.*sentinel\|native-stderr-no-final-LF' "$CONTRACT_STDOUT" || false
}

use_upgrade_fixture() {
  local executable
  executable=$BATS_TEST_TMPDIR/upgrade-brew
  cat >"$executable" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CONTRACT_PROVIDER_LOG"
case "$*" in
  'upgrade --formula alpha-fixture'|'install --formula alpha-fixture')
    printf 'native-stdout-sentinel\n'
    printf '\033[33mnative-stderr-no-final-LF\033[0m' >&2
    exit "$CONTRACT_PROVIDER_EXIT" ;;
  *) exit 99 ;;
esac
SH
  chmod +x "$executable"
  sed -e 's/install.provider = "runner"/install.provider = "homebrew"/' \
    -e 's/install.kind = "executable"/install.kind = "formula"/' \
    "$RIG_CONFIG_HOME/rig.toml" >"$BATS_TEST_TMPDIR/upgrade-config"
  mv "$BATS_TEST_TMPDIR/upgrade-config" "$RIG_CONFIG_HOME/rig.toml"
  printf '%s\n' '[provider.homebrew]' "executable = \"$executable\"" \
    >>"$RIG_CONFIG_HOME/rig.toml"
}

@test "all configuration-free utilities and init preserve terminal-independent stdout" {
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/absent
  compare_command 0 help
  compare_command 0 completion bash
  compare_command 0 completion zsh
  [ ! -e "$CONTRACT_PROVIDER_LOG" ] || false
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/init-config
  compare_command 0 init --dry-run
  [ ! -e "$RIG_CONFIG_HOME" ] || false
  CONTRACT_RESET_INIT=1
  compare_command 0 init
  CONTRACT_RESET_INIT=0
  [ -f "$RIG_CONFIG_HOME/rig.toml" ] || false
  [ ! -e "$CONTRACT_PROVIDER_LOG" ] || false
}

@test "show tables item explanations and JSON stay quiet and byte-identical" {
  compare_command 0 show
  compare_command 0 show alpha
  compare_command 0 show --all --format json
  assert_json show
  [ ! -e "$CONTRACT_PROVIDER_LOG" ] || false
  ! LC_ALL=C grep -q $'\033' "$CONTRACT_TTY_STDERR" || false
}

@test "status and doctor preserve observations diagnostics JSON and separate history" {
  compare_command 0 status --unmanaged
  compare_command 0 status --format json
  assert_json status
  compare_command 0 doctor --verbose
  compare_command 0 doctor --verbose --format json
  assert_json doctor
  mkdir -p "$RIG_STATE_HOME/apply-history"
  printf 'rig-apply-history\t1\t1\ntool:alpha\trunner\t1\t2023-12-31T00:00:00Z\t7\n' \
    >"$RIG_STATE_HOME/apply-history/macos.tsv"
  cp "$RIG_STATE_HOME/apply-history/macos.tsv" "$BATS_TEST_TMPDIR/history-before"
  compare_command 1 status --problems
  grep -q 'Historical apply failures: 1' "$CONTRACT_STDOUT" || false
  compare_command 1 status --problems --format json
  assert_json status
  "$CONTRACT_PYTHON" -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["summary"]["unhealthy"] == 0; assert not d["healthy"]; assert d["historical_failure_count"] == 1; assert d["apply_failures"][0]["age_seconds"] == 86400' "$CONTRACT_STDOUT" || false
  compare_command 1 doctor --format json
  assert_json doctor
  cmp "$RIG_STATE_HOME/apply-history/macos.tsv" "$BATS_TEST_TMPDIR/history-before" || false
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/invalid-config
  compare_command 1 doctor
  compare_command 1 doctor --format json
  assert_json doctor
}

@test "apply and upgrade preserve previews completed JSON and native diagnostic bytes" {
  local command
  for command in apply upgrade; do
    [ "$command" != upgrade ] || use_upgrade_fixture
    compare_command 0 "$command" --dry-run
    compare_command 0 "$command" --dry-run --format json
    assert_json "$command"
    compare_command 0 "$command"
    assert_native_diagnostics
    compare_command 0 "$command" --format json
    assert_json "$command"
    assert_native_diagnostics
  done
  compare_command 0 upgrade --unattended --format json
  assert_json upgrade
  assert_native_diagnostics
  [ -f "$RIG_STATE_HOME/last-upgrade" ] || false
  export CONTRACT_PROVIDER_EXIT=7
  compare_command 1 apply --format json
  assert_json apply
  assert_native_diagnostics
  compare_command 1 upgrade --unattended
  assert_native_diagnostics
}

@test "capture discovery proposal text and output-file confirmation remain unchanged" {
  compare_command 0 capture
  compare_command 0 capture formula:jq --category core --purpose 'Query JSON' --rationale 'Small queries' --dry-run
  grep -q '^\[tool.homebrew-formula-jq\]' "$CONTRACT_STDOUT" || false
  CONTRACT_RESET_PROPOSAL=1
  compare_command 0 capture formula:jq --category core --purpose 'Query JSON' --rationale 'Small queries' --output "$BATS_TEST_TMPDIR/proposal.toml"
  CONTRACT_RESET_PROPOSAL=0
  cmp "$BATS_TEST_TMPDIR/proposal.toml" "$BATS_TEST_TMPDIR/proposal-before.toml" || false
  [ ! -e "$CONTRACT_PROVIDER_LOG" ] || false
}

@test "export keeps its confirmation separate from deterministic public artifacts" {
  compare_command 0 export --profile public --output "$BATS_TEST_TMPDIR/public"
  cp "$BATS_TEST_TMPDIR/public/rig.json" "$BATS_TEST_TMPDIR/public-before.json"
  compare_command 0 export --profile public --output "$BATS_TEST_TMPDIR/public"
  cmp "$BATS_TEST_TMPDIR/public/rig.json" "$BATS_TEST_TMPDIR/public-before.json" || false
  "$CONTRACT_PYTHON" -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["format"] == "rig-publication"; assert d["profile"]["id"] == "public"' "$BATS_TEST_TMPDIR/public/rig.json" || false
  [ ! -e "$CONTRACT_PROVIDER_LOG" ] || false
}

@test "native controlling-terminal prompts keep geometry answers and native outcomes" {
  local mode last
  cat >"$CONTRACT_PROVIDER" <<'SH'
#!/usr/bin/env bash
case "$2" in
  observe) printf 'present\n'; exit 0 ;;
  apply)
    exec 3<>/dev/tty || exit 91
    [ -t 3 ] || exit 92
    [ "$(stty size <&3)" = '24 100' ] || exit 93
    printf 'contract-native-prompt> ' >&3
    IFS= read -r answer <&3 || exit 94
    [ "$answer" = fixture-answer ] || exit 95
    [ "$(stty size <&3)" = '24 100' ] || exit 96
    printf 'native-prompt-accepted\n' >&2
    exit 7 ;;
  *) exit 99 ;;
esac
SH
  export CONTRACT_PROMPT_SENTINEL='contract-native-prompt> '
  export CONTRACT_PROMPT_REPLY=fixture-answer
  for mode in never auto; do
    export CONTRACT_PROGRESS_MODE=$mode
    export CONTRACT_STDOUT=$BATS_TEST_TMPDIR/prompt-$mode.out
    export CONTRACT_STATUS=$BATS_TEST_TMPDIR/prompt-$mode.status
    export CONTRACT_GEOMETRY=$BATS_TEST_TMPDIR/prompt-$mode.geometry
    CONTRACT_TTY_STDERR=$BATS_TEST_TMPDIR/prompt-$mode.err
    run_contract_terminal apply --format json
    [ "$status" -eq 0 ] || { cat "$CONTRACT_TTY_STDERR" >&3; false; }
    [ "$(<"$CONTRACT_STATUS")" -eq 1 ] || false
    [ "$(<"$CONTRACT_GEOMETRY")" = '24 100' ] || false
    assert_json apply
    "$CONTRACT_PYTHON" -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "exit:7" in d["report"]' "$CONTRACT_STDOUT" || false
    grep -q 'contract-native-prompt> ' "$CONTRACT_TTY_STDERR" || false
    grep -q 'native-prompt-accepted' "$CONTRACT_TTY_STDERR" || false
    ! grep -q 'contract-native-prompt\|fixture-answer\|native-prompt-accepted' "$CONTRACT_STDOUT" || false
    ! LC_ALL=C grep -q $'\033' "$CONTRACT_STDOUT" || false
    last=$(tr -d '\r' <"$CONTRACT_TTY_STDERR" | tail -n 1)
    [[ "$last" == "rig: apply "*": status 1"* ]] || false
  done
  cmp "$BATS_TEST_TMPDIR/prompt-never.out" "$BATS_TEST_TMPDIR/prompt-auto.out" || false
}
