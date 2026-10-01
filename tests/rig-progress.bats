#!/usr/bin/env bats

load helpers/isolate

setup() {
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  PYTHON=${RIG_TEST_PYTHON:-/usr/bin/python3}
  WRAPPER=$BATS_TEST_TMPDIR/progress-wrapper
  STDOUT=$BATS_TEST_TMPDIR/stdout
  STDERR=$BATS_TEST_TMPDIR/stderr
  export TERM=xterm-256color
}

fixture() {
  printf '%s\n' '#!/usr/bin/env bash' 'source "$1"' 'RIG_PROGRESS=auto' \
    'RIG_PROGRESS_CONTEXT=operational' 'RIG_PROGRESS_COMMAND=apply' \
    'rig_progress_selection work macos' "$@" >"$WRAPPER"
}

terminal() {
  run "$PYTHON" "$BATS_TEST_DIRNAME/helpers/tty-progress.py" \
    --stdout "$STDOUT" --stderr "$STDERR" "$@" -- /bin/bash "$WRAPPER" "$RIG"
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&3; false; }
  [[ "$output" == *'"restored": true'* ]] || { printf '%s\n' "$output" >&3; false; }
}

@test "owned footer is bottom anchored with truthful phase counts and isolated stdout" {
  fixture 'rig_progress_start applying 2 owned' 'rig_progress_begin runner:alpha declaration' \
    'rig_progress_result succeeded runner:alpha declaration' 'rig_progress_begin runner:beta declaration' \
    'rig_progress_result failed runner:beta declaration' 'rig_progress_finish' 'printf "FINAL\n"'
  terminal
  [[ "$output" == *'"status": 0'* ]] || false
  [[ "$(<"$STDERR")" == *$'\033[1;22r'* ]] || false
  [[ "$(<"$STDERR")" == *'rig: apply | work/macos | applying | 0/2'* ]] || false
  [[ "$(<"$STDERR")" == *'active: runner:beta | ok=1 skip=0 fail=0'* ]] || false
  [[ "$(<"$STDERR")" == *'active: waiting | ok=1 skip=0 fail=1'* ]] || false
  [[ "$(<"$STDERR")" == *'finished completed=2/2 succeeded=1 skipped=0 failed=1'* ]] || false
  [ "$(<"$STDOUT")" = FINAL ] || false
}

@test "default and explicit passthrough phases restore before native ANSI and partial diagnostics" {
  local ownership
  for ownership in '' passthrough; do
    fixture "rig_progress_start applying 1 $ownership" 'rig_progress_begin runner:alpha declaration' \
      'printf "NATIVE\033[1;1Hnative-ui-no-lf" >&2' \
      'rig_progress_result succeeded runner:alpha declaration' 'rig_progress_finish'
    terminal
    [[ "$output" == *'"native_full": true'* ]] || false
    [[ "$(<"$STDERR")" == *$'NATIVE\033[1;1Hnative-ui-no-lf\r\n'* ]] || false
    [[ "$(<"$STDERR")" == *'runner:alpha [declaration] running'* ]] || false
  done
}

@test "nested suspension cannot resume while an outer native operation owns the terminal" {
  fixture 'rig_progress_start applying 1 owned' 'rig_progress_begin runner:alpha' \
    'rig_progress_suspend' 'rig_progress_suspend' 'rig_progress_resume' \
    'printf "NATIVE nested-depth=%s panel=%s\n" "$RIG_PROGRESS_SUSPEND_DEPTH" "$RIG_PROGRESS_PANEL_ACTIVE" >&2' \
    'rig_progress_resize' 'rig_progress_resume' 'rig_progress_result succeeded runner:alpha' 'rig_progress_finish'
  terminal
  [[ "$output" == *'"native_full": true'* ]] || false
  [[ "$(<"$STDERR")" == *'NATIVE nested-depth=1 panel=0'* ]] || false
}

@test "native controlling tty dimensions and modes remain unchanged" {
  fixture 'before=$(stty -g </dev/tty)' 'rig_progress_start applying 1' \
    'rig_progress_begin runner:alpha' 'printf "NATIVE tty-size=" >/dev/tty' \
    'stty size </dev/tty >/dev/tty' 'rig_progress_result succeeded runner:alpha' \
    'rig_progress_finish' 'after=$(stty -g </dev/tty)' '[ "$before" = "$after" ]'
  terminal
  [[ "$output" == *'"status": 0'* ]] || false
  [[ "$output" == *'"native_full": true'* ]] || false
  # BSD stty may insert its control-descriptor warning before the size output.
  [[ "$(<"$STDERR")" == *'NATIVE tty-size='* ]] || false
  [[ "$(<"$STDERR")" == *'24 100'* ]] || false
}

@test "small and unsupported terminals use plain events without control sequences" {
  local geometry
  fixture 'rig_progress_start applying 1 owned' 'rig_progress_begin alpha declaration' \
    'rig_progress_result succeeded alpha declaration' 'rig_progress_finish'
  for geometry in '--rows 7 --columns 100' '--rows 24 --columns 59'; do
    # These fixture-only arguments deliberately contain two numeric options.
    terminal $geometry
    [[ "$output" == *'"regions": 0'* ]] || false
    [[ "$(<"$STDERR")" != *$'\033'* ]] || false
    [[ "$(<"$STDERR")" == *'alpha [declaration] running'* ]] || false
  done
  TERM=dumb terminal
  [[ "$(<"$STDERR")" != *$'\033'* ]] || false
  TERM=unrecognised-terminal terminal
  [[ "$(<"$STDERR")" != *$'\033'* ]] || false
}

@test "missing geometry falls back to plain events rather than guessing width" {
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$RIG_TEST_PROVIDER_BIN/stty"
  chmod +x "$RIG_TEST_PROVIDER_BIN/stty"
  fixture 'rig_progress_start applying 1 owned' 'rig_progress_begin alpha' \
    'rig_progress_result skipped alpha' 'rig_progress_finish'
  terminal
  [[ "$(<"$STDERR")" != *$'\033'* ]] || false
  [[ "$(<"$STDERR")" == *'skipped=1'* ]] || false
}

@test "resize remeasures at safe events and shrinking below bounds restores margins" {
  fixture 'printf "DIAGNOSTIC-SENTINEL\n" >&2' \
    'trap rig_progress_resize WINCH' 'rig_progress_start applying 2 owned' \
    'rig_progress_begin runner:alpha' 'printf "RESIZE:12:80\n"' '/bin/sleep 0.2' \
    'rig_progress_result succeeded runner:alpha' 'printf "RESIZE:6:50\n"' '/bin/sleep 0.2' \
    'rig_progress_begin runner:beta' 'rig_progress_result skipped runner:beta' 'rig_progress_finish'
  terminal
  [[ "$(<"$STDERR")" == *$'\033[1;10r'* ]] || false
  [[ "$(<"$STDERR")" != *$'\033[1;4r'* ]] || false
  [[ "$(<"$STDERR")" == *'runner:beta skipped'* ]] || false
  [[ "$output" == *'"diagnostic_survived": true'* ]] || false
  [[ "$output" == *'"resize_erase_safe": true'* ]] || false
}

@test "geometry failure after rendering restores without erasing uncertain positions" {
  export GEOMETRY_FAILED=$BATS_TEST_TMPDIR/geometry-failed
  printf '%s\n' '#!/usr/bin/env bash' '[ ! -f "$GEOMETRY_FAILED" ] || exit 1' \
    'exec /bin/stty "$@"' >"$RIG_TEST_PROVIDER_BIN/stty"
  chmod +x "$RIG_TEST_PROVIDER_BIN/stty"
  fixture 'rig_progress_start applying 1 owned' 'rig_progress_begin alpha' \
    'printf "FAIL-GEOMETRY\n" >&2' ': >"$GEOMETRY_FAILED"' \
    'rig_progress_result succeeded alpha' 'rig_progress_finish'
  terminal
  local remainder
  remainder=$(<"$STDERR")
  remainder=${remainder#*FAIL-GEOMETRY}
  [[ "$remainder" != *$'\033[2K'* ]] || false
  [[ "$remainder" == *$'\033[r'* ]] || false
}

@test "resize during native suspension never reclaims terminal early" {
  fixture 'trap rig_progress_resize WINCH' 'rig_progress_start applying 1' \
    'rig_progress_begin runner:alpha' 'printf "RESIZE:12:80\n"' '/bin/sleep 0.2' \
    'printf "NATIVE panel=%s\n" "$RIG_PROGRESS_PANEL_ACTIVE" >&2' \
    'rig_progress_result succeeded runner:alpha' 'rig_progress_finish'
  terminal
  [[ "$output" == *'"native_full": true'* ]] || false
  [[ "$(<"$STDERR")" == *'NATIVE panel=0'* ]] || false
  [[ "$(<"$STDERR")" == *$'\033[1;10r'* ]] || false
}

@test "handled signals restore footer and retain signal-compatible statuses" {
  local signal code
  for signal in INT TERM HUP; do
    case "$signal" in INT) code=130 ;; TERM) code=143 ;; HUP) code=129 ;; esac
    fixture "trap 'rig_progress_signal $code' $signal" 'rig_progress_start applying 2 owned' \
      'rig_progress_begin alpha' "printf 'SIGNAL:$signal\n'" '/bin/sleep 5'
    terminal
    [[ "$output" == *"\"status\": $code"* ]] || false
    [[ "$(<"$STDERR")" == *'interrupted completed=0/2 succeeded=0 skipped=0 failed=0'* ]] || false
  done
}

@test "cleanup is idempotent and reset forgets prior command and selection" {
  fixture 'rig_progress_start applying 1 owned' 'rig_progress_cleanup' \
    'rig_progress_cleanup' 'rig_progress_reset' \
    'printf "reset:%s:%s:%s:%s\n" "$RIG_PROGRESS_COMMAND" "$RIG_PROGRESS_PROFILE" "$RIG_PROGRESS_PLATFORM" "$RIG_PROGRESS_ACTIVE"'
  terminal
  [ "$(<"$STDOUT")" = 'reset::::0' ] || false
}

@test "invalid metadata and task control bytes never enter progress" {
  fixture 'RIG_PROGRESS_COMMAND=$'"'"'bad\033[2J'"'" \
    'rig_progress_selection $'"'"'private\033[2J'"'"' /private/path' \
    'rig_progress_start applying 1 owned' 'rig_progress_begin $'"'"'secret\033[2J'"'" \
    'rig_progress_result succeeded safe-id' 'rig_progress_finish'
  terminal
  [[ "$(<"$STDERR")" == *'rig: rig | pending | applying | 0/1'* ]] || false
  [[ "$(<"$STDERR")" != *'private'* ]] || false
  [[ "$(<"$STDERR")" != *'secret'* ]] || false
  [[ "$(<"$STDERR")" != *$'\033[2J'* ]] || false
}

@test "minimum footer width elides long identifiers without dropping counts" {
  fixture 'rig_progress_selection profile-with-a-very-long-identifier macos' \
    'rig_progress_start applying 12345 owned' \
    'rig_progress_begin runner:target-with-a-very-long-identifier' \
    'rig_progress_result failed runner:target-with-a-very-long-identifier' 'rig_progress_finish'
  terminal --rows 8 --columns 60
  local pattern='"max_frame_width": ([0-9]+)'
  [[ "$output" =~ $pattern ]] || false
  [ "${BASH_REMATCH[1]}" -le 59 ] || false
  [[ "$(<"$STDERR")" == *'| 0/12345'* ]] || false
  [[ "$(<"$STDERR")" == *'ok=0 skip=0 fail=1'* ]] || false
}

@test "redirected and explicit line events preserve format while never and queries remain quiet" {
  fixture 'rig_progress_start applying 1 owned' 'rig_progress_begin alpha declaration' \
    'rig_progress_result succeeded alpha declaration' 'rig_progress_finish'
  run /bin/bash "$WRAPPER" "$RIG"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'applying 0/1: alpha [declaration] running'* ]] || false
  [[ "$output" == *'applying 1/1: alpha [declaration] succeeded'* ]] || false
  [[ "$output" != *$'\033'* ]] || false
  fixture 'RIG_PROGRESS=lines' 'rig_progress_start applying 1 owned' \
    'rig_progress_begin alpha' 'rig_progress_result succeeded alpha' 'rig_progress_finish'
  terminal
  [[ "$output" == *'"regions": 0'* ]] || false
  fixture 'RIG_PROGRESS=never' 'rig_progress_start applying 1 owned' \
    'rig_progress_begin alpha' 'rig_progress_result succeeded alpha' 'rig_progress_finish'
  terminal
  [ ! -s "$STDERR" ] || false
  fixture 'RIG_PROGRESS_CONTEXT=query' 'rig_progress_start query 1 owned' \
    'rig_progress_begin alpha' 'rig_progress_result succeeded alpha' 'rig_progress_finish'
  terminal
  [ ! -s "$STDERR" ] || false
}
