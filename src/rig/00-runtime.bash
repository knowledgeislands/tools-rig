#!/usr/bin/env bash

# Indexed arrays intentionally use explicit arithmetic indexes throughout.
# The parser reads a path held in $file but never writes to that path.
# Cross-module globals are intentionally initialised and consumed after assembly.
# shellcheck disable=SC2004,SC2034,SC2094

# Rig — declarative description and manager of a working setup.

RIG_VERSION=0.3.0
RIG_CAPTURE_ERROR=0
RIG_CAPTURED_ERROR=

# Indexed arrays keep the installed executable compatible with macOS Bash 3.2.
RIG_SECTION_NAMES=()
RIG_SECTION_TYPES=()
RIG_SECTION_IDS=()
RIG_SECTION_SECONDARY_IDS=()
RIG_SECTION_FIELD_STARTS=()
RIG_SECTION_FIELD_ENDS=()
RIG_SECTION_DECLARED_STARTS=()
RIG_SECTION_DECLARED_ENDS=()
RIG_SECTION_LOOKUP_NAMES=()
RIG_SECTION_LOOKUP_INDICES=()
RIG_FIELD_SECTIONS=()
RIG_FIELD_KEYS=()
RIG_FIELD_VALUES=()
RIG_SELECTED_TOOLS=()
RIG_SELECTED_SKILLS=()
RIG_SELECTED_BINDINGS=()
RIG_SELECTED_VARIANTS=()
RIG_SELECTED_RESOURCE_SECTIONS=()
RIG_SELECTED_PORTS=()
RIG_ACTIVE_PROFILES=()
RIG_PLAN_TOOLS=()
RIG_PLAN_BINDINGS=()
RIG_PLAN_PROVIDERS=()
RIG_PLAN_RESULTS=()
RIG_PLAN_DETAILS=()
RIG_PLAN_STATES=()
RIG_RESOURCE_PLAN_SECTIONS=()
RIG_RESOURCE_PLAN_RESULTS=()
RIG_RESOURCE_PLAN_DETAILS=()
RIG_RESOURCE_PLAN_STATES=()
RIG_RESOURCE_PREFLIGHT_DETAILS=()
RIG_STALE_RESOURCE_PROVIDERS=()
RIG_STALE_RESOURCE_KINDS=()
RIG_STALE_RESOURCE_IDS=()
RIG_STALE_RESOURCE_LOCATORS=()
RIG_INVOKE_ARGUMENTS=()
RIG_VISIT_NAMES=()
RIG_VISIT_STATES=()
RIG_QUERY_ITEMS=()
RIG_DECLARED_FIELD_KEYS=()
RIG_PORT_STATES=()
RIG_PORT_DETAILS=()
RIG_SKILL_STATES=()
RIG_SKILL_DETAILS=()
RIG_SKILL_RESULTS=()
RIG_SKILL_PREFLIGHT_DETAILS=()
RIG_SKILL_PLANNED=0
RIG_SKILL_COMPLETED=0
RIG_SKILL_FAILED=0
RIG_SKILL_SKIPPED=0
RIG_SKILLS_INVENTORY_NAMES=()
RIG_SKILLS_INVENTORY_SOURCES=()
RIG_SKILLS_INVENTORY_AGENTS=()
RIG_SKILLS_INVENTORY_LOADED=0
RIG_SKILLS_INVENTORY_STATUS=
RIG_SKILLS_INVENTORY_DETAIL=
RIG_LISTENER_PORTS=()
RIG_LISTENER_SCOPES=()
RIG_LISTENER_COMMANDS=()
RIG_LISTENER_PIDS=()
RIG_LISTENER_ARGVS=()
RIG_OBSERVATION_CACHE_KEYS=()
RIG_OBSERVATION_CACHE_OUTPUTS=()
RIG_OBSERVATION_CACHE_STATUSES=()
RIG_VALUE=
RIG_INDEX=
RIG_COUNT=0
RIG_RESOLVED_PROFILE=
RIG_RESOLVED_PLATFORM=
RIG_INVOKED_PATH=
RIG_RESOURCE_PREFLIGHT_DETAIL=
RIG_PUBLICATION_PLATFORM_NEUTRAL=0
RIG_PROGRESS_ACTIVE=0
RIG_PROGRESS_CURRENT=0
RIG_PROGRESS_LABEL=
RIG_PROGRESS_TOTAL=0
RIG_PROGRESS_ITEM=
RIG_PROGRESS_SCOPE=
RIG_PROGRESS_SUCCEEDED=0
RIG_PROGRESS_SKIPPED=0
RIG_PROGRESS_FAILED=0
RIG_PROGRESS_CONTEXT=query
RIG_PROGRESS_RENDER=off
RIG_PROGRESS_PASSTHROUGH=0
RIG_PROGRESS_COMMAND=
RIG_PROGRESS_PROFILE=
RIG_PROGRESS_PLATFORM=
RIG_PROGRESS_COLUMNS=
RIG_PROGRESS_ROWS=
RIG_PROGRESS_PANEL_ACTIVE=0
RIG_PROGRESS_PANEL_ROWS=0
RIG_PROGRESS_PANEL_COLUMNS=0
RIG_PROGRESS_SUSPEND_DEPTH=0
RIG_PROGRESS_ITEM_SUSPENDED=0
RIG_PROGRESS_DIRTY=1
RIG_OUTCOME_RESULT=
RIG_OUTCOME_DETAIL=
RIG_PROFILE_SELECTION_MODE=
RIG_RESOLVED_PROFILE_KIND=
RIG_RECONCILIATION_LOCK=
RIG_RECONCILIATION_LOCK_ACQUIRED=0
RIG_APPLY_ALLOW_DEFERRED_SKILLS=0
RIG_APPLY_ALLOW_DEFERRED_PROVIDERS=0
RIG_LISTENER_OBSERVATION_AVAILABLE=0
RIG_UNATTENDED=0
RIG_APPLY_TARGETS=()
RIG_APPLY_DIRECT=()

print_help() {
  printf '%s\n' \
    'Usage: rig [options] [command]' \
    '' \
    "Describe and manage a person's working setup." \
    '' \
    'Options:' \
    '  -h, --help            Show this help.' \
    '  -V, --version         Print the Rig release or development version.' \
    '' \
    'Commands:' \
    '  init        Create a minimal Rig configuration.' \
    '  show        Describe the selected setup or one declared item.' \
    '  status      Compare expected and observed tool, skill, and resource state.' \
    '  capture     Discover installed items and propose additive declarations.' \
    '  apply       Materialise the selected setup and its prerequisites.' \
    '  upgrade     Upgrade selected provider-managed tools and skills.' \
    '  doctor      Check whether Rig can operate; --verbose adds diagnostics.' \
    '  export      Generate public Rig data.' \
    '  help        Show this help.' \
    '  completion  Print shell completion source.' \
    '' \
    "Run 'rig COMMAND --help' for command usage."
}

rig_command_options() {
  # name | value placeholder | purpose | completion values | required
  # This is the authored option inventory for help, usage and both completions.
  case "$1" in
    init) printf '%s\n' '--dry-run||Preview the configuration without writing it.||' ;;
    show) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--all||Browse all catalogue tools.||' '--category|ID|Limit tools to a category.|category id|' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    completion) ;;
    status) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--problems||Show only entries needing attention.||' '--unmanaged||Include observed items not declared by an installation.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    doctor) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--verbose||Include runtime and configuration diagnostics.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    apply) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--scope|SCOPE|Restrict to tools, skills, resources, or all.|tools skills resources all|' '--target|ID|Apply one selected entry; repeat for several targets.||' '--dry-run||Print the plan without invoking providers.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    upgrade) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--dry-run||Print the plan without invoking providers.||' '--unattended||Give native stdin EOF, skip App Store upgrades, and record outcomes.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    capture) printf '%s\n' '--provider|NAME|Select an inventory provider.|homebrew|' '--profile|NAME|Select the profile for proposed membership.|profile name|' '--dry-run||Inspect and preview without writing a proposal.||' '--output|PATH|Write a new proposal outside active configuration.|path|' '--category|ID|Declare the category for selected items.|category id|' '--purpose|TEXT|Declare the purpose for selected items.|text|' '--rationale|TEXT|Declare the rationale for selected items.|text|' ;;
    export) printf '%s\n' '--profile|NAME|Select the view profile to export.|profile name|required' '--output|DIRECTORY|Write the public data tree here.|directory|required' '--title|TEXT|Set the exported document title.|title|' '--base-url|URL|Set the published document canonical URL.|url|' ;;
  esac
}

rig_command_positionals() {
  case "$1" in
    show) printf ' [ITEM]' ;;
    capture) printf ' [ITEM...]' ;;
    completion) printf ' bash|zsh' ;;
  esac
}

rig_command_usage() {
  local option value description choices required
  printf 'Usage: rig %s' "$1"
  rig_command_positionals "$1"
  while IFS='|' read -r option value description choices required; do
    [ -n "$option" ] || continue
    case "$choices" in
      'text json') value='text|json' ;;
      'tools skills resources all') value='tools|skills|resources|all' ;;
    esac
    if [ -n "$required" ]; then
      printf ' %s %s' "$option" "$value"
    elif [ -n "$value" ]; then
      printf ' [%s %s]' "$option" "$value"
    else
      printf ' [%s]' "$option"
    fi
  done < <(rig_command_options "$1")
  printf '\n'
}

rig_command_syntax_error() {
  local usage
  usage=$(rig_command_usage "$1")
  syntax_error "usage: ${usage#Usage: }"
}

rig_command_help() {
  local command option value description choices required
  command=$1
  rig_command_usage "$command"
  if [ "$command" = apply ]; then
    printf '%s\n' '' 'Reconciles the selection; applying resources may restart applications mid-run.'
    printf '%s\n' 'Records apply outcomes; later success clears the matching historical failure.'
  fi
  case "$command" in
    status|doctor)
      printf '%s\n' '' 'Shows selected historical apply failures separately from current observations.' ;;
  esac
  if [ "$command" = upgrade ]; then
      printf '%s\n' '' 'Interactive progress uses a footer on supported terminals and yields for native work.'
    printf '%s\n' 'Unattended mode sets Homebrew NONINTERACTIVE=1; native failures keep their results.' \
      'It does not prevent terminal or graphical authentication or impose a time limit.'
  fi
  printf '%s\n' '' 'Options:' '  -h, --help  Show command help.'
  while IFS='|' read -r option value description choices required; do
    [ -n "$option" ] || continue
    printf '  %-20s %s\n' "$option${value:+ $value}" "$description"
  done < <(rig_command_options "$command")
  case "$command" in
    init|status|doctor|apply|upgrade|capture|export)
      printf '%s\n' '' 'Exit status: 0 on success, 1 on an operational problem, 2 on usage error.' ;;
  esac
  printf '\nExample: rig %s\n' "$(rig_command_example "$command")"
}

rig_command_example() {
  case "$1" in
    init) printf 'init --dry-run' ;;
    show) printf 'show tool-name' ;;
    status) printf 'status --problems' ;;
    doctor) printf 'doctor --verbose' ;;
    apply) printf 'apply --dry-run' ;;
    upgrade) printf 'upgrade --dry-run' ;;
    capture) printf 'capture --provider homebrew --dry-run' ;;
    export) printf 'export --profile public --output ./public' ;;
    completion) printf 'completion bash' ;;
  esac
}

syntax_error() {
  printf 'rig: error: %s\n' "$1" >&2
  print_help >&2
  return 2
}

rig_json_escape() {
  local value escaped index character code
  local LC_ALL=C

  value=$1
  escaped=
  index=0
  while [ "$index" -lt "${#value}" ]; do
    character=${value:$index:1}
    case "$character" in
      '"') escaped="${escaped}\\\"" ;;
      \\) escaped="${escaped}\\\\" ;;
      $'\b') escaped=$escaped'\b' ;;
      $'\f') escaped=$escaped'\f' ;;
      $'\n') escaped=$escaped'\n' ;;
      $'\r') escaped=$escaped'\r' ;;
      $'\t') escaped=$escaped'\t' ;;
      *)
        printf -v code '%d' "'$character"
        if [ "$code" -ge 0 ] && [ "$code" -lt 32 ]; then
          printf -v character '\\u%04x' "$code"
        fi
        escaped=$escaped$character
        ;;
    esac
    index=$((index + 1))
  done
  RIG_VALUE=$escaped
}

rig_json_field() {
  local separator

  separator=$1
  rig_json_escape "$3"
  printf '%s"%s":"%s"' "$separator" "$2" "$RIG_VALUE"
}

rig_fail() {
  rig_progress_fail
  if [ "${RIG_CAPTURE_ERROR:-0}" -eq 1 ]; then
    RIG_CAPTURED_ERROR=$1
    return 2
  fi
  printf 'rig: error: %s\n' "$1" >&2
  return 2
}

rig_outcome_enabled() {
  case "${RIG_OUTCOME:-auto}" in
    always) return 0 ;;
    never) return 1 ;;
    auto|'') [ -t 2 ] ;;
    *) [ -t 2 ] ;;
  esac
}

rig_outcome_note() {
  RIG_OUTCOME_RESULT=$1
  RIG_OUTCOME_DETAIL=${2:-}
}

rig_outcome_report() {
  local command_name status result

  command_name=$1
  status=$2
  # A status-2 rejection already named its cause through rig: error:, and a
  # second line after it would say less than the first.
  [ "$status" -ne 2 ] || return 0
  rig_outcome_enabled || return 0
  result=$RIG_OUTCOME_RESULT
  if [ -z "$result" ]; then
    case "$command_name" in
      status|doctor)
        if [ "$status" -eq 0 ]; then
          result=healthy
        else
          result=unhealthy
        fi
        ;;
      init|apply|upgrade|capture|export)
        if [ "$status" -eq 0 ]; then
          result=succeeded
        elif [ "$status" -eq 1 ]; then
          result=incomplete
        else
          result=failed
        fi
        ;;
      *)
        if [ "$status" -eq 0 ]; then
          result=succeeded
        else
          result=failed
        fi
        ;;
    esac
  fi
  if [ -n "$RIG_OUTCOME_DETAIL" ]; then
    printf 'rig: %s %s: status %s (%s)\n' \
      "$command_name" "$result" "$status" "$RIG_OUTCOME_DETAIL" >&2
  else
    printf 'rig: %s %s: status %s\n' "$command_name" "$result" "$status" >&2
  fi
}

rig_progress_enabled() {
  case "${RIG_PROGRESS:-auto}" in
    always|lines) return 0 ;; never) return 1 ;;
    auto|'') [ "${RIG_PROGRESS_CONTEXT:-query}" = operational ] ;;
    *) [ "${RIG_PROGRESS_CONTEXT:-query}" = operational ] && [ -t 2 ] ;;
  esac
}

rig_progress_dimensions() {
  local size rows columns extra
  RIG_PROGRESS_ROWS=; RIG_PROGRESS_COLUMNS=
  [ -t 2 ] || return 1
  size=$(stty size <&2 2>/dev/null) || return 1
  read -r rows columns extra <<< "$size"
  case "$rows:$columns" in *[!0-9:]*|:*|*:) return 1 ;; esac
  [ -z "$extra" ] && [ "${#rows}" -le 5 ] && [ "${#columns}" -le 5 ] || return 1
  rows=$((10#$rows)); columns=$((10#$columns))
  [ "$rows" -gt 0 ] && [ "$rows" -le 4096 ] && [ "$columns" -gt 0 ] && [ "$columns" -le 16384 ] || return 1
  RIG_PROGRESS_ROWS=$rows; RIG_PROGRESS_COLUMNS=$columns
}

rig_progress_select_renderer() {
  RIG_PROGRESS_RENDER=off
  rig_progress_enabled || return 0
  RIG_PROGRESS_RENDER=lines
  [ "${RIG_PROGRESS:-auto}" != lines ] && [ -t 2 ] || return 0
  case "${TERM:-}" in xterm*|screen*|tmux*|rxvt*|vt100|vt220|linux) ;; *) return 0 ;; esac
  rig_progress_dimensions || return 0
  [ "$RIG_PROGRESS_ROWS" -ge 8 ] && [ "$RIG_PROGRESS_COLUMNS" -ge 60 ] || return 0
  RIG_PROGRESS_RENDER=footer
}

rig_progress_compact() {
  local width
  RIG_VALUE=$1; width=$2
  [ "$width" -gt 0 ] || { RIG_VALUE=; return 0; }
  if [ "${#RIG_VALUE}" -gt "$width" ]; then
    if [ "$width" -ge 4 ]; then RIG_VALUE=${RIG_VALUE:0:$((width - 3))}...
    else RIG_VALUE=${RIG_VALUE:0:$width}; fi
  fi
}

rig_progress_safe_item() {
  local value part
  local -a parts
  value=$1
  case "$value" in
    'selected plan') RIG_VALUE=$value; return 0 ;;
    'source '*)
      part=${value#source }
      case "$part" in ''|*[!0-9]*) RIG_VALUE=work ;; *) RIG_VALUE=$value ;; esac
      return 0 ;;
    'retire '*) value=${value#retire } ;;
  esac
  case "$value" in ''|*[!a-z0-9:.-]*|[.:]*|*[.:]|*..*|*::*|*.:*|*:.*) RIG_VALUE=work; return 0 ;; esac
  IFS=':.' read -r -a parts <<< "$value"
  for part in "${parts[@]}"; do rig_valid_id "$part" || { RIG_VALUE=work; return 0; }; done
  RIG_VALUE=$1
}

rig_progress_selection() {
  RIG_PROGRESS_PROFILE=; RIG_PROGRESS_PLATFORM=
  if rig_valid_id "$1"; then RIG_PROGRESS_PROFILE=$1; fi
  if rig_valid_id "$2"; then RIG_PROGRESS_PLATFORM=$2; fi
  return 0
}

rig_progress_resize() {
  # Signal traps invalidate geometry; never redraw during a native writer.
  RIG_PROGRESS_DIRTY=1
  return 0
}

rig_progress_cleanup() {
  local rows first second
  if [ "${RIG_PROGRESS_PANEL_ACTIVE:-0}" -eq 1 ]; then
    rows=$RIG_PROGRESS_PANEL_ROWS
    if ! rig_progress_dimensions; then
      # Without geometry, preserve the current output position instead of
      # erasing addresses whose ownership can no longer be established.
      printf '\0337\033[r\0338\n' >&2 || true
    elif [ "$RIG_PROGRESS_ROWS" -ne "$RIG_PROGRESS_PANEL_ROWS" ] ||
      [ "$RIG_PROGRESS_COLUMNS" -ne "$RIG_PROGRESS_PANEL_COLUMNS" ]; then
      # Resize/reflow can move previous footer rows onto diagnostics. Never
      # erase stale addresses: preserve that text as ordinary scrollback.
      printf '\033[r\033[%s;1H\n' "$RIG_PROGRESS_ROWS" >&2 || true
    else
      first=$((rows - 1)); second=$rows
      # Resetting margins homes the cursor; leave a fresh output position too.
      printf '\033[r\033[%s;1H\033[2K\033[%s;1H\033[2K\033[%s;1H' \
        "$first" "$second" "$first" >&2 || true
    fi
  fi
  RIG_PROGRESS_PANEL_ACTIVE=0; RIG_PROGRESS_PANEL_ROWS=0; RIG_PROGRESS_PANEL_COLUMNS=0
  return 0
}

rig_progress_reset() {
  rig_progress_cleanup
  RIG_PROGRESS_ACTIVE=0; RIG_PROGRESS_CURRENT=0; RIG_PROGRESS_TOTAL=0
  RIG_PROGRESS_LABEL=; RIG_PROGRESS_ITEM=; RIG_PROGRESS_SCOPE=
  RIG_PROGRESS_SUCCEEDED=0; RIG_PROGRESS_SKIPPED=0; RIG_PROGRESS_FAILED=0
  RIG_PROGRESS_RENDER=off; RIG_PROGRESS_PASSTHROUGH=0
  RIG_PROGRESS_COMMAND=; RIG_PROGRESS_PROFILE=; RIG_PROGRESS_PLATFORM=
  RIG_PROGRESS_SUSPEND_DEPTH=0; RIG_PROGRESS_ITEM_SUSPENDED=0
  RIG_PROGRESS_ROWS=; RIG_PROGRESS_COLUMNS=; RIG_PROGRESS_DIRTY=1
  return 0
}

rig_progress_footer_render() {
  local command selection phase target count outcomes width budget first second rows columns
  [ "$RIG_PROGRESS_ACTIVE" -eq 1 ] && [ "$RIG_PROGRESS_SUSPEND_DEPTH" -eq 0 ] || return 0
  rig_progress_select_renderer
  if [ "$RIG_PROGRESS_RENDER" != footer ]; then rig_progress_cleanup; return 0; fi
  rows=$RIG_PROGRESS_ROWS; columns=$RIG_PROGRESS_COLUMNS
  if [ "$RIG_PROGRESS_PANEL_ACTIVE" -eq 1 ] &&
    { [ "$rows" -ne "$RIG_PROGRESS_PANEL_ROWS" ] || [ "$columns" -ne "$RIG_PROGRESS_PANEL_COLUMNS" ]; }; then
    rig_progress_cleanup
  fi
  width=$((columns - 1))
  command=$RIG_PROGRESS_COMMAND
  case "$command" in init|show|status|capture|apply|upgrade|doctor|export|help|completion) ;; *) command=rig ;; esac
  selection=pending
  if [ -n "$RIG_PROGRESS_PROFILE" ]; then
    selection=$RIG_PROGRESS_PROFILE
    [ -z "$RIG_PROGRESS_PLATFORM" ] || selection=$selection/$RIG_PROGRESS_PLATFORM
  fi
  count="$RIG_PROGRESS_CURRENT/$RIG_PROGRESS_TOTAL"
  budget=$((width - ${#command} - ${#count} - 14))
  rig_progress_compact "$selection" "$((budget / 2))"; selection=$RIG_VALUE
  rig_progress_compact "$RIG_PROGRESS_LABEL" "$((budget - ${#selection}))"; phase=$RIG_VALUE
  first="rig: $command | $selection | $phase | $count"
  outcomes="ok=$RIG_PROGRESS_SUCCEEDED skip=$RIG_PROGRESS_SKIPPED fail=$RIG_PROGRESS_FAILED"
  target=$RIG_PROGRESS_ITEM
  [ -n "$target" ] || target=waiting
  rig_progress_compact "$target" "$((width - ${#outcomes} - 11))"; target=$RIG_VALUE
  second="active: $target | $outcomes"
  rig_progress_compact "$first" "$width"; first=$RIG_VALUE
  rig_progress_compact "$second" "$width"; second=$RIG_VALUE
  if [ "$RIG_PROGRESS_PANEL_ACTIVE" -eq 0 ]; then
    # Reserve blank rows by scrolling, never erase diagnostics or read replies.
    printf '\033[r\033[%s;1H\n\n\033[1;%sr' "$rows" "$((rows - 2))" >&2 || true
    RIG_PROGRESS_PANEL_ACTIVE=1
    RIG_PROGRESS_PANEL_ROWS=$rows; RIG_PROGRESS_PANEL_COLUMNS=$columns
  fi
  printf '\033[%s;1H\033[2K%s\033[%s;1H\033[2K%s\033[%s;1H' \
    "$((rows - 1))" "$first" "$rows" "$second" "$((rows - 2))" >&2 || true
  RIG_PROGRESS_DIRTY=0
  return 0
}

rig_progress_suspend() {
  RIG_PROGRESS_SUSPEND_DEPTH=$((RIG_PROGRESS_SUSPEND_DEPTH + 1))
  if [ "$RIG_PROGRESS_SUSPEND_DEPTH" -eq 1 ]; then rig_progress_cleanup; fi
  return 0
}

rig_progress_resume() {
  [ "$RIG_PROGRESS_SUSPEND_DEPTH" -gt 0 ] || return 0
  RIG_PROGRESS_SUSPEND_DEPTH=$((RIG_PROGRESS_SUSPEND_DEPTH - 1))
  if [ "$RIG_PROGRESS_SUSPEND_DEPTH" -eq 0 ] && [ "$RIG_PROGRESS_ACTIVE" -eq 1 ]; then
    # Native output is opaque: a separator may add a blank line after native LF.
    if [ -t 2 ] && [ "$RIG_PROGRESS_RENDER" = footer ]; then printf '\n' >&2 || true; fi
    rig_progress_footer_render
  fi
  return 0
}

rig_progress_start() {
  rig_progress_fail
  RIG_PROGRESS_ACTIVE=0; RIG_PROGRESS_CURRENT=0
  RIG_PROGRESS_LABEL=$1; RIG_PROGRESS_TOTAL=$2
  RIG_PROGRESS_ITEM=; RIG_PROGRESS_SCOPE=
  RIG_PROGRESS_SUCCEEDED=0; RIG_PROGRESS_SKIPPED=0; RIG_PROGRESS_FAILED=0
  RIG_PROGRESS_PASSTHROUGH=1
  [ "${3:-}" != owned ] || RIG_PROGRESS_PASSTHROUGH=0
  RIG_PROGRESS_SUSPEND_DEPTH=0; RIG_PROGRESS_ITEM_SUSPENDED=0
  [ "$RIG_PROGRESS_TOTAL" -gt 0 ] || return 0
  rig_progress_select_renderer
  [ "$RIG_PROGRESS_RENDER" != off ] || return 0
  RIG_PROGRESS_ACTIVE=1
  if [ "$RIG_PROGRESS_RENDER" = footer ]; then rig_progress_footer_render
  else printf 'rig: progress: %s 0/%s started\n' "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_TOTAL" >&2; fi
  return 0
}

rig_progress_begin() {
  [ "$RIG_PROGRESS_ACTIVE" -eq 1 ] || return 0
  rig_progress_safe_item "$1"; RIG_PROGRESS_ITEM=$RIG_VALUE
  case "${2:-}" in declaration|target|dependency) RIG_PROGRESS_SCOPE=$2 ;; *) RIG_PROGRESS_SCOPE= ;; esac
  if [ "$RIG_PROGRESS_RENDER" = footer ] && [ "$RIG_PROGRESS_PASSTHROUGH" -eq 0 ]; then
    rig_progress_footer_render
    [ "$RIG_PROGRESS_RENDER" = footer ] && return 0
  fi
  if [ "$RIG_PROGRESS_PASSTHROUGH" -eq 1 ] && [ "$RIG_PROGRESS_ITEM_SUSPENDED" -eq 0 ]; then
    rig_progress_suspend; RIG_PROGRESS_ITEM_SUSPENDED=1
  fi
  if [ -n "$RIG_PROGRESS_SCOPE" ]; then
    printf 'rig: progress: %s %s/%s: %s [%s] running\n' \
      "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" "$RIG_PROGRESS_ITEM" "$RIG_PROGRESS_SCOPE" >&2
  else
    printf 'rig: progress: %s %s/%s: %s running\n' \
      "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" "$RIG_PROGRESS_ITEM" >&2
  fi
  return 0
}

rig_progress_result() {
  local result item scope
  [ "$RIG_PROGRESS_ACTIVE" -eq 1 ] || return 0
  result=$1
  rig_progress_safe_item "${2:-$RIG_PROGRESS_ITEM}"; item=$RIG_VALUE
  scope=${3:-$RIG_PROGRESS_SCOPE}
  case "$scope" in declaration|target|dependency) ;; *) scope= ;; esac
  case "$result" in
    succeeded) RIG_PROGRESS_SUCCEEDED=$((RIG_PROGRESS_SUCCEEDED + 1)) ;;
    skipped) RIG_PROGRESS_SKIPPED=$((RIG_PROGRESS_SKIPPED + 1)) ;;
    failed) RIG_PROGRESS_FAILED=$((RIG_PROGRESS_FAILED + 1)) ;;
    *) return 2 ;;
  esac
  RIG_PROGRESS_CURRENT=$((RIG_PROGRESS_CURRENT + 1))
  # A completed item is not still active while receipts or later phases run.
  RIG_PROGRESS_ITEM=; RIG_PROGRESS_SCOPE=
  if [ "$RIG_PROGRESS_ITEM_SUSPENDED" -eq 1 ]; then
    RIG_PROGRESS_ITEM_SUSPENDED=0; rig_progress_resume
  else rig_progress_footer_render; fi
  if [ "$RIG_PROGRESS_RENDER" != footer ]; then
    if [ -n "$scope" ]; then
      printf 'rig: progress: %s %s/%s: %s [%s] %s\n' \
        "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" "$item" "$scope" "$result" >&2
    else
      printf 'rig: progress: %s %s/%s: %s %s\n' \
        "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" "$item" "$result" >&2
    fi
  fi
  RIG_PROGRESS_ITEM=; RIG_PROGRESS_SCOPE=
  return 0
}

rig_progress_end() {
  local state
  state=$1
  if [ "${RIG_PROGRESS_ACTIVE:-0}" -eq 1 ]; then
    rig_progress_cleanup
    if [ "$RIG_PROGRESS_SUSPEND_DEPTH" -gt 0 ] && [ -t 2 ]; then printf '\n' >&2 || true; fi
    printf 'rig: progress: %s %s completed=%s/%s succeeded=%s skipped=%s failed=%s\n' \
      "$RIG_PROGRESS_LABEL" "$state" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
      "$RIG_PROGRESS_SUCCEEDED" "$RIG_PROGRESS_SKIPPED" "$RIG_PROGRESS_FAILED" >&2 || true
  else rig_progress_cleanup; fi
  RIG_PROGRESS_ACTIVE=0; RIG_PROGRESS_ITEM=; RIG_PROGRESS_SCOPE=
  RIG_PROGRESS_SUSPEND_DEPTH=0; RIG_PROGRESS_ITEM_SUSPENDED=0
  return 0
}
rig_progress_finish() { rig_progress_end finished; }
rig_progress_fail() { rig_progress_end failed; }
rig_progress_interrupted() { rig_progress_end interrupted; }

rig_progress_signal() {
  local exit_code
  exit_code=$1
  trap - HUP INT TERM
  rig_progress_interrupted
  exit "$exit_code"
}

require_home() {
  if [ -z "${HOME:-}" ]; then
    printf '%s\n' 'rig: error: HOME is required when an XDG directory is not set' >&2
    return 1
  fi
}

rig_command_completion_words() {
  local option value description choices required
  printf '%s' '-h --help'
  while IFS='|' read -r option value description choices required; do
    [ -n "$option" ] || continue
    printf ' %s' "$option"
  done < <(rig_command_options "$1")
  while IFS='|' read -r option value description choices required; do
    case "$choices" in
      ''|'profile name'|'category id'|directory|path|text|title|url) ;;
      *) printf ' %s' "$choices" ;;
    esac
  done < <(rig_command_options "$1")
  case "$1" in
    completion) printf ' bash zsh' ;;
  esac
}

rig_command_zsh_arguments() {
  local option value description choices required
  printf " '(-h --help)'{-h,--help}'[show command help]'"
  while IFS='|' read -r option value description choices required; do
    [ -n "$option" ] || continue
    if [ -n "$choices" ] && [ "$choices" != 'profile name' ] &&
      [ "$choices" != 'category id' ] && [ "$choices" != directory ] &&
      [ "$choices" != path ] && [ "$choices" != text ] &&
      [ "$choices" != title ] && [ "$choices" != url ]; then
      printf " '%s[%s]:%s:(%s)'" "$option" "$description" "$value" "$choices"
    elif [ -n "$value" ]; then
      printf " '%s[%s]:%s:'" "$option" "$description" "$value"
    else
      printf " '%s[%s]'" "$option" "$description"
    fi
  done < <(rig_command_options "$1")
  case "$1" in
    show) printf " '1:tool, qualified skill, resource, or private port:'" ;;
    capture) printf " '*:installed item:'" ;;
    completion) printf " '1:shell:(bash zsh)'" ;;
  esac
}

print_bash_completion() {
  # The emitted completion deliberately retains runtime shell expressions.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '_rig() {' \
    '  local current command' \
    '  current=${COMP_WORDS[COMP_CWORD]}' \
    '  command=${COMP_WORDS[1]:-}' \
    '  if [ "$COMP_CWORD" -eq 1 ]; then' \
    '    COMPREPLY=($(compgen -W "-h --help -V --version init show status capture apply upgrade doctor export help completion" -- "$current"))' \
    '    return' \
    '  fi' \
    '  case "$command" in'
  local command words
  for command in init show status capture apply upgrade doctor export completion; do
    words=$(rig_command_completion_words "$command")
    # shellcheck disable=SC2016
    printf '    %s) COMPREPLY=($(compgen -W "%s" -- "$current")) ;;\n' "$command" "$words"
  done
  # shellcheck disable=SC2016
  printf '%s\n' \
    '    help) COMPREPLY=($(compgen -W "-h --help" -- "$current")) ;;' \
    '  esac' \
    '}' \
    'complete -F _rig rig'
}

print_zsh_completion() {
  # The emitted completion deliberately retains runtime shell expressions.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#compdef rig' \
    '' \
    '_rig() {' \
    '  local -a commands' \
    '  local state' \
    '  commands=(' \
    "    'init:create a minimal Rig configuration'" \
    "    'show:describe the selected setup or one declared item'" \
    "    'status:compare expected and observed state'" \
    "    'capture:discover installed items and propose additive declarations'" \
    "    'apply:materialise the selected setup and its prerequisites'" \
    "    'upgrade:upgrade selected provider-managed tools and skills'" \
    "    'doctor:check whether Rig can operate'" \
    "    'export:generate public rig data'" \
    "    'help:show help'" \
    "    'completion:print shell completion source'" \
    '  )' \
    "  _arguments '(-h --help)'{-h,--help}'[show help]' '(-V --version)'{-V,--version}'[print the Rig release or development version]' '1:command:->command' '*::argument:->argument'" \
    '  case $state in' \
    "    command) _describe -t commands 'rig command' commands ;;" \
    '    argument)' \
    '      case $words[2] in'
  local command arguments
  for command in init show status capture apply upgrade doctor export completion; do
    arguments=$(rig_command_zsh_arguments "$command")
    printf '        %s) _arguments%s ;;\n' "$command" "$arguments"
  done
  printf '%s\n' \
    "        help) _arguments '(-h --help)'{-h,--help}'[show command help]' ;;" \
    '      esac' \
    '      ;;' \
    '  esac' \
    '}' \
    '' \
    'compdef _rig rig'
}
