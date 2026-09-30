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
RIG_PROGRESS_BAR=
RIG_PROGRESS_BAR_WIDTH=0
RIG_PROGRESS_BAR_MAXIMUM=48
RIG_PROGRESS_BAR_MINIMUM=8
RIG_PROGRESS_LABEL_WIDTH=20
RIG_PROGRESS_LABEL_BUDGET=20
RIG_PROGRESS_COUNT_WIDTH=7
RIG_PROGRESS_ITEM_WIDTH=28
RIG_PROGRESS_ITEM_BUDGET=28
RIG_PROGRESS_STATE_WIDTH=4
RIG_PROGRESS_COLUMNS=
RIG_OUTCOME_RESULT=
RIG_OUTCOME_DETAIL=
RIG_PROFILE_SELECTION_MODE=
RIG_RESOLVED_PROFILE_KIND=
RIG_RECONCILIATION_LOCK=
RIG_RECONCILIATION_LOCK_ACQUIRED=0
RIG_BOOTSTRAP_ALLOW_DEFERRED_SKILLS=0
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
    '  show        Describe a resolved profile with tools and skills.' \
    '  list        Browse declared catalogue tools.' \
    '  explain     Explain a declared tool, skill, resource, or private port.' \
    '  status      Compare expected and observed tool, skill, and resource state.' \
    '  doctor      Check whether Rig can operate.' \
    '  apply       Materialise a resolved profile.' \
    '  bootstrap   Materialise the bootstrap profile.' \
    '  update      Update selected provider-managed tools and skills.' \
    '  maintain    Run explicit selected-provider maintenance.' \
    '  capture     Refresh one provider-native manifest.' \
    '  run         Invoke a declared provider action.' \
    '  export      Generate public Rig data.' \
    '  diag        Print runtime and configuration diagnostics.' \
    '  completion  Print shell completion source.' \
    '  help        Show this help.' \
    '' \
    "Run 'rig COMMAND --help' for command usage."
}

rig_command_options() {
  # name | value placeholder | purpose | completion values | required
  # This is the authored option inventory for help, usage and both completions.
  case "$1" in
    show) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    list) printf '%s\n' '--category|ID|Limit the catalogue to a category.|category id|' '--profile|NAME|Select a profile.|profile name|' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    explain) printf '%s\n' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    run|diag|completion) ;;
    status) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--problems||Show only entries needing attention.||' '--unmanaged||Include observed items not declared by an installation.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    doctor) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    apply) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--scope|SCOPE|Restrict to tools, skills, resources, or all.|tools skills resources all|' '--target|ID|Apply one selected entry; repeat for several targets.||' '--dry-run||Print the plan without invoking providers.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    bootstrap) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--scope|SCOPE|Restrict to tools, skills, resources, or all.|tools skills resources all|' '--dry-run||Print the plan without invoking providers.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    update|maintain) printf '%s\n' '--profile|NAME|Select a profile.|profile name|' '--dry-run||Print the plan without invoking providers.||' '--unattended||Record an outcome when nobody is watching.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    capture) printf '%s\n' '--dry-run||Print the plan without invoking the provider.||' '--format|FORMAT|Choose text or JSON output.|text json|' ;;
    export) printf '%s\n' '--profile|NAME|Select the view profile to export.|profile name|required' '--output|DIRECTORY|Write the public data tree here.|directory|required' '--title|TEXT|Set the exported document title.|title|' '--base-url|URL|Set the published document canonical URL.|url|' ;;
  esac
}

rig_command_positionals() {
  case "$1" in
    explain) printf ' TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID' ;;
    run) printf ' PROVIDER ACTION [-- ARGUMENT...]' ;;
    capture) printf ' PROVIDER' ;;
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
  fi
  if [ "$command" = update ] || [ "$command" = maintain ]; then
    printf '%s\n' '' 'Interactive progress appears on stderr unless a provider writes to the terminal.'
  fi
  printf '%s\n' '' 'Options:' '  -h, --help  Show command help.'
  while IFS='|' read -r option value description choices required; do
    [ -n "$option" ] || continue
    printf '  %-20s %s\n' "$option${value:+ $value}" "$description"
  done < <(rig_command_options "$command")
  case "$command" in
    status|doctor|apply|bootstrap|update|maintain|capture|run|export)
      printf '%s\n' '' 'Exit status: 0 on success, 1 on an operational problem, 2 on usage error.' ;;
  esac
  printf '\nExample: rig %s\n' "$(rig_command_example "$command")"
}

rig_command_example() {
  case "$1" in
    show) printf 'show --profile default' ;;
    list) printf 'list --category core' ;;
    explain) printf 'explain tool-name' ;;
    status) printf 'status --problems' ;;
    doctor) printf 'doctor' ;;
    apply) printf 'apply --dry-run' ;;
    bootstrap) printf 'bootstrap --dry-run' ;;
    update) printf 'update --dry-run' ;;
    maintain) printf 'maintain --dry-run' ;;
    capture) printf 'capture homebrew --dry-run' ;;
    run) printf 'run provider action -- argument' ;;
    export) printf 'export --profile public --output ./public' ;;
    diag) printf 'diag' ;;
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
      status|doctor|diag)
        if [ "$status" -eq 0 ]; then
          result=healthy
        else
          result=unhealthy
        fi
        ;;
      apply|bootstrap|update|maintain|capture|export)
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
    always) return 0 ;;
    lines) return 0 ;;
    never) return 1 ;;
    auto|'') [ "${RIG_PROGRESS_CONTEXT:-query}" = operational ] && [ -t 2 ] ;;
    *) [ "${RIG_PROGRESS_CONTEXT:-query}" = operational ] && [ -t 2 ] ;;
  esac
}

rig_progress_select_renderer() {
  case "${RIG_PROGRESS:-auto}" in
    lines) RIG_PROGRESS_RENDER=lines ;;
    always)
      if [ -t 2 ]; then
        RIG_PROGRESS_RENDER=bar
      else
        RIG_PROGRESS_RENDER=lines
      fi
      ;;
    never) RIG_PROGRESS_RENDER=off ;;
    auto|'')
      if [ "${RIG_PROGRESS_CONTEXT:-query}" = operational ] && [ -t 2 ]; then
        RIG_PROGRESS_RENDER=bar
      else
        RIG_PROGRESS_RENDER=off
      fi
      ;;
    *)
      if [ "${RIG_PROGRESS_CONTEXT:-query}" = operational ] && [ -t 2 ]; then
        RIG_PROGRESS_RENDER=bar
      else
        RIG_PROGRESS_RENDER=off
      fi
      ;;
  esac
  # A phase that lets provider-native output reach the terminal cannot also
  # redraw a bar on the line it shares with that output: neither writer yields,
  # so the two overwrite each other. Such a phase reports its start and its
  # summary and leaves the per-item narrative to the provider and to the
  # command's own rows. An explicit lines request stays line-oriented, because
  # whole lines interleave safely.
  if [ "$RIG_PROGRESS_PASSTHROUGH" -eq 1 ] && [ "$RIG_PROGRESS_RENDER" = bar ]; then
    RIG_PROGRESS_RENDER=phase
  fi
}

rig_progress_make_bar() {
  local current total width running filled index

  current=$1
  total=$2
  width=$3
  running=$4
  filled=0
  index=0
  RIG_PROGRESS_BAR=
  if [ "$total" -gt 0 ]; then
    filled=$((current * width / total))
  fi
  [ "$filled" -le "$width" ] || filled=$width
  while [ "$index" -lt "$width" ]; do
    if [ "$index" -lt "$filled" ]; then
      RIG_PROGRESS_BAR=${RIG_PROGRESS_BAR}#
    elif [ "$index" -eq "$filled" ] && [ "$running" -eq 1 ]; then
      RIG_PROGRESS_BAR="${RIG_PROGRESS_BAR}>"
    else
      RIG_PROGRESS_BAR=${RIG_PROGRESS_BAR}.
    fi
    index=$((index + 1))
  done
}

rig_progress_columns() {
  local columns size

  [ -z "$RIG_PROGRESS_COLUMNS" ] || return 0
  columns=${COLUMNS:-}
  case "$columns" in
  ''|*[!0-9]*)
    columns=
    if [ -t 2 ]; then
      size=$(stty size <&2 2>/dev/null) || size=
      columns=${size#* }
    fi
    ;;
  esac
  case "$columns" in
  ''|*[!0-9]*) columns=100 ;;
  esac
  [ "$columns" -ge 40 ] || columns=100
  RIG_PROGRESS_COLUMNS=$columns
}

# Every field except the bar holds a fixed width, so a longer phase name, a
# counter that gains a digit, or a longer identity never shifts the column
# beside it. The bar spends what the terminal has left, up to a bound past
# which a longer bar tells a reader nothing the identity beside it does not;
# beyond that bound the surplus goes to the identity, which can always use it.
rig_progress_geometry() {
  local line label item bar

  rig_progress_columns
  line=$((RIG_PROGRESS_COLUMNS - 1))
  label=$RIG_PROGRESS_LABEL_WIDTH
  item=$RIG_PROGRESS_ITEM_WIDTH
  bar=$((line - label - item - RIG_PROGRESS_COUNT_WIDTH -
    RIG_PROGRESS_STATE_WIDTH - 11))
  if [ "$bar" -gt "$RIG_PROGRESS_BAR_MAXIMUM" ]; then
    bar=$RIG_PROGRESS_BAR_MAXIMUM
    item=$((line - label - bar - RIG_PROGRESS_COUNT_WIDTH -
      RIG_PROGRESS_STATE_WIDTH - 11))
  elif [ "$bar" -lt "$RIG_PROGRESS_BAR_MINIMUM" ]; then
    # A narrow terminal buys the bar's minimum from the identity first, then
    # from the phase name, and finally gives the bar up altogether rather than
    # draw one too short to read.
    item=$((item + bar - RIG_PROGRESS_BAR_MINIMUM))
    bar=$RIG_PROGRESS_BAR_MINIMUM
    if [ "$item" -lt 8 ]; then
      label=$((label + item - 8))
      item=8
      if [ "$label" -lt 10 ]; then
        bar=$((bar + label - 10))
        label=10
      fi
      [ "$bar" -ge 4 ] || bar=0
    fi
  fi
  RIG_PROGRESS_LABEL_BUDGET=$label
  RIG_PROGRESS_ITEM_BUDGET=$item
  RIG_PROGRESS_BAR_WIDTH=$bar
}

rig_progress_compact() {
  local width

  RIG_VALUE=$1
  width=$2
  if [ "$width" -lt 4 ]; then
    RIG_VALUE=
    return 0
  fi
  if [ "${#RIG_VALUE}" -gt "$width" ]; then
    RIG_VALUE=${RIG_VALUE:0:$((width - 3))}...
  fi
}

rig_progress_bar_render() {
  local state detail result running label count line

  state=$1
  rig_progress_geometry
  running=0
  [ "$state" != running ] || running=1
  rig_progress_make_bar "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
    "$RIG_PROGRESS_BAR_WIDTH" "$running"

  detail=$RIG_PROGRESS_ITEM
  result=
  case "$state" in
  started) detail=starting ;;
  succeeded) result=ok ;;
  skipped) result=skip ;;
  failed) result=fail ;;
  finished|phase-failed)
    detail="ok=$RIG_PROGRESS_SUCCEEDED skip=$RIG_PROGRESS_SKIPPED"
    detail="$detail fail=$RIG_PROGRESS_FAILED"
    ;;
  interrupted)
    detail="stopped ok=$RIG_PROGRESS_SUCCEEDED skip=$RIG_PROGRESS_SKIPPED"
    detail="$detail fail=$RIG_PROGRESS_FAILED"
    ;;
  esac

  rig_progress_compact "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_LABEL_BUDGET"
  label=$RIG_VALUE
  count="$RIG_PROGRESS_CURRENT/$RIG_PROGRESS_TOTAL"
  rig_progress_compact "$detail" "$RIG_PROGRESS_ITEM_BUDGET"
  detail=$RIG_VALUE

  if [ "$RIG_PROGRESS_BAR_WIDTH" -gt 0 ]; then
    printf -v line 'rig: %-*s %*s [%s] %-*s %-*s' \
      "$RIG_PROGRESS_LABEL_BUDGET" "$label" \
      "$RIG_PROGRESS_COUNT_WIDTH" "$count" "$RIG_PROGRESS_BAR" \
      "$RIG_PROGRESS_ITEM_BUDGET" "$detail" \
      "$RIG_PROGRESS_STATE_WIDTH" "$result"
  else
    printf -v line 'rig: %-*s %*s %-*s %-*s' \
      "$RIG_PROGRESS_LABEL_BUDGET" "$label" \
      "$RIG_PROGRESS_COUNT_WIDTH" "$count" \
      "$RIG_PROGRESS_ITEM_BUDGET" "$detail" \
      "$RIG_PROGRESS_STATE_WIDTH" "$result"
  fi
  # The frame is written to one fixed width, so it erases the frame before it
  # without remembering how long that one was.
  line=${line:0:$((RIG_PROGRESS_COLUMNS - 1))}
  printf '\r%-*s\r' "$((RIG_PROGRESS_COLUMNS - 1))" "$line" >&2
  case "$state" in
  finished|phase-failed|interrupted)
    printf '\n' >&2
    ;;
  esac
}

rig_progress_start() {
  rig_progress_fail
  RIG_PROGRESS_ACTIVE=0
  RIG_PROGRESS_CURRENT=0
  RIG_PROGRESS_LABEL=$1
  RIG_PROGRESS_TOTAL=$2
  RIG_PROGRESS_ITEM=
  RIG_PROGRESS_SCOPE=
  RIG_PROGRESS_SUCCEEDED=0
  RIG_PROGRESS_SKIPPED=0
  RIG_PROGRESS_FAILED=0
  RIG_PROGRESS_PASSTHROUGH=0
  [ "${3:-}" != passthrough ] || RIG_PROGRESS_PASSTHROUGH=1
  [ "$RIG_PROGRESS_TOTAL" -gt 0 ] || return 0
  rig_progress_select_renderer
  rig_progress_enabled || return 0
  RIG_PROGRESS_ACTIVE=1
  if [ "$RIG_PROGRESS_RENDER" = bar ]; then
    rig_progress_bar_render started
    return 0
  fi
  printf 'rig: progress: %s 0/%s started\n' \
    "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_TOTAL" >&2
}

rig_progress_begin() {
  [ "$RIG_PROGRESS_ACTIVE" -eq 1 ] || return 0
  RIG_PROGRESS_ITEM=$1
  RIG_PROGRESS_SCOPE=${2:-}
  if [ "$RIG_PROGRESS_RENDER" = bar ]; then
    rig_progress_bar_render running
    return 0
  fi
  [ "$RIG_PROGRESS_RENDER" != phase ] || return 0
  if [ -n "$RIG_PROGRESS_SCOPE" ]; then
    printf 'rig: progress: %s %s/%s: %s [%s] running\n' \
      "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
      "$RIG_PROGRESS_ITEM" "$RIG_PROGRESS_SCOPE" >&2
  else
    printf 'rig: progress: %s %s/%s: %s running\n' \
      "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
      "$RIG_PROGRESS_ITEM" >&2
  fi
}

rig_progress_result() {
  local result item scope

  [ "$RIG_PROGRESS_ACTIVE" -eq 1 ] || return 0
  result=$1
  item=${2:-$RIG_PROGRESS_ITEM}
  scope=${3:-$RIG_PROGRESS_SCOPE}
  case "$result" in
    succeeded) RIG_PROGRESS_SUCCEEDED=$((RIG_PROGRESS_SUCCEEDED + 1)) ;;
    skipped) RIG_PROGRESS_SKIPPED=$((RIG_PROGRESS_SKIPPED + 1)) ;;
    failed) RIG_PROGRESS_FAILED=$((RIG_PROGRESS_FAILED + 1)) ;;
    *) return 2 ;;
  esac
  RIG_PROGRESS_CURRENT=$((RIG_PROGRESS_CURRENT + 1))
  if [ "$RIG_PROGRESS_RENDER" = bar ]; then
    RIG_PROGRESS_ITEM=$item
    RIG_PROGRESS_SCOPE=$scope
    rig_progress_bar_render "$result"
    RIG_PROGRESS_ITEM=
    RIG_PROGRESS_SCOPE=
    return 0
  fi
  if [ "$RIG_PROGRESS_RENDER" = phase ]; then
    RIG_PROGRESS_ITEM=
    RIG_PROGRESS_SCOPE=
    return 0
  fi
  if [ -n "$scope" ]; then
    printf 'rig: progress: %s %s/%s: %s [%s] %s\n' \
      "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
      "$item" "$scope" "$result" >&2
  else
    printf 'rig: progress: %s %s/%s: %s %s\n' \
      "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
      "$item" "$result" >&2
  fi
  RIG_PROGRESS_ITEM=
  RIG_PROGRESS_SCOPE=
}

rig_progress_finish() {
  [ "$RIG_PROGRESS_ACTIVE" -eq 1 ] || return 0
  if [ "$RIG_PROGRESS_RENDER" = bar ]; then
    RIG_PROGRESS_ITEM=
    RIG_PROGRESS_SCOPE=
    rig_progress_bar_render finished
    RIG_PROGRESS_ACTIVE=0
    return 0
  fi
  printf 'rig: progress: %s finished completed=%s/%s succeeded=%s skipped=%s failed=%s\n' \
    "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
    "$RIG_PROGRESS_SUCCEEDED" "$RIG_PROGRESS_SKIPPED" "$RIG_PROGRESS_FAILED" >&2
  RIG_PROGRESS_ACTIVE=0
  RIG_PROGRESS_ITEM=
  RIG_PROGRESS_SCOPE=
}

rig_progress_fail() {
  [ "${RIG_PROGRESS_ACTIVE:-0}" -eq 1 ] || return 0
  if [ "$RIG_PROGRESS_RENDER" = bar ]; then
    rig_progress_bar_render phase-failed
    RIG_PROGRESS_ACTIVE=0
    RIG_PROGRESS_ITEM=
    RIG_PROGRESS_SCOPE=
    return 0
  fi
  printf 'rig: progress: %s failed completed=%s/%s succeeded=%s skipped=%s failed=%s\n' \
    "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
    "$RIG_PROGRESS_SUCCEEDED" "$RIG_PROGRESS_SKIPPED" "$RIG_PROGRESS_FAILED" >&2
  RIG_PROGRESS_ACTIVE=0
  RIG_PROGRESS_ITEM=
  RIG_PROGRESS_SCOPE=
}

rig_progress_interrupted() {
  [ "${RIG_PROGRESS_ACTIVE:-0}" -eq 1 ] || return 0
  if [ "$RIG_PROGRESS_RENDER" = bar ]; then
    rig_progress_bar_render interrupted
    RIG_PROGRESS_ACTIVE=0
    RIG_PROGRESS_ITEM=
    RIG_PROGRESS_SCOPE=
    return 0
  fi
  printf 'rig: progress: %s interrupted completed=%s/%s succeeded=%s skipped=%s failed=%s\n' \
    "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" \
    "$RIG_PROGRESS_SUCCEEDED" "$RIG_PROGRESS_SKIPPED" "$RIG_PROGRESS_FAILED" >&2
  RIG_PROGRESS_ACTIVE=0
  RIG_PROGRESS_ITEM=
  RIG_PROGRESS_SCOPE=
}

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
      ''|'profile name'|'category id'|directory|title|url) ;;
      *) printf ' %s' "$choices" ;;
    esac
  done < <(rig_command_options "$1")
  case "$1" in
    capture) printf ' homebrew' ;;
    completion) printf ' bash zsh' ;;
    run) printf ' --' ;;
  esac
}

rig_command_zsh_arguments() {
  local option value description choices required
  printf " '(-h --help)'{-h,--help}'[show command help]'"
  while IFS='|' read -r option value description choices required; do
    [ -n "$option" ] || continue
    if [ -n "$choices" ] && [ "$choices" != 'profile name' ] &&
      [ "$choices" != 'category id' ] && [ "$choices" != directory ] &&
      [ "$choices" != title ] && [ "$choices" != url ]; then
      printf " '%s[%s]:%s:(%s)'" "$option" "$description" "$value" "$choices"
    elif [ -n "$value" ]; then
      printf " '%s[%s]:%s:'" "$option" "$description" "$value"
    else
      printf " '%s[%s]'" "$option" "$description"
    fi
  done < <(rig_command_options "$1")
  case "$1" in
    explain) printf " '1:tool, qualified resource, or private port:'" ;;
    capture) printf " '1:provider:(homebrew)'" ;;
    run) printf " '1:provider name:' '2:action name:' '3:separator:(--)' '*::action argument:'" ;;
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
    '    COMPREPLY=($(compgen -W "-h --help -V --version show list explain status doctor apply bootstrap update maintain capture run export diag completion help" -- "$current"))' \
    '    return' \
    '  fi' \
    '  case "$command" in'
  local command words
  for command in show list explain status doctor apply bootstrap update maintain capture run export diag completion; do
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
    "    'show:describe a resolved profile'" \
    "    'list:browse declared catalogue tools'" \
    "    'explain:explain a declared tool, resource, or private port'" \
    "    'status:compare expected and observed state'" \
    "    'doctor:check whether Rig can operate'" \
    "    'apply:materialise a resolved profile'" \
    "    'bootstrap:materialise the bootstrap profile'" \
    "    'update:update selected provider-managed tools'" \
    "    'maintain:run explicit selected-provider maintenance'" \
    "    'capture:refresh one provider-native manifest'" \
    "    'run:invoke a declared provider action'" \
    "    'export:generate public rig data'" \
    "    'diag:print runtime and configuration diagnostics'" \
    "    'completion:print shell completion source'" \
    "    'help:show help'" \
    '  )' \
    "  _arguments '(-h --help)'{-h,--help}'[show help]' '(-V --version)'{-V,--version}'[print the Rig release or development version]' '1:command:->command' '*::argument:->argument'" \
    '  case $state in' \
    "    command) _describe -t commands 'rig command' commands ;;" \
    '    argument)' \
    '      case $words[2] in'
  local command arguments
  for command in show list explain status doctor apply bootstrap update maintain capture run export diag completion; do
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
