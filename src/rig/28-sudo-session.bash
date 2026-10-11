# rig-module: 28-sudo-session
# shellcheck shell=bash
# Cross-module apply state is intentionally shared.
# shellcheck disable=SC2034
RIG_SUDO_KEEPER_PID=
RIG_SUDO_FAILED=0

rig_sudo_cleanup() {
  local keeper
  keeper=${RIG_SUDO_KEEPER_PID:-}
  RIG_SUDO_KEEPER_PID=
  if [ -n "$keeper" ]; then
    kill -TERM "$keeper" 2>/dev/null || true
    wait "$keeper" 2>/dev/null || true
  fi
}

rig_sudo_guard() {
  [ "${RIG_SUDO_FAILED:-0}" -eq 0 ] || {
    rig_sudo_cleanup
    printf 'rig: administrator session refresh failed; no further tasks dispatched.\n' >&2
    rig_outcome_note incomplete 'administrator-session-refresh-failed'
    return 1
  }
}

rig_sudo_start() {
  local dry_run index tool binding provider needed executable interval owner
  dry_run=$1
  needed=0
  if [ "$dry_run" -eq 1 ]; then
    printf 'Administrator session: preview only; no authentication.\n'
    return 0
  fi
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    if [ -n "$binding" ] && ! rig_application_apply_skip "$tool" "$binding" "$provider"; then needed=1; fi
    index=$((index + 1))
  done
  if [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ] || [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ] ||
    [ "${#RIG_STALE_RESOURCE_IDS[@]}" -gt 0 ]; then needed=1; fi
  if [ "$needed" -eq 0 ]; then
    printf 'Administrator session: no prompt needed; no native work requires the requested grant.\n'
    return 0
  fi
  [ -t 0 ] || { rig_fail 'apply --sudo requires an attended terminal'; return 1; }
  executable=${RIG_SUDO:-sudo}
  rig_executable_available "$executable" || { rig_fail 'sudo executable unavailable'; return 1; }
  interval=${RIG_SUDO_REFRESH_SECONDS:-30}
  case "$interval" in ''|*[!0-9]*|???*) rig_fail 'RIG_SUDO_REFRESH_SECONDS must be an integer from 1 to 60'; return 2 ;; esac
  [ "$interval" -ge 1 ] && [ "$interval" -le 60 ] || { rig_fail 'RIG_SUDO_REFRESH_SECONDS must be an integer from 1 to 60'; return 2; }
  # Bash 3.2 lacks BASHPID. The transient /bin/sh is a child of the command
  # substitution, whose parent is this captured backend shell (not main's $$).
  owner=$(/bin/sh -c 'ps -p "$PPID" -o ppid=') || return 1
  owner=${owner//[[:space:]]/}
  case "$owner" in ''|0|*[!0-9]*) rig_fail 'cannot identify administrator-session owner'; return 1 ;; esac
  rig_progress_cleanup
  printf 'rig: authorise administrator rights once for this attended run.\n' >&2
  "$executable" -v || { rig_outcome_note incomplete 'administrator-authorisation-refused'; return 1; }
  "$executable" -n -v </dev/null || { rig_outcome_note incomplete 'administrator-grant-not-reusable'; return 1; }
  RIG_SUDO_FAILED=0
  trap 'RIG_SUDO_FAILED=1' USR1
  (
    sleeper=
    trap 'if [ -n "$sleeper" ]; then kill "$sleeper" 2>/dev/null || true; wait "$sleeper" 2>/dev/null || true; fi' EXIT
    trap 'exit 0' HUP INT TERM
    while kill -0 "$owner" 2>/dev/null; do
      sleep "$interval" &
      sleeper=$!
      if ! wait "$sleeper"; then
        kill -USR1 "$owner" 2>/dev/null || true
        exit 1
      fi
      sleeper=
      kill -0 "$owner" 2>/dev/null || exit 0
      if ! "$executable" -n -v </dev/null; then
        kill -USR1 "$owner" 2>/dev/null || true
        exit 1
      fi
    done
  ) </dev/null >/dev/null 2>&1 &
  RIG_SUDO_KEEPER_PID=$!
  printf 'Administrator session: native grant refreshed during this run.\n'
}
