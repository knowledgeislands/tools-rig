#!/usr/bin/env bats

load helpers/isolate

setup() {
  rig_test_isolate
  RIG=${RIG_TEST_EXECUTABLE:-$BATS_TEST_DIRNAME/../bin/rig}
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  export RIG_STATE_HOME=$BATS_TEST_TMPDIR/state
  export HISTORY_LOG=$BATS_TEST_TMPDIR/provider.log
  LEDGER=$RIG_STATE_HOME/apply-history/macos.tsv
  mkdir -p "$RIG_CONFIG_HOME"
  PROVIDER=$BATS_TEST_TMPDIR/provider
  cat >"$PROVIDER" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HISTORY_LOG"
case "$2" in
  observe|observe-resource) printf 'present\n'; exit 0 ;;
  apply|apply-resource)
    if [ "${HISTORY_INTERRUPT_ON:-}" = "$4" ]; then kill -TERM "$PPID"; sleep 0.1; exit 0; fi
    if [ -n "${HISTORY_STARTED:-}" ]; then
      : >"$HISTORY_STARTED"
      count=0
      while [ ! -f "$HISTORY_RELEASE" ] && [ "$count" -lt 300 ]; do sleep 0.02; count=$((count + 1)); done
      [ -f "$HISTORY_RELEASE" ] || exit 98
    fi
    exit "${HISTORY_EXIT:-0}" ;;
  retire-resource) exit "${HISTORY_EXIT:-0}" ;;
esac
exit 99
SH
  chmod +x "$PROVIDER"
  printf '%s\n' '[rig]' 'schema = 1' 'default-profile = "default"' \
    '[profile.default]' 'kind = "complete"' '[profile.other]' 'kind = "complete"' \
    '[category.core]' 'name = "Core"' 'purpose = "History fixtures"' \
    '[tool.alpha]' 'name = "Alpha"' 'category = "core"' 'purpose = "Exercise history"' \
    'rationale = "Keep execution separate from presence"' 'platforms = ["any"]' \
    'install.provider = "runner"' 'install.kind = "tool"' 'install.locator = "private-alpha"' \
    '[tool.beta]' 'name = "Beta"' 'category = "core"' 'purpose = "Exercise preservation"' \
    'rationale = "Unrelated targets retain history"' 'platforms = ["any"]' \
    'install.provider = "runner"' 'install.kind = "tool"' 'install.locator = "private-beta"' \
    '[provider.runner]' 'adapter = "custom"' "executable = \"$PROVIDER\"" \
    'capabilities = ["observe", "apply", "resource-observe", "resource-apply", "resource-retire"]' \
    >"$RIG_CONFIG_HOME/rig.toml"
}

@test "failed apply stays historical while native state remains present and reads write nothing" {
  run env HISTORY_EXIT=7 "$RIG" apply --target alpha
  [ "$status" -eq 1 ] || false
  rig_test_report_contains "$output" $'alpha\trunner\tfailed\texit:7' || false
  [ -f "$LEDGER" ] || false
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"id":"alpha","provider":"runner","state":"present"'* ]] || false
  [[ "$output" == *'"historical_failure_count":1'* ]] || false
  [[ "$output" == *'"native_exit_status":7'* ]] || false
  [[ "$output" == *'"target":"tool:alpha"'* ]] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  run "$RIG" status --problems
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'Historical apply failures: 1'* ]] || false
  rig_test_report_contains "$output" $'tool:alpha\trunner' || false
  run "$RIG" doctor --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"historical_failure_count":1'* ]] || false
  [[ "$output" == *'"apply_failures":[{"target":"tool:alpha"'* ]] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  [ "$(grep -c 'rig-provider-v1 apply ' "$HISTORY_LOG")" -eq 1 ] || false
  ! grep -F 'private-alpha' "$LEDGER" || false
}

@test "success clears only matching failure and retains success ordering watermark" {
  run env HISTORY_EXIT=9 "$RIG" apply
  [ "$status" -eq 1 ] || false
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"apply_failures":[{"target":"tool:beta"'* ]] || false
  [[ "$output" == *'"historical_failure_count":1'* ]] || false
  grep -E '^tool:alpha.*[[:space:]]0$' "$LEDGER" || false
  run env HISTORY_EXIT=11 "$RIG" apply --target beta
  [ "$status" -eq 1 ] || false
  run "$RIG" status --format json
  [[ "$output" == *'"native_exit_status":11'* ]] || false
  [ "$(grep -c '^tool:beta' "$LEDGER")" -eq 1 ] || false
}

@test "dry run skipped catalogue-only and rejected targets allocate no history" {
  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ] || false
  [ ! -e "$RIG_STATE_HOME/apply-history" ] || false
  run "$RIG" apply --target absent
  [ "$status" -eq 2 ] || false
  [ ! -e "$RIG_STATE_HOME/apply-history" ] || false
  printf '%s\n' '[tool.catalogue]' 'name = "Catalogue"' 'category = "core"' \
    'purpose = "No mutation"' 'rationale = "No attempt"' 'platforms = ["any"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --target catalogue
  [ "$status" -eq 0 ] || false
  [ ! -e "$RIG_STATE_HOME/apply-history" ] || false
}

@test "provider and platform changes do not inherit failures and writes prune removed pairs" {
  run env HISTORY_EXIT=7 "$RIG" apply --target alpha
  [ "$status" -eq 1 ] || false
  run env RIG_PLATFORM=linux "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"apply_failures":[]'* ]] || false
  cp "$LEDGER" "$BATS_TEST_TMPDIR/original"
  sed -i.bak 's/rationale = "Keep execution separate from presence"/rationale = "Edited declaration"/' "$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'last-recorded-attempt/declaration-may-have-changed'* ]] || false
  sed -i.bak 's/install.provider = "runner"/install.provider = "replacement"/g' "$RIG_CONFIG_HOME/rig.toml"
  printf '%s\n' '[provider.replacement]' 'adapter = "custom"' "executable = \"$PROVIDER\"" \
    'capabilities = ["observe", "apply"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/original" || false
  run "$RIG" apply --target beta
  [ "$status" -eq 0 ] || false
  ! grep -F $'tool:alpha\trunner' "$LEDGER" || false
}

@test "doctor counts multiple historical failures separately from present tools" {
  run env HISTORY_EXIT=7 "$RIG" apply
  [ "$status" -eq 1 ] || false
  run "$RIG" doctor --format json
  [ "$status" -eq 1 ] || false
  printf '%s\n' "$output" | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["historical_failure_count"] == 2
assert d["summary"]["present"] == 2
assert d["checks"]["pass"] == 8
assert d["checks"]["fail"] == 2 and d["checks"]["skipped"] == 0
' || false
}

@test "missing history is neutral corrupt history is unavailable and never overwritten" {
  run "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  [ ! -e "$RIG_STATE_HOME/apply-history" ] || false
  mkdir -p "${LEDGER%/*}"
  printf 'corrupt\n' >"$LEDGER"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"apply_history_unavailable":"invalid-history-header"'* ]] || false
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'apply history unavailable'* ]] || false
  [ "$(cat "$LEDGER")" = corrupt ] || false
  run "$RIG" doctor
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'Apply history unavailable: invalid-history-header'* ]] || false
  [[ "$output" == *'Checks: pass=7 warn=0 fail=1 skipped=0 (unit=item)'* ]] || false
}

@test "history symlinks and foreign locks preserve evidence and native results" {
  mkdir -p "${LEDGER%/*}"
  printf 'protected\n' >"$BATS_TEST_TMPDIR/protected"
  ln -s "$BATS_TEST_TMPDIR/protected" "$LEDGER"
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'unsafe-history-file'* ]] || false
  [ "$(cat "$BATS_TEST_TMPDIR/protected")" = protected ] || false
  rm "$LEDGER"
  mkdir "${LEDGER%.tsv}.lock"
  printf 'another-owner\n' >"${LEDGER%.tsv}.lock/owner"
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'history-lock-unavailable'* ]] || false
  [ "$(cat "${LEDGER%.tsv}.lock/owner")" = another-owner ] || false
}

@test "future timestamps expose clock discrepancy and malformed timestamps are unavailable" {
  mkdir -p "${LEDGER%/*}"
  printf 'rig-apply-history\t1\t1\ntool:alpha\trunner\t1\t9999-12-31T23:59:59Z\t7\n' >"$LEDGER"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"age_seconds":null,"clock_discrepancy":true'* ]] || false
  sed -i.bak 's/9999-12-31/2025-02-30/' "$LEDGER"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'invalid-history-time'* ]] || false
}

@test "parallel unrelated outcomes merge and older failure cannot beat newer success" {
  env HISTORY_EXIT=7 "$RIG" apply --target alpha >"$BATS_TEST_TMPDIR/alpha.out" 2>&1 &
  local alpha_pid=$!
  env HISTORY_EXIT=8 "$RIG" apply --target beta >"$BATS_TEST_TMPDIR/beta.out" 2>&1 &
  local beta_pid=$!
  wait "$alpha_pid" || [ "$?" -eq 1 ] || false
  wait "$beta_pid" || [ "$?" -eq 1 ] || false
  [ "$(grep -c '^tool:' "$LEDGER")" -eq 2 ] || false
  env HISTORY_EXIT=17 HISTORY_STARTED="$BATS_TEST_TMPDIR/started" HISTORY_RELEASE="$BATS_TEST_TMPDIR/release" \
    "$RIG" apply --target alpha >"$BATS_TEST_TMPDIR/older.out" 2>&1 &
  local older_pid=$! count=0
  while [ ! -f "$BATS_TEST_TMPDIR/started" ] && [ "$count" -lt 300 ]; do sleep 0.02; count=$((count + 1)); done
  [ -f "$BATS_TEST_TMPDIR/started" ] || false
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  : >"$BATS_TEST_TMPDIR/release"
  wait "$older_pid" || [ "$?" -eq 1 ] || false
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"apply_failures":[{"target":"tool:beta"'* ]] || false
  [[ "$output" != *'"native_exit_status":17'* ]] || false
}

@test "unselected declared pairs survive reads and targeted writes while removed pairs prune only on writes" {
  run env HISTORY_EXIT=7 "$RIG" apply --target alpha
  [ "$status" -eq 1 ] || false
  sed -i.bak '/\[tool.alpha\]/a\
profiles = ["other"]\
' "$RIG_CONFIG_HOME/rig.toml"
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  run "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  run "$RIG" apply --target beta
  [ "$status" -eq 0 ] || false
  grep -F $'tool:alpha\trunner' "$LEDGER" || false
  sed -i.bak '/\[tool.alpha\]/,/\[tool.beta\]/{ /\[tool.beta\]/!d; }' "$RIG_CONFIG_HOME/rig.toml"
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  run "$RIG" status
  [ "$status" -eq 0 ] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  run "$RIG" apply --target beta
  [ "$status" -eq 0 ] || false
  ! grep -F $'tool:alpha\trunner' "$LEDGER" || false
}

@test "interruption keeps earlier completed evidence without completing the inflight attempt" {
  run env HISTORY_EXIT=7 HISTORY_INTERRUPT_ON=beta bash -c \
    'source "$1"; trap "exit 143" TERM; rig_command_apply_impl' _ "$RIG"
  [ "$status" -eq 143 ] || false
  grep -E '^tool:alpha.*[[:space:]]7$' "$LEDGER" || false
  ! grep -F 'tool:beta' "$LEDGER" || false
  [ ! -d "${LEDGER%.tsv}.lock" ] || false
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"historical_failure_count":1'* ]] || false
}

@test "malformed and oversized history is unavailable rather than silently treated healthy" {
  mkdir -p "${LEDGER%/*}"
  local malformed
  for malformed in \
    $'tool:alpha\trunner\t1\t2026-01-01T00:00:00Z\t7\ntool:alpha\trunner\t2\t2026-01-01T00:00:00Z\t8' \
    $'tool:alpha\trunner\t1\t2026-01-01T00:00:00Z\t7\ntool:beta\trunner\t1\t2026-01-01T00:00:00Z\t8' \
    $'tool:alpha\trunner\t01\t2026-01-01T00:00:00Z\t7' \
    $'tool:alpha\trunner\t3\t2026-01-01T00:00:00Z\t7' \
    $'tool:alpha\trunner\t1\t2026-01-01T00:00:00Z\t999'; do
    printf 'rig-apply-history\t1\t2\n%s\n' "$malformed" >"$LEDGER"
    run "$RIG" status --format json
    [ "$status" -eq 1 ] || false
    [[ "$output" != *'"apply_history_unavailable":null'* ]] || false
    [[ "$output" == *'"apply_failures":[]'* ]] || false
  done
  dd if=/dev/zero of="$LEDGER" bs=1048576 count=5 2>/dev/null
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'history-byte-limit'* ]] || false
  printf 'rig-apply-history\t1\t4097\n' >"$LEDGER"
  local index=1
  while [ "$index" -le 4097 ]; do
    printf 'tool:a%04d\trunner\t%d\t2026-01-01T00:00:00Z\t7\n' "$index" "$index" >>"$LEDGER"
    index=$((index + 1))
  done
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'history-row-limit'* ]] || false
}

@test "failed atomic replacement preserves valid history and does not change provider success" {
  run env HISTORY_EXIT=7 "$RIG" apply --target alpha
  [ "$status" -eq 1 ] || false
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$RIG_TEST_PROVIDER_BIN/mv"
  chmod +x "$RIG_TEST_PROVIDER_BIN/mv"
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'history-replacement-failed'* ]] || false
  rig_test_report_contains "$output" $'alpha\trunner\tcompleted' || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  [ ! -d "${LEDGER%.tsv}.lock" ] || false
}

@test "state-owned directories reject symlinks while configured ancestors remain trusted" {
  mkdir -p "$BATS_TEST_TMPDIR/real-state"
  ln -s "$BATS_TEST_TMPDIR/real-state" "$RIG_STATE_HOME"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'unsafe-state-home'* ]] || false
  run env RIG_STATE_HOME="$RIG_STATE_HOME//./" "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [ ! -d "$BATS_TEST_TMPDIR/real-state/apply-history" ] || false
  run env RIG_STATE_HOME="$RIG_STATE_HOME/trusted-child" "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [ -f "$BATS_TEST_TMPDIR/real-state/trusted-child/apply-history/macos.tsv" ] || false
}

history_resources() {
  printf '%s\n' '[service.daemon]' 'name = "Daemon"' 'purpose = "History service"' 'rationale = "Fixture"' \
    'platforms = ["macos"]' 'provider = "runner"' 'locator = "private-daemon"' \
    'desired-state = "running"' 'program = ["/unused/fixture"]' \
    '[scheduled-job.job]' 'name = "Job"' 'purpose = "History job"' 'rationale = "Fixture"' \
    'platforms = ["macos"]' 'provider = "runner"' 'locator = "private-job"' \
    'desired-state = "enabled"' 'program = ["/unused/fixture"]' 'schedule.interval = "60"' \
    >>"$RIG_CONFIG_HOME/rig.toml"
}

@test "services scheduled jobs and skill applications publish qualified outcomes" {
  history_resources
  run env HISTORY_EXIT=6 "$RIG" apply --scope resources
  [ "$status" -eq 1 ] || false
  grep -F $'service:daemon\trunner' "$LEDGER" || false
  grep -F $'scheduled-job:job\trunner' "$LEDGER" || false
  rig_test_provider skills
  rig_test_provider_response skills '--version' 0 '1.0.0'
  rig_test_provider_response skills 'add fixture/skills --global --skill demo --agent codex --yes --json' 4 '-'
  printf '%s\n' '[skill.demo]' 'name = "Demo"' 'purpose = "History skill"' 'rationale = "Fixture"' \
    'authority = "skills-cli"' 'source = "fixture/skills"' 'trust = "reviewed"' \
    'platforms = ["macos"]' 'runtimes = ["codex"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --target skill:demo
  [ "$status" -eq 1 ] || false
  grep -E '^skill:demo.*skills-cli.*[[:space:]]4$' "$LEDGER" || false
}

@test "removed resource retirement never creates history for undeclared targets" {
  history_resources
  run "$RIG" apply --scope resources
  [ "$status" -eq 0 ] || false
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  sed -i.bak '/\[service.daemon\]/,$d' "$RIG_CONFIG_HOME/rig.toml"
  run env HISTORY_EXIT=9 "$RIG" apply --scope resources
  [ "$status" -eq 1 ] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"apply_failures":[]'* ]] || false
}

@test "discarded NUL bytes and unterminated records are unavailable and preserved" {
  mkdir -p "${LEDGER%/*}"
  printf 'rig-apply-history\t1\t0\000\n' >"$LEDGER"
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  run "$RIG" apply --target alpha
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'invalid-history-bytes'* ]] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  printf 'rig-apply-history\t1\t0' >"$LEDGER"
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'invalid-history-bytes'* ]] || false
}

@test "selected preflight failures and dependent skips allocate no attempts" {
  chmod -x "$PROVIDER"
  run "$RIG" apply --target alpha
  [ "$status" -eq 2 ] || false
  [ ! -d "${LEDGER%/*}" ] || false
  chmod +x "$PROVIDER"
  sed -i.bak '/\[tool.beta\]/a\
requires = ["alpha"]\
' "$RIG_CONFIG_HOME/rig.toml"
  run env HISTORY_EXIT=7 "$RIG" apply
  [ "$status" -eq 1 ] || false
  grep -F $'tool:alpha\trunner' "$LEDGER" || false
  ! grep -F 'tool:beta' "$LEDGER" || false
  [ "$(grep -c 'rig-provider-v1 apply ' "$HISTORY_LOG")" -eq 1 ] || false
}

@test "newer inflight attempt does not hide an older completed failure" {
  env HISTORY_EXIT=7 HISTORY_STARTED="$BATS_TEST_TMPDIR/older-start" HISTORY_RELEASE="$BATS_TEST_TMPDIR/older-release" \
    "$RIG" apply --target alpha >"$BATS_TEST_TMPDIR/older.out" 2>&1 &
  local older_pid=$! count=0
  while [ ! -f "$BATS_TEST_TMPDIR/older-start" ] && [ "$count" -lt 300 ]; do sleep 0.02; count=$((count + 1)); done
  [ -f "$BATS_TEST_TMPDIR/older-start" ] || false
  env HISTORY_STARTED="$BATS_TEST_TMPDIR/newer-start" HISTORY_RELEASE="$BATS_TEST_TMPDIR/newer-release" \
    "$RIG" apply --target alpha >"$BATS_TEST_TMPDIR/newer.out" 2>&1 &
  local newer_pid=$! count=0
  while [ ! -f "$BATS_TEST_TMPDIR/newer-start" ] && [ "$count" -lt 300 ]; do sleep 0.02; count=$((count + 1)); done
  [ -f "$BATS_TEST_TMPDIR/newer-start" ] || false
  : >"$BATS_TEST_TMPDIR/older-release"
  wait "$older_pid" || [ "$?" -eq 1 ] || false
  run "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"native_exit_status":7'* ]] || false
  : >"$BATS_TEST_TMPDIR/newer-release"
  wait "$newer_pid" || false
  run "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"apply_failures":[]'* ]] || false
}

@test "native setting and Dock dispatch failures retain their qualified history" {
  printf '%s\n' '#!/usr/bin/env bash' 'exit 7' >"$RIG_DEFAULTS"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 8' >"$RIG_DOCKUTIL"
  mkdir -p "$HOME/Documents"
  printf '%s\n' '[setting.fixture]' 'name = "Fixture"' 'purpose = "Test settings"' \
    'rationale = "Isolated fixture"' 'provider = "macos-defaults"' 'domain = "fixture.domain"' \
    'key = "Enabled"' 'value-type = "bool"' 'value = "true"' 'platforms = ["macos"]' \
    '[dock.fixture]' 'name = "Fixture Dock"' 'purpose = "Test Dock"' 'rationale = "Isolated fixture"' \
    'provider = "macos-dock"' 'platforms = ["macos"]' 'items = ["folder"]' \
    '[dock-item.folder]' 'kind = "folder"' "path = \"$HOME/Documents\"" \
    >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply --target setting:fixture
  [ "$status" -eq 1 ] || false
  grep -E '^setting:fixture.*macos-defaults.*[[:space:]]7$' "$LEDGER" || false
  run "$RIG" apply --target dock:fixture
  [ "$status" -eq 1 ] || false
  grep -E '^dock:fixture.*macos-dock.*[[:space:]]8$' "$LEDGER" || false
}

@test "a full ledger refuses a new completed row without evicting prior evidence" {
  mkdir -p "${LEDGER%/*}"
  printf 'rig-apply-history\t1\t4096\n' >"$LEDGER"
  local index=1
  while [ "$index" -le 4096 ]; do
    printf 'tool:a%04d\trunner\t%d\t2026-01-01T00:00:00Z\t7\n' "$index" "$index" >>"$LEDGER"
    index=$((index + 1))
  done
  run bash -c '
    source "$1"
    RIG_RESOLVED_PLATFORM=macos
    RIG_HISTORY_DECLARED_KEYS=$'"'"'\n'"'"'
    for ((index=1; index<=4096; index++)); do
      printf -v key "tool:a%04d\trunner\n" "$index"
      RIG_HISTORY_DECLARED_KEYS=$RIG_HISTORY_DECLARED_KEYS$key
    done
    RIG_HISTORY_DECLARED_KEYS=$RIG_HISTORY_DECLARED_KEYS$'"'"'tool:znew\trunner\n'"'"'
    rig_history_begin tool:znew runner
    cp "$2" "$3"
    rig_history_complete tool:znew runner 7
    cmp "$2" "$3"
  ' _ "$RIG" "$LEDGER" "$BATS_TEST_TMPDIR/before-completion"
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'history-row-limit'* ]] || false
  [ "$(grep -c '^tool:' "$LEDGER")" -eq 4096 ] || false
}

@test "inaccessible owned directories are unavailable rather than missing history" {
  [ "$(id -u)" -ne 0 ] || skip "root bypasses directory access restrictions"
  run env HISTORY_EXIT=7 "$RIG" apply --target alpha
  [ "$status" -eq 1 ] || false
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before"
  chmod 000 "${LEDGER%/*}"
  run "$RIG" status --format json
  chmod 700 "${LEDGER%/*}"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"apply_history_unavailable":"inaccessible-history-directory"'* ]] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
  chmod 000 "$RIG_STATE_HOME"
  run "$RIG" status --format json
  chmod 700 "$RIG_STATE_HOME"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"apply_history_unavailable":"inaccessible-state-home"'* ]] || false
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before" || false
}

@test "lock release between failed mkdir and inspection is retried" {
  export HISTORY_LOCK_RACE_MARKER=$BATS_TEST_TMPDIR/lock-race
  printf '%s\n' '#!/usr/bin/env bash' \
    'for argument in "$@"; do :; done' \
    'case "$argument" in *.lock) if [ ! -e "$HISTORY_LOCK_RACE_MARKER" ]; then : >"$HISTORY_LOCK_RACE_MARKER"; exit 1; fi ;; esac' \
    'exec /bin/mkdir "$@"' >"$RIG_TEST_PROVIDER_BIN/mkdir"
  chmod +x "$RIG_TEST_PROVIDER_BIN/mkdir"
  run env HISTORY_EXIT=7 "$RIG" apply --target alpha
  [ "$status" -eq 1 ] || false
  [ -f "$HISTORY_LOCK_RACE_MARKER" ] || false
  [[ "$output" != *'apply history unavailable'* ]] || false
  grep -E '^tool:alpha.*[[:space:]]7$' "$LEDGER" || false
}

@test "missing HOME and state override makes history unavailable without provider mutation" {
  run env -u HOME -u RIG_STATE_HOME -u XDG_STATE_HOME "$RIG" status --format json
  [ "$status" -eq 1 ] || false
  [[ "$output" == *'"state":"present"'* ]] || false
  [[ "$output" == *'"apply_history_unavailable":"state-home-unavailable"'* ]] || false
  ! grep -F 'rig-provider-v1 apply' "$HISTORY_LOG" || false
  [ ! -e "$RIG_STATE_HOME" ] || false
  run env -u HOME -u XDG_STATE_HOME RIG_STATE_HOME="$RIG_STATE_HOME" "$RIG" status --format json
  [ "$status" -eq 0 ] || false
  [[ "$output" == *'"healthy":true'* ]] || false
  [[ "$output" == *'"apply_history_unavailable":null'* ]] || false
  ! grep -F 'rig-provider-v1 apply' "$HISTORY_LOG" || false
  [ ! -e "$RIG_STATE_HOME" ] || false
}
