# rig-module: 25-apply-history
# shellcheck shell=bash
# Shared history and projection arrays are consumed across authored modules.
# shellcheck disable=SC2004,SC2034

rig_history_error() {
  RIG_HISTORY_ERROR=$1
  return 1
}

rig_history_number() {
  case "$1" in ''|*[!0-9]*|0[0-9]*) return 1 ;; esac
  [ "${#1}" -le 10 ] && [ "$1" -le 2147483647 ]
}

rig_history_target_valid() {
  case "$1" in tool:*|skill:*|service:*|scheduled-job:*|setting:*|dock:*) ;; *) return 1 ;; esac
  rig_valid_id "${1#*:}"
}

rig_history_epoch() {
  local stamp year month day hour minute second leap limit days index
  local -a months
  stamp=$1
  [[ "$stamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || return 1
  year=$((10#${stamp:0:4})); month=$((10#${stamp:5:2})); day=$((10#${stamp:8:2}))
  hour=$((10#${stamp:11:2})); minute=$((10#${stamp:14:2})); second=$((10#${stamp:17:2}))
  [ "$year" -ge 1970 ] && [ "$month" -ge 1 ] && [ "$month" -le 12 ] &&
    [ "$day" -ge 1 ] && [ "$hour" -le 23 ] && [ "$minute" -le 59 ] && [ "$second" -le 59 ] || return 1
  leap=0
  if [ "$((year % 4))" -eq 0 ] && { [ "$((year % 100))" -ne 0 ] || [ "$((year % 400))" -eq 0 ]; }; then leap=1; fi
  months=(31 "$((28 + leap))" 31 30 31 30 31 31 30 31 30 31)
  limit=${months[$((month - 1))]}
  [ "$day" -le "$limit" ] || return 1
  days=$((365 * (year - 1970) + (year - 1) / 4 - 1969 / 4 - (year - 1) / 100 + 1969 / 100 + (year - 1) / 400 - 1969 / 400 + day - 1))
  index=0
  while [ "$index" -lt "$((month - 1))" ]; do days=$((days + months[index])); index=$((index + 1)); done
  RIG_HISTORY_EPOCH=$((days * 86400 + hour * 3600 + minute * 60 + second))
}

rig_history_paths() {
  local platform state_home
  platform=$1
  rig_valid_id "$platform" || { rig_history_error invalid-platform; return; }
  rig_effective_state_home || { rig_history_error state-home-unavailable; return; }
  state_home=$RIG_VALUE
  # Ancestors of the configured XDG boundary remain user-selected. Refuse
  # aliases of a symlink at the state home itself, as well as our owned subtree.
  while :; do
    case "$state_home" in /) state_home=; break ;; */) state_home=${state_home%/} ;; */.) state_home=${state_home%/.} ;; *) break ;; esac
  done
  [ -n "$state_home" ] || { rig_history_error unsafe-state-home; return; }
  if [ -L "$state_home" ] || { [ -e "$state_home" ] && [ ! -d "$state_home" ]; }; then
    rig_history_error unsafe-state-home; return
  fi
  if [ -d "$state_home" ] && { [ ! -r "$state_home" ] || [ ! -x "$state_home" ]; }; then
    rig_history_error inaccessible-state-home; return
  fi
  RIG_HISTORY_DIRECTORY=$state_home/apply-history
  RIG_HISTORY_FILE=$RIG_HISTORY_DIRECTORY/$platform.tsv
  RIG_HISTORY_LOCK=$RIG_HISTORY_DIRECTORY/$platform.lock
  if [ -L "$RIG_HISTORY_DIRECTORY" ] || { [ -e "$RIG_HISTORY_DIRECTORY" ] && [ ! -d "$RIG_HISTORY_DIRECTORY" ]; }; then
    rig_history_error unsafe-history-directory; return
  fi
  if [ -d "$RIG_HISTORY_DIRECTORY" ] && { [ ! -r "$RIG_HISTORY_DIRECTORY" ] || [ ! -x "$RIG_HISTORY_DIRECTORY" ]; }; then
    rig_history_error inaccessible-history-directory; return
  fi
  if [ -L "$RIG_HISTORY_FILE" ] || { [ -e "$RIG_HISTORY_FILE" ] && [ ! -f "$RIG_HISTORY_FILE" ]; }; then
    rig_history_error unsafe-history-file; return
  fi
}

rig_history_load() {
  local platform bytes parsed_bytes line header target provider token recorded status extra key previous tokens canonical
  local LC_ALL=C
  platform=$1
  RIG_HISTORY_ERROR=
  RIG_HISTORY_LAST_TOKEN=0
  RIG_HISTORY_KEYS=(); RIG_HISTORY_TOKENS=(); RIG_HISTORY_TIMES=(); RIG_HISTORY_STATUSES=()
  rig_history_paths "$platform" || return
  [ -e "$RIG_HISTORY_FILE" ] || return 0
  [ -r "$RIG_HISTORY_FILE" ] || { rig_history_error unreadable-history; return; }
  bytes=$(wc -c <"$RIG_HISTORY_FILE" 2>/dev/null) || { rig_history_error unreadable-history; return; }
  bytes=${bytes//[[:space:]]/}
  case "$bytes" in ''|*[!0-9]*) rig_history_error unreadable-history; return ;; esac
  [ "$bytes" -le 4194304 ] || { rig_history_error history-byte-limit; return; }
  header=0; previous=; tokens=$'\n'; parsed_bytes=0
  # Canonical ledgers end every record with LF. Byte accounting also detects
  # NUL bytes silently discarded by Bash read; corrupted evidence is not repaired.
  while IFS= read -r line; do
    parsed_bytes=$((parsed_bytes + ${#line} + 1))
    if [ "$header" -eq 0 ]; then
      case "$line" in $'rig-apply-history\t1\t'*) token=${line#$'rig-apply-history\t1\t'} ;; *) rig_history_error invalid-history-header; return ;; esac
      rig_history_number "$token" || { rig_history_error invalid-history-token; return; }
      RIG_HISTORY_LAST_TOKEN=$token; header=1; continue
    fi
    [ "${#RIG_HISTORY_KEYS[@]}" -lt 4096 ] || { rig_history_error history-row-limit; return; }
    IFS=$'\t' read -r target provider token recorded status extra <<< "$line"
    canonical=$target$'\t'$provider$'\t'$token$'\t'$recorded$'\t'$status
    if ! { [ "$line" = "$canonical" ] && [ -z "$extra" ] && rig_history_target_valid "$target" && rig_valid_id "$provider"; }; then
      rig_history_error invalid-history-row; return
    fi
    if ! { rig_history_number "$token" && [ "$token" -gt 0 ] && [ "$token" -le "$RIG_HISTORY_LAST_TOKEN" ]; }; then
      rig_history_error invalid-history-token; return
    fi
    if ! { rig_history_number "$status" && [ "$status" -le 255 ]; }; then
      rig_history_error invalid-history-exit-status; return
    fi
    rig_history_epoch "$recorded" || { rig_history_error invalid-history-time; return; }
    key=$target$'\t'$provider
    if [ -n "$previous" ] && [[ "$key" < "$previous" || "$key" = "$previous" ]]; then
      rig_history_error duplicate-or-unordered-history-key; return
    fi
    case "$tokens" in *$'\n'"$token"$'\n'*) rig_history_error duplicate-history-token; return ;; esac
    tokens=$tokens$token$'\n'; previous=$key
    RIG_HISTORY_KEYS[${#RIG_HISTORY_KEYS[@]}]=$key
    RIG_HISTORY_TOKENS[${#RIG_HISTORY_TOKENS[@]}]=$token
    RIG_HISTORY_TIMES[${#RIG_HISTORY_TIMES[@]}]=$recorded
    RIG_HISTORY_STATUSES[${#RIG_HISTORY_STATUSES[@]}]=$status
  done <"$RIG_HISTORY_FILE"
  [ "$parsed_bytes" -eq "$bytes" ] || { rig_history_error invalid-history-bytes; return; }
  [ "$header" -eq 1 ] || { rig_history_error invalid-history-header; return; }
}

rig_history_prepare() {
  local platform index section kind id provider key
  platform=$1
  RIG_HISTORY_DECLARED_KEYS=$'\n'
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    section=${RIG_SECTION_NAMES[$index]}; kind=${RIG_SECTION_TYPES[$index]}; id=${RIG_SECTION_IDS[$index]}
    key=
    case "$kind" in
      binding)
        if rig_tool_supports_platform "$id" "$platform" && rig_binding_supports_platform "$index" "$platform"; then
          key=tool:$id$'\t'${RIG_SECTION_SECONDARY_IDS[$index]}
        fi ;;
      skill)
        if rig_skill_supports_platform "$id" "$platform"; then
          rig_get_value "$section" authority || return 2; key=skill:$id$'\t'$RIG_VALUE
        fi ;;
      service|scheduled-job|setting|dock)
        if rig_resource_supports_platform "$section" "$platform"; then
          rig_get_value "$section" provider || return 2; provider=$RIG_VALUE; key=$kind:$id$'\t'$provider
        fi ;;
    esac
    [ -z "$key" ] || RIG_HISTORY_DECLARED_KEYS=$RIG_HISTORY_DECLARED_KEYS$key$'\n'
    index=$((index + 1))
  done
}

rig_history_warning() {
  printf 'rig: warning: apply history unavailable (%s); provider outcome is unchanged\n' "${RIG_HISTORY_ERROR:-persistence-failed}" >&2
}

# Transaction-local array changes intentionally remain in this short subshell.
# shellcheck disable=SC2030
rig_history_transaction() (
  local operation target provider attempt recorded native_status platform tries key index inserted bytes
  local -a keys tokens times statuses
  local -a RIG_HISTORY_KEYS RIG_HISTORY_TOKENS RIG_HISTORY_TIMES RIG_HISTORY_STATUSES
  local LC_ALL=C
  operation=$1; target=$2; provider=$3; attempt=${4:-}; recorded=${5:-}; native_status=${6:-}
  platform=$RIG_RESOLVED_PLATFORM
  # Cleanup state is subshell-global: EXIT runs after function locals unwind.
  owner=$$:$RANDOM:$RANDOM; temporary=; held=0
  umask 077
  rig_history_paths "$platform" || { rig_history_warning; exit 1; }
  mkdir -p -- "$RIG_HISTORY_DIRECTORY" 2>/dev/null || { RIG_HISTORY_ERROR=history-directory-unavailable; rig_history_warning; exit 1; }
  rig_history_paths "$platform" || { rig_history_warning; exit 1; }
  tries=0
  while ! mkdir -- "$RIG_HISTORY_LOCK" 2>/dev/null; do
    tries=$((tries + 1))
    # A contending owner may remove its directory between mkdir and this check.
    # Retry that normal release race; other non-directory obstructions time out.
    if [ "$tries" -ge 20 ] || [ -L "$RIG_HISTORY_LOCK" ]; then
      RIG_HISTORY_ERROR=history-lock-unavailable; rig_history_warning; exit 1
    fi
    sleep 0.05
  done
  held=1
  # Traps exist only in this short transaction subshell, not in the apply run.
  trap 'if [ -n "$temporary" ] && [ -f "$temporary" ] && [ ! -L "$temporary" ]; then rm -f -- "$temporary"; fi; if [ "$held" -eq 1 ] && [ ! -L "$RIG_HISTORY_LOCK" ] && [ -d "$RIG_HISTORY_LOCK" ]; then if [ -f "$RIG_HISTORY_LOCK/owner" ] && [ ! -L "$RIG_HISTORY_LOCK/owner" ] && [ "$(<"$RIG_HISTORY_LOCK/owner")" = "$owner" ]; then rm -f -- "$RIG_HISTORY_LOCK/owner"; rmdir -- "$RIG_HISTORY_LOCK" 2>/dev/null || true; elif [ ! -e "$RIG_HISTORY_LOCK/owner" ] && [ ! -L "$RIG_HISTORY_LOCK/owner" ]; then rmdir -- "$RIG_HISTORY_LOCK" 2>/dev/null || true; fi; fi' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  (set -C; printf '%s\n' "$owner" >"$RIG_HISTORY_LOCK/owner") || { RIG_HISTORY_ERROR=history-lock-owner-unavailable; rig_history_warning; exit 1; }
  rig_history_load "$platform" || { rig_history_warning; exit 1; }
  key=$target$'\t'$provider
  case "$RIG_HISTORY_DECLARED_KEYS" in *$'\n'"$key"$'\n'*) ;; *) RIG_HISTORY_ERROR=undeclared-history-target; rig_history_warning; exit 1 ;; esac
  keys=(); tokens=(); times=(); statuses=(); inserted=0; index=0
  if [ "$operation" = reserve ]; then
    [ "$RIG_HISTORY_LAST_TOKEN" -lt 2147483647 ] || { RIG_HISTORY_ERROR=history-token-exhausted; rig_history_warning; exit 1; }
    RIG_HISTORY_LAST_TOKEN=$((RIG_HISTORY_LAST_TOKEN + 1)); attempt=$RIG_HISTORY_LAST_TOKEN
  else
    if ! { rig_history_number "$attempt" && [ "$attempt" -gt 0 ] && [ "$attempt" -le "$RIG_HISTORY_LAST_TOKEN" ] &&
      rig_history_epoch "$recorded" && rig_history_number "$native_status" && [ "$native_status" -le 255 ]; }; then
      RIG_HISTORY_ERROR=invalid-history-completion; rig_history_warning; exit 1
    fi
  fi
  while [ "$index" -lt "${#RIG_HISTORY_KEYS[@]}" ]; do
    case "$RIG_HISTORY_DECLARED_KEYS" in *$'\n'"${RIG_HISTORY_KEYS[$index]}"$'\n'*) ;; *) index=$((index + 1)); continue ;; esac
    if [ "$operation" = complete ] && [ "$inserted" -eq 0 ]; then
      if [ "${RIG_HISTORY_KEYS[$index]}" = "$key" ]; then
        if [ "$attempt" -gt "${RIG_HISTORY_TOKENS[$index]}" ]; then
          RIG_HISTORY_TOKENS[$index]=$attempt; RIG_HISTORY_TIMES[$index]=$recorded; RIG_HISTORY_STATUSES[$index]=$native_status
        fi
        inserted=1
      elif [[ "$key" < "${RIG_HISTORY_KEYS[$index]}" ]]; then
        keys[${#keys[@]}]=$key; tokens[${#tokens[@]}]=$attempt; times[${#times[@]}]=$recorded; statuses[${#statuses[@]}]=$native_status
        inserted=1
      fi
    fi
    keys[${#keys[@]}]=${RIG_HISTORY_KEYS[$index]}; tokens[${#tokens[@]}]=${RIG_HISTORY_TOKENS[$index]}
    times[${#times[@]}]=${RIG_HISTORY_TIMES[$index]}; statuses[${#statuses[@]}]=${RIG_HISTORY_STATUSES[$index]}
    index=$((index + 1))
  done
  if [ "$operation" = complete ] && [ "$inserted" -eq 0 ]; then
    keys[${#keys[@]}]=$key; tokens[${#tokens[@]}]=$attempt; times[${#times[@]}]=$recorded; statuses[${#statuses[@]}]=$native_status
  fi
  [ "${#keys[@]}" -le 4096 ] || { RIG_HISTORY_ERROR=history-row-limit; rig_history_warning; exit 1; }
  temporary=$(mktemp "$RIG_HISTORY_DIRECTORY/.${platform}.XXXXXX") || { RIG_HISTORY_ERROR=history-staging-unavailable; rig_history_warning; exit 1; }
  if ! { [ -f "$temporary" ] && [ ! -L "$temporary" ]; }; then
    RIG_HISTORY_ERROR=unsafe-history-staging; rig_history_warning; exit 1
  fi
  {
    printf 'rig-apply-history\t1\t%s\n' "$RIG_HISTORY_LAST_TOKEN" || {
      RIG_HISTORY_ERROR=history-staging-write-failed; rig_history_warning; exit 1;
    }
    index=0
    while [ "$index" -lt "${#keys[@]}" ]; do
      printf '%s\t%s\t%s\t%s\n' "${keys[$index]}" "${tokens[$index]}" "${times[$index]}" "${statuses[$index]}" || {
        RIG_HISTORY_ERROR=history-staging-write-failed; rig_history_warning; exit 1;
      }
      index=$((index + 1))
    done
  } >"$temporary" || { RIG_HISTORY_ERROR=history-staging-write-failed; rig_history_warning; exit 1; }
  bytes=$(wc -c <"$temporary") || { RIG_HISTORY_ERROR=history-staging-read-failed; rig_history_warning; exit 1; }
  [ "$bytes" -le 4194304 ] || { RIG_HISTORY_ERROR=history-byte-limit; rig_history_warning; exit 1; }
  rig_history_paths "$platform" || { rig_history_warning; exit 1; }
  if ! { [ -f "$temporary" ] && [ ! -L "$temporary" ]; }; then
    RIG_HISTORY_ERROR=unsafe-history-staging; rig_history_warning; exit 1
  fi
  if ! { [ ! -L "$RIG_HISTORY_LOCK/owner" ] && [ "$(<"$RIG_HISTORY_LOCK/owner")" = "$owner" ]; }; then
    RIG_HISTORY_ERROR=history-lock-ownership-changed; rig_history_warning; exit 1
  fi
  mv -f -- "$temporary" "$RIG_HISTORY_FILE" || { RIG_HISTORY_ERROR=history-replacement-failed; rig_history_warning; exit 1; }
  temporary=
  [ "$operation" != reserve ] || printf '%s\n' "$attempt"
)

rig_history_begin() {
  RIG_HISTORY_ATTEMPT=
  if RIG_HISTORY_ATTEMPT=$(rig_history_transaction reserve "$1" "$2"); then :; else RIG_HISTORY_ATTEMPT=; fi
  return 0
}

rig_history_complete() {
  local target provider status recorded
  target=$1; provider=$2; status=$3
  [ -n "${RIG_HISTORY_ATTEMPT:-}" ] || return 0
  recorded=$(date -u +%Y-%m-%dT%H:%M:%SZ) || { RIG_HISTORY_ERROR=completion-time-unavailable; rig_history_warning; return 0; }
  rig_history_transaction complete "$target" "$provider" "$RIG_HISTORY_ATTEMPT" "$recorded" "$status" || true
  RIG_HISTORY_ATTEMPT=
}

# This projection reloads the ledger; it does not consume transaction-local copies.
# shellcheck disable=SC2031
rig_history_project() {
  local selected index key section provider now age
  RIG_APPLY_FAILURE_KEYS=(); RIG_APPLY_FAILURE_TIMES=(); RIG_APPLY_FAILURE_STATUSES=(); RIG_APPLY_FAILURE_AGES=()
  RIG_APPLY_HISTORY_UNAVAILABLE=
  if ! rig_history_load "$RIG_RESOLVED_PLATFORM"; then RIG_APPLY_HISTORY_UNAVAILABLE=$RIG_HISTORY_ERROR; return 0; fi
  selected=$'\n'
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    selected=${selected}tool:${RIG_PLAN_TOOLS[$index]}$'\t'${RIG_PLAN_PROVIDERS[$index]}$'\n'
    index=$((index + 1))
  done
  for section in "${RIG_SELECTED_SKILLS[@]+"${RIG_SELECTED_SKILLS[@]}"}"; do
    rig_get_value "skill.$section" authority || return 2
    selected=${selected}skill:$section$'\t'$RIG_VALUE$'\n'
  done
  for section in "${RIG_RESOURCE_PLAN_SECTIONS[@]+"${RIG_RESOURCE_PLAN_SECTIONS[@]}"}"; do
    rig_get_value "$section" provider || return 2; provider=$RIG_VALUE
    selected=$selected${section/./:}$'\t'$provider$'\n'
  done
  now=$(date -u +%s) || { RIG_APPLY_HISTORY_UNAVAILABLE='current-time-unavailable'; return 0; }
  case "$now" in ''|*[!0-9]*) RIG_APPLY_HISTORY_UNAVAILABLE='current-time-unavailable'; return 0 ;; esac
  index=0
  while [ "$index" -lt "${#RIG_HISTORY_KEYS[@]}" ]; do
    key=${RIG_HISTORY_KEYS[$index]}
    if [ "${RIG_HISTORY_STATUSES[$index]}" -ne 0 ]; then
      case "$selected" in *$'\n'"$key"$'\n'*)
        rig_history_epoch "${RIG_HISTORY_TIMES[$index]}" || return 2
        if [ "$RIG_HISTORY_EPOCH" -gt "$now" ]; then age=clock-discrepancy; else age=$((now - RIG_HISTORY_EPOCH)); fi
        RIG_APPLY_FAILURE_KEYS[${#RIG_APPLY_FAILURE_KEYS[@]}]=$key
        RIG_APPLY_FAILURE_TIMES[${#RIG_APPLY_FAILURE_TIMES[@]}]=${RIG_HISTORY_TIMES[$index]}
        RIG_APPLY_FAILURE_STATUSES[${#RIG_APPLY_FAILURE_STATUSES[@]}]=${RIG_HISTORY_STATUSES[$index]}
        RIG_APPLY_FAILURE_AGES[${#RIG_APPLY_FAILURE_AGES[@]}]=$age
        ;;
      esac
    fi
    index=$((index + 1))
  done
}

rig_history_healthy() {
  [ "${#RIG_APPLY_FAILURE_KEYS[@]}" -eq 0 ] && [ -z "$RIG_APPLY_HISTORY_UNAVAILABLE" ]
}

rig_history_json() {
  local index separator key age
  printf ',"apply_failures":['
  index=0; separator=
  while [ "$index" -lt "${#RIG_APPLY_FAILURE_KEYS[@]}" ]; do
    key=${RIG_APPLY_FAILURE_KEYS[$index]}; age=${RIG_APPLY_FAILURE_AGES[$index]}
    rig_json_field "$separator{" target "${key%%$'\t'*}"
    rig_json_field ',' provider "${key#*$'\t'}"
    rig_json_field ',' recorded_at "${RIG_APPLY_FAILURE_TIMES[$index]}"
    if [ "$age" = clock-discrepancy ]; then printf ',"age_seconds":null,"clock_discrepancy":true'; else printf ',"age_seconds":%s,"clock_discrepancy":false' "$age"; fi
    printf ',"native_exit_status":%s' "${RIG_APPLY_FAILURE_STATUSES[$index]}"
    rig_json_field ',' detail last-recorded-attempt/declaration-may-have-changed
    printf '}'; separator=,; index=$((index + 1))
  done
  printf '],"apply_history_unavailable":'
  if [ -n "$RIG_APPLY_HISTORY_UNAVAILABLE" ]; then rig_json_escape "$RIG_APPLY_HISTORY_UNAVAILABLE"; printf '"%s"' "$RIG_VALUE"; else printf null; fi
}

rig_history_print() {
  local index key age
  if [ -n "$RIG_APPLY_HISTORY_UNAVAILABLE" ]; then printf '\nApply history unavailable: %s\n' "$RIG_APPLY_HISTORY_UNAVAILABLE"; fi
  [ "${#RIG_APPLY_FAILURE_KEYS[@]}" -gt 0 ] || return 0
  printf '\nHistorical apply failures: %s (last recorded attempts; declarations may have changed)\n' "${#RIG_APPLY_FAILURE_KEYS[@]}"
  rig_table_reset
  rig_table_add_column TARGET 28 end keep
  rig_table_add_column PROVIDER 18 end keep
  rig_table_add_column RECORDED-UTC 20 end keep
  rig_table_add_column AGE 18 end keep
  rig_table_add_column EXIT 4 end keep
  index=0
  while [ "$index" -lt "${#RIG_APPLY_FAILURE_KEYS[@]}" ]; do
    key=${RIG_APPLY_FAILURE_KEYS[$index]}; age=${RIG_APPLY_FAILURE_AGES[$index]}
    [ "$age" = clock-discrepancy ] || age=${age}s
    rig_table_add_row "${key%%$'\t'*}" "${key#*$'\t'}" "${RIG_APPLY_FAILURE_TIMES[$index]}" "$age" "${RIG_APPLY_FAILURE_STATUSES[$index]}" || return 2
    index=$((index + 1))
  done
  rig_table_print
}
