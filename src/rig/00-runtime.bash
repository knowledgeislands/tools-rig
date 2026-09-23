#!/usr/bin/env bash

# Indexed arrays intentionally use explicit arithmetic indexes throughout.
# The parser reads a path held in $file but never writes to that path.
# Cross-module globals are intentionally initialised and consumed after assembly.
# shellcheck disable=SC2004,SC2034,SC2094

# Rig — declarative description and manager of a working setup.

RIG_VERSION=0.3.0

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
RIG_CLEAN_PATHS=()
RIG_CLEAN_STATES=()
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
RIG_PUBLISH_STAGE=
RIG_PUBLISH_ROOT=
RIG_PUBLISH_STAGING_ROOT=
RIG_RESOURCE_PREFLIGHT_DETAIL=
RIG_PUBLISH_RETAINED_ROOT=
RIG_PUBLISH_COMPLETE=0
RIG_CLEAN_CLAIM=
RIG_CLEAN_ROOT=
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
RIG_PROGRESS_BAR=
RIG_PROGRESS_BAR_WIDTH=16
RIG_PROGRESS_RENDERED=0
RIG_PROGRESS_COLUMNS=
RIG_PROFILE_SELECTION_MODE=
RIG_RESOLVED_PROFILE_KIND=
RIG_RECONCILIATION_LOCK=
RIG_RECONCILIATION_LOCK_ACQUIRED=0
RIG_BOOTSTRAP_ALLOW_DEFERRED_SKILLS=0
RIG_LISTENER_OBSERVATION_AVAILABLE=0

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
    '  publish     Publish public Rig data.' \
    '  clean       Remove eligible Rig-owned cache data.' \
    '  diag        Print runtime and configuration diagnostics.' \
    '  completion  Print shell completion source.' \
    '  help        Show this help.' \
    '' \
    "Run 'rig COMMAND --help' for command usage." \
    '' \
    'Interactive operations use an in-place progress bar on stderr.'
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
  printf 'rig: error: %s\n' "$1" >&2
  return 2
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
}

rig_progress_make_bar() {
  local current total filled index

  current=$1
  total=$2
  filled=0
  index=0
  RIG_PROGRESS_BAR=
  if [ "$total" -gt 0 ]; then
    filled=$((current * RIG_PROGRESS_BAR_WIDTH / total))
  fi
  [ "$filled" -le "$RIG_PROGRESS_BAR_WIDTH" ] || filled=$RIG_PROGRESS_BAR_WIDTH
  while [ "$index" -lt "$RIG_PROGRESS_BAR_WIDTH" ]; do
    if [ "$index" -lt "$filled" ]; then
      RIG_PROGRESS_BAR=${RIG_PROGRESS_BAR}#
    else
      RIG_PROGRESS_BAR=${RIG_PROGRESS_BAR}-
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
  local state detail summary label_width head_width budget line_width

  state=$1
  rig_progress_columns
  rig_progress_make_bar "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL"
  detail=$RIG_PROGRESS_ITEM
  if [ -n "$RIG_PROGRESS_SCOPE" ]; then
    detail="$detail [$RIG_PROGRESS_SCOPE]"
  fi

  label_width=${#RIG_PROGRESS_LABEL}
  [ "$label_width" -ge 22 ] || label_width=22
  head_width=$((5 + label_width + 2 + ${#RIG_PROGRESS_BAR} + 2 \
    + ${#RIG_PROGRESS_CURRENT} + 1 + ${#RIG_PROGRESS_TOTAL}))
  budget=$((RIG_PROGRESS_COLUMNS - head_width - 3))

  summary=
  case "$state" in
    started)
      rig_progress_compact starting "$budget"
      summary=$RIG_VALUE
      ;;
    running)
      rig_progress_compact "$detail" "$budget"
      summary=$RIG_VALUE
      ;;
    succeeded|skipped|failed)
      rig_progress_compact "$detail" "$((budget - ${#state} - 1))"
      summary=$RIG_VALUE
      [ -z "$summary" ] || summary="$summary $state"
      ;;
    finished)
      rig_progress_compact \
        "$RIG_PROGRESS_SUCCEEDED succeeded, $RIG_PROGRESS_SKIPPED skipped, $RIG_PROGRESS_FAILED failed" \
        "$budget"
      summary=$RIG_VALUE
      ;;
    interrupted)
      rig_progress_compact \
        "interrupted; $RIG_PROGRESS_SUCCEEDED succeeded, $RIG_PROGRESS_SKIPPED skipped, $RIG_PROGRESS_FAILED failed" \
        "$budget"
      summary=$RIG_VALUE
      ;;
    phase-failed)
      rig_progress_compact \
        "$RIG_PROGRESS_SUCCEEDED succeeded, $RIG_PROGRESS_SKIPPED skipped, $RIG_PROGRESS_FAILED failed" \
        "$budget"
      summary=$RIG_VALUE
      ;;
  esac

  line_width=$head_width
  [ -z "$summary" ] || line_width=$((line_width + 2 + ${#summary}))

  printf '\rrig: %-22s [%s] %s/%s' \
    "$RIG_PROGRESS_LABEL" "$RIG_PROGRESS_BAR" \
    "$RIG_PROGRESS_CURRENT" "$RIG_PROGRESS_TOTAL" >&2
  [ -z "$summary" ] || printf '  %s' "$summary" >&2
  if [ "$RIG_PROGRESS_RENDERED" -gt "$line_width" ]; then
    printf '%*s' "$((RIG_PROGRESS_RENDERED - line_width))" '' >&2
  fi
  printf '\r' >&2
  RIG_PROGRESS_RENDERED=$line_width
  case "$state" in
    finished|phase-failed|interrupted)
      printf '\n' >&2
      RIG_PROGRESS_RENDERED=0
      ;;
  esac
}

rig_progress_start() {
  rig_progress_fail
  RIG_PROGRESS_ACTIVE=0
  RIG_PROGRESS_CURRENT=0
  RIG_PROGRESS_RENDERED=0
  RIG_PROGRESS_LABEL=$1
  RIG_PROGRESS_TOTAL=$2
  RIG_PROGRESS_ITEM=
  RIG_PROGRESS_SCOPE=
  RIG_PROGRESS_SUCCEEDED=0
  RIG_PROGRESS_SKIPPED=0
  RIG_PROGRESS_FAILED=0
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

print_bash_completion() {
  # The emitted completion deliberately retains runtime shell expressions.
  # shellcheck disable=SC2016
  printf '%s\n' \
    '_rig() {' \
    '  local current command' \
    '  current=${COMP_WORDS[COMP_CWORD]}' \
    '  command=${COMP_WORDS[1]:-}' \
    '  if [ "$COMP_CWORD" -eq 1 ]; then' \
    '    COMPREPLY=($(compgen -W "-h --help -V --version show list explain status doctor apply bootstrap update maintain capture run export publish clean diag completion help" -- "$current"))' \
    '    return' \
    '  fi' \
    '  case "$command" in' \
    '    show) COMPREPLY=($(compgen -W "-h --help --profile" -- "$current")) ;;' \
    '    list) COMPREPLY=($(compgen -W "-h --help --category --profile" -- "$current")) ;;' \
    '    explain) COMPREPLY=($(compgen -W "-h --help" -- "$current")) ;;' \
    '    status) COMPREPLY=($(compgen -W "-h --help --profile --unmanaged --format" -- "$current")) ;;' \
    '    doctor) COMPREPLY=($(compgen -W "-h --help --profile --format" -- "$current")) ;;' \
    '    apply) COMPREPLY=($(compgen -W "-h --help --profile --scope --dry-run tools skills resources all" -- "$current")) ;;' \
    '    bootstrap) COMPREPLY=($(compgen -W "-h --help --profile --scope --dry-run tools skills resources all" -- "$current")) ;;' \
    '    update|maintain) COMPREPLY=($(compgen -W "-h --help --profile --dry-run" -- "$current")) ;;' \
    '    capture) COMPREPLY=($(compgen -W "-h --help --dry-run homebrew" -- "$current")) ;;' \
    '    run) COMPREPLY=($(compgen -W "-h --help --" -- "$current")) ;;' \
    '    export) COMPREPLY=($(compgen -W "-h --help --output" -- "$current")) ;;' \
    '    publish) COMPREPLY=($(compgen -W "-h --help" -- "$current")) ;;' \
    '    clean) COMPREPLY=($(compgen -W "-h --help --dry-run" -- "$current")) ;;' \
    '    diag) COMPREPLY=($(compgen -W "-h --help" -- "$current")) ;;' \
    '    completion) COMPREPLY=($(compgen -W "-h --help bash zsh" -- "$current")) ;;' \
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
    "    'publish:publish public rig data'" \
    "    'clean:remove eligible Rig-owned cache data'" \
    "    'diag:print runtime and configuration diagnostics'" \
    "    'completion:print shell completion source'" \
    "    'help:show help'" \
    '  )' \
    "  _arguments '(-h --help)'{-h,--help}'[show help]' '(-V --version)'{-V,--version}'[print the Rig release or development version]' '1:command:->command' '*::argument:->argument'" \
    '  case $state in' \
    "    command) _describe -t commands 'rig command' commands ;;" \
    '    argument)' \
    '      case $words[2] in' \
    "        show) _arguments '(-h --help)'{-h,--help}'[show command help]' '--profile[select a profile]:profile name:' ;;" \
    "        list) _arguments '(-h --help)'{-h,--help}'[show command help]' '--category[select a category]:category id:' '--profile[select a profile]:profile name:' ;;" \
    "        explain) _arguments '(-h --help)'{-h,--help}'[show command help]' '1:tool, qualified resource, or private port:' ;;" \
    "        status) _arguments '(-h --help)'{-h,--help}'[show command help]' '--profile[select profile]:profile name:' '--unmanaged[report observed items no tool installation declares]' '--format[select rendering]:format:(text json)' ;;" \
    "        doctor) _arguments '(-h --help)'{-h,--help}'[show command help]' '--profile[select profile]:profile name:' '--format[select rendering]:format:(text json)' ;;" \
    "        apply) _arguments '(-h --help)'{-h,--help}'[show command help]' '--profile[select profile]:profile name:' '--scope[select plan scope]:scope:(tools skills resources all)' '--dry-run[print plan without invoking providers]' ;;" \
    "        bootstrap) _arguments '(-h --help)'{-h,--help}'[show command help]' '--profile[select profile]:profile name:' '--scope[select plan scope]:scope:(tools skills resources all)' '--dry-run[print plan without invoking providers]' ;;" \
    "        update|maintain) _arguments '(-h --help)'{-h,--help}'[show command help]' '--profile[select profile]:profile name:' '--dry-run[print plan without invoking providers]' ;;" \
    "        capture) _arguments '(-h --help)'{-h,--help}'[show command help]' '1:provider:(homebrew)' '--dry-run[print plan without invoking provider]' ;;" \
    "        run) _arguments '(-h --help)'{-h,--help}'[show command help]' '1:provider name:' '2:action name:' '3:separator:(--)' '*::action argument:' ;;" \
    "        export) _arguments '(-h --help)'{-h,--help}'[show command help]' '1:publication name:' '--output[write complete public data tree]:directory:_directories' ;;" \
    "        publish) _arguments '(-h --help)'{-h,--help}'[show command help]' '1:publication name:' ;;" \
    "        clean) _arguments '(-h --help)'{-h,--help}'[show command help]' '--dry-run[report eligible cache data without removing it]' ;;" \
    "        diag) _arguments '(-h --help)'{-h,--help}'[show command help]' ;;" \
    "        completion) _arguments '(-h --help)'{-h,--help}'[show command help]' '1:shell:(bash zsh)' ;;" \
    "        help) _arguments '(-h --help)'{-h,--help}'[show command help]' ;;" \
    '      esac' \
    '      ;;' \
    '  esac' \
    '}' \
    '' \
    'compdef _rig rig'
}
