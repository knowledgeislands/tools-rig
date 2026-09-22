# rig-module: 20-orchestration
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

rig_plan_index() {
  local wanted index

  wanted=$1
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    if [ "${RIG_PLAN_TOOLS[$index]}" = "$wanted" ]; then
      RIG_INDEX=$index
      return 0
    fi
    index=$((index + 1))
  done
  RIG_INDEX=
  return 1
}

rig_tool_dependencies_planned() {
  local tool section_index field_index field_end dependency

  tool=$1
  rig_section_index "tool.$tool" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      dependency=${RIG_FIELD_VALUES[$field_index]}
      rig_plan_index "$dependency" || return 1
    fi
    field_index=$((field_index + 1))
  done
  return 0
}

rig_build_plan() {
  local selected_count progress index tool binding provider section_index

  RIG_PLAN_TOOLS=()
  RIG_PLAN_BINDINGS=()
  RIG_PLAN_PROVIDERS=()
  RIG_PLAN_RESULTS=()
  RIG_PLAN_DETAILS=()
  selected_count=${#RIG_SELECTED_TOOLS[@]}

  while [ "${#RIG_PLAN_TOOLS[@]}" -lt "$selected_count" ]; do
    progress=0
    index=0
    while [ "$index" -lt "$selected_count" ]; do
      tool=${RIG_SELECTED_TOOLS[$index]}
      if rig_plan_index "$tool"; then
        index=$((index + 1))
        continue
      fi
      if rig_tool_dependencies_planned "$tool"; then
        binding=${RIG_SELECTED_BINDINGS[$index]:-}
        provider=-
        if [ -n "$binding" ]; then
          rig_section_index "$binding" || return 2
          section_index=$RIG_INDEX
          provider=${RIG_SECTION_SECONDARY_IDS[$section_index]}
        fi
        RIG_PLAN_TOOLS[${#RIG_PLAN_TOOLS[@]}]=$tool
        RIG_PLAN_BINDINGS[${#RIG_PLAN_BINDINGS[@]}]=$binding
        RIG_PLAN_PROVIDERS[${#RIG_PLAN_PROVIDERS[@]}]=$provider
        progress=1
        break
      fi
      index=$((index + 1))
    done
    [ "$progress" -eq 1 ] || rig_fail 'cannot produce a dependency-ordered provider plan' || return
  done
}

rig_provider_has_capability() {
  local provider capability adapter section_index field_index field_end

  provider=$1
  capability=$2
  if rig_provider_adapter "$provider"; then
    adapter=$RIG_VALUE
    case "$adapter:$capability" in
      homebrew:observe|homebrew:apply|homebrew:update|homebrew:maintain|homebrew:capture|\
      uv:observe|uv:apply|uv:update|uv:maintain|\
      mise:observe|mise:apply|mise:update|mise:maintain|\
      npm:observe|npm:apply|npm:update|npm:maintain|\
      chezmoi:observe|chezmoi:apply|\
      direct-download:observe|direct-download:apply|\
      launchd:resource-observe|launchd:resource-apply|launchd:resource-retire|\
      macos-applications:inventory|\
      macos-defaults:resource-observe|macos-defaults:resource-apply|\
      macos-dock:resource-observe|macos-dock:resource-apply|\
      skills-cli:skill-observe|skills-cli:skill-apply|skills-cli:skill-update|skills-cli:skill-inventory|\
      ki:skill-apply|ki:skill-update)
        return 0
        ;;
    esac
  fi
  rig_section_index "provider.$provider" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = capability ] &&
      [ "${RIG_FIELD_VALUES[$field_index]}" = "$capability" ]; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_executable_available() {
  local executable resolved

  executable=$1
  case "$executable" in
    */*) [ -f "$executable" ] && [ -x "$executable" ] ;;
    *)
      resolved=$(command -v "$executable" 2>/dev/null) || return 1
      [ -f "$resolved" ] && [ -x "$resolved" ]
      ;;
  esac
}

rig_prepare_custom_invocation() {
  local verb provider subject kind locator executable

  verb=$1
  provider=$2
  subject=$3
  kind=$4
  locator=$5

  rig_custom_provider_executable "$provider" || return 2
  executable=$RIG_VALUE
  RIG_INVOKE_ARGUMENTS=()
  rig_append_arguments "provider.$provider" || return 2
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=rig-provider-v1
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$verb
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$provider
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$subject
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$kind
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
  RIG_VALUE=$executable
}

rig_prepare_provider_invocation() {
  local verb tool binding provider binding_section
  local field_index field_end kind locator executable

  verb=$1
  tool=$2
  binding=$3
  provider=$4
  rig_section_index "$binding" || return 2
  binding_section=$RIG_INDEX
  rig_get_value "$binding" kind || return 2
  kind=$RIG_VALUE
  rig_get_value "$binding" locator || return 2
  locator=$RIG_VALUE
  rig_prepare_custom_invocation "$verb" "$provider" "$tool" "$kind" "$locator" || return
  executable=$RIG_VALUE
  field_index=${RIG_SECTION_FIELD_STARTS[$binding_section]}
  field_end=${RIG_SECTION_FIELD_ENDS[$binding_section]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = argument ]; then
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=${RIG_FIELD_VALUES[$field_index]}
    fi
    field_index=$((field_index + 1))
  done
  RIG_VALUE=$executable
}

rig_append_resource_fields() {
  local section_name section_index section_type field_index field_end key output_key
  local restart_policy start_policy run_policy priority

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  section_type=${RIG_SECTION_TYPES[$section_index]}
  restart_policy=0
  start_policy=0
  run_policy=0
  priority=0
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    output_key=$key
    [ "$key" != resource-dependency ] || output_key=depends-on
    case "$key" in
      provider|locator) ;;
      *) RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]="$output_key=${RIG_FIELD_VALUES[$field_index]}" ;;
    esac
    case "$key" in
      restart-policy) restart_policy=1 ;;
      start-policy) start_policy=1 ;;
      run-policy) run_policy=1 ;;
      priority) priority=1 ;;
    esac
    field_index=$((field_index + 1))
  done
  if [ "$section_type" = service ]; then
    [ "$restart_policy" -eq 1 ] || RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=restart-policy=never
    [ "$start_policy" -eq 1 ] || RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=start-policy=load
  else
    [ "$run_policy" -eq 1 ] || RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=run-policy=scheduled-only
    [ "$priority" -eq 1 ] || RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=priority=background
  fi
}

rig_prepare_resource_invocation() {
  local verb section_name section_index kind id provider locator executable

  verb=$1
  section_name=$2
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  kind=${RIG_SECTION_TYPES[$section_index]}
  id=${RIG_SECTION_IDS[$section_index]}
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  rig_get_value "$section_name" locator || return 2
  locator=$RIG_VALUE
  rig_prepare_custom_invocation "$verb" "$provider" "$id" "$kind" "$locator" || return
  executable=$RIG_VALUE
  rig_append_resource_fields "$section_name" || return
  RIG_VALUE=$executable
}

rig_launchd_label_valid() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) return 1 ;;
  esac
  return 0
}

rig_launchd_command() {
  RIG_VALUE=${RIG_LAUNCHCTL:-/bin/launchctl}
}

rig_launchd_domain() {
  local uid

  if [ -n "${RIG_LAUNCHD_DOMAIN:-}" ]; then
    RIG_VALUE=$RIG_LAUNCHD_DOMAIN
    return 0
  fi
  uid=$(id -u) || return 1
  RIG_VALUE=gui/$uid
}

rig_expand_home_value() {
  local value

  value=$1
  case "$value" in
    '~'|\$HOME) require_home || return 2; value=$HOME ;;
    \~/*) require_home || return 2; value=$HOME/${value#\~/} ;;
    \$HOME/*) require_home || return 2; value=$HOME/${value#\$HOME/} ;;
    file://\$HOME) require_home || return 2; value=file://$HOME ;;
    file://\$HOME/*) require_home || return 2; value=file://$HOME/${value#file://\$HOME/} ;;
  esac
  RIG_VALUE=$value
}

rig_launchd_expand_home() {
  local value

  value=$1
  case "$value" in
    '~') require_home || return; value=$HOME ;;
    \~/*) require_home || return; value=$HOME/${value#\~/} ;;
  esac
  RIG_VALUE=$value
}

rig_launchd_expand_environment_value() {
  local value

  rig_launchd_expand_home "$1" || return
  value=$RIG_VALUE
  if [ -n "${HOME:-}" ]; then
    value=${value//:\~\//:$HOME/}
  fi
  RIG_VALUE=$value
}

rig_launchd_xml_escape() {
  local value

  value=$1
  value=${value//&/&amp;}
  value=${value//</&lt;}
  value=${value//>/&gt;}
  RIG_VALUE=$value
}

rig_launchd_print_string() {
  rig_launchd_xml_escape "$1" || return
  printf '<string>%s</string>' "$RIG_VALUE"
}

rig_launchd_calendar_key() {
  case "$1" in
    minute) RIG_VALUE=Minute ;;
    hour) RIG_VALUE=Hour ;;
    day) RIG_VALUE=Day ;;
    weekday) RIG_VALUE=Weekday ;;
    month) RIG_VALUE=Month ;;
    *) return 2 ;;
  esac
}

rig_launchd_render_calendar_dict() {
  local entry indent remaining pair key value

  entry=$1
  indent=$2
  remaining=$entry
  printf '%s<dict>\n' "$indent"
  while :; do
    case "$remaining" in
      *,*) pair=${remaining%%,*}; remaining=${remaining#*,} ;;
      *) pair=$remaining; remaining= ;;
    esac
    key=${pair%%=*}
    value=${pair#*=}
    rig_launchd_calendar_key "$key" || return
    printf '%s  <key>%s</key>\n' "$indent" "$RIG_VALUE"
    printf '%s  <integer>%s</integer>\n' "$indent" "$value"
    [ -n "$remaining" ] || break
  done
  printf '%s</dict>\n' "$indent"
}

rig_launchd_render_plist() {
  local section_name section_index kind label purpose desired field_index field_end key value
  local restart_policy start_policy run_policy priority run_at_load keep_alive disabled
  local calendar_count environment_count program_count env_key env_value

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  kind=${RIG_SECTION_TYPES[$section_index]}
  rig_get_value "$section_name" locator || return 2
  label=$RIG_VALUE
  rig_get_value "$section_name" purpose || return 2
  purpose=$RIG_VALUE
  rig_get_value "$section_name" desired-state || return 2
  desired=$RIG_VALUE
  restart_policy=never
  start_policy=load
  run_policy=scheduled-only
  priority=background
  if rig_get_value "$section_name" restart-policy; then restart_policy=$RIG_VALUE; fi
  if rig_get_value "$section_name" start-policy; then start_policy=$RIG_VALUE; fi
  if rig_get_value "$section_name" run-policy; then run_policy=$RIG_VALUE; fi
  if rig_get_value "$section_name" priority; then priority=$RIG_VALUE; fi

  run_at_load=false
  keep_alive=false
  disabled=false
  if [ "$kind" = service ]; then
    [ "$start_policy" != load ] || run_at_load=true
    [ "$restart_policy" != always ] || keep_alive=true
    [ "$desired" != stopped ] || disabled=true
  else
    [ "$run_policy" != also-at-load ] || run_at_load=true
    [ "$desired" != disabled ] || disabled=true
  fi

  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
  printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  printf '%s\n' '<plist version="1.0">' '<dict>'
  printf '%s' '  <key>Label</key>'$'\n''  '
  rig_launchd_print_string "$label" || return
  printf '\n'
  printf '%s' '  <key>ServiceDescription</key>'$'\n''  '
  rig_launchd_print_string "$purpose" || return
  printf '\n'

  program_count=0
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = program ]; then
      value=${RIG_FIELD_VALUES[$field_index]}
      rig_launchd_expand_home "$value" || return
      value=$RIG_VALUE
      if [ "$program_count" -eq 0 ]; then
        printf '%s' '  <key>Program</key>'$'\n''  '
        rig_launchd_print_string "$value" || return
        printf '\n'
      fi
      program_count=$((program_count + 1))
    fi
    field_index=$((field_index + 1))
  done
  printf '%s\n' '  <key>ProgramArguments</key>' '  <array>'
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = program ]; then
      rig_launchd_expand_home "${RIG_FIELD_VALUES[$field_index]}" || return
      printf '%s' '    '
      rig_launchd_print_string "$RIG_VALUE" || return
      printf '\n'
    fi
    field_index=$((field_index + 1))
  done
  printf '%s\n' '  </array>'

  if rig_get_value "$section_name" working-directory; then
    rig_launchd_expand_home "$RIG_VALUE" || return
    value=$RIG_VALUE
    printf '%s' '  <key>WorkingDirectory</key>'$'\n''  '
    rig_launchd_print_string "$value" || return
    printf '\n'
  fi

  rig_field_count "$section_index" environment
  environment_count=$RIG_COUNT
  if [ "$environment_count" -gt 0 ]; then
    printf '%s\n' '  <key>EnvironmentVariables</key>' '  <dict>'
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = environment ]; then
        value=${RIG_FIELD_VALUES[$field_index]}
        env_key=${value%%=*}
        env_value=${value#*=}
        rig_launchd_expand_environment_value "$env_value" || return
        env_value=$RIG_VALUE
        rig_launchd_xml_escape "$env_key" || return
        printf '    <key>%s</key>\n' "$RIG_VALUE"
        printf '%s' '    '
        rig_launchd_print_string "$env_value" || return
        printf '\n'
      fi
      field_index=$((field_index + 1))
    done
    printf '%s\n' '  </dict>'
  fi

  if [ "$kind" = scheduled-job ]; then
    rig_field_count "$section_index" schedule-calendar
    calendar_count=$RIG_COUNT
    if [ "$calendar_count" -gt 0 ]; then
      printf '%s\n' '  <key>StartCalendarInterval</key>'
      if [ "$calendar_count" -eq 1 ]; then
        rig_get_value "$section_name" schedule-calendar || return 2
        rig_launchd_render_calendar_dict "$RIG_VALUE" '' || return
      else
        printf '%s\n' '  <array>'
        field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
        while [ "$field_index" -lt "$field_end" ]; do
          if [ "${RIG_FIELD_KEYS[$field_index]}" = schedule-calendar ]; then
            rig_launchd_render_calendar_dict "${RIG_FIELD_VALUES[$field_index]}" '    ' || return
          fi
          field_index=$((field_index + 1))
        done
        printf '%s\n' '  </array>'
      fi
    else
      rig_get_value "$section_name" schedule-interval || return 2
      printf '  <key>StartInterval</key>\n  <integer>%s</integer>\n' "$RIG_VALUE"
    fi
  fi
  printf '  <key>RunAtLoad</key>\n  <%s/>\n' "$run_at_load"
  if [ "$kind" = service ]; then
    printf '  <key>KeepAlive</key>\n  <%s/>\n' "$keep_alive"
  fi
  if [ "$disabled" = true ]; then
    printf '%s\n' '  <key>Disabled</key>' '  <true/>'
  fi
  if [ "$kind" = scheduled-job ] && [ "$priority" = background ]; then
    printf '%s\n' '  <key>LowPriorityIO</key>' '  <true/>'
    printf '%s\n' '  <key>Nice</key>' '  <integer>5</integer>'
  fi
  for key in standard-output standard-error; do
    if rig_get_value "$section_name" "$key"; then
      rig_launchd_expand_home "$RIG_VALUE" || return
      value=$RIG_VALUE
      case "$key" in standard-output) key=StandardOutPath ;; standard-error) key=StandardErrorPath ;; esac
      printf '  <key>%s</key>\n  ' "$key"
      rig_launchd_print_string "$value" || return
      printf '\n'
    fi
  done
  printf '%s\n' '</dict>' '</plist>'
}

rig_launchd_plist_path() {
  local label

  label=$1
  rig_launchd_label_valid "$label" || return 2
  require_home || return
  RIG_VALUE=$HOME/Library/LaunchAgents/$label.plist
}

rig_launchd_load_state() {
  local label command domain output native_status

  label=$1
  rig_launchd_command
  command=$RIG_VALUE
  rig_launchd_domain || return
  domain=$RIG_VALUE
  output=$("$command" print "$domain/$label" 2>&1)
  native_status=$?
  if [ "$native_status" -eq 0 ]; then
    RIG_LAUNCHD_LOAD_STATE=loaded
    return 0
  fi
  case "$output" in
    *'Could not find service'*|*'Could not find specified service'*)
      RIG_LAUNCHD_LOAD_STATE=absent
      return 0
      ;;
  esac
  RIG_OBSERVATION_DETAIL=launchctl-exit:$native_status
  return 1
}

rig_launchd_unload() {
  local label command domain

  label=$1
  rig_launchd_load_state "$label" || return
  [ "$RIG_LAUNCHD_LOAD_STATE" != absent ] || return 0
  rig_launchd_command
  command=$RIG_VALUE
  rig_launchd_domain || return
  domain=$RIG_VALUE
  "$command" bootout "$domain/$label"
}

rig_launchd_resource_expected_loaded() {
  local section_name kind desired

  section_name=$1
  kind=${section_name%%.*}
  rig_get_value "$section_name" desired-state || return 2
  desired=$RIG_VALUE
  case "$kind:$desired" in
    service:running|scheduled-job:enabled) return 0 ;;
  esac
  return 1
}

rig_launchd_observe_resource() {
  local section_name label target temporary expected_loaded

  section_name=$1
  rig_get_value "$section_name" locator || return 2
  label=$RIG_VALUE
  rig_launchd_plist_path "$label" || return
  target=$RIG_VALUE
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
    RIG_OBSERVATION=unavailable
    RIG_OBSERVATION_DETAIL=unsafe-plist
    return 0
  fi
  if [ ! -f "$target" ]; then
    RIG_OBSERVATION=missing
    RIG_OBSERVATION_DETAIL=-
    return 0
  fi
  if ! temporary=$(mktemp "${TMPDIR:-/tmp}/rig-launchd.XXXXXX"); then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL='temporary-file-failed'
    return 0
  fi
  if ! rig_launchd_render_plist "$section_name" >"$temporary"; then
    rm -f "$temporary"
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL='render-failed'
    return 0
  fi
  if ! cmp -s "$temporary" "$target"; then
    rm -f "$temporary"
    RIG_OBSERVATION=drifted
    RIG_OBSERVATION_DETAIL=plist
    return 0
  fi
  rm -f "$temporary"
  if rig_launchd_resource_expected_loaded "$section_name"; then expected_loaded=loaded; else expected_loaded=absent; fi
  if ! rig_launchd_load_state "$label"; then
    RIG_OBSERVATION=unknown
    return 0
  fi
  if [ "$RIG_LAUNCHD_LOAD_STATE" = "$expected_loaded" ]; then
    RIG_OBSERVATION=present
    RIG_OBSERVATION_DETAIL=-
  else
    RIG_OBSERVATION=drifted
    RIG_OBSERVATION_DETAIL=load-state
  fi
}

rig_launchd_prepare_plist() {
  local section_name label target directory temporary

  section_name=$1
  rig_get_value "$section_name" locator || return 2
  label=$RIG_VALUE
  rig_launchd_plist_path "$label" || return
  target=$RIG_VALUE
  directory=${target%/*}
  mkdir -p "$directory" || return
  temporary=$(mktemp "$directory/.rig-launchd.XXXXXX") || return
  if ! rig_launchd_render_plist "$section_name" >"$temporary" || ! chmod 0644 "$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  RIG_VALUE=$temporary
}

rig_launchd_apply_resource() {
  local section_name label target temporary command domain native_status

  section_name=$1
  rig_get_value "$section_name" locator || return 2
  label=$RIG_VALUE
  rig_launchd_plist_path "$label" || return
  target=$RIG_VALUE
  rig_launchd_prepare_plist "$section_name" || return
  temporary=$RIG_VALUE
  if rig_launchd_unload "$label"; then
    :
  else
    native_status=$?
    rm -f "$temporary"
    return "$native_status"
  fi
  if mv "$temporary" "$target"; then
    :
  else
    native_status=$?
    rm -f "$temporary"
    return "$native_status"
  fi
  if rig_launchd_resource_expected_loaded "$section_name"; then
    rig_launchd_command
    command=$RIG_VALUE
    rig_launchd_domain || return
    domain=$RIG_VALUE
    "$command" bootstrap "$domain" "$target"
  fi
}

rig_launchd_retire_resource() {
  local label target

  label=$1
  rig_launchd_plist_path "$label" || return
  target=$RIG_VALUE
  rig_launchd_unload "$label" || return
  rm -f "$target"
}

rig_launchd_preflight_resource() {
  local section_name verb label command target directory ancestor executable

  section_name=$1
  verb=$2
  [ "${RIG_RESOLVED_PLATFORM:-macos}" = macos ] ||
    rig_fail "provider 'launchd' requires platform 'macos'" || return
  rig_get_value "$section_name" locator || return 2
  label=$RIG_VALUE
  rig_launchd_label_valid "$label" || rig_fail "provider 'launchd' has invalid label '$label'" || return
  rig_launchd_command
  command=$RIG_VALUE
  rig_executable_available "$command" ||
    rig_fail "provider 'launchd' executable is unavailable: $command" || return
  rig_launchd_plist_path "$label" || return
  target=$RIG_VALUE
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
    rig_fail "provider 'launchd' refuses unsafe plist: $target" || return
  fi
  case "$verb" in
    observe-resource) set -- cmp mktemp rm id ;;
    apply-resource) set -- chmod cmp mkdir mktemp mv rm id ;;
    retire-resource) set -- rm id ;;
    *) return 2 ;;
  esac
  for executable in "$@"; do
    rig_executable_available "$executable" ||
      rig_fail "provider 'launchd' executable is unavailable: $executable" || return
  done
  if [ "$verb" = apply-resource ]; then
    directory=${target%/*}
    if [ -L "$directory" ] || { [ -e "$directory" ] && [ ! -d "$directory" ]; }; then
      rig_fail "provider 'launchd' plist directory is unsafe: $directory" || return
    fi
    ancestor=$directory
    while [ ! -e "$ancestor" ]; do
      [ "$ancestor" != "${ancestor%/*}" ] || { ancestor=/; break; }
      ancestor=${ancestor%/*}
      [ -n "$ancestor" ] || ancestor=/
    done
    [ -d "$ancestor" ] && [ -w "$ancestor" ] && [ -x "$ancestor" ] ||
      rig_fail "provider 'launchd' plist parent is unavailable: $ancestor" || return
  fi
  RIG_VALUE=$command
}

rig_launchd_preflight_retirement() {
  local label command target executable

  label=$1
  [ "${RIG_RESOLVED_PLATFORM:-macos}" = macos ] ||
    rig_fail "provider 'launchd' requires platform 'macos'" || return
  rig_launchd_label_valid "$label" || rig_fail "provider 'launchd' has invalid label '$label'" || return
  rig_launchd_command
  command=$RIG_VALUE
  rig_executable_available "$command" ||
    rig_fail "provider 'launchd' executable is unavailable: $command" || return
  rig_launchd_plist_path "$label" || return
  target=$RIG_VALUE
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
    rig_fail "provider 'launchd' refuses unsafe plist: $target" || return
  fi
  for executable in rm id; do
    rig_executable_available "$executable" ||
      rig_fail "provider 'launchd' executable is unavailable: $executable" || return
  done
  RIG_VALUE=$command
}

rig_macos_defaults_command() {
  RIG_VALUE=${RIG_DEFAULTS:-defaults}
}

rig_macos_dockutil_command() {
  RIG_VALUE=${RIG_DOCKUTIL:-dockutil}
}

rig_macos_killall_command() {
  RIG_VALUE=${RIG_KILLALL:-killall}
}

rig_setting_observe() {
  local section_name command domain key value_type expected actual native_status

  section_name=$1
  rig_macos_defaults_command; command=$RIG_VALUE
  rig_get_value "$section_name" domain || return 2; domain=$RIG_VALUE
  rig_get_value "$section_name" key || return 2; key=$RIG_VALUE
  rig_get_value "$section_name" value-type || return 2; value_type=$RIG_VALUE
  rig_get_value "$section_name" value || return 2; expected=$RIG_VALUE
  if [ "$value_type" = string ]; then
    rig_expand_home_value "$expected" || return
    expected=$RIG_VALUE
  fi
  actual=$("$command" read "$domain" "$key" 2>/dev/null)
  native_status=$?
  if [ "$native_status" -ne 0 ]; then
    RIG_OBSERVATION=missing
    RIG_OBSERVATION_DETAIL=-
    return 0
  fi
  if [ "$value_type" = bool ]; then
    case "$actual" in 1|true|TRUE|YES|yes) actual=true ;; 0|false|FALSE|NO|no) actual=false ;; esac
  fi
  if [ "$actual" = "$expected" ]; then
    RIG_OBSERVATION=present
    RIG_OBSERVATION_DETAIL=-
  else
    RIG_OBSERVATION=drifted
    RIG_OBSERVATION_DETAIL="expected:$expected observed:$actual"
  fi
}

rig_setting_apply() {
  local section_name command domain key value_type value

  section_name=$1
  rig_macos_defaults_command; command=$RIG_VALUE
  rig_get_value "$section_name" domain || return 2; domain=$RIG_VALUE
  rig_get_value "$section_name" key || return 2; key=$RIG_VALUE
  rig_get_value "$section_name" value-type || return 2; value_type=$RIG_VALUE
  rig_get_value "$section_name" value || return 2; value=$RIG_VALUE
  if [ "$value_type" = string ]; then
    rig_expand_home_value "$value" || return
    value=$RIG_VALUE
  fi
  "$command" write "$domain" "$key" "-$value_type" "$value" 1>&2
}

rig_dock_expected_paths() {
  local section_name section_index field_index field_end item path expanded joined

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  joined=
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = item ]; then
      item=${RIG_FIELD_VALUES[$field_index]}
      rig_get_value "dock-item.$item" path || return 2
      path=$RIG_VALUE
      rig_expand_home_value "$path" || return
      rig_dock_normalize_path "$RIG_VALUE"
      expanded=$RIG_VALUE
      if [ -n "$joined" ]; then joined=$joined$'\n'$expanded; else joined=$expanded; fi
    fi
    field_index=$((field_index + 1))
  done
  RIG_VALUE=$joined
}

rig_dock_normalize_path() {
  local value result prefix hex character

  value=$1
  case "$value" in file://*) value=${value#file://} ;; esac
  [ "$value" = / ] || value=${value%/}
  result=
  while [ -n "$value" ]; do
    prefix=${value%%\%*}
    result=$result$prefix
    [ "$prefix" != "$value" ] || break
    value=${value#*%}
    hex=${value:0:2}
    case "$hex" in
      [0-9A-Fa-f][0-9A-Fa-f])
        printf -v character '%b' "\\x$hex"
        result=$result$character
        value=${value:2}
        ;;
      *) result=$result%; ;;
    esac
  done
  RIG_VALUE=$result
}

rig_dock_observe() {
  local section_name command output native_status expected actual line path

  section_name=$1
  rig_macos_dockutil_command; command=$RIG_VALUE
  output=$("$command" --list 2>/dev/null)
  native_status=$?
  if [ "$native_status" -ne 0 ]; then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL="exit:$native_status"
    return 0
  fi
  rig_dock_expected_paths "$section_name" || return
  expected=$RIG_VALUE
  actual=
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in *$'\t'*) path=${line#*$'\t'}; path=${path%%$'\t'*} ;; *) path=$line ;; esac
    rig_dock_normalize_path "$path"
    path=$RIG_VALUE
    if [ -n "$actual" ]; then actual=$actual$'\n'$path; else actual=$path; fi
  done <<< "$output"
  if [ "$actual" = "$expected" ]; then
    RIG_OBSERVATION=present
    RIG_OBSERVATION_DETAIL=-
  else
    RIG_OBSERVATION=drifted
    RIG_OBSERVATION_DETAIL=order
  fi
}

rig_dock_apply() {
  local section_name command killall_command section_index field_index field_end item item_section
  local kind path view display

  section_name=$1
  rig_macos_dockutil_command; command=$RIG_VALUE
  rig_macos_killall_command; killall_command=$RIG_VALUE
  "$command" --remove all --no-restart 1>&2 || return
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = item ]; then
      item=${RIG_FIELD_VALUES[$field_index]}
      item_section=dock-item.$item
      rig_get_value "$item_section" kind || return 2; kind=$RIG_VALUE
      rig_get_value "$item_section" path || return 2
      rig_expand_home_value "$RIG_VALUE" || return; path=$RIG_VALUE
      if [ "$kind" = folder ]; then
        set -- --add "$path"
        if rig_get_value "$item_section" view; then view=$RIG_VALUE; set -- "$@" --view "$view"; fi
        if rig_get_value "$item_section" display; then display=$RIG_VALUE; set -- "$@" --display "$display"; fi
        "$command" "$@" --no-restart 1>&2 || return
      else
        "$command" --add "$path" --no-restart 1>&2 || return
      fi
    fi
    field_index=$((field_index + 1))
  done
  "$killall_command" Dock 1>&2
}

rig_macos_resource_preflight() {
  local section_name verb adapter command killall_command paths path value_type value

  section_name=$1
  verb=$2
  adapter=$3
  RIG_RESOURCE_PREFLIGHT_DETAIL=
  [ "${RIG_RESOLVED_PLATFORM:-macos}" = macos ] ||
    rig_fail "provider '$adapter' requires platform 'macos'" || return
  case "$adapter" in
    macos-defaults)
      rig_macos_defaults_command; command=$RIG_VALUE
      rig_executable_available "$command" || rig_fail "provider '$adapter' executable unavailable: $command" || return
      if [ "$verb" = apply-resource ]; then
        rig_get_value "$section_name" value-type || return 2; value_type=$RIG_VALUE
        rig_get_value "$section_name" value || return 2; value=$RIG_VALUE
        if [ "$value_type" = string ]; then
          rig_expand_home_value "$value" || return
        fi
      fi
      ;;
    macos-dock)
      rig_macos_dockutil_command; command=$RIG_VALUE
      rig_executable_available "$command" || rig_fail "provider '$adapter' executable unavailable: $command" || return
      if [ "$verb" = apply-resource ]; then
        rig_macos_killall_command; killall_command=$RIG_VALUE
        rig_executable_available "$killall_command" ||
          rig_fail "provider '$adapter' executable unavailable: $killall_command" || return
        rig_dock_expected_paths "$section_name" || return
        paths=$RIG_VALUE
        while IFS= read -r path; do
          if [ ! -e "$path" ]; then
            RIG_RESOURCE_PREFLIGHT_DETAIL="dock-item-path-missing:$path"
            return 1
          fi
        done <<< "$paths"
      fi
      ;;
    *) return 2 ;;
  esac
  RIG_VALUE=$command
}

rig_preflight_resource() {
  local section_name verb capability provider adapter executable

  section_name=$1
  verb=$2
  case "$verb" in
    observe-resource) capability='resource-observe' ;;
    apply-resource) capability='resource-apply' ;;
    retire-resource) capability='resource-retire' ;;
    *) return 2 ;;
  esac
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_provider_has_capability "$provider" "$capability" ||
    rig_fail "provider '$provider' does not declare capability '$capability'" || return
  if [ "$adapter" = launchd ]; then
    rig_launchd_preflight_resource "$section_name" "$verb"
    return
  fi
  case "$adapter" in
    macos-defaults|macos-dock)
      rig_macos_resource_preflight "$section_name" "$verb" "$adapter"
      return
      ;;
  esac
  [ "$adapter" = custom ] || return 2
  rig_custom_provider_executable "$provider" || return 2
  executable=$RIG_VALUE
  rig_executable_available "$executable" ||
    rig_fail "provider '$provider' executable is unavailable: $executable" || return
  rig_prepare_resource_invocation "$verb" "$section_name" || return
}

rig_observe_resource() {
  local section_name provider adapter executable

  section_name=$1
  RIG_OBSERVATION=unknown
  RIG_OBSERVATION_DETAIL=-
  if ! rig_preflight_resource "$section_name" observe-resource; then
    RIG_OBSERVATION=unavailable
    RIG_OBSERVATION_DETAIL=preflight-failed
    return 0
  fi
  executable=$RIG_VALUE
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  if [ "$adapter" = launchd ]; then
    rig_launchd_observe_resource "$section_name"
    return
  fi
  case "$adapter" in
    macos-defaults) rig_setting_observe "$section_name"; return ;;
    macos-dock) rig_dock_observe "$section_name"; return ;;
  esac
  rig_capture_invocation "$executable"
  if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL=exit:$RIG_NATIVE_STATUS
    return 0
  fi
  case "$RIG_CAPTURED_OUTPUT" in
    present|missing|drifted|unavailable|unknown) RIG_OBSERVATION=$RIG_CAPTURED_OUTPUT ;;
    *) RIG_OBSERVATION=unknown; RIG_OBSERVATION_DETAIL=invalid-response ;;
  esac
}

rig_plan_blocker() {
  local tool section_index field_index field_end dependency dependency_index
  local dependency_result blocker
  local LC_ALL=C

  tool=$1
  blocker=
  rig_section_index "tool.$tool" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      dependency=${RIG_FIELD_VALUES[$field_index]}
      rig_plan_index "$dependency" || return 2
      dependency_index=$RIG_INDEX
      dependency_result=${RIG_PLAN_RESULTS[$dependency_index]:-}
      if [ "$dependency_result" = failed ] ||
        { [ "$dependency_result" = skipped ] &&
          [ "${RIG_PLAN_DETAILS[$dependency_index]:-}" != catalogue-only ]; }; then
        if [ -z "$blocker" ] || [[ "$dependency" < "$blocker" ]]; then
          blocker=$dependency
        fi
      fi
    fi
    field_index=$((field_index + 1))
  done
  [ -n "$blocker" ] || return 1
  RIG_VALUE=$blocker
}

rig_resolve_operational_plan() {
  local profile receipt_mode platform index

  profile=$1
  receipt_mode=${2:-load}
  rig_load_config || return
  rig_current_platform || return
  platform=$RIG_VALUE
  rig_resolve_profile "$profile" "$platform" || return
  rig_resolve_bindings || return
  rig_build_plan || return
  RIG_RESOURCE_PLAN_SECTIONS=()
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" ]; do
    RIG_RESOURCE_PLAN_SECTIONS[$index]=${RIG_SELECTED_RESOURCE_SECTIONS[$index]}
    index=$((index + 1))
  done
  if [ "$receipt_mode" = load ] && [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] && {
    [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -gt 0 ] ||
      [ -n "${RIG_STATE_HOME:-}${XDG_STATE_HOME:-}${HOME:-}" ];
  }; then
    rig_load_resource_receipt "$platform"
  fi
}

rig_adapter_is_builtin() {
  case "$1" in
    homebrew|uv|mise|npm|chezmoi|direct-download) return 0 ;;
  esac
  return 1
}

rig_effective_data_home() {
  if [ -n "${RIG_DATA_HOME:-}" ]; then
    RIG_VALUE=$RIG_DATA_HOME
  elif [ -n "${XDG_DATA_HOME:-}" ]; then
    RIG_VALUE=$XDG_DATA_HOME/rig
  else
    require_home || return
    RIG_VALUE=$HOME/.local/share/rig
  fi
}

rig_effective_state_home() {
  if [ -n "${RIG_STATE_HOME:-}" ]; then
    RIG_VALUE=$RIG_STATE_HOME
  elif [ -n "${XDG_STATE_HOME:-}" ]; then
    RIG_VALUE=$XDG_STATE_HOME/rig
  else
    require_home || return
    RIG_VALUE=$HOME/.local/state/rig
  fi
}

rig_reconciliation_lock_path() {
  local state_home platform

  platform=$1
  rig_effective_state_home || return
  state_home=$RIG_VALUE
  RIG_VALUE=$state_home/reconciliation/$platform.lock
}

rig_release_reconciliation_lock() {
  local lock parent

  lock=${RIG_RECONCILIATION_LOCK:-}
  [ -n "$lock" ] || return 0
  rig_effective_state_home || return
  parent=$RIG_VALUE/reconciliation
  case "$lock" in "$parent"/*.lock) ;; *)
    rig_fail "refusing unsafe reconciliation lock release: $lock" || return ;;
  esac
  [ -d "$lock" ] && [ ! -L "$lock" ] ||
    rig_fail "reconciliation lock became unsafe: $lock" || return
  rm -f "$lock/owner" || return
  rmdir "$lock" || return
  RIG_RECONCILIATION_LOCK=
  RIG_RECONCILIATION_LOCK_ACQUIRED=0
}

rig_reconciliation_signal() {
  local exit_code

  exit_code=$1
  trap - HUP INT TERM
  rig_release_reconciliation_lock || true
  exit "$exit_code"
}

rig_acquire_reconciliation_lock() {
  local platform profile command lock parent ancestor owner owner_pid owner_state

  platform=$1
  profile=$2
  command=$3
  rig_reconciliation_lock_path "$platform" || return
  lock=$RIG_VALUE
  if [ -n "${RIG_RECONCILIATION_LOCK:-}" ]; then
    [ "$RIG_RECONCILIATION_LOCK" = "$lock" ] ||
      rig_fail "another reconciliation target is already locked by this process: $RIG_RECONCILIATION_LOCK" || return
    RIG_RECONCILIATION_LOCK_ACQUIRED=0
    return 0
  fi
  parent=${lock%/*}
  if [ -L "$parent" ] || { [ -e "$parent" ] && [ ! -d "$parent" ]; }; then
    rig_fail "reconciliation lock directory is unsafe: $parent" || return
  fi
  ancestor=$parent
  while [ ! -e "$ancestor" ]; do
    [ "$ancestor" != "${ancestor%/*}" ] || { ancestor=/; break; }
    ancestor=${ancestor%/*}
    [ -n "$ancestor" ] || ancestor=/
  done
  [ -d "$ancestor" ] && [ -w "$ancestor" ] && [ -x "$ancestor" ] ||
    rig_fail "reconciliation lock parent is unavailable: $ancestor" || return
  mkdir -p "$parent" || rig_fail "cannot create reconciliation lock directory: $parent" || return
  if ! mkdir "$lock" 2>/dev/null; then
    [ -d "$lock" ] && [ ! -L "$lock" ] ||
      rig_fail "reconciliation target lock is unsafe: $lock" || return
    owner=unknown
    if [ -f "$lock/owner" ] && [ -r "$lock/owner" ]; then
      IFS= read -r owner <"$lock/owner" || owner=unknown
    fi
    owner_state=active
    case "$owner" in
      pid=[0-9]*' '*)
        owner_pid=${owner#pid=}
        owner_pid=${owner_pid%% *}
        kill -0 "$owner_pid" 2>/dev/null || owner_state=stale
        ;;
      *) owner_state=unknown ;;
    esac
    rig_fail "reconciliation target '$platform' is $owner_state; owner=$owner" || return
  fi
  if ! printf 'pid=%s profile=%s command=%s\n' "$$" "$profile" "$command" >"$lock/owner"; then
    rmdir "$lock" 2>/dev/null || true
    rig_fail "cannot record reconciliation lock owner: $lock" || return
  fi
  RIG_RECONCILIATION_LOCK=$lock
  RIG_RECONCILIATION_LOCK_ACQUIRED=1
  trap rig_release_reconciliation_lock EXIT
  trap 'rig_reconciliation_signal 129' HUP
  trap 'rig_reconciliation_signal 130' INT
  trap 'rig_reconciliation_signal 143' TERM
}

rig_resource_receipt_path() {
  local state_home platform

  platform=$1
  rig_effective_state_home || return
  state_home=$RIG_VALUE
  RIG_VALUE=$state_home/resources/$platform.tsv
}

rig_reconciliation_needed() {
  local platform receipt

  platform=$1
  [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -eq 0 ] || return 0
  rig_resource_receipt_path "$platform" || return
  receipt=$RIG_VALUE
  [ -e "$receipt" ] || [ -L "$receipt" ]
}

rig_selected_resource_has_locator() {
  local provider kind locator section_name current_provider current_locator

  provider=$1
  kind=$2
  locator=$3
  for section_name in "${RIG_SELECTED_RESOURCE_SECTIONS[@]+"${RIG_SELECTED_RESOURCE_SECTIONS[@]}"}"; do
    [ "${section_name%%.*}" = "$kind" ] || continue
    rig_get_value "$section_name" provider || return 2
    current_provider=$RIG_VALUE
    rig_get_value "$section_name" locator || return 2
    current_locator=$RIG_VALUE
    [ "$provider" = "$current_provider" ] && [ "$locator" = "$current_locator" ] && return 0
  done
  return 1
}

rig_load_resource_receipt() {
  local platform receipt provider kind id locator extra

  platform=$1
  RIG_STALE_RESOURCE_PROVIDERS=()
  RIG_STALE_RESOURCE_KINDS=()
  RIG_STALE_RESOURCE_IDS=()
  RIG_STALE_RESOURCE_LOCATORS=()
  rig_resource_receipt_path "$platform" || return
  receipt=$RIG_VALUE
  [ -e "$receipt" ] || return 0
  [ -f "$receipt" ] && [ -r "$receipt" ] ||
    rig_fail "resource receipt is not a readable regular file: $receipt" || return
  while IFS=$'\t' read -r provider kind id locator extra ||
    [ -n "$provider$kind$id$locator$extra" ]; do
    [ -z "$extra" ] && rig_valid_id "$provider" && rig_valid_id "$id" ||
      rig_fail "invalid resource receipt record: $receipt" || return
    case "$kind" in service|scheduled-job) ;; *)
      rig_fail "invalid resource receipt kind '$kind': $receipt" || return ;;
    esac
    [ -n "$locator" ] || rig_fail "invalid empty resource receipt locator: $receipt" || return
    if rig_selected_resource_has_locator "$provider" "$kind" "$locator"; then
      continue
    fi
    RIG_STALE_RESOURCE_PROVIDERS[${#RIG_STALE_RESOURCE_PROVIDERS[@]}]=$provider
    RIG_STALE_RESOURCE_KINDS[${#RIG_STALE_RESOURCE_KINDS[@]}]=$kind
    RIG_STALE_RESOURCE_IDS[${#RIG_STALE_RESOURCE_IDS[@]}]=$id
    RIG_STALE_RESOURCE_LOCATORS[${#RIG_STALE_RESOURCE_LOCATORS[@]}]=$locator
  done <"$receipt"
}

rig_prepare_retire_invocation() {
  local provider kind id locator adapter executable

  provider=$1
  kind=$2
  id=$3
  locator=$4
  rig_provider_exists "$provider" ||
    rig_fail "resource receipt references unknown provider '$provider'" || return
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_provider_has_capability "$provider" resource-retire ||
    rig_fail "provider '$provider' does not declare capability 'resource-retire'" || return
  if [ "$adapter" = launchd ]; then
    rig_launchd_preflight_retirement "$locator"
    return
  fi
  [ "$adapter" = custom ] || return 2
  rig_custom_provider_executable "$provider" || return 2
  executable=$RIG_VALUE
  rig_executable_available "$executable" ||
    rig_fail "provider '$provider' executable is unavailable: $executable" || return
  rig_prepare_custom_invocation retire-resource "$provider" "$id" "$kind" "$locator" || return
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]='previous-managed=true'
  RIG_VALUE=$executable
}

rig_retire_resource() {
  local provider kind id locator adapter executable

  provider=$1
  kind=$2
  id=$3
  locator=$4
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  if [ "$adapter" = launchd ]; then
    rig_launchd_retire_resource "$locator"
    return
  fi
  rig_prepare_retire_invocation "$provider" "$kind" "$id" "$locator" || return
  executable=$RIG_VALUE
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
}

rig_write_resource_receipt() {
  local platform receipt directory temporary section_name section_index
  local kind id provider locator old_umask

  platform=$1
  rig_resource_receipt_path "$platform" || return
  receipt=$RIG_VALUE
  directory=${receipt%/*}
  old_umask=$(umask)
  umask 077
  mkdir -p "$directory" || { umask "$old_umask"; return 1; }
  temporary=$(mktemp "$directory/.resources.XXXXXX") || { umask "$old_umask"; return 1; }
  for section_name in "${RIG_SELECTED_RESOURCE_SECTIONS[@]+"${RIG_SELECTED_RESOURCE_SECTIONS[@]}"}"; do
    rig_section_index "$section_name" || { rm -f "$temporary"; umask "$old_umask"; return 2; }
    section_index=$RIG_INDEX
    kind=${RIG_SECTION_TYPES[$section_index]}
    id=${RIG_SECTION_IDS[$section_index]}
    case "$kind" in service|scheduled-job) ;; *) continue ;; esac
    rig_get_value "$section_name" provider || { rm -f "$temporary"; umask "$old_umask"; return 2; }
    provider=$RIG_VALUE
    rig_get_value "$section_name" locator || { rm -f "$temporary"; umask "$old_umask"; return 2; }
    locator=$RIG_VALUE
    printf '%s\t%s\t%s\t%s\n' "$provider" "$kind" "$id" "$locator" >>"$temporary" ||
      { rm -f "$temporary"; umask "$old_umask"; return 1; }
  done
  mv "$temporary" "$receipt" || { rm -f "$temporary"; umask "$old_umask"; return 1; }
  umask "$old_umask"
}

rig_preflight_resource_receipt() {
  local platform receipt directory ancestor executable

  platform=$1
  rig_resource_receipt_path "$platform" || return
  receipt=$RIG_VALUE
  directory=${receipt%/*}
  if [ -L "$receipt" ] || { [ -e "$receipt" ] && [ ! -f "$receipt" ]; }; then
    rig_fail "resource receipt is not a safe regular-file target: $receipt" || return
  fi
  if [ -L "$directory" ] || { [ -e "$directory" ] && [ ! -d "$directory" ]; }; then
    rig_fail "resource receipt directory is unsafe: $directory" || return
  fi
  ancestor=$directory
  while [ ! -e "$ancestor" ]; do
    [ "$ancestor" != "${ancestor%/*}" ] || { ancestor=/; break; }
    ancestor=${ancestor%/*}
    [ -n "$ancestor" ] || ancestor=/
  done
  [ -d "$ancestor" ] && [ -w "$ancestor" ] && [ -x "$ancestor" ] ||
    rig_fail "resource receipt parent is unavailable: $ancestor" || return
  for executable in mkdir mktemp mv rm; do
    rig_executable_available "$executable" ||
      rig_fail "resource receipt executable is unavailable: $executable" || return
  done
}

rig_custom_provider_executable() {
  local provider data_home

  provider=$1
  if rig_get_value "provider.$provider" executable; then
    return 0
  fi
  rig_effective_data_home || return
  data_home=$RIG_VALUE
  RIG_VALUE=$data_home/providers/$provider
}

rig_provider_executable() {
  local provider adapter kind

  provider=$1
  adapter=$2
  kind=$3
  if rig_get_value "provider.$provider" executable; then
    return 0
  fi
  case "$adapter:$kind" in
    homebrew:mas) RIG_VALUE=mas ;;
    homebrew:*) RIG_VALUE=brew ;;
    uv:*) RIG_VALUE=uv ;;
    mise:*) RIG_VALUE=mise ;;
    npm:*) RIG_VALUE=npm ;;
    chezmoi:*) RIG_VALUE=chezmoi ;;
    direct-download:*) RIG_VALUE=curl ;;
    skills-cli:*) RIG_VALUE=skills ;;
    ki:*) RIG_VALUE=ki ;;
    *) return 1 ;;
  esac
}

rig_append_arguments() {
  local section_name section_index field_index field_end

  section_name=$1
  if ! rig_section_index "$section_name"; then
    case "$section_name" in
      provider.*)
        rig_builtin_provider_adapter "${section_name#provider.}" && return 0
        ;;
    esac
    return 2
  fi
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = argument ]; then
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=${RIG_FIELD_VALUES[$field_index]}
    fi
    field_index=$((field_index + 1))
  done
}

rig_prepare_builtin_invocation() {
  local verb binding provider adapter kind locator observation_locator

  verb=$1
  binding=$2
  provider=$3
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_get_value "$binding" kind || return 2
  kind=$RIG_VALUE
  rig_get_value "$binding" locator || return 2
  locator=$RIG_VALUE
  rig_provider_executable "$provider" "$adapter" "$kind" || return 2
  RIG_EXECUTABLE=$RIG_VALUE
  RIG_INVOKE_ARGUMENTS=()
  rig_append_arguments "provider.$provider" || return

  case "$adapter:$kind:$verb" in
    homebrew:formula:observe)
      rig_normalize_provider_identity "$adapter" "$kind" "$locator"
      observation_locator=$RIG_VALUE
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=list
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--formula
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--versions
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$observation_locator
      ;;
    homebrew:cask:observe)
      rig_normalize_provider_identity "$adapter" "$kind" "$locator"
      observation_locator=$RIG_VALUE
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=list
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--cask
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--versions
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$observation_locator
      ;;
    homebrew:formula:apply|homebrew:cask:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=install
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--$kind
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    homebrew:mas:observe)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=list
      rig_append_arguments "$binding" || return
      ;;
    homebrew:mas:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=install
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    uv:tool:observe)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=tool
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=list
      rig_append_arguments "$binding" || return
      ;;
    uv:tool:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=tool
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=install
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    mise:tool:observe)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=which
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    mise:tool:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=install
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    npm:global:observe)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=list
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--global
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--depth=0
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    npm:global:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=install
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--global
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    chezmoi:target:observe)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=status
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--path-style=absolute
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    chezmoi:target:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=apply
      rig_append_arguments "$binding" || return
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
      ;;
    direct-download:executable:apply)
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--fail
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--location
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--proto
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]='=https'
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--proto-redir
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]='=https'
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--silent
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--show-error
      rig_append_arguments "$binding" || return
      ;;
    *) return 2 ;;
  esac
}

rig_sha256_file() {
  local file output executable

  file=$1
  if executable=$(command -v shasum 2>/dev/null); then
    output=$("$executable" -a 256 "$file") || return 1
  elif executable=$(command -v sha256sum 2>/dev/null); then
    output=$("$executable" "$file") || return 1
  else
    return 1
  fi
  RIG_VALUE=${output%%[[:space:]]*}
  [ "${#RIG_VALUE}" -eq 64 ]
}

rig_sha256_available() {
  command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1
}

rig_capture_invocation() {
  local executable captured marker native_status

  executable=$1
  marker=$'\036'
  captured=$("$executable" "${RIG_INVOKE_ARGUMENTS[@]}"; native_status=$?; \
    printf '%s%s' "$marker" "$native_status")
  RIG_NATIVE_STATUS=${captured##*"$marker"}
  RIG_CAPTURED_OUTPUT=${captured%"$marker"*}
  case "$RIG_CAPTURED_OUTPUT" in
    *$'\n') RIG_CAPTURED_OUTPUT=${RIG_CAPTURED_OUTPUT%$'\n'} ;;
  esac
}

rig_capture_observation_invocation() {
  local executable key argument index

  executable=$1
  key=${#executable}:$executable
  for argument in "${RIG_INVOKE_ARGUMENTS[@]}"; do
    key=$key:${#argument}:$argument
  done

  index=0
  while [ "$index" -lt "${#RIG_OBSERVATION_CACHE_KEYS[@]}" ]; do
    if [ "${RIG_OBSERVATION_CACHE_KEYS[$index]}" = "$key" ]; then
      RIG_CAPTURED_OUTPUT=${RIG_OBSERVATION_CACHE_OUTPUTS[$index]}
      RIG_NATIVE_STATUS=${RIG_OBSERVATION_CACHE_STATUSES[$index]}
      return 0
    fi
    index=$((index + 1))
  done

  rig_capture_invocation "$executable"
  index=${#RIG_OBSERVATION_CACHE_KEYS[@]}
  RIG_OBSERVATION_CACHE_KEYS[$index]=$key
  RIG_OBSERVATION_CACHE_OUTPUTS[$index]=$RIG_CAPTURED_OUTPUT
  RIG_OBSERVATION_CACHE_STATUSES[$index]=$RIG_NATIVE_STATUS
}

rig_output_has_identity() {
  local output wanted identity

  output=$1
  wanted=$2
  while IFS=' ' read -r identity _; do
    [ "$identity" = "$wanted" ] && return 0
  done <<< "$output"
  return 1
}

rig_normalize_provider_identity() {
  local adapter kind identity

  adapter=$1
  kind=$2
  identity=$3
  case "$adapter:$kind" in
    homebrew:formula|homebrew:cask) RIG_VALUE=${identity##*/} ;;
    uv:tool)
      case "$identity" in
        *'['*']') RIG_VALUE=${identity%%\[*} ;;
        *) RIG_VALUE=$identity ;;
      esac
      ;;
    *) RIG_VALUE=$identity ;;
  esac
}

rig_normalize_artifact_identity() {
  local identity

  identity=$1
  case "$identity" in
    \~/*)
      if [ -n "${HOME:-}" ]; then
        RIG_VALUE=$HOME/${identity#\~/}
      else
        RIG_VALUE=$identity
      fi
      ;;
    \$HOME/*)
      if [ -n "${HOME:-}" ]; then
        RIG_VALUE=$HOME/${identity#\$HOME/}
      else
        RIG_VALUE=$identity
      fi
      ;;
    *) RIG_VALUE=$identity ;;
  esac
}

rig_artifact_detail() {
  local kind identity maximum

  kind=$1
  identity=$2
  maximum=160
  if [ "${#identity}" -gt "$maximum" ]; then
    identity=${identity:0:$((maximum - 3))}...
  fi
  RIG_VALUE=artifact-$kind:$identity
}

rig_selected_variant_for_tool() {
  local tool index

  tool=$1
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    if [ "${RIG_SELECTED_TOOLS[$index]}" = "$tool" ]; then
      RIG_VALUE=${RIG_SELECTED_VARIANTS[$index]:-}
      return 0
    fi
    index=$((index + 1))
  done
  RIG_VALUE=
  return 1
}

rig_observe_tool_artifacts() {
  local tool section_name section_index field_index field_end declared artifact variant artifact_key
  local state detail rank candidate_state candidate_detail candidate_rank info_plist
  local macos_dir app_exec app_exec_found

  tool=$1
  section_name=tool.$tool
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  rig_selected_variant_for_tool "$tool" || true
  variant=$RIG_VALUE
  artifact_key=variant:$variant:artifact
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  state=present
  detail=-
  rank=0
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = artifact ] || {
      [ -n "$variant" ] && [ "${RIG_FIELD_KEYS[$field_index]}" = "$artifact_key" ];
    }; then
      declared=${RIG_FIELD_VALUES[$field_index]}
      rig_normalize_artifact_identity "$declared"
      artifact=$RIG_VALUE
      candidate_state=
      candidate_detail=
      candidate_rank=0
      if [ -L "$artifact" ]; then
        candidate_state=unavailable
        candidate_detail=unsafe
        candidate_rank=3
      elif [ ! -e "$artifact" ]; then
        candidate_state=missing
        candidate_detail=missing
        candidate_rank=1
      elif [ ! -f "$artifact" ] && [ ! -d "$artifact" ]; then
        candidate_state=unavailable
        candidate_detail=unsafe
        candidate_rank=3
      elif [ -d "$artifact" ]; then
        case "$artifact" in
        *.app|*.app/)
          info_plist=${artifact%/}/Contents/Info.plist
          if [ ! -f "$info_plist" ] || [ ! -r "$info_plist" ]; then
            candidate_state=drifted
            candidate_detail=damaged-app
            candidate_rank=2
          else
            macos_dir=${artifact%/}/Contents/MacOS
            app_exec_found=0
            if [ ! -L "$macos_dir" ] && [ -d "$macos_dir" ]; then
              for app_exec in "$macos_dir"/*; do
                if [ -f "$app_exec" ] && [ -x "$app_exec" ]; then
                  app_exec_found=1
                  break
                fi
              done
            fi
            if [ "$app_exec_found" -eq 0 ]; then
              candidate_state=drifted
              candidate_detail=damaged-app
              candidate_rank=2
            fi
          fi
          ;;
        esac
      fi
      if [ "$candidate_rank" -gt "$rank" ]; then
        state=$candidate_state
        rig_artifact_detail "$candidate_detail" "$declared"
        detail=$RIG_VALUE
        rank=$candidate_rank
      fi
    fi
    field_index=$((field_index + 1))
  done
  RIG_ARTIFACT_STATE=$state
  RIG_ARTIFACT_DETAIL=$detail
}

rig_observe_provider() {
  local tool binding provider adapter kind locator observation_locator executable checksum expected destination

  tool=$1
  binding=$2
  provider=$3
  RIG_OBSERVATION=unknown
  RIG_OBSERVATION_DETAIL=-
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_get_value "$binding" kind || return 2
  kind=$RIG_VALUE
  rig_get_value "$binding" locator || return 2
  locator=$RIG_VALUE

  if [ "$adapter" = custom ]; then
    rig_custom_provider_executable "$provider" || return 2
    executable=$RIG_VALUE
    if ! rig_executable_available "$executable"; then
      RIG_OBSERVATION=unavailable
      RIG_OBSERVATION_DETAIL='executable-unavailable'
      return 0
    fi
    rig_prepare_provider_invocation observe "$tool" "$binding" "$provider" || return
    executable=$RIG_VALUE
    rig_capture_invocation "$executable"
    if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
      RIG_OBSERVATION=unknown
      RIG_OBSERVATION_DETAIL=exit:$RIG_NATIVE_STATUS
      return 0
    fi
    case "$RIG_CAPTURED_OUTPUT" in
      present|missing|drifted|unavailable|unknown) RIG_OBSERVATION=$RIG_CAPTURED_OUTPUT ;;
      *)
        RIG_OBSERVATION=unknown
        RIG_OBSERVATION_DETAIL=invalid-response
        ;;
    esac
    return 0
  fi

  if [ "$adapter" = direct-download ]; then
    rig_get_value "$binding" destination || return 2
    destination=$RIG_VALUE
    if [ -L "$destination" ] || { [ -e "$destination" ] && [ ! -f "$destination" ]; }; then
      RIG_OBSERVATION=unavailable
      RIG_OBSERVATION_DETAIL=unsafe-destination
    elif [ ! -e "$destination" ]; then
      RIG_OBSERVATION=missing
    elif ! rig_sha256_available; then
      RIG_OBSERVATION=unavailable
      RIG_OBSERVATION_DETAIL='checksum-executable-unavailable'
    elif ! rig_sha256_file "$destination"; then
      RIG_OBSERVATION=unknown
      RIG_OBSERVATION_DETAIL='checksum-failed'
    else
      checksum=$RIG_VALUE
      rig_get_value "$binding" checksum || return 2
      expected=${RIG_VALUE#sha256:}
      if [ "$checksum" = "$expected" ] && [ -x "$destination" ]; then
        RIG_OBSERVATION=present
      else
        RIG_OBSERVATION=drifted
      fi
    fi
    return 0
  fi

  rig_prepare_builtin_invocation observe "$binding" "$provider" || return 2
  executable=$RIG_EXECUTABLE
  if ! rig_executable_available "$executable"; then
    RIG_OBSERVATION=unavailable
    RIG_OBSERVATION_DETAIL='executable-unavailable'
    return 0
  fi
  rig_capture_observation_invocation "$executable"
  if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
    if [ "$adapter:$kind:$RIG_NATIVE_STATUS" = homebrew:formula:1 ] ||
      [ "$adapter:$kind:$RIG_NATIVE_STATUS" = homebrew:cask:1 ] ||
      [ "$adapter:$kind:$RIG_NATIVE_STATUS" = mise:tool:1 ] ||
      [ "$adapter:$kind:$RIG_NATIVE_STATUS" = npm:global:1 ]; then
      RIG_OBSERVATION=missing
    else
      RIG_OBSERVATION=unknown
      RIG_OBSERVATION_DETAIL=exit:$RIG_NATIVE_STATUS
    fi
    return 0
  fi
  case "$adapter:$kind" in
    homebrew:formula|homebrew:cask|mise:tool|npm:global) RIG_OBSERVATION=present ;;
    homebrew:mas|uv:tool)
      rig_normalize_provider_identity "$adapter" "$kind" "$locator"
      observation_locator=$RIG_VALUE
      if rig_output_has_identity "$RIG_CAPTURED_OUTPUT" "$observation_locator"; then
        RIG_OBSERVATION=present
      else
        RIG_OBSERVATION=missing
      fi
      ;;
    chezmoi:target)
      if [ -n "$RIG_CAPTURED_OUTPUT" ]; then
        RIG_OBSERVATION=drifted
      else
        RIG_OBSERVATION=present
      fi
      ;;
  esac
}

rig_prepare_inventory_invocation() {
  local provider executable

  provider=$1
  rig_custom_provider_executable "$provider" || return 2
  executable=$RIG_VALUE
  RIG_INVOKE_ARGUMENTS=()
  rig_append_arguments "provider.$provider" || return 2
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=rig-provider-v1
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=inventory
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$provider
  RIG_VALUE=$executable
}

rig_binding_declares_locator() {
  local provider identity index section_name artifact_index
  local adapter kind declared_identity observed_identity artifact_identity

  provider=$1
  identity=$2
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = binding ]; then
      section_name=${RIG_SECTION_NAMES[$index]}
      # A locator is meaningful only inside its own provider's namespace: a
      # Mac App Store numeric identity and a cask name may coincide.
      if [ "${RIG_SECTION_SECONDARY_IDS[$index]}" = "$provider" ] &&
        rig_get_value "$section_name" locator; then
        declared_identity=$RIG_VALUE
        rig_provider_adapter "$provider" || return 2
        adapter=$RIG_VALUE
        rig_get_value "$section_name" kind || return 2
        kind=$RIG_VALUE
        rig_normalize_provider_identity "$adapter" "$kind" "$declared_identity"
        declared_identity=$RIG_VALUE
        rig_normalize_provider_identity "$adapter" "$kind" "$identity"
        observed_identity=$RIG_VALUE
        [ "$declared_identity" = "$observed_identity" ] && return 0
      fi
    fi
    # An artifact is a machine-observable path rather than a provider identity,
    # so it matches whichever provider observed it. It is declared on the tool
    # because a catalogue-only tool has no installation metadata to carry it.
    if [ "${RIG_SECTION_TYPES[$index]}" = tool ] &&
      rig_collect_all_tool_artifacts "${RIG_SECTION_NAMES[$index]}"; then
      artifact_index=0
      while [ "$artifact_index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
        rig_normalize_artifact_identity "${RIG_QUERY_ITEMS[$artifact_index]}" || return
        artifact_identity=$RIG_VALUE
        rig_normalize_artifact_identity "$identity" || return
        observed_identity=$RIG_VALUE
        [ "$artifact_identity" = "$observed_identity" ] && return 0
        artifact_index=$((artifact_index + 1))
      done
    fi
    index=$((index + 1))
  done
  return 1
}

rig_macos_plist_value() {
  local plist key format command output

  plist=$1
  key=$2
  format=$3
  command=${RIG_PLUTIL:-/usr/bin/plutil}
  output=$("$command" -extract "$key" "$format" -o - "$plist" 2>/dev/null) || return 1
  RIG_VALUE=$output
}

rig_macos_application_is_native() {
  local bundle plist value wrapper count candidate

  bundle=$1
  plist=$bundle/Contents/Info.plist
  [ -f "$plist" ] || return 1
  wrapper=$bundle/Wrapper
  count=0
  if [ -d "$wrapper" ]; then
    for candidate in "$wrapper"/*.app; do
      [ -d "$candidate" ] || continue
      count=$((count + 1))
    done
  fi
  [ "$count" -eq 0 ] || return 1
  if rig_macos_plist_value "$plist" DTPlatformName raw; then
    [ "$RIG_VALUE" != iphoneos ] || return 1
  fi
  if rig_macos_plist_value "$plist" LSRequiresIPhoneOS raw; then
    [ "$RIG_VALUE" != true ] || return 1
  fi
  if rig_macos_plist_value "$plist" CFBundleSupportedPlatforms json; then
    value=$RIG_VALUE
    case "$value" in *'"iPhoneOS"'*) return 1 ;; esac
  fi
  return 0
}

rig_macos_inventory_directory() {
  local directory bundle localized resolved
  local LC_ALL=C

  directory=$1
  [ -d "$directory" ] || return 0
  for bundle in "$directory"/*.app; do
    [ -d "$bundle" ] || continue
    rig_macos_application_is_native "$bundle" || continue
    resolved=$(cd "${bundle%/*}" && pwd -P)/${bundle##*/} || return
    printf '%s\tnative\n' "$resolved"
  done
  for localized in "$directory"/*.localized; do
    [ -d "$localized" ] || continue
    for bundle in "$localized"/*.app; do
      [ -d "$bundle" ] || continue
      rig_macos_application_is_native "$bundle" || continue
      resolved=$(cd "${bundle%/*}" && pwd -P)/${bundle##*/} || return
      printf '%s\tnative\n' "$resolved"
    done
  done
}

rig_macos_application_inventory() {
  local roots remaining root
  local LC_ALL=C

  roots=${RIG_APPLICATION_ROOTS:-/Applications:${HOME:-}/Applications}
  remaining=$roots
  while :; do
    case "$remaining" in *:*) root=${remaining%%:*}; remaining=${remaining#*:} ;; *) root=$remaining; remaining= ;; esac
    [ -n "$root" ] && rig_macos_inventory_directory "$root" || return
    [ -n "$remaining" ] || break
  done
}

rig_inventory_provider() {
  local provider adapter executable identity detail line

  provider=$1
  RIG_INVENTORY_STATE=observed
  RIG_INVENTORY_DETAIL=-
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  if [ "$adapter" = macos-applications ]; then
    if [ "${RIG_RESOLVED_PLATFORM:-}" != macos ]; then
      RIG_INVENTORY_STATE=unavailable
      RIG_INVENTORY_DETAIL=platform
      return 0
    fi
    executable=${RIG_PLUTIL:-/usr/bin/plutil}
    if ! rig_executable_available "$executable"; then
      RIG_INVENTORY_STATE=unavailable
      RIG_INVENTORY_DETAIL='executable-unavailable'
      return 0
    fi
    RIG_CAPTURED_OUTPUT=$(rig_macos_application_inventory)
    RIG_NATIVE_STATUS=$?
    if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
      RIG_INVENTORY_STATE=unknown
      RIG_INVENTORY_DETAIL="exit:$RIG_NATIVE_STATUS"
      return 0
    fi
  elif [ "$adapter" != custom ]; then
    RIG_INVENTORY_STATE=unavailable
    RIG_INVENTORY_DETAIL="unsupported-adapter:$adapter"
    return 0
  else
    rig_custom_provider_executable "$provider" || return 2
    executable=$RIG_VALUE
    if ! rig_executable_available "$executable"; then
      RIG_INVENTORY_STATE=unavailable
      RIG_INVENTORY_DETAIL='executable-unavailable'
      return 0
    fi
    rig_prepare_inventory_invocation "$provider" || return
    executable=$RIG_VALUE
    rig_capture_invocation "$executable"
    if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
      RIG_INVENTORY_STATE=unknown
      RIG_INVENTORY_DETAIL="exit:$RIG_NATIVE_STATUS"
      return 0
    fi
  fi
  [ -n "$RIG_CAPTURED_OUTPUT" ] || return 0
  while IFS=$'\t' read -r identity detail; do
    [ -n "$identity" ] || continue
    rig_binding_declares_locator "$provider" "$identity" && continue
    [ -n "$detail" ] || detail=-
    RIG_UNMANAGED_IDENTITIES[${#RIG_UNMANAGED_IDENTITIES[@]}]=$identity
    RIG_UNMANAGED_PROVIDERS[${#RIG_UNMANAGED_PROVIDERS[@]}]=$provider
    RIG_UNMANAGED_DETAILS[${#RIG_UNMANAGED_DETAILS[@]}]=$detail
  done <<< "$RIG_CAPTURED_OUTPUT"
}

rig_collect_unmanaged() {
  local index provider total

  RIG_UNMANAGED_IDENTITIES=()
  RIG_UNMANAGED_PROVIDERS=()
  RIG_UNMANAGED_DETAILS=()
  RIG_UNMANAGED_PROBLEMS=()
  rig_collect_section_ids provider || RIG_QUERY_ITEMS=()
  if [ "$RIG_RESOLVED_PLATFORM" = macos ] && [ "${#RIG_QUERY_ITEMS[@]}" -eq 0 ]; then
    RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=macos-applications
  fi
  total=0
  index=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    provider=${RIG_QUERY_ITEMS[$index]}
    if rig_provider_has_capability "$provider" inventory; then
      total=$((total + 1))
    fi
    index=$((index + 1))
  done
  rig_progress_start inventory "$total"
  index=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    provider=${RIG_QUERY_ITEMS[$index]}
    index=$((index + 1))
    rig_provider_has_capability "$provider" inventory || continue
    rig_progress_step "$provider"
    rig_inventory_provider "$provider" || return
    if [ "$RIG_INVENTORY_STATE" != observed ]; then
      RIG_UNMANAGED_PROBLEMS[${#RIG_UNMANAGED_PROBLEMS[@]}]="$provider	$RIG_INVENTORY_STATE	$RIG_INVENTORY_DETAIL"
    fi
  done
  rig_progress_finish
}

rig_bootstrap_provider_prerequisite() {
  local adapter index binding provider kind locator

  adapter=$1
  index=0
  while [ "$index" -lt "${#RIG_PLAN_BINDINGS[@]}" ]; do
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    if [ -n "$binding" ]; then
      rig_get_value "$binding" kind || return 2
      kind=$RIG_VALUE
      rig_get_value "$binding" locator || return 2
      locator=$RIG_VALUE
      case "$adapter:$provider:$kind:$locator" in
        mise:homebrew:formula:mise)
          rig_get_value provider.homebrew manifest || return 1
          RIG_BOOTSTRAP_DEFER_MISE=1
          return 0
          ;;
        npm:mise:tool:node)
          RIG_BOOTSTRAP_NPM_TOOL_INDEX=$index
          RIG_BOOTSTRAP_DEFER_NPM=1
          return 0
          ;;
      esac
    fi
    index=$((index + 1))
  done
  return 1
}

rig_preflight_provider() {
  local tool binding provider adapter kind executable destination parent

  tool=$1
  binding=$2
  provider=$3
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_provider_has_capability "$provider" apply ||
    rig_fail "provider '$provider' does not declare capability 'apply'" || return
  if [ "$adapter" = custom ]; then
    rig_custom_provider_executable "$provider" || return 2
    executable=$RIG_VALUE
    rig_executable_available "$executable" ||
      rig_fail "provider '$provider' executable is unavailable: $executable" || return
    rig_prepare_provider_invocation apply "$tool" "$binding" "$provider" || return
    return 0
  fi
  rig_adapter_is_builtin "$adapter" ||
    rig_fail "provider '$provider' has unsupported adapter '$adapter' apply" || return
  rig_get_value "$binding" kind || return 2
  kind=$RIG_VALUE
  rig_provider_executable "$provider" "$adapter" "$kind" || return 2
  executable=$RIG_VALUE
  if ! rig_executable_available "$executable"; then
    if [ "${RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS:-0}" -eq 1 ] &&
      rig_bootstrap_provider_prerequisite "$adapter"; then
      return 0
    fi
    rig_fail "provider '$provider' executable is unavailable: $executable" || return
  fi
  if [ "$adapter" = direct-download ]; then
    rig_sha256_available ||
      rig_fail "provider '$provider' checksum executable is unavailable" || return
    rig_executable_available mktemp ||
      rig_fail "provider '$provider' temporary-file executable is unavailable: mktemp" || return
    rig_get_value "$binding" destination || return 2
    destination=$RIG_VALUE
    if [ -L "$destination" ] || { [ -e "$destination" ] && [ ! -f "$destination" ]; }; then
      rig_fail "provider '$provider' refuses unsafe destination: $destination" || return
    fi
    parent=${destination%/*}
    [ -n "$parent" ] || parent=/
    [ -d "$parent" ] && [ -w "$parent" ] ||
      rig_fail "provider '$provider' destination directory is unavailable: $parent" || return
  else
    rig_prepare_builtin_invocation apply "$binding" "$provider" || return 2
  fi
}

rig_apply_direct_download() {
  local binding provider executable locator destination expected actual temporary

  binding=$1
  provider=$2
  rig_get_value "$binding" locator || return 2
  locator=$RIG_VALUE
  rig_get_value "$binding" destination || return 2
  destination=$RIG_VALUE
  rig_get_value "$binding" checksum || return 2
  expected=${RIG_VALUE#sha256:}
  rig_prepare_builtin_invocation apply "$binding" "$provider" || return 2
  executable=$RIG_EXECUTABLE
  temporary=$(mktemp "$destination.rig-tmp.XXXXXX") || return 1
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--output
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$temporary
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
  if ! "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2; then
    rm -f "$temporary"
    return 1
  fi
  if ! rig_sha256_file "$temporary"; then
    rm -f "$temporary"
    return 1
  fi
  actual=$RIG_VALUE
  if [ "$actual" != "$expected" ]; then
    printf 'rig: error: checksum mismatch for %s\n' "$locator" >&2
    rm -f "$temporary"
    return 1
  fi
  if [ -L "$destination" ] || { [ -e "$destination" ] && [ ! -f "$destination" ]; }; then
    printf 'rig: error: destination became unsafe before replacement: %s\n' "$destination" >&2
    rm -f "$temporary"
    return 1
  fi
  if ! chmod 0755 "$temporary" || ! mv -f "$temporary" "$destination"; then
    rm -f "$temporary"
    return 1
  fi
  if [ -L "$destination" ] || [ ! -f "$destination" ]; then
    if [ -d "$destination" ] && [ -f "$destination/${temporary##*/}" ]; then
      rm -f "$destination/${temporary##*/}"
    fi
    printf 'rig: error: destination was not replaced safely: %s\n' "$destination" >&2
    return 1
  fi
}

rig_apply_provider() {
  local tool binding provider adapter executable

  tool=$1
  binding=$2
  provider=$3
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  if [ "$adapter" = custom ]; then
    rig_prepare_provider_invocation apply "$tool" "$binding" "$provider" || return
    executable=$RIG_VALUE
    "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
  elif [ "$adapter" = direct-download ]; then
    rig_apply_direct_download "$binding" "$provider"
  else
    rig_prepare_builtin_invocation apply "$binding" "$provider" || return 2
    executable=$RIG_EXECUTABLE
    "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
  fi
}

rig_observe_resource_plan() {
  local index section_name state detail

  RIG_RESOURCE_PLAN_RESULTS=()
  RIG_RESOURCE_PLAN_DETAILS=()
  RIG_RESOURCE_PLAN_STATES=()
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
    section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
    if rig_resource_blocker "$section_name"; then
      state=unknown
      detail=blocked-by:$RIG_VALUE
    else
      rig_observe_resource "$section_name" || return
      state=$RIG_OBSERVATION
      detail=$RIG_OBSERVATION_DETAIL
    fi
    RIG_RESOURCE_PLAN_STATES[$index]=$state
    RIG_RESOURCE_PLAN_DETAILS[$index]=$detail
    case "$state" in
      present) RIG_RESOURCE_PLAN_RESULTS[$index]=observed ;;
      *) RIG_RESOURCE_PLAN_RESULTS[$index]=failed ;;
    esac
    index=$((index + 1))
  done
}

rig_lsof_command() {
  if [ -n "${RIG_LSOF_COMMAND:-}" ]; then
    [ -x "$RIG_LSOF_COMMAND" ] || return 1
    RIG_VALUE=$RIG_LSOF_COMMAND
    return 0
  fi
  RIG_VALUE=$(command -v lsof 2>/dev/null) || return 1
  [ -n "$RIG_VALUE" ]
}

rig_listener_scope() {
  local endpoint address port

  endpoint=$1
  endpoint=${endpoint% (LISTEN)}
  port=${endpoint##*:}
  case "$port" in ''|*[!0-9]*) return 1 ;; esac
  address=${endpoint%:*}
  case "$address" in
    127.*|localhost|'[::1]'|::1) RIG_VALUE=loopback ;;
    *) RIG_VALUE=all-interfaces ;;
  esac
  RIG_LISTENER_NUMBER=$port
}

rig_load_listeners() {
  local platform command output rc line pid process parsed malformed

  [ "$RIG_LISTENER_OBSERVATION_AVAILABLE" -eq 0 ] || return 0
  RIG_LISTENER_PORTS=()
  RIG_LISTENER_SCOPES=()
  RIG_LISTENER_COMMANDS=()
  RIG_LISTENER_PIDS=()
  platform=$RIG_RESOLVED_PLATFORM
  [ "$platform" = macos ] || { RIG_LISTENER_OBSERVATION_AVAILABLE=-1; return 0; }
  if ! rig_lsof_command; then
    RIG_LISTENER_OBSERVATION_AVAILABLE=-1
    return 0
  fi
  command=$RIG_VALUE
  output=$("$command" -nP -iTCP -sTCP:LISTEN -Fpcn 2>/dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    RIG_LISTENER_OBSERVATION_AVAILABLE=-1
    return 0
  fi
  pid=
  process=
  parsed=0
  malformed=0
  while IFS= read -r line; do
    case "$line" in
      p*) pid=${line#p}; process= ;;
      c*) process=${line#c} ;;
      n*)
        if rig_listener_scope "${line#n}"; then
          RIG_LISTENER_PORTS[${#RIG_LISTENER_PORTS[@]}]=$RIG_LISTENER_NUMBER
          RIG_LISTENER_SCOPES[${#RIG_LISTENER_SCOPES[@]}]=$RIG_VALUE
          RIG_LISTENER_COMMANDS[${#RIG_LISTENER_COMMANDS[@]}]=$process
          RIG_LISTENER_PIDS[${#RIG_LISTENER_PIDS[@]}]=$pid
          parsed=$((parsed + 1))
        else
          malformed=1
        fi
        ;;
    esac
  done <<< "$output"
  if [ "$malformed" -eq 1 ]; then
    RIG_LISTENER_OBSERVATION_AVAILABLE=-1
    RIG_LISTENER_PORTS=()
    RIG_LISTENER_SCOPES=()
    RIG_LISTENER_COMMANDS=()
    RIG_LISTENER_PIDS=()
    return 0
  fi
  RIG_LISTENER_OBSERVATION_AVAILABLE=1
}

rig_expected_owner_command() {
  local owner kind id section_name section_index field_index field_end value index binding

  owner=$1
  kind=${owner%%:*}
  id=${owner#*:}
  case "$kind" in
    service|scheduled-job)
      section_name=$kind.$id
      rig_section_index "$section_name" || return 1
      section_index=$RIG_INDEX
      field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
      field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
      while [ "$field_index" -lt "$field_end" ]; do
        if [ "${RIG_FIELD_KEYS[$field_index]}" = program ]; then
          value=${RIG_FIELD_VALUES[$field_index]}
          RIG_VALUE=${value##*/}
          return 0
        fi
        field_index=$((field_index + 1))
      done
      ;;
    tool)
      index=0
      while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
        if [ "${RIG_PLAN_TOOLS[$index]}" = "$id" ]; then
          binding=${RIG_PLAN_BINDINGS[$index]}
          if [ -n "$binding" ] && rig_get_value "$binding" locator; then
            value=$RIG_VALUE
            value=${value##*/}
            RIG_VALUE=${value##*:}
            return 0
          fi
          break
        fi
        index=$((index + 1))
      done
      RIG_VALUE=$id
      return 0
      ;;
  esac
  return 1
}

rig_observe_ports() {
  local index port section_name number expected_scope mode owner expected_command
  local listener_index found actual_scope observed_command command_conflict state detail

  RIG_PORT_STATES=()
  RIG_PORT_DETAILS=()
  rig_load_listeners || return
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
    port=${RIG_SELECTED_PORTS[$index]}
    section_name=port.$port
    if [ "$RIG_LISTENER_OBSERVATION_AVAILABLE" -ne 1 ]; then
      RIG_PORT_STATES[$index]=unavailable
      RIG_PORT_DETAILS[$index]=$([ "$RIG_RESOLVED_PLATFORM" = macos ] && printf listener-observation-unavailable || printf unsupported-platform)
      index=$((index + 1))
      continue
    fi
    rig_get_value "$section_name" port || return 2
    number=$RIG_VALUE
    rig_get_value "$section_name" scope || return 2
    expected_scope=$RIG_VALUE
    rig_get_value "$section_name" mode || return 2
    mode=$RIG_VALUE
    rig_get_value "$section_name" owner || return 2
    owner=$RIG_VALUE
    rig_expected_owner_command "$owner" || return 2
    expected_command=$RIG_VALUE
    found=0
    actual_scope=loopback
    observed_command=
    command_conflict=0
    listener_index=0
    while [ "$listener_index" -lt "${#RIG_LISTENER_PORTS[@]}" ]; do
      if [ "${RIG_LISTENER_PORTS[$listener_index]}" = "$number" ]; then
        found=$((found + 1))
        [ "${RIG_LISTENER_SCOPES[$listener_index]}" != all-interfaces ] || actual_scope=all-interfaces
        if [ -n "${RIG_LISTENER_COMMANDS[$listener_index]}" ]; then
          if [ -n "$observed_command" ] &&
            [ "$observed_command" != "${RIG_LISTENER_COMMANDS[$listener_index]}" ]; then
            command_conflict=1
          fi
          observed_command=${RIG_LISTENER_COMMANDS[$listener_index]}
        fi
      fi
      listener_index=$((listener_index + 1))
    done
    if [ "$found" -eq 0 ]; then
      if [ "$mode" = required ]; then
        state=missing
        detail=not-listening
      else
        state=present
        detail=available:$mode
      fi
    elif [ "$actual_scope" != "$expected_scope" ]; then
      state=drifted
      detail="scope:$actual_scope;expected:$expected_scope"
    elif [ "$command_conflict" -eq 1 ]; then
      state=conflicting
      detail=multiple-owners
    elif [ -z "$observed_command" ]; then
      if [ "$mode" = allocated ]; then
        state=present
        detail='occupied:owner-unverified'
      else
        state=unknown
        detail='owner-unavailable'
      fi
    elif [ "$observed_command" != "$expected_command" ]; then
      state=conflicting
      detail="owner:$observed_command;expected:$expected_command"
    else
      state=present
      detail="listening:$actual_scope;owner:$observed_command"
    fi
    RIG_PORT_STATES[$index]=$state
    RIG_PORT_DETAILS[$index]=$detail
    index=$((index + 1))
  done
}

rig_print_port_status() {
  local index port section_name number mode owner state detail unhealthy

  printf '\nPORT\tNUMBER\tPROTOCOL\tMODE\tOWNER\tSTATE\tDETAIL\n'
  unhealthy=0
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
    port=${RIG_SELECTED_PORTS[$index]}
    section_name=port.$port
    rig_get_value "$section_name" port || return 2
    number=$RIG_VALUE
    rig_get_value "$section_name" mode || return 2
    mode=$RIG_VALUE
    rig_get_value "$section_name" owner || return 2
    owner=$RIG_VALUE
    state=${RIG_PORT_STATES[$index]}
    detail=${RIG_PORT_DETAILS[$index]}
    [ "$state" = present ] || unhealthy=$((unhealthy + 1))
    printf '%s\t%s\ttcp\t%s\t%s\t%s\t%s\n' "$port" "$number" "$mode" "$owner" "$state" "$detail"
    index=$((index + 1))
  done
  printf 'Port summary: selected=%s unhealthy=%s\n' "${#RIG_SELECTED_PORTS[@]}" "$unhealthy"
  RIG_COUNT=$unhealthy
}

rig_port_number_declared() {
  local number index section_name

  number=$1
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = port ]; then
      section_name=${RIG_SECTION_NAMES[$index]}
      if rig_get_value "$section_name" port && [ "$RIG_VALUE" = "$number" ]; then
        return 0
      fi
    fi
    index=$((index + 1))
  done
  return 1
}

rig_print_unmanaged_listeners() {
  local index number row port scope command pid count

  rig_load_listeners || return
  printf '\nLISTENER\tPROTOCOL\tSCOPE\tSTATE\tDETAIL\n'
  if [ "$RIG_LISTENER_OBSERVATION_AVAILABLE" -ne 1 ]; then
    printf '%s\ttcp\t-\tunavailable\t%s\n' - \
      "$([ "$RIG_RESOLVED_PLATFORM" = macos ] && printf listener-observation-unavailable || printf unsupported-platform)"
    printf 'Unmanaged listeners: unavailable\n'
    return 0
  fi
  RIG_QUERY_ITEMS=()
  index=0
  while [ "$index" -lt "${#RIG_LISTENER_PORTS[@]}" ]; do
    number=${RIG_LISTENER_PORTS[$index]}
    if ! rig_port_number_declared "$number"; then
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]="$number"$'\t'"${RIG_LISTENER_SCOPES[$index]}"$'\t'"${RIG_LISTENER_COMMANDS[$index]}"$'\t'"${RIG_LISTENER_PIDS[$index]}"
    fi
    index=$((index + 1))
  done
  rig_sort_query_items
  count=0
  for row in "${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}"; do
    port=${row%%$'\t'*}
    row=${row#*$'\t'}
    scope=${row%%$'\t'*}
    row=${row#*$'\t'}
    command=${row%%$'\t'*}
    pid=${row#*$'\t'}
    printf '%s\ttcp\t%s\tunmanaged\towner:%s;pid:%s\n' "$port" "$scope" "${command:--}" "${pid:--}"
    count=$((count + 1))
  done
  printf 'Unmanaged listeners: %s\n' "$count"
}

rig_print_resource_status() {
  local index section_name section_index kind id provider state detail unhealthy

  unhealthy=0
  printf '\nRESOURCE\tKIND\tPROVIDER\tSTATE\tDETAIL\n'
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
    section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
    rig_section_index "$section_name" || return 2
    section_index=$RIG_INDEX
    kind=${RIG_SECTION_TYPES[$section_index]}
    id=${RIG_SECTION_IDS[$section_index]}
    rig_get_value "$section_name" provider || return 2
    provider=$RIG_VALUE
    state=${RIG_RESOURCE_PLAN_STATES[$index]}
    detail=${RIG_RESOURCE_PLAN_DETAILS[$index]}
    [ "$state" = present ] || unhealthy=$((unhealthy + 1))
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$kind" "$provider" "$state" "$detail"
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_STALE_RESOURCE_IDS[@]}" ]; do
    printf '%s\t%s\t%s\tdrifted\tretire-pending:%s\n' \
      "${RIG_STALE_RESOURCE_IDS[$index]}" "${RIG_STALE_RESOURCE_KINDS[$index]}" \
      "${RIG_STALE_RESOURCE_PROVIDERS[$index]}" "${RIG_STALE_RESOURCE_LOCATORS[$index]}"
    unhealthy=$((unhealthy + 1))
    index=$((index + 1))
  done
  printf 'Resource summary: selected=%s retire-pending=%s unhealthy=%s\n' \
    "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" "${#RIG_STALE_RESOURCE_IDS[@]}" "$unhealthy"
  RIG_COUNT=$unhealthy
}

rig_skill_runtime_path() {
  local runtime skill

  runtime=$1
  skill=$2
  [ -n "${HOME:-}" ] || return 1
  case "$runtime" in
    agents) RIG_VALUE=$HOME/.agents/skills/$skill ;;
    claude-code) RIG_VALUE=$HOME/.claude/skills/$skill ;;
    codex) RIG_VALUE=$HOME/.codex/skills/$skill ;;
    github-copilot) RIG_VALUE=$HOME/.copilot/skills/$skill ;;
    warp) RIG_VALUE=$HOME/.warp/skills/$skill ;;
    zed) RIG_VALUE=${XDG_CONFIG_HOME:-$HOME/.config}/zed/skills/$skill ;;
    *) return 1 ;;
  esac
}

rig_skill_source_name() {
  local skill
  skill=$1
  if rig_get_value "skill.$skill" source-skill; then return 0; fi
  RIG_VALUE=$skill
}

rig_skills_cli_load_inventory() {
  local executable version name_re source_re agents_re text index character escaped quoted depth object name source agents

  [ "$RIG_SKILLS_INVENTORY_LOADED" -eq 0 ] || return 0
  RIG_SKILLS_INVENTORY_LOADED=1
  RIG_SKILLS_INVENTORY_STATUS=unavailable
  RIG_SKILLS_INVENTORY_DETAIL=inventory-unavailable
  rig_provider_executable skills-cli skills-cli skill || return 0
  executable=$RIG_VALUE
  rig_executable_available "$executable" || { RIG_SKILLS_INVENTORY_DETAIL='executable-unavailable'; return 0; }
  version=$("$executable" --version 2>/dev/null) || { RIG_SKILLS_INVENTORY_DETAIL='version-unavailable'; return 0; }
  case "$version" in 1.*|skills\ 1.*) ;; *) RIG_SKILLS_INVENTORY_DETAIL=unsupported-version; return 0 ;; esac
  RIG_INVOKE_ARGUMENTS=(list --global --json)
  rig_capture_invocation "$executable"
  [ "$RIG_NATIVE_STATUS" -eq 0 ] || { RIG_SKILLS_INVENTORY_DETAIL=exit:$RIG_NATIVE_STATUS; return 0; }
  text=$RIG_CAPTURED_OUTPUT
  case "$text" in \[*\]) ;; *) RIG_SKILLS_INVENTORY_DETAIL='malformed-json'; return 0 ;; esac
  name_re='"name"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
  source_re='"source"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
  agents_re='"agents"[[:space:]]*:[[:space:]]*\[([^]]*)\]'
  index=0
  quoted=0
  escaped=0
  depth=0
  object=
  while [ "$index" -lt "${#text}" ]; do
    character=${text:$index:1}
    if [ "$depth" -gt 0 ]; then object=$object$character; fi
    if [ "$quoted" -eq 1 ]; then
      if [ "$escaped" -eq 1 ]; then
        escaped=0
      else
        case "$character" in
          \\) escaped=1 ;;
          '"') quoted=0 ;;
        esac
      fi
    else
      case "$character" in
        '"') quoted=1 ;;
        '{')
          depth=$((depth + 1))
          [ "$depth" -ne 1 ] || object='{'
          ;;
        '}')
          depth=$((depth - 1))
          [ "$depth" -ge 0 ] || { RIG_SKILLS_INVENTORY_DETAIL='malformed-json'; return 0; }
          if [ "$depth" -eq 0 ]; then
            [[ "$object" =~ $name_re ]] || { RIG_SKILLS_INVENTORY_DETAIL='malformed-json'; return 0; }
            name=${BASH_REMATCH[1]}
            source=
            [[ "$object" =~ $source_re ]] && source=${BASH_REMATCH[1]}
            agents=
            [[ "$object" =~ $agents_re ]] && agents=${BASH_REMATCH[1]}
            RIG_SKILLS_INVENTORY_NAMES[${#RIG_SKILLS_INVENTORY_NAMES[@]}]=$name
            RIG_SKILLS_INVENTORY_SOURCES[${#RIG_SKILLS_INVENTORY_SOURCES[@]}]=$source
            RIG_SKILLS_INVENTORY_AGENTS[${#RIG_SKILLS_INVENTORY_AGENTS[@]}]=$agents
            object=
          fi
          ;;
      esac
    fi
    index=$((index + 1))
  done
  [ "$depth" -eq 0 ] && [ "$quoted" -eq 0 ] || { RIG_SKILLS_INVENTORY_DETAIL='malformed-json'; return 0; }
  RIG_SKILLS_INVENTORY_STATUS=ok
  RIG_SKILLS_INVENTORY_DETAIL=-
}

rig_skill_runtime_display() {
  case "$1" in
    agents) RIG_VALUE=Agents ;;
    claude-code) RIG_VALUE='Claude Code' ;;
    codex) RIG_VALUE=Codex ;;
    github-copilot) RIG_VALUE='GitHub Copilot' ;;
    warp) RIG_VALUE=Warp ;;
    zed) RIG_VALUE=Zed ;;
    *) return 1 ;;
  esac
}

rig_observe_skill() {
  local skill section_name authority source source_skill index found observed_source agents runtime display target root canonical

  skill=$1
  section_name=skill.$skill
  rig_get_value "$section_name" authority || return 2
  authority=$RIG_VALUE
  rig_get_value "$section_name" source || return 2
  source=$RIG_VALUE
  rig_skill_source_name "$skill" || return 2
  source_skill=$RIG_VALUE
  RIG_OBSERVATION=unknown
  RIG_OBSERVATION_DETAIL=-
  case "$authority" in
    ki)
      RIG_OBSERVATION=unavailable
      RIG_OBSERVATION_DETAIL=inventory-unavailable
      return 0
      ;;
    skills-cli)
      rig_skills_cli_load_inventory || return 2
      if [ "$RIG_SKILLS_INVENTORY_STATUS" != ok ]; then
        RIG_OBSERVATION=unavailable
        RIG_OBSERVATION_DETAIL=$RIG_SKILLS_INVENTORY_DETAIL
        return 0
      fi
      found=0
      index=0
      while [ "$index" -lt "${#RIG_SKILLS_INVENTORY_NAMES[@]}" ]; do
        if [ "${RIG_SKILLS_INVENTORY_NAMES[$index]}" = "$source_skill" ]; then
          found=1
          observed_source=${RIG_SKILLS_INVENTORY_SOURCES[$index]}
          agents=${RIG_SKILLS_INVENTORY_AGENTS[$index]}
          break
        fi
        index=$((index + 1))
      done
      if [ "$found" -eq 0 ]; then RIG_OBSERVATION=missing; RIG_OBSERVATION_DETAIL=not-installed; return 0; fi
      if [ -z "$observed_source" ]; then RIG_OBSERVATION=drifted; RIG_OBSERVATION_DETAIL=provenance-missing; return 0; fi
      if [ "$observed_source" != "$source" ]; then RIG_OBSERVATION=drifted; RIG_OBSERVATION_DETAIL='source-mismatch'; return 0; fi
      rig_collect_field_values "$section_name" runtime
      for runtime in "${RIG_QUERY_ITEMS[@]}"; do
        rig_skill_runtime_display "$runtime" || return 2
        display=$RIG_VALUE
        case "$agents" in *"\"$display\""*) ;; *) RIG_OBSERVATION=missing; RIG_OBSERVATION_DETAIL=runtime-missing:$runtime; return 0 ;; esac
      done
      RIG_OBSERVATION=present
      RIG_OBSERVATION_DETAIL=verified-source-and-runtimes
      return 0
      ;;
    local)
      rig_normalize_artifact_identity "$source"
      root=$RIG_VALUE
      if [ -L "$root" ] || [ ! -d "$root" ] || [ ! -f "$root/SKILL.md" ]; then
        RIG_OBSERVATION=unavailable
        RIG_OBSERVATION_DETAIL=unsafe-local-source
        return 0
      fi
      canonical=$(cd "$root" 2>/dev/null && pwd -P) || { RIG_OBSERVATION=unavailable; RIG_OBSERVATION_DETAIL=unsafe-local-source; return 0; }
      ;;
    runtime|plugin) canonical= ;;
  esac
  rig_collect_field_values "$section_name" runtime
  for runtime in "${RIG_QUERY_ITEMS[@]}"; do
    rig_skill_runtime_path "$runtime" "$source_skill" || return 2
    target=$RIG_VALUE
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then RIG_OBSERVATION=missing; RIG_OBSERVATION_DETAIL=runtime-missing:$runtime; return 0; fi
    if [ "$authority" = local ]; then
      [ -L "$target" ] || { RIG_OBSERVATION=drifted; RIG_OBSERVATION_DETAIL=foreign-target:$runtime; return 0; }
      [ "$(readlink "$target")" = "$canonical" ] || { RIG_OBSERVATION=drifted; RIG_OBSERVATION_DETAIL=source-mismatch:$runtime; return 0; }
    elif [ ! -d "$target" ] || [ ! -f "$target/SKILL.md" ]; then
      RIG_OBSERVATION=drifted
      RIG_OBSERVATION_DETAIL=invalid-projection:$runtime
      return 0
    fi
  done
  RIG_OBSERVATION=present
  RIG_OBSERVATION_DETAIL='authority-owned'
}

rig_observe_skills() {
  local index skill
  RIG_SKILL_STATES=()
  RIG_SKILL_DETAILS=()
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    skill=${RIG_SELECTED_SKILLS[$index]}
    rig_observe_skill "$skill" || return
    RIG_SKILL_STATES[$index]=$RIG_OBSERVATION
    RIG_SKILL_DETAILS[$index]=$RIG_OBSERVATION_DETAIL
    index=$((index + 1))
  done
}

rig_print_skill_status() {
  local index skill authority state detail unhealthy
  printf '\nSKILL\tAUTHORITY\tSTATE\tDETAIL\n'
  unhealthy=0
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    skill=${RIG_SELECTED_SKILLS[$index]}
    rig_get_value "skill.$skill" authority || return 2
    authority=$RIG_VALUE
    state=${RIG_SKILL_STATES[$index]}
    detail=${RIG_SKILL_DETAILS[$index]}
    [ "$state" = present ] || unhealthy=$((unhealthy + 1))
    printf '%s\t%s\t%s\t%s\n' "$skill" "$authority" "$state" "$detail"
    index=$((index + 1))
  done
  RIG_COUNT=$unhealthy
}

rig_skill_source_is_declared() {
  local wanted section_index section_name source_name

  wanted=$1
  section_index=0
  while [ "$section_index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    section_name=${RIG_SECTION_NAMES[$section_index]}
    case "$section_name" in
      skill.*)
        if rig_get_value "$section_name" authority && [ "$RIG_VALUE" = skills-cli ]; then
          if rig_get_value "$section_name" source-skill; then
            source_name=$RIG_VALUE
          else
            source_name=${section_name#skill.}
          fi
          if [ "$source_name" = "$wanted" ]; then
            return 0
          fi
        fi
        ;;
    esac
    section_index=$((section_index + 1))
  done
  return 1
}

rig_print_unmanaged_skills() {
  local index name count

  rig_skills_cli_load_inventory || return 2
  if [ "$RIG_SKILLS_INVENTORY_STATUS" != ok ]; then
    printf '\nUnmanaged skills unavailable: %s\n' "$RIG_SKILLS_INVENTORY_DETAIL"
    return 0
  fi
  count=0
  printf '\nSKILL\tAUTHORITY\tSTATE\tDETAIL\n'
  index=0
  while [ "$index" -lt "${#RIG_SKILLS_INVENTORY_NAMES[@]}" ]; do
    name=${RIG_SKILLS_INVENTORY_NAMES[$index]}
    if ! rig_skill_source_is_declared "$name"; then
      printf '%s\tskills-cli\tunmanaged\tglobal\n' "$name"
      count=$((count + 1))
    fi
    index=$((index + 1))
  done
  printf 'Unmanaged skills: %s\n' "$count"
}

rig_command_status() {
  local profile index tool provider state detail unhealthy unmanaged_requested
  local present missing drifted unavailable unknown catalogue_only

  profile=
  unmanaged_requested=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        printf '%s\n' 'Usage: rig status [--profile NAME] [--unmanaged]'
        return
        ;;
      --unmanaged)
        unmanaged_requested=1
        shift
        ;;
      --profile)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          syntax_error 'usage: rig status [--profile NAME] [--unmanaged]'
          return
        fi
        profile=$2
        shift 2
        ;;
      *)
        syntax_error 'usage: rig status [--profile NAME] [--unmanaged]'
        return
        ;;
    esac
  done

  rig_resolve_operational_plan "$profile" || return
  rig_observe_plan || return
  if [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ] ||
    [ "${#RIG_STALE_RESOURCE_IDS[@]}" -gt 0 ]; then
    rig_observe_resource_plan || return
  fi
  if [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ]; then
    rig_observe_ports || return
  fi
  if [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ]; then
    rig_observe_skills || return
  fi
  printf 'Profile: %s\nPlatform: %s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  printf 'TOOL\tPROVIDER\tSTATE\tDETAIL\n'
  unhealthy=0
  present=0
  missing=0
  drifted=0
  unavailable=0
  unknown=0
  catalogue_only=0
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    state=${RIG_PLAN_STATES[$index]}
    detail=${RIG_PLAN_DETAILS[$index]}
    case "$state" in
      present) present=$((present + 1)) ;;
      missing) missing=$((missing + 1)) ;;
      drifted) drifted=$((drifted + 1)) ;;
      unavailable)
        unavailable=$((unavailable + 1))
        [ "${RIG_PLAN_RESULTS[$index]}" = neutral ] && catalogue_only=$((catalogue_only + 1))
        ;;
      unknown) unknown=$((unknown + 1)) ;;
    esac
    [ "${RIG_PLAN_RESULTS[$index]}" = neutral ] || [ "$state" = present ] || unhealthy=$((unhealthy + 1))
    printf '%s\t%s\t%s\t%s\n' "$tool" "$provider" "$state" "$detail"
    index=$((index + 1))
  done
  printf 'Summary: present=%s missing=%s drifted=%s unavailable=%s unknown=%s catalogue-only=%s\n' \
    "$present" "$missing" "$drifted" "$unavailable" "$unknown" "$catalogue_only"
  if [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ]; then
    rig_print_skill_status || return
    [ "$RIG_COUNT" -eq 0 ] || unhealthy=$((unhealthy + RIG_COUNT))
  fi
  if [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ] ||
    [ "${#RIG_STALE_RESOURCE_IDS[@]}" -gt 0 ]; then
    rig_print_resource_status || return
    [ "$RIG_COUNT" -eq 0 ] || unhealthy=$((unhealthy + RIG_COUNT))
  fi
  if [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ]; then
    rig_print_port_status || return
    [ "$RIG_COUNT" -eq 0 ] || unhealthy=$((unhealthy + RIG_COUNT))
  fi
  if [ "$unmanaged_requested" -eq 1 ]; then
    rig_collect_unmanaged || return
    printf '\nIDENTITY\tPROVIDER\tSTATE\tDETAIL\n'
    index=0
    while [ "$index" -lt "${#RIG_UNMANAGED_IDENTITIES[@]}" ]; do
      printf '%s\t%s\tunmanaged\t%s\n' \
        "${RIG_UNMANAGED_IDENTITIES[$index]}" \
        "${RIG_UNMANAGED_PROVIDERS[$index]}" \
        "${RIG_UNMANAGED_DETAILS[$index]}"
      index=$((index + 1))
    done
    index=0
    while [ "$index" -lt "${#RIG_UNMANAGED_PROBLEMS[@]}" ]; do
      printf '%s\n' "${RIG_UNMANAGED_PROBLEMS[$index]}"
      index=$((index + 1))
    done
    printf 'Unmanaged: %s\n' "${#RIG_UNMANAGED_IDENTITIES[@]}"
    rig_print_unmanaged_listeners || return
    rig_print_unmanaged_skills || return
  fi
  [ "$unhealthy" -eq 0 ]
}

rig_doctor_path_finding() {
  local label candidate ancestor

  label=$1
  candidate=$2
  if [ -e "$candidate" ]; then
    if [ ! -d "$candidate" ]; then
      printf '  %s: %s; owner=configuration; action=replace-with-directory\n' "$label" "$candidate"
      return 0
    fi
    if [ ! -r "$candidate" ] || [ ! -x "$candidate" ]; then
      printf '  %s: %s; owner=configuration; action=restore-directory-access\n' "$label" "$candidate"
      return 0
    fi
    return 1
  fi

  ancestor=$candidate
  while [ ! -e "$ancestor" ] && [ "$ancestor" != / ]; do
    ancestor=${ancestor%/*}
    [ -n "$ancestor" ] || ancestor=/
  done
  if [ ! -d "$ancestor" ] || [ ! -w "$ancestor" ] || [ ! -x "$ancestor" ]; then
    printf '  %s: %s; owner=configuration; action=make-parent-writable\n' "$label" "$candidate"
    return 0
  fi
  return 1
}

rig_doctor_incompatible_tools() {
  local profile platform index tool count information
  local -a tools

  profile=$1
  platform=$2
  count=0
  information=
  rig_collect_section_ids tool
  tools=("${RIG_QUERY_ITEMS[@]}")
  index=0
  while [ "$index" -lt "${#tools[@]}" ]; do
    tool=${tools[$index]}
    if { rig_profile_contains_declared_tool "$profile" "$tool" ||
      rig_profile_requires_tool "$profile" "$tool"; } &&
      ! rig_tool_supports_platform "$tool" "$platform"; then
      information="${information}  ${tool}: incompatible-platform; owner=catalogue; action=none"$'\n'
      count=$((count + 1))
    fi
    index=$((index + 1))
  done
  RIG_COUNT=$count
  RIG_VALUE=${information%$'\n'}
}

rig_observe_plan() {
  local index tool binding provider adapter state detail findings present catalogue_only
  local findings_output

  findings=0
  present=0
  catalogue_only=0
  findings_output=
  RIG_PLAN_RESULTS=()
  RIG_PLAN_DETAILS=()
  RIG_PLAN_STATES=()
  rig_progress_start observing "${#RIG_PLAN_TOOLS[@]}"
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    rig_progress_step "$tool${provider:+ via $provider}"
    detail=-
    if [ -z "$binding" ]; then
      state=unavailable
      detail=catalogue-only
      RIG_PLAN_RESULTS[$index]=neutral
      catalogue_only=$((catalogue_only + 1))
    elif rig_plan_blocker "$tool"; then
      state=unknown
      detail=blocked-by:$RIG_VALUE
      RIG_PLAN_RESULTS[$index]=skipped
    elif ! rig_provider_has_capability "$provider" observe; then
      state=unavailable
      detail=unsupported-capability:observe
      RIG_PLAN_RESULTS[$index]=failed
    else
      rig_provider_adapter "$provider" || return 2
      adapter=$RIG_VALUE
      if [ "$adapter" != custom ] && ! rig_adapter_is_builtin "$adapter"; then
        state=unavailable
        detail=unsupported-adapter:$adapter
        RIG_PLAN_RESULTS[$index]=failed
      else
      rig_observe_provider "$tool" "$binding" "$provider" || return
      state=$RIG_OBSERVATION
      detail=$RIG_OBSERVATION_DETAIL
      if [ "$state" = present ]; then
        rig_observe_tool_artifacts "$tool" || return
        state=$RIG_ARTIFACT_STATE
        detail=$RIG_ARTIFACT_DETAIL
      fi
      if [ "$state" = present ] || [ "$state" = missing ] || [ "$state" = drifted ]; then
          RIG_PLAN_RESULTS[$index]=observed
        else
          RIG_PLAN_RESULTS[$index]=failed
        fi
      fi
    fi
    RIG_PLAN_DETAILS[$index]=$detail
    RIG_PLAN_STATES[$index]=$state
    if [ "${RIG_PLAN_RESULTS[$index]}" = neutral ]; then
      :
    elif [ "$state" = present ]; then
      present=$((present + 1))
    else
      case "$state:$detail" in
        missing:*) RIG_OBSERVATION_DETAIL=run-rig-apply ;;
        drifted:*) RIG_OBSERVATION_DETAIL=review-then-run-rig-apply ;;
        unknown:blocked-by:*) RIG_OBSERVATION_DETAIL=resolve-${detail#blocked-by:} ;;
        unavailable:unsupported-capability:*) RIG_OBSERVATION_DETAIL=declare-observe-capability ;;
        unavailable:unsupported-adapter:*) RIG_OBSERVATION_DETAIL=select-supported-adapter ;;
        unavailable:executable-unavailable) RIG_OBSERVATION_DETAIL=install-or-configure-provider ;;
        *) RIG_OBSERVATION_DETAIL=inspect-provider-diagnostics ;;
      esac
      findings_output="${findings_output}  ${tool}: ${state} via ${provider} (${detail}); owner=${provider}; action=${RIG_OBSERVATION_DETAIL}"$'\n'
      findings=$((findings + 1))
    fi
    index=$((index + 1))
  done
  rig_progress_finish
  RIG_VALUE=${findings_output%$'\n'}
  RIG_DOCTOR_FINDINGS=$findings
  RIG_DOCTOR_PRESENT=$present
  RIG_DOCTOR_CATALOGUE_ONLY=$catalogue_only
}

rig_command_doctor() {
  local profile findings incompatible xdg_findings tool_findings resource_findings port_findings skill_findings
  local index section_name state detail port owner action skill authority

  profile=
  case "$#" in
    0) ;;
    1)
      case "$1" in
        -h|--help) printf '%s\n' 'Usage: rig doctor [--profile NAME]'; return ;;
        *) syntax_error 'usage: rig doctor [--profile NAME]'; return ;;
      esac
      ;;
    2)
      if [ "$1" != --profile ] || [ -z "$2" ]; then
        syntax_error 'usage: rig doctor [--profile NAME]'
        return
      fi
      profile=$2
      ;;
    *) syntax_error 'usage: rig doctor [--profile NAME]'; return ;;
  esac

  rig_resolve_operational_plan "$profile" || return
  rig_effective_paths || return 2
  rig_observe_plan || return
  tool_findings=$RIG_VALUE
  findings=$RIG_DOCTOR_FINDINGS
  resource_findings=
  if [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ]; then
    rig_observe_resource_plan || return
    index=0
    while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
      section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
      state=${RIG_RESOURCE_PLAN_STATES[$index]}
      detail=${RIG_RESOURCE_PLAN_DETAILS[$index]}
      if [ "$state" != present ]; then
        resource_findings="${resource_findings}  ${section_name}: ${state} (${detail}); owner=provider; action=review-then-run-rig-apply"$'\n'
        findings=$((findings + 1))
      fi
      index=$((index + 1))
    done
  fi
  index=0
  while [ "$index" -lt "${#RIG_STALE_RESOURCE_IDS[@]}" ]; do
    resource_findings="${resource_findings}  ${RIG_STALE_RESOURCE_KINDS[$index]}.${RIG_STALE_RESOURCE_IDS[$index]}: drifted (retire-pending); owner=${RIG_STALE_RESOURCE_PROVIDERS[$index]}; action=review-then-run-rig-apply"$'\n'
    findings=$((findings + 1))
    index=$((index + 1))
  done
  resource_findings=${resource_findings%$'\n'}
  port_findings=
  if [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ]; then
    rig_observe_ports || return
    index=0
    while [ "$index" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
      port=${RIG_SELECTED_PORTS[$index]}
      state=${RIG_PORT_STATES[$index]}
      detail=${RIG_PORT_DETAILS[$index]}
      if [ "$state" != present ]; then
        rig_get_value "port.$port" owner || return 2
        owner=$RIG_VALUE
        case "$state" in
          missing) action=start-owner ;;
          drifted) action=correct-listener-scope ;;
          conflicting) action=stop-or-reconfigure-occupant ;;
          *) action=inspect-listener-observation ;;
        esac
        port_findings="${port_findings}  port.${port}: ${state} (${detail}); owner=${owner}; action=${action}"$'\n'
        findings=$((findings + 1))
      fi
      index=$((index + 1))
    done
    port_findings=${port_findings%$'\n'}
  fi
  skill_findings=
  if [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ]; then
    rig_observe_skills || return
    index=0
    while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
      skill=${RIG_SELECTED_SKILLS[$index]}
      state=${RIG_SKILL_STATES[$index]}
      detail=${RIG_SKILL_DETAILS[$index]}
      if [ "$state" != present ]; then
        rig_get_value "skill.$skill" authority || return 2
        authority=$RIG_VALUE
        case "$state" in
          missing) action=run-rig-apply ;;
          drifted) action=review-source-and-run-rig-apply ;;
          *) action=inspect-native-authority ;;
        esac
        skill_findings="${skill_findings} skill.${skill}: ${state} (${detail}); owner=${authority}; action=${action}"$'\n'
        findings=$((findings + 1))
      fi
      index=$((index + 1))
    done
    skill_findings=${skill_findings%$'\n'}
  fi
  xdg_findings=$(rig_doctor_path_finding config "$RIG_DIAG_CONFIG_HOME"; \
    rig_doctor_path_finding data "$RIG_DIAG_DATA_HOME"; \
    rig_doctor_path_finding state "$RIG_DIAG_STATE_HOME"; \
    rig_doctor_path_finding cache "$RIG_DIAG_CACHE_HOME")
  if [ -n "$xdg_findings" ]; then
    while IFS= read -r _; do findings=$((findings + 1)); done <<< "$xdg_findings"
  fi

  printf 'Rig doctor: %s\nProfile: %s\nPlatform: %s\n' \
    "$([ "$findings" -eq 0 ] && printf healthy || printf findings)" \
    "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  if [ -n "$xdg_findings" ]; then
    printf 'XDG findings:\n%s\n' "$xdg_findings"
  fi
  if [ -n "$tool_findings" ]; then
    printf 'Tool findings:\n%s\n' "$tool_findings"
  fi
  if [ -n "$resource_findings" ]; then
    printf 'Resource findings:\n%s\n' "$resource_findings"
  fi
  if [ -n "$port_findings" ]; then
    printf 'Port findings:\n%s\n' "$port_findings"
  fi
  if [ -n "$skill_findings" ]; then
    printf 'Skill findings:\n%s\n' "$skill_findings"
  fi
  rig_doctor_incompatible_tools "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  incompatible=$RIG_COUNT
  if [ -n "$RIG_VALUE" ]; then
    printf 'Information:\n%s\n' "$RIG_VALUE"
  fi
  printf 'Summary: findings=%s present=%s catalogue-only=%s incompatible-platform=%s\n' \
    "$findings" "$RIG_DOCTOR_PRESENT" "$RIG_DOCTOR_CATALOGUE_ONLY" "$incompatible"
  [ "$findings" -eq 0 ]
}

rig_local_skill_roots() {
  local skill section_name source runtime target parent canonical_source canonical_parent

  skill=$1
  section_name=skill.$skill
  rig_get_value "$section_name" source || return 2
  rig_normalize_artifact_identity "$RIG_VALUE"
  source=$RIG_VALUE
  [ ! -L "$source" ] && [ -d "$source" ] && [ -f "$source/SKILL.md" ] && [ ! -L "$source/SKILL.md" ] || return 1
  canonical_source=$(cd "$source" 2>/dev/null && pwd -P) || return 1
  rig_skill_source_name "$skill" || return 2
  skill=$RIG_VALUE
  rig_collect_field_values "$section_name" runtime
  for runtime in "${RIG_QUERY_ITEMS[@]}"; do
    rig_skill_runtime_path "$runtime" "$skill" || return 2
    target=$RIG_VALUE
    parent=${target%/*}
    [ ! -L "$parent" ] && [ -d "$parent" ] && [ -w "$parent" ] || return 1
    canonical_parent=$(cd "$parent" 2>/dev/null && pwd -P) || return 1
    target=$canonical_parent/${target##*/}
    case "$target" in "$canonical_parent"/*) ;; *) return 1 ;; esac
    if [ -e "$target" ] || [ -L "$target" ]; then
      [ -L "$target" ] && [ "$(readlink "$target")" = "$canonical_source" ] || return 1
    fi
  done
  RIG_VALUE=$canonical_source
}

rig_preflight_skill() {
  local skill authority executable version

  skill=$1
  RIG_SKILL_PREFLIGHT_DETAIL=
  rig_get_value "skill.$skill" authority || return 2
  authority=$RIG_VALUE
  case "$authority" in
    skills-cli)
      rig_provider_executable skills-cli skills-cli skill || return 2
      executable=$RIG_VALUE
      if ! rig_executable_available "$executable"; then
        if [ "${RIG_BOOTSTRAP_ALLOW_DEFERRED_SKILLS:-0}" -eq 1 ] &&
          rig_skill_has_materializer_tool "$skill"; then return 0; fi
        RIG_SKILL_PREFLIGHT_DETAIL='executable-unavailable'
        return 1
      fi
      version=$("$executable" --version 2>/dev/null) || { RIG_SKILL_PREFLIGHT_DETAIL='version-unavailable'; return 1; }
      case "$version" in 1.*|skills\ 1.*) ;; *) RIG_SKILL_PREFLIGHT_DETAIL=unsupported-version; return 1 ;; esac
      ;;
    local)
      rig_local_skill_roots "$skill" || { RIG_SKILL_PREFLIGHT_DETAIL=unsafe-local-boundary; return 1; }
      ;;
    ki) RIG_SKILL_PREFLIGHT_DETAIL=inventory-unavailable; return 1 ;;
    runtime|plugin) RIG_SKILL_PREFLIGHT_DETAIL=observation-only; return 1 ;;
  esac
}

rig_skill_has_materializer_tool() {
  local skill section_index field_index field_end tool binding provider locator

  skill=$1
  rig_section_index "skill.$skill" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      tool=${RIG_FIELD_VALUES[$field_index]}
      if rig_plan_index "$tool"; then
        binding=${RIG_PLAN_BINDINGS[$RIG_INDEX]:-}
        provider=${RIG_PLAN_PROVIDERS[$RIG_INDEX]:-}
        if [ "$provider" = npm ] && [ -n "$binding" ]; then
          rig_get_value "$binding" locator || return 1
          locator=$RIG_VALUE
          case "$locator" in skills|skills@*) return 0 ;; esac
        fi
      fi
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_preflight_skills() {
  local index skill

  RIG_SKILL_PREFLIGHT_DETAILS=()
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    skill=${RIG_SELECTED_SKILLS[$index]}
    RIG_SKILL_PREFLIGHT_DETAIL=
    if rig_preflight_skill "$skill"; then
      RIG_SKILL_PREFLIGHT_DETAILS[$index]=
    else
      RIG_SKILL_PREFLIGHT_DETAILS[$index]=${RIG_SKILL_PREFLIGHT_DETAIL:-preflight-failed}
    fi
    index=$((index + 1))
  done
}

rig_skill_tool_blocker() {
  local skill section_index field_index field_end tool

  skill=$1
  rig_section_index "skill.$skill" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      tool=${RIG_FIELD_VALUES[$field_index]}
      if rig_plan_index "$tool"; then
        case "${RIG_PLAN_RESULTS[$RIG_INDEX]:-}" in completed|planned|neutral|observed) ;; *) RIG_VALUE=$tool; return 0 ;; esac
      fi
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_apply_skill() {
  local skill section_name authority source source_skill executable runtime target parent canonical_source

  skill=$1
  section_name=skill.$skill
  rig_get_value "$section_name" authority || return 2
  authority=$RIG_VALUE
  case "$authority" in
    skills-cli)
      rig_provider_executable skills-cli skills-cli skill || return 2
      executable=$RIG_VALUE
      rig_get_value "$section_name" source || return 2
      source=$RIG_VALUE
      rig_skill_source_name "$skill" || return 2
      source_skill=$RIG_VALUE
      RIG_INVOKE_ARGUMENTS=(add "$source" --global --skill "$source_skill")
      rig_collect_field_values "$section_name" runtime
      for runtime in "${RIG_QUERY_ITEMS[@]}"; do
        [ "$runtime" != agents ] || continue
        RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--agent
        RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$runtime
      done
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--yes
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--json
      "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
      ;;
    local)
      rig_local_skill_roots "$skill" || return 2
      canonical_source=$RIG_VALUE
      rig_skill_source_name "$skill" || return 2
      source_skill=$RIG_VALUE
      rig_collect_field_values "$section_name" runtime
      for runtime in "${RIG_QUERY_ITEMS[@]}"; do
        rig_skill_runtime_path "$runtime" "$source_skill" || return 2
        target=$RIG_VALUE
        parent=${target%/*}
        # Revalidate every component immediately before creating only a missing leaf.
        [ ! -L "$canonical_source" ] && [ -d "$canonical_source" ] && [ -f "$canonical_source/SKILL.md" ] || return 2
        [ ! -L "$parent" ] && [ -d "$parent" ] || return 2
        parent=$(cd "$parent" && pwd -P) || return 2
        target=$parent/${target##*/}
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
          ln -s -- "$canonical_source" "$target" || return
        elif [ ! -L "$target" ] || [ "$(readlink "$target")" != "$canonical_source" ]; then
          return 2
        fi
      done
      ;;
    *) return 2 ;;
  esac
}

rig_run_skill_apply() {
  local dry_run index skill authority blocker native_status

  dry_run=$1
  RIG_SKILL_APPLY_FAILURE=0
  RIG_SKILL_PLANNED=0
  RIG_SKILL_COMPLETED=0
  RIG_SKILL_FAILED=0
  RIG_SKILL_SKIPPED=0
  [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ] || return 0
  printf '\nSKILL\tAUTHORITY\tRESULT\tDETAIL\tSCOPE\n'
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    skill=${RIG_SELECTED_SKILLS[$index]}
    rig_get_value "skill.$skill" authority || return 2
    authority=$RIG_VALUE
    if [ -n "${RIG_SKILL_PREFLIGHT_DETAILS[$index]:-}" ]; then
      RIG_SKILL_RESULTS[$index]=failed
      RIG_SKILL_DETAILS[$index]=preflight:${RIG_SKILL_PREFLIGHT_DETAILS[$index]}
      RIG_SKILL_APPLY_FAILURE=1
      RIG_SKILL_FAILED=$((RIG_SKILL_FAILED + 1))
    elif [ "$dry_run" -eq 1 ]; then
      RIG_SKILL_RESULTS[$index]=planned
      RIG_SKILL_DETAILS[$index]=-
      RIG_SKILL_PLANNED=$((RIG_SKILL_PLANNED + 1))
    elif rig_skill_tool_blocker "$skill"; then
      blocker=$RIG_VALUE
      RIG_SKILL_RESULTS[$index]=skipped
      RIG_SKILL_DETAILS[$index]=blocked-by:$blocker
      RIG_SKILL_APPLY_FAILURE=1
      RIG_SKILL_SKIPPED=$((RIG_SKILL_SKIPPED + 1))
    else
      rig_progress_step "skill.$skill via $authority"
      rig_apply_skill "$skill"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        RIG_SKILL_RESULTS[$index]=completed
        RIG_SKILL_DETAILS[$index]=-
        RIG_SKILL_COMPLETED=$((RIG_SKILL_COMPLETED + 1))
      else
        RIG_SKILL_RESULTS[$index]=failed
        RIG_SKILL_DETAILS[$index]=exit:$native_status
        RIG_SKILL_APPLY_FAILURE=1
        RIG_SKILL_FAILED=$((RIG_SKILL_FAILED + 1))
      fi
    fi
    printf '%s\t%s\t%s\t%s\tdeclaration\n' "$skill" "$authority" \
      "${RIG_SKILL_RESULTS[$index]}" "${RIG_SKILL_DETAILS[$index]}"
    index=$((index + 1))
  done
}

rig_preflight_apply() {
  local scope index section_name native_status

  scope=${1:-all}
  if [ "$scope" = tools ] || [ "$scope" = all ]; then
    index=0
    while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
      if [ -n "${RIG_PLAN_BINDINGS[$index]}" ]; then
        rig_preflight_provider "${RIG_PLAN_TOOLS[$index]}" \
          "${RIG_PLAN_BINDINGS[$index]}" "${RIG_PLAN_PROVIDERS[$index]}" || return
      fi
      index=$((index + 1))
    done
  fi
  if [ "$scope" = skills ] || [ "$scope" = all ]; then
    rig_preflight_skills || return
  else
    RIG_SKILL_PREFLIGHT_DETAILS=()
  fi
  { [ "$scope" = resources ] || [ "$scope" = all ]; } || return 0
  RIG_RESOURCE_PREFLIGHT_DETAILS=()
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
    section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
    RIG_RESOURCE_PREFLIGHT_DETAIL=
    rig_preflight_resource "$section_name" apply-resource
    native_status=$?
    case "$native_status" in
      0) RIG_RESOURCE_PREFLIGHT_DETAILS[$index]= ;;
      1)
        RIG_RESOURCE_PREFLIGHT_DETAILS[$index]=${RIG_RESOURCE_PREFLIGHT_DETAIL:-resource-unavailable}
        ;;
      *) return "$native_status" ;;
    esac
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_STALE_RESOURCE_IDS[@]}" ]; do
    rig_prepare_retire_invocation \
      "${RIG_STALE_RESOURCE_PROVIDERS[$index]}" \
      "${RIG_STALE_RESOURCE_KINDS[$index]}" \
      "${RIG_STALE_RESOURCE_IDS[$index]}" \
      "${RIG_STALE_RESOURCE_LOCATORS[$index]}" || return
    index=$((index + 1))
  done
  if [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ] ||
    [ "${#RIG_STALE_RESOURCE_IDS[@]}" -gt 0 ]; then
    rig_preflight_resource_receipt "$RIG_RESOLVED_PLATFORM" || return
  fi
}

rig_resource_plan_index() {
  local wanted index

  wanted=$1
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
    if [ "${RIG_RESOURCE_PLAN_SECTIONS[$index]}" = "$wanted" ]; then
      RIG_INDEX=$index
      return 0
    fi
    index=$((index + 1))
  done
  RIG_INDEX=
  return 1
}

rig_resource_blocker() {
  local section_name section_index field_index field_end tool reference dependency dependency_index

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      tool=${RIG_FIELD_VALUES[$field_index]}
      if rig_plan_index "$tool"; then
        case "${RIG_PLAN_RESULTS[$RIG_INDEX]:-}" in completed|planned|neutral|observed) ;;
          *) RIG_VALUE=$tool; return 0 ;;
        esac
      fi
    elif [ "${RIG_FIELD_KEYS[$field_index]}" = resource-dependency ]; then
      reference=${RIG_FIELD_VALUES[$field_index]}
      rig_resource_reference "$reference" || return 2
      dependency=$RIG_VALUE
      if rig_resource_plan_index "$dependency"; then
        dependency_index=$RIG_INDEX
        case "${RIG_RESOURCE_PLAN_RESULTS[$dependency_index]:-}" in completed|planned|observed) ;;
          *) RIG_VALUE=$reference; return 0 ;;
        esac
      fi
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_resource_locator_summary() {
  local section_name kind domain key

  section_name=$1
  kind=${section_name%%.*}
  if rig_get_value "$section_name" locator; then return 0; fi
  case "$kind" in
    setting)
      rig_get_value "$section_name" domain || return 2; domain=$RIG_VALUE
      rig_get_value "$section_name" key || return 2; key=$RIG_VALUE
      RIG_VALUE=$domain/$key
      ;;
    dock) RIG_VALUE=${section_name#*.} ;;
    *) return 2 ;;
  esac
}

rig_apply_resource() {
  local section_name provider adapter executable

  section_name=$1
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  if [ "$adapter" = launchd ]; then
    rig_launchd_apply_resource "$section_name"
    return
  fi
  case "$adapter" in
    macos-defaults) rig_setting_apply "$section_name"; return ;;
    macos-dock) rig_dock_apply "$section_name"; return ;;
  esac
  rig_prepare_resource_invocation apply-resource "$section_name" || return
  executable=$RIG_VALUE
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
}

rig_print_resource_projection() {
  local section_name provider adapter index

  section_name=$1
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  case "$adapter" in
    launchd|macos-defaults|macos-dock)
    RIG_INVOKE_ARGUMENTS=()
    rig_append_resource_fields "$section_name" || return
    index=0
    while [ "$index" -lt "${#RIG_INVOKE_ARGUMENTS[@]}" ]; do
      printf '  %s\n' "${RIG_INVOKE_ARGUMENTS[$index]}"
      index=$((index + 1))
    done
    return 0
    ;;
  esac
  rig_prepare_resource_invocation apply-resource "$section_name" || return
  index=6
  while [ "$index" -lt "${#RIG_INVOKE_ARGUMENTS[@]}" ]; do
    printf '  %s\n' "${RIG_INVOKE_ARGUMENTS[$index]}"
    index=$((index + 1))
  done
}

rig_command_apply() {
  local profile scope dry_run profile_seen scope_seen dry_run_seen index tool binding provider
  local blocker native_status planned completed failed skipped operational_failure
  local section_name section_index kind id locator resource_total lock_acquired exit_code

  profile=
  scope=all
  dry_run=0
  profile_seen=0
  scope_seen=0
  dry_run_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
      [ "$#" -eq 1 ] || { syntax_error 'usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'; return; }
      printf '%s\n' 'Usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
        return
        ;;
      --profile)
        if [ "$profile_seen" -ne 0 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        syntax_error 'usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --scope)
        if [ "$scope_seen" -ne 0 ] || [ "$#" -lt 2 ]; then
        syntax_error 'usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return
        fi
        case "$2" in tools|skills|resources|all) scope=$2 ;; *)
          syntax_error 'usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return ;;
        esac
        scope_seen=1
        shift 2
        ;;
      --dry-run)
      [ "$dry_run_seen" -eq 0 ] ||
        { syntax_error 'usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'; return; }
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      *) syntax_error 'usage: rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'; return ;;
    esac
  done

  rig_resolve_operational_plan "$profile" defer || return
  [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
    rig_fail "profile '$RIG_RESOLVED_PROFILE' is a non-appliable view" || return
  lock_acquired=0
  if { [ "$scope" = resources ] || [ "$scope" = all ]; } &&
    rig_reconciliation_needed "$RIG_RESOLVED_PLATFORM"; then
    if [ "$dry_run" -eq 0 ]; then
      rig_acquire_reconciliation_lock \
        "$RIG_RESOLVED_PLATFORM" "$RIG_RESOLVED_PROFILE" apply || return
      lock_acquired=$RIG_RECONCILIATION_LOCK_ACQUIRED
    fi
    rig_load_resource_receipt "$RIG_RESOLVED_PLATFORM" || return
  fi
  case "$scope" in
    tools)
      RIG_SELECTED_SKILLS=()
      RIG_RESOURCE_PLAN_SECTIONS=()
      RIG_STALE_RESOURCE_PROVIDERS=()
      RIG_STALE_RESOURCE_KINDS=()
      RIG_STALE_RESOURCE_IDS=()
      RIG_STALE_RESOURCE_LOCATORS=()
      ;;
    skills)
      RIG_PLAN_TOOLS=()
      RIG_PLAN_BINDINGS=()
      RIG_PLAN_PROVIDERS=()
      RIG_RESOURCE_PLAN_SECTIONS=()
      RIG_STALE_RESOURCE_PROVIDERS=()
      RIG_STALE_RESOURCE_KINDS=()
      RIG_STALE_RESOURCE_IDS=()
      RIG_STALE_RESOURCE_LOCATORS=()
      ;;
    resources)
      RIG_SELECTED_SKILLS=()
      RIG_PLAN_TOOLS=()
      RIG_PLAN_BINDINGS=()
      RIG_PLAN_PROVIDERS=()
      ;;
  esac
  rig_preflight_apply "$scope" || return
  printf 'Profile: %s\nPlatform: %s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  printf 'Operation scope: declaration\n'
  printf 'TOOL\tPROVIDER\tRESULT\tDETAIL\tSCOPE\n'
  planned=0
  completed=0
  failed=0
  skipped=0
  operational_failure=0
  index=0
  while [ "$index" -lt "${#RIG_PLAN_BINDINGS[@]}" ]; do
    [ -z "${RIG_PLAN_BINDINGS[$index]}" ] || planned=$((planned + 1))
    index=$((index + 1))
  done
  resource_total=$((${#RIG_RESOURCE_PLAN_SECTIONS[@]} + ${#RIG_STALE_RESOURCE_IDS[@]}))
  if [ "$dry_run" -eq 0 ]; then
    rig_progress_start applying "$((planned + ${#RIG_SELECTED_SKILLS[@]} + resource_total))"
  fi

  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    if [ "$dry_run" -eq 0 ] && [ -n "$binding" ]; then
      rig_progress_step "$tool via $provider"
    fi
    if [ -z "$binding" ]; then
      RIG_PLAN_RESULTS[$index]=skipped
      RIG_PLAN_DETAILS[$index]=catalogue-only
      skipped=$((skipped + 1))
    elif [ "$dry_run" -eq 1 ]; then
      RIG_PLAN_RESULTS[$index]=planned
      RIG_PLAN_DETAILS[$index]=-
    elif rig_plan_blocker "$tool"; then
      blocker=$RIG_VALUE
      RIG_PLAN_RESULTS[$index]=skipped
      RIG_PLAN_DETAILS[$index]=blocked-by:$blocker
      skipped=$((skipped + 1))
      operational_failure=1
    else
      rig_apply_provider "$tool" "$binding" "$provider"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        RIG_PLAN_RESULTS[$index]=completed
        RIG_PLAN_DETAILS[$index]=-
        completed=$((completed + 1))
      else
        RIG_PLAN_RESULTS[$index]=failed
        RIG_PLAN_DETAILS[$index]=exit:$native_status
        failed=$((failed + 1))
        operational_failure=1
      fi
    fi
    printf '%s\t%s\t%s\t%s\tdeclaration\n' "$tool" "$provider" \
      "${RIG_PLAN_RESULTS[$index]}" "${RIG_PLAN_DETAILS[$index]}"
    index=$((index + 1))
  done
  rig_run_skill_apply "$dry_run" || return
  planned=$((planned + RIG_SKILL_PLANNED))
  completed=$((completed + RIG_SKILL_COMPLETED))
  failed=$((failed + RIG_SKILL_FAILED))
  skipped=$((skipped + RIG_SKILL_SKIPPED))
  [ "$RIG_SKILL_APPLY_FAILURE" -eq 0 ] || operational_failure=1
  if [ "$resource_total" -gt 0 ]; then
    printf '\nRESOURCE\tKIND\tPROVIDER\tRESULT\tDETAIL\tSCOPE\n'
  fi
  RIG_RESOURCE_PLAN_RESULTS=()
  RIG_RESOURCE_PLAN_DETAILS=()
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
    section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
    rig_section_index "$section_name" || return 2
    section_index=$RIG_INDEX
    kind=${RIG_SECTION_TYPES[$section_index]}
    id=${RIG_SECTION_IDS[$section_index]}
    rig_get_value "$section_name" provider || return 2
    provider=$RIG_VALUE
    rig_resource_locator_summary "$section_name" || return 2
    locator=$RIG_VALUE
    if [ -n "${RIG_RESOURCE_PREFLIGHT_DETAILS[$index]:-}" ]; then
      RIG_RESOURCE_PLAN_RESULTS[$index]=failed
      RIG_RESOURCE_PLAN_DETAILS[$index]=preflight:${RIG_RESOURCE_PREFLIGHT_DETAILS[$index]}
      failed=$((failed + 1))
      operational_failure=1
    elif [ "$dry_run" -eq 1 ]; then
      RIG_RESOURCE_PLAN_RESULTS[$index]=planned
      RIG_RESOURCE_PLAN_DETAILS[$index]=reconcile:$locator
      planned=$((planned + 1))
    elif rig_resource_blocker "$section_name"; then
      blocker=$RIG_VALUE
      RIG_RESOURCE_PLAN_RESULTS[$index]=skipped
      RIG_RESOURCE_PLAN_DETAILS[$index]=blocked-by:$blocker
      skipped=$((skipped + 1))
      operational_failure=1
    else
      rig_progress_step "$kind.$id via $provider"
      rig_apply_resource "$section_name"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        RIG_RESOURCE_PLAN_RESULTS[$index]=completed
        RIG_RESOURCE_PLAN_DETAILS[$index]=reconciled:$locator
        completed=$((completed + 1))
      else
        RIG_RESOURCE_PLAN_RESULTS[$index]=failed
        RIG_RESOURCE_PLAN_DETAILS[$index]=exit:$native_status
        failed=$((failed + 1))
        operational_failure=1
      fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\tdeclaration\n' "$id" "$kind" "$provider" \
      "${RIG_RESOURCE_PLAN_RESULTS[$index]}" "${RIG_RESOURCE_PLAN_DETAILS[$index]}"
    if [ "$dry_run" -eq 1 ]; then
      rig_print_resource_projection "$section_name" || return
    fi
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_STALE_RESOURCE_IDS[@]}" ]; do
    provider=${RIG_STALE_RESOURCE_PROVIDERS[$index]}
    kind=${RIG_STALE_RESOURCE_KINDS[$index]}
    id=${RIG_STALE_RESOURCE_IDS[$index]}
    locator=${RIG_STALE_RESOURCE_LOCATORS[$index]}
    if [ "$operational_failure" -ne 0 ]; then
      printf '%s\t%s\t%s\tskipped\tblocked-by:resource-failure\tdeclaration\n' "$id" "$kind" "$provider"
      skipped=$((skipped + 1))
    elif [ "$dry_run" -eq 1 ]; then
      printf '%s\t%s\t%s\tplanned\tretire:%s\tdeclaration\n' "$id" "$kind" "$provider" "$locator"
      planned=$((planned + 1))
    else
      rig_progress_step "retire $kind.$id via $provider"
      rig_retire_resource "$provider" "$kind" "$id" "$locator"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        printf '%s\t%s\t%s\tcompleted\tretired:%s\tdeclaration\n' "$id" "$kind" "$provider" "$locator"
        completed=$((completed + 1))
      else
        printf '%s\t%s\t%s\tfailed\texit:%s\tdeclaration\n' "$id" "$kind" "$provider" "$native_status"
        failed=$((failed + 1))
        operational_failure=1
      fi
    fi
    index=$((index + 1))
  done
  if [ "$dry_run" -eq 0 ] && [ "$operational_failure" -eq 0 ] && [ "$resource_total" -gt 0 ]; then
    rig_write_resource_receipt "$RIG_RESOLVED_PLATFORM" || {
      rig_fail 'cannot update resource reconciliation receipt' || return
    }
  fi
  rig_progress_finish
  printf 'Summary: planned=%s completed=%s failed=%s skipped=%s\n' \
    "$planned" "$completed" "$failed" "$skipped"
  exit_code=0
  [ "$operational_failure" -eq 0 ] || exit_code=1
  if [ "$lock_acquired" -eq 1 ]; then
    rig_release_reconciliation_lock || return
    trap - EXIT HUP INT TERM
  fi
  return "$exit_code"
}

rig_bootstrap_preflight_homebrew_manifest() {
  local scope index uses_homebrew manifest executable

  scope=$1
  RIG_BOOTSTRAP_MANIFEST=
  RIG_BOOTSTRAP_MANIFEST_EXECUTABLE=
  RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL=
  RIG_BOOTSTRAP_AUTOUPDATE_OPTIONS=()
  [ "$scope" != resources ] || return 0
  uses_homebrew=0
  index=0
  while [ "$index" -lt "${#RIG_PLAN_PROVIDERS[@]}" ]; do
    if [ "${RIG_PLAN_PROVIDERS[$index]}" = homebrew ]; then
      uses_homebrew=1
      break
    fi
    index=$((index + 1))
  done
  [ "$uses_homebrew" -eq 1 ] || return 0
  manifest=
  if rig_get_value provider.homebrew manifest; then
    manifest=$RIG_VALUE
    [ -f "$manifest" ] && [ -r "$manifest" ] ||
      rig_fail "provider 'homebrew' manifest is not a readable regular file: $manifest" || return
  fi
  if rig_get_value provider.homebrew autoupdate-interval; then
    RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL=$RIG_VALUE
    rig_collect_field_values provider.homebrew autoupdate-option || return
    RIG_BOOTSTRAP_AUTOUPDATE_OPTIONS=("${RIG_QUERY_ITEMS[@]}")
  fi
  [ -n "$manifest" ] || [ -n "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ] || return 0
  rig_provider_executable homebrew homebrew formula || return 2
  executable=$RIG_VALUE
  rig_executable_available "$executable" ||
    rig_fail "provider 'homebrew' executable unavailable: $executable" || return
  RIG_BOOTSTRAP_MANIFEST=$manifest
  RIG_BOOTSTRAP_MANIFEST_EXECUTABLE=$executable
}

rig_bootstrap_apply_homebrew_manifest() {
  local executable manifest

  executable=$RIG_BOOTSTRAP_MANIFEST_EXECUTABLE
  manifest=$RIG_BOOTSTRAP_MANIFEST
  [ -n "$manifest" ] || return 0
  "$executable" bundle "--file=$manifest" 1>&2
}

rig_bootstrap_apply_homebrew_autoupdate() {
  local executable option

  executable=$RIG_BOOTSTRAP_MANIFEST_EXECUTABLE
  [ -n "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ] || return 0
  "$executable" autoupdate delete 1>&2 || return
  RIG_INVOKE_ARGUMENTS=(autoupdate start "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL")
  for option in "${RIG_BOOTSTRAP_AUTOUPDATE_OPTIONS[@]}"; do
    RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--$option
  done
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
}

rig_bootstrap_verify_deferred_mise() {
  local executable

  rig_provider_executable mise mise tool || return 2
  executable=$RIG_VALUE
  rig_executable_available "$executable" ||
    rig_fail "bootstrap prerequisite did not make provider 'mise' available: $executable" || return
}

rig_bootstrap_apply_npm_prerequisite() {
  local index tool binding provider executable native_status

  index=$RIG_BOOTSTRAP_NPM_TOOL_INDEX
  tool=${RIG_PLAN_TOOLS[$index]}
  binding=${RIG_PLAN_BINDINGS[$index]}
  provider=${RIG_PLAN_PROVIDERS[$index]}
  rig_preflight_provider "$tool" "$binding" "$provider" || return
  rig_apply_provider "$tool" "$binding" "$provider"
  native_status=$?
  [ "$native_status" -eq 0 ] || return "$native_status"
  rig_provider_executable npm npm global || return 2
  executable=$RIG_VALUE
  rig_executable_available "$executable" ||
    rig_fail "bootstrap prerequisite '$tool' did not make provider 'npm' available: $executable" || return
}

rig_command_bootstrap() {
  local profile scope dry_run profile_seen scope_seen dry_run_seen native_status manager_total
  local lock_acquired exit_code

  profile=
  scope=all
  dry_run=0
  RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=0
  RIG_BOOTSTRAP_DEFER_MISE=0
  RIG_BOOTSTRAP_DEFER_NPM=0
  RIG_BOOTSTRAP_NPM_TOOL_INDEX=
  profile_seen=0
  scope_seen=0
  dry_run_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        [ "$#" -eq 1 ] || {
          syntax_error 'usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return
        }
      printf '%s\n' 'Usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
        return
        ;;
      --profile)
        if [ "$profile_seen" -ne 0 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        syntax_error 'usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --scope)
        if [ "$scope_seen" -ne 0 ] || [ "$#" -lt 2 ]; then
        syntax_error 'usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return
        fi
        case "$2" in tools|skills|resources|all) scope=$2 ;; *)
          syntax_error 'usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return ;;
        esac
        scope_seen=1
        shift 2
        ;;
      --dry-run)
        [ "$dry_run_seen" -eq 0 ] || {
          syntax_error 'usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'
          return
        }
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      *) syntax_error 'usage: rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]'; return ;;
    esac
  done

  if [ -z "$profile" ]; then
    rig_load_config || return
    if rig_get_value rig bootstrap-profile; then
      profile=$RIG_VALUE
    fi
  fi

  rig_resolve_operational_plan "$profile" defer || return
  profile=$RIG_RESOLVED_PROFILE
  [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
    rig_fail "profile '$profile' is a non-appliable view" || return
  lock_acquired=0
  if { [ "$scope" = resources ] || [ "$scope" = all ]; } &&
    rig_reconciliation_needed "$RIG_RESOLVED_PLATFORM"; then
    if [ "$dry_run" -eq 0 ]; then
      rig_acquire_reconciliation_lock "$RIG_RESOLVED_PLATFORM" "$profile" bootstrap || return
      lock_acquired=$RIG_RECONCILIATION_LOCK_ACQUIRED
    fi
    rig_load_resource_receipt "$RIG_RESOLVED_PLATFORM" || return
  fi
  case "$scope" in
    tools)
      RIG_SELECTED_SKILLS=()
      RIG_RESOURCE_PLAN_SECTIONS=()
      RIG_STALE_RESOURCE_PROVIDERS=()
      RIG_STALE_RESOURCE_KINDS=()
      RIG_STALE_RESOURCE_IDS=()
      RIG_STALE_RESOURCE_LOCATORS=()
      ;;
    skills)
      RIG_PLAN_TOOLS=()
      RIG_PLAN_BINDINGS=()
      RIG_PLAN_PROVIDERS=()
      RIG_RESOURCE_PLAN_SECTIONS=()
      RIG_STALE_RESOURCE_PROVIDERS=()
      RIG_STALE_RESOURCE_KINDS=()
      RIG_STALE_RESOURCE_IDS=()
      RIG_STALE_RESOURCE_LOCATORS=()
      ;;
    resources)
      RIG_SELECTED_SKILLS=()
      RIG_PLAN_TOOLS=()
      RIG_PLAN_BINDINGS=()
      RIG_PLAN_PROVIDERS=()
      ;;
  esac
  RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=1
  RIG_BOOTSTRAP_ALLOW_DEFERRED_SKILLS=1
  rig_preflight_apply "$scope"
  native_status=$?
  if [ "$native_status" -ne 0 ]; then
    RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=0
    return "$native_status"
  fi
  rig_bootstrap_preflight_homebrew_manifest "$scope" || return
  if [ -n "$RIG_BOOTSTRAP_MANIFEST" ] || [ -n "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ] ||
    [ "$RIG_BOOTSTRAP_DEFER_MISE" -eq 1 ] || [ "$RIG_BOOTSTRAP_DEFER_NPM" -eq 1 ]; then
    printf 'Operation scopes: declaration, manifest, provider-wide\n'
    printf 'MANAGER\tPROVIDER\tRESULT\tDETAIL\tSCOPE\n'
    if [ "$dry_run" -eq 1 ]; then
      if [ -n "$RIG_BOOTSTRAP_MANIFEST" ]; then
        printf 'manifest\thomebrew\tplanned\tbundle:%s\tmanifest\n' "$RIG_BOOTSTRAP_MANIFEST"
      fi
      if [ -n "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ]; then
        printf 'autoupdate\thomebrew\tplanned\tinterval:%s\tprovider-wide\n' "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL"
      fi
      if [ "$RIG_BOOTSTRAP_DEFER_MISE" -eq 1 ]; then
        printf 'provider:mise\thomebrew\tplanned\tbootstrap-prerequisite\tdeclaration\n'
      fi
      if [ "$RIG_BOOTSTRAP_DEFER_NPM" -eq 1 ]; then
        printf 'provider:npm\tmise\tplanned\tbootstrap-prerequisite\tdeclaration\n'
      fi
      printf '\n'
    else
      manager_total=0
      [ -z "$RIG_BOOTSTRAP_MANIFEST" ] || manager_total=$((manager_total + 1))
      [ -z "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ] || manager_total=$((manager_total + 1))
      [ "$RIG_BOOTSTRAP_DEFER_MISE" -eq 0 ] || manager_total=$((manager_total + 1))
      [ "$RIG_BOOTSTRAP_DEFER_NPM" -eq 0 ] || manager_total=$((manager_total + 1))
      rig_progress_start bootstrapping "$manager_total"
      if [ -n "$RIG_BOOTSTRAP_MANIFEST" ]; then
        rig_progress_step 'homebrew manifest'
        rig_bootstrap_apply_homebrew_manifest
        native_status=$?
        if [ "$native_status" -ne 0 ]; then
          rig_progress_finish
          printf 'manifest\thomebrew\tfailed\texit:%s\tmanifest\n' "$native_status"
          return "$native_status"
        fi
        printf 'manifest\thomebrew\tcompleted\tbundle:%s\tmanifest\n' "$RIG_BOOTSTRAP_MANIFEST"
      fi
      if [ -n "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ]; then
        rig_progress_step 'homebrew autoupdate'
        rig_bootstrap_apply_homebrew_autoupdate
        native_status=$?
        if [ "$native_status" -ne 0 ]; then
          rig_progress_finish
          printf 'autoupdate\thomebrew\tfailed\texit:%s\tprovider-wide\n' "$native_status"
          return "$native_status"
        fi
        printf 'autoupdate\thomebrew\tcompleted\tinterval:%s\tprovider-wide\n' "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL"
      fi
      RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=0
      if [ "$RIG_BOOTSTRAP_DEFER_MISE" -eq 1 ]; then
        rig_progress_step 'verify provider mise'
        if ! rig_bootstrap_verify_deferred_mise; then
          rig_progress_finish
          printf 'provider:mise\thomebrew\tfailed\tunavailable\tdeclaration\n'
          return 1
        fi
        printf 'provider:mise\thomebrew\tcompleted\tavailable\tdeclaration\n'
      fi
      if [ "$RIG_BOOTSTRAP_DEFER_NPM" -eq 1 ]; then
        rig_progress_step 'materialise provider npm'
        rig_bootstrap_apply_npm_prerequisite
        native_status=$?
        if [ "$native_status" -ne 0 ]; then
          rig_progress_finish
          printf 'provider:npm\tmise\tfailed\texit:%s\tdeclaration\n' "$native_status"
          return "$native_status"
        fi
        printf 'provider:npm\tmise\tcompleted\tavailable\tdeclaration\n'
      fi
      rig_progress_finish
      printf '\n'
    fi
  fi

  [ "$dry_run" -eq 1 ] || RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=0
  if [ -n "$profile" ]; then
    if [ "$dry_run" -eq 1 ]; then
      rig_command_apply --profile "$profile" --scope "$scope" --dry-run
    else
      rig_command_apply --profile "$profile" --scope "$scope"
    fi
  elif [ "$dry_run" -eq 1 ]; then
    rig_command_apply --scope "$scope" --dry-run
  else
    rig_command_apply --scope "$scope"
  fi
  exit_code=$?
  if [ "$lock_acquired" -eq 1 ]; then
    rig_release_reconciliation_lock || return
    trap - EXIT HUP INT TERM
  fi
  return "$exit_code"
}
