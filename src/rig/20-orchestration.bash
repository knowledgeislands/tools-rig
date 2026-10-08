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
  rig_validate_selected_cli_destinations
}

rig_provider_has_capability() {
  local provider capability adapter section_index field_index field_end

  provider=$1
  capability=$2
  if rig_provider_adapter "$provider"; then
    adapter=$RIG_VALUE
    case "$adapter:$capability" in
      homebrew:observe|homebrew:apply|homebrew:update|homebrew:maintain|homebrew:capture|homebrew:inventory|\
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
  # The quotes around each replacement are load-bearing. Bash 5.2 expands an
  # unquoted & in a substitution replacement to the text the pattern matched,
  # the way sed does, so ${value//</&lt;} turns '<' into '<lt;' there while
  # Bash 3.2 produces '&lt;'. Quoting keeps one meaning on every Bash.
  value=${value//&/"&amp;"}
  value=${value//</"&lt;"}
  value=${value//>/"&gt;"}
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
  local calendar_count environment_count program_count bundle_count env_key env_value

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
  printf '<!-- Managed by rig from %s. Generated file; rig apply replaces edits. -->\n' "$section_name"
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

  rig_field_count "$section_index" associated-application
  bundle_count=$RIG_COUNT
  if [ "$bundle_count" -gt 0 ]; then
    printf '%s\n' '  <key>AssociatedBundleIdentifiers</key>' '  <array>'
    field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
    while [ "$field_index" -lt "$field_end" ]; do
      if [ "${RIG_FIELD_KEYS[$field_index]}" = associated-application ]; then
        printf '%s' '    '
        rig_launchd_print_string "${RIG_FIELD_VALUES[$field_index]}" || return
        printf '\n'
      fi
      field_index=$((field_index + 1))
    done
    printf '%s\n' '  </array>'
  fi

  if [ "$kind" = scheduled-job ]; then
    rig_field_count "$section_index" schedule-calendar
    calendar_count=$RIG_COUNT
    if [ "$calendar_count" -gt 0 ]; then
      printf '%s\n' '  <key>StartCalendarInterval</key>'
      if [ "$calendar_count" -eq 1 ]; then
        rig_get_value "$section_name" schedule-calendar || return 2
        rig_launchd_render_calendar_dict "$RIG_VALUE" '  ' || return
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
  local label command domain waited timeout

  label=$1
  rig_launchd_load_state "$label" || return
  [ "$RIG_LAUNCHD_LOAD_STATE" != absent ] || return 0
  rig_launchd_command
  command=$RIG_VALUE
  rig_launchd_domain || return
  domain=$RIG_VALUE
  "$command" bootout "$domain/$label" || return
  # launchctl bootout returns once termination has been requested, not once the
  # service has gone, so a program that takes a moment to exit is still in the
  # domain when it returns and the bootstrap that follows fails with
  # 'Bootstrap failed: 5: Input/output error' — leaving the service unloaded.
  # An unload therefore is not complete until the domain says so.
  waited=0
  timeout=${RIG_LAUNCHD_UNLOAD_TIMEOUT:-30}
  while :; do
    rig_launchd_load_state "$label" || return
    [ "$RIG_LAUNCHD_LOAD_STATE" != absent ] || return 0
    [ "$waited" -lt "$timeout" ] || break
    sleep 1
    waited=$((waited + 1))
  done
  RIG_OBSERVATION_DETAIL=launchctl-unload-timeout:$timeout
  return 1
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
  RIG_VALUE=${RIG_DEFAULTS:-/usr/bin/defaults}
}

rig_macos_dockutil_command() {
  # Homebrew installs dockutil beneath its own prefix, so PATH is its default.
  RIG_VALUE=${RIG_DOCKUTIL:-dockutil}
}

rig_macos_killall_command() {
  RIG_VALUE=${RIG_KILLALL:-/usr/bin/killall}
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

rig_dock_reset_snapshot() {
  RIG_DOCK_SNAPSHOT_LOADED=0
  RIG_DOCK_SNAPSHOT_VALID=0
  RIG_DOCK_SNAPSHOT=
  RIG_DOCK_SNAPSHOT_COUNT=0
}

rig_dock_reset_snapshot

rig_dock_snapshot_value() {
  local command value

  command=${RIG_PLUTIL:-/usr/bin/plutil}
  # Suppress plutil's formatting newline and keep a sentinel until after command
  # substitution, so a literal trailing newline remains invalid path evidence.
  value=$("$command" -extract "$1" raw -expect "$2" -n -o - - <<< "$RIG_DOCK_SNAPSHOT" 2>/dev/null && printf '.') || return 1
  RIG_VALUE=${value%.}
}

rig_dock_load_snapshot() {
  local command plutil snapshot count

  if [ "$RIG_DOCK_SNAPSHOT_LOADED" -ne 0 ]; then
    [ "$RIG_DOCK_SNAPSHOT_VALID" -eq 1 ]
    return
  fi
  RIG_DOCK_SNAPSHOT_LOADED=1
  rig_macos_defaults_command; command=$RIG_VALUE
  plutil=${RIG_PLUTIL:-/usr/bin/plutil}
  rig_executable_available "$command" && rig_executable_available "$plutil" || return 1
  # Convert before capturing text: defaults may export a binary plist. Pipefail
  # stays inside the subshell and no temporary file or persistent state is used.
  snapshot=$(
    set -o pipefail
    "$command" export com.apple.dock - 2>/dev/null |
      "$plutil" -convert xml1 -o - - 2>/dev/null
  ) || return 1
  RIG_DOCK_SNAPSHOT=$snapshot
  rig_dock_snapshot_value persistent-others array || return 1
  count=$RIG_VALUE
  case "$count" in ''|*[!0-9]*) return 1 ;; esac
  # Native arrays cannot approach this bound on a useful Dock; reject malformed
  # evidence rather than permit an unbounded extraction loop.
  [ "${#count}" -le 5 ] && [ "$count" -le 65536 ] || return 1
  RIG_DOCK_SNAPSHOT_COUNT=$count
  RIG_DOCK_SNAPSHOT_VALID=1
}

rig_dock_native_path() {
  local value url_type remainder hex

  value=$1
  url_type=$2
  case "$url_type" in
    0) case "$value" in /*) ;; *) return 1 ;; esac ;;
    15)
      case "$value" in
        file://localhost/*) value=/${value#file://localhost/} ;;
        file:///*) value=${value#file://} ;;
        *) return 1 ;;
      esac
      # Only a local, well-formed URL is usable evidence. A percent-encoded
      # percent is deliberately decoded once, not recursively.
      case "$value" in *\?*|*\#*) return 1 ;; esac
      remainder=$value
      while [ "${remainder#*%}" != "$remainder" ]; do
        remainder=${remainder#*%}
        hex=${remainder:0:2}
        case "$hex" in
          00|0[Aa]|0[Dd]|09) return 1 ;;
          [0-9A-Fa-f][0-9A-Fa-f]) remainder=${remainder:2} ;;
          *) return 1 ;;
        esac
      done
      rig_dock_normalize_path "$value"
      value=$RIG_VALUE
      ;;
    *) return 1 ;;
  esac
  case "$value" in *$'\n'*|*$'\r'*|*$'\t'*) return 1 ;; esac
  [ "$value" = / ] || value=${value%/}
  RIG_VALUE=$value
}

rig_dock_find_folder() {
  local expected index tile_type path url_type matches uncertain

  expected=$1
  index=0
  matches=0
  uncertain=0
  RIG_DOCK_MATCH_INDEX=
  while [ "$index" -lt "$RIG_DOCK_SNAPSHOT_COUNT" ]; do
    if ! rig_dock_snapshot_value "persistent-others.$index.tile-type" string; then
      uncertain=1
    else
      tile_type=$RIG_VALUE
      case "$tile_type" in
        directory-tile)
          if rig_dock_snapshot_value "persistent-others.$index.tile-data.file-data._CFURLString" string; then
            path=$RIG_VALUE
            if rig_dock_snapshot_value "persistent-others.$index.tile-data.file-data._CFURLStringType" integer; then
              url_type=$RIG_VALUE
              if rig_dock_native_path "$path" "$url_type"; then
                if [ "$RIG_VALUE" = "$expected" ]; then
                  matches=$((matches + 1))
                  RIG_DOCK_MATCH_INDEX=$index
                fi
              else uncertain=1; fi
            else uncertain=1; fi
          else uncertain=1; fi
          ;;
        file-tile|url-tile|spacer-tile|small-spacer-tile|recents-tile) ;;
        *) uncertain=1 ;;
      esac
    fi
    index=$((index + 1))
  done
  [ "$matches" -eq 1 ] && [ "$uncertain" -eq 0 ]
}

rig_dock_observe_attributes() {
  local section_name section_index field_index field_end item item_section kind path view display
  local matched observed view_drift display_drift unavailable

  section_name=$1
  view_drift=''; display_drift=''; unavailable=''
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = item ]; then
      item=${RIG_FIELD_VALUES[$field_index]}
      item_section=dock-item.$item
      rig_get_value "$item_section" kind || return 2; kind=$RIG_VALUE
      view=''; display=''
      if rig_get_value "$item_section" view; then view=$RIG_VALUE; fi
      if rig_get_value "$item_section" display; then display=$RIG_VALUE; fi
      if [ "$kind" = folder ] && { [ -n "$view" ] || [ -n "$display" ]; }; then
        rig_get_value "$item_section" path || return 2
        rig_expand_home_value "$RIG_VALUE" || return
        path=$RIG_VALUE
        [ "$path" = / ] || path=${path%/}
        matched=0
        if rig_dock_load_snapshot && rig_dock_find_folder "$path"; then matched=1; fi
        if [ -n "$view" ]; then
          observed=
          if [ "$matched" -eq 1 ] && rig_dock_snapshot_value "persistent-others.$RIG_DOCK_MATCH_INDEX.tile-data.showas" integer; then
            case "$RIG_VALUE" in 0) observed=auto ;; 1) observed=fan ;; 2) observed=grid ;; 3) observed=list ;; esac
          fi
          if [ -z "$observed" ]; then
            [ -n "$unavailable" ] || unavailable="view-unobservable:$item"
          elif [ "$observed" != "$view" ]; then
            [ -n "$view_drift" ] || view_drift="view:$item"
          fi
        fi
        if [ -n "$display" ]; then
          observed=
          if [ "$matched" -eq 1 ] && rig_dock_snapshot_value "persistent-others.$RIG_DOCK_MATCH_INDEX.tile-data.displayas" integer; then
            case "$RIG_VALUE" in 0) observed=stack ;; 1) observed=folder ;; esac
          fi
          if [ -z "$observed" ]; then
            [ -n "$unavailable" ] || unavailable="display-unobservable:$item"
          elif [ "$observed" != "$display" ]; then
            [ -n "$display_drift" ] || display_drift="display:$item"
          fi
        fi
      fi
    fi
    field_index=$((field_index + 1))
  done
  if [ -n "$view_drift" ]; then RIG_OBSERVATION=drifted; RIG_OBSERVATION_DETAIL=$view_drift
  elif [ -n "$display_drift" ]; then RIG_OBSERVATION=drifted; RIG_OBSERVATION_DETAIL=$display_drift
  elif [ -n "$unavailable" ]; then RIG_OBSERVATION=unknown; RIG_OBSERVATION_DETAIL=$unavailable
  else RIG_OBSERVATION=present; RIG_OBSERVATION_DETAIL=-; fi
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
    rig_dock_observe_attributes "$section_name"
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
