# rig-module: 30-commands
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

rig_current_platform() {
  local shell_platform

  if [ -n "${RIG_PLATFORM:-}" ]; then
    RIG_VALUE=$RIG_PLATFORM
    return
  fi

  shell_platform=${OSTYPE:-unknown}
  case "$shell_platform" in
    darwin*) RIG_VALUE=macos ;;
    linux*) RIG_VALUE=linux ;;
    *) rig_fail "unsupported platform '$shell_platform'" || return ;;
  esac
}

rig_operation_supports_platform() {
  local section_name platform section_index field_index field_end found

  section_name=$1
  platform=$2
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  found=0
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = platform ]; then
      found=1
      case "${RIG_FIELD_VALUES[$field_index]}" in
        any|"$platform") return 0 ;;
      esac
    fi
    field_index=$((field_index + 1))
  done
  [ "$found" -eq 0 ]
}

rig_operation_allows_argument() {
  local section_name argument section_index field_index field_end

  section_name=$1
  argument=$2
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = allow-argument ] &&
      [ "${RIG_FIELD_VALUES[$field_index]}" = "$argument" ]; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_prepare_operation_invocation() {
  local section_name provider action verb executable

  section_name=$1
  provider=$2
  action=$3
  verb=$4

  rig_prepare_custom_invocation "$verb" "$provider" "$provider" action "$action" || return
  executable=$RIG_VALUE
  rig_append_arguments "$section_name" || return 2
  RIG_VALUE=$executable
}

rig_action_allows_resource_kind() {
  local section_name wanted section_index field_index field_end

  section_name=$1
  wanted=$2
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = resource-kind ] &&
      [ "${RIG_FIELD_VALUES[$field_index]}" = "$wanted" ]; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_launchd_action_kind_allowed() {
  local action kind

  action=$1
  kind=$2
  case "$action:$kind" in
    status:service|status:scheduled-job|\
    logs:service|logs:scheduled-job|\
    restart:service|restart:scheduled-job|\
    run:scheduled-job) return 0 ;;
  esac
  return 1
}

rig_command_run_launchd_action() {
  local action target kind id section_name provider platform label command domain
  local output_path error_path follow native_status
  local -a remaining_arguments logs tail_arguments

  action=$1
  shift
  case "$action" in status|logs|run|restart) ;; *)
    rig_fail "unknown launchd action '$action'" || return ;;
  esac
  [ "$#" -gt 0 ] || rig_fail "launchd action '$action' requires a qualified resource" || return
  target=$1
  shift
  kind=${target%%:*}
  id=${target#*:}
  [ "$target" != "$id" ] && rig_valid_id "$id" &&
    rig_launchd_action_kind_allowed "$action" "$kind" ||
    rig_fail "launchd action '$action' does not allow resource '$target'" || return
  section_name=$kind.$id
  rig_section_index "$section_name" || rig_fail "unknown resource '$target'" || return
  rig_get_value "$section_name" provider || return 2
  provider=$RIG_VALUE
  [ "$provider" = launchd ] ||
    rig_fail "resource '$target' is owned by provider '$provider', not 'launchd'" || return
  rig_current_platform || return
  platform=$RIG_VALUE
  [ "$platform" = macos ] || rig_fail "action 'launchd $action' not supported on platform '$platform'" || return
  rig_resolve_profile '' "$platform" || return
  case "$action" in run|restart)
    [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
      rig_fail "profile '$RIG_RESOLVED_PROFILE' is a non-appliable view" || return
    ;;
  esac
  if [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -eq 0 ] ||
    ! rig_array_contains "$section_name" "${RIG_SELECTED_RESOURCE_SECTIONS[@]}"; then
    rig_fail "resource '$target' is not selected by the default profile" || return
  fi
  remaining_arguments=("$@")
  follow=
  case "$action" in
    logs)
      [ "${#remaining_arguments[@]}" -le 1 ] ||
        rig_fail "launchd action 'logs' accepts only '--follow'" || return
      if [ "${#remaining_arguments[@]}" -eq 1 ]; then
        [ "${remaining_arguments[0]}" = --follow ] ||
          rig_fail "launchd action 'logs' accepts only '--follow'" || return
        follow=--follow
      fi
      ;;
    *)
      [ "${#remaining_arguments[@]}" -eq 0 ] ||
        rig_fail "launchd action '$action' accepts no additional arguments" || return
      ;;
  esac
  rig_get_value "$section_name" locator || return 2
  label=$RIG_VALUE
  rig_launchd_label_valid "$label" || return 2
  rig_launchd_command
  command=$RIG_VALUE
  rig_executable_available "$command" ||
    rig_fail "provider 'launchd' executable is unavailable: $command" || return
  rig_launchd_domain || return
  domain=$RIG_VALUE

  rig_progress_start running 1 passthrough
  rig_progress_begin "launchd $action" declaration
  case "$action" in
    status)
      "$command" print "$domain/$label"
      native_status=$?
      ;;
    run)
      "$command" kickstart -p "$domain/$label"
      native_status=$?
      ;;
    restart)
      "$command" kickstart -k -p "$domain/$label"
      native_status=$?
      ;;
    logs)
      logs=()
      output_path=
      error_path=
      if rig_get_value "$section_name" standard-output; then
        rig_launchd_expand_home "$RIG_VALUE" || return
        output_path=$RIG_VALUE
        logs[${#logs[@]}]=$output_path
      fi
      if rig_get_value "$section_name" standard-error; then
        rig_launchd_expand_home "$RIG_VALUE" || return
        error_path=$RIG_VALUE
        if [ "$error_path" != "$output_path" ]; then
          logs[${#logs[@]}]=$error_path
        fi
      fi
      [ "${#logs[@]}" -gt 0 ] || rig_fail "resource '$target' has no declared logs" || return
      rig_executable_available tail || rig_fail "launchd logs executable is unavailable: tail" || return
      tail_arguments=(-n 100)
      [ "$follow" != --follow ] || tail_arguments[${#tail_arguments[@]}]=-f
      tail "${tail_arguments[@]}" "${logs[@]}"
      native_status=$?
      ;;
  esac
  if [ "$native_status" -eq 0 ]; then
    rig_progress_result succeeded "launchd $action" declaration
  else
    rig_progress_result failed "launchd $action" declaration
  fi
  rig_progress_finish
  return "$native_status"
}

rig_command_run_action() {
  local provider action section_name platform mode verb adapter executable argument argument_policy native_status
  local resource_count target kind id resource_section resource_index locator index progress_scope
  local -a caller_arguments remaining_arguments

  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help)
        rig_command_help run
        return
        ;;
    esac
  fi

  [ "$#" -ge 2 ] ||
    rig_command_syntax_error run || return
  provider=$1
  action=$2
  shift 2
  caller_arguments=()
  if [ "$#" -gt 0 ]; then
    [ "$1" = -- ] ||
      rig_command_syntax_error run || return
    shift
    caller_arguments=("$@")
  fi

  rig_valid_id "$provider" || rig_fail "invalid provider identity '$provider'" || return
  rig_valid_id "$action" || rig_fail "invalid action identity '$action'" || return
  rig_load_config || return
  rig_provider_adapter "$provider" || rig_fail "unknown provider '$provider'" || return
  adapter=$RIG_VALUE
  if [ "$provider" = launchd ] && [ "$adapter" = launchd ]; then
    rig_command_run_launchd_action "$action" "${caller_arguments[@]+"${caller_arguments[@]}"}"
    return
  fi
  section_name=action.$provider.$action
  rig_section_index "$section_name" ||
    rig_fail "unknown action '$provider $action'" || return

  rig_current_platform || return
  platform=$RIG_VALUE
  rig_operation_supports_platform "$section_name" "$platform" ||
    rig_fail "action '$provider $action' not supported on platform '$platform'" || return

  rig_get_value "$section_name" mode || return 2
  mode=$RIG_VALUE
  case "$mode" in
    observe) verb=observe ;;
    mutate) verb=apply ;;
    *) return 2 ;;
  esac

  argument_policy=rig
  if rig_get_value "$section_name" argument-policy; then
    argument_policy=$RIG_VALUE
  fi
  if [ "$argument_policy" = rig ] && [ "${#caller_arguments[@]}" -gt 0 ]; then
    for argument in "${caller_arguments[@]}"; do
      rig_operation_allows_argument "$section_name" "$argument" ||
        rig_fail "argument is not allowed for action '$provider $action': $argument" || return
    done
  fi

  rig_section_index "$section_name" || return 2
  resource_index=$RIG_INDEX
  rig_field_count "$resource_index" resource-kind
  resource_count=$RIG_COUNT
  resource_section=
  remaining_arguments=()
  if [ "$resource_count" -gt 0 ]; then
    [ "${#caller_arguments[@]}" -gt 0 ] ||
      rig_fail "action '$provider $action' requires a qualified resource" || return
    target=${caller_arguments[0]}
    kind=${target%%:*}
    id=${target#*:}
    [ "$target" != "$id" ] && rig_valid_id "$id" &&
      rig_action_allows_resource_kind "$section_name" "$kind" ||
      rig_fail "action '$provider $action' does not allow resource '$target'" || return
    resource_section=$kind.$id
    rig_section_index "$resource_section" ||
      rig_fail "unknown resource '$target'" || return
    rig_get_value "$resource_section" provider || return 2
    [ "$RIG_VALUE" = "$provider" ] ||
      rig_fail "resource '$target' is owned by provider '$RIG_VALUE', not '$provider'" || return
    rig_resolve_profile '' "$platform" || return
    if [ "$mode" = mutate ]; then
      [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
        rig_fail "profile '$RIG_RESOLVED_PROFILE' is a non-appliable view" || return
    fi
    if [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -eq 0 ] ||
      ! rig_array_contains "$resource_section" "${RIG_SELECTED_RESOURCE_SECTIONS[@]}"; then
      rig_fail "resource '$target' is not selected by the default profile" || return
    fi
    index=1
    while [ "$index" -lt "${#caller_arguments[@]}" ]; do
      remaining_arguments[${#remaining_arguments[@]}]=${caller_arguments[$index]}
      index=$((index + 1))
    done
  else
    remaining_arguments=("${caller_arguments[@]+"${caller_arguments[@]}"}")
  fi

  rig_custom_provider_executable "$provider" || return 2
  executable=$RIG_VALUE
  [ -x "$executable" ] ||
    rig_fail "provider '$provider' executable unavailable: $executable" || return
  rig_prepare_operation_invocation "$section_name" "$provider" "$action" "$verb" || return
  executable=$RIG_VALUE
  if [ -n "$resource_section" ]; then
    rig_section_index "$resource_section" || return 2
    resource_index=$RIG_INDEX
    kind=${RIG_SECTION_TYPES[$resource_index]}
    id=${RIG_SECTION_IDS[$resource_index]}
    rig_get_value "$resource_section" locator || return 2
    locator=$RIG_VALUE
    RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]='resource-v1'
    RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$kind
    RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$id
    RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$locator
    rig_append_resource_fields "$resource_section" || return
    RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--
  fi
  if [ "${#remaining_arguments[@]}" -gt 0 ]; then
    for argument in "${remaining_arguments[@]}"; do
      RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=$argument
    done
  fi
  if [ -n "$resource_section" ]; then
    progress_scope=declaration
  else
    progress_scope='provider-wide'
  fi
  rig_progress_start running 1 passthrough
  rig_progress_begin "$provider $action" "$progress_scope"
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}"
  native_status=$?
  if [ "$native_status" -eq 0 ]; then
    rig_progress_result succeeded "$provider $action" "$progress_scope"
  else
    rig_progress_result failed "$provider $action" "$progress_scope"
  fi
  rig_progress_finish
  return "$native_status"
}

rig_effective_paths() {
  if [ -n "${RIG_CONFIG_HOME:-}" ]; then
    RIG_DIAG_CONFIG_HOME=$RIG_CONFIG_HOME
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
    RIG_DIAG_CONFIG_HOME=$XDG_CONFIG_HOME/rig
  else
    require_home || return
    RIG_DIAG_CONFIG_HOME=$HOME/.config/rig
  fi

  rig_effective_data_home || return
  RIG_DIAG_DATA_HOME=$RIG_VALUE

  if [ -n "${RIG_STATE_HOME:-}" ]; then
    RIG_DIAG_STATE_HOME=$RIG_STATE_HOME
  elif [ -n "${XDG_STATE_HOME:-}" ]; then
    RIG_DIAG_STATE_HOME=$XDG_STATE_HOME/rig
  else
    require_home || return
    RIG_DIAG_STATE_HOME=$HOME/.local/state/rig
  fi

  if [ -n "${RIG_CACHE_HOME:-}" ]; then
    RIG_DIAG_CACHE_HOME=$RIG_CACHE_HOME
  elif [ -n "${XDG_CACHE_HOME:-}" ]; then
    RIG_DIAG_CACHE_HOME=$XDG_CACHE_HOME/rig
  else
    require_home || return
    RIG_DIAG_CACHE_HOME=$HOME/.cache/rig
  fi
}

rig_diagnostic_platform() {
  if [ -n "${RIG_PLATFORM:-}" ]; then
    RIG_VALUE=$RIG_PLATFORM
    return
  fi

  case "${OSTYPE:-unknown}" in
    darwin*) RIG_VALUE=macos ;;
    linux*) RIG_VALUE=linux ;;
    *) RIG_VALUE=unknown ;;
  esac
}

rig_count_config_fragments() {
  local fragment count

  count=0
  for fragment in "$RIG_DIAG_CONFIG_HOME"/conf.d/*.toml; do
    [ -f "$fragment" ] || continue
    count=$((count + 1))
  done
  RIG_COUNT=$count
}

rig_doctor_diagnostics() {
  local platform root_file root_display fragment_count config_status schema default_profile exit_code
  local index key profiles tools skills resources ports variants variant rest
  local format config_loaded
  local -a seen_variants

  config_loaded=$1
  format=${2:-text}

  rig_effective_paths || return 1
  rig_diagnostic_platform
  platform=$RIG_VALUE
  root_file=$RIG_DIAG_CONFIG_HOME/rig.toml
  root_display=$root_file
  rig_count_config_fragments
  fragment_count=$RIG_COUNT
  [ -e "$root_file" ] || root_display="$root_file (absent)"

  config_status=missing
  schema=
  default_profile=
  profiles=0
  tools=0
  skills=0
  resources=0
  ports=0
  variants=0
  seen_variants=()
  exit_code=1
  if [ -e "$root_file" ] || [ "$fragment_count" -gt 0 ]; then
    if [ "$config_loaded" -eq 1 ]; then
      config_status=valid
      rig_get_value rig schema || return 1
      schema=$RIG_VALUE
      rig_get_value rig default-profile || return 1
      default_profile=$RIG_VALUE
      index=0
      while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
        case "${RIG_SECTION_TYPES[$index]}" in
          profile) profiles=$((profiles + 1)) ;;
        tool) tools=$((tools + 1)) ;;
        skill) skills=$((skills + 1)) ;;
          service|scheduled-job|setting|dock) resources=$((resources + 1)) ;;
          port) ports=$((ports + 1)) ;;
        esac
        index=$((index + 1))
      done
      index=0
      while [ "$index" -lt "${#RIG_FIELD_KEYS[@]}" ]; do
        key=${RIG_FIELD_KEYS[$index]}
        case "$key" in variant:*:*)
          rest=${key#variant:}
          variant=${RIG_FIELD_SECTIONS[$index]}:${rest%%:*}
          if [ "${#seen_variants[@]}" -eq 0 ] ||
            ! rig_array_contains "$variant" "${seen_variants[@]}"; then
            seen_variants[${#seen_variants[@]}]=$variant
            variants=$((variants + 1))
          fi
          ;;
        esac
        index=$((index + 1))
      done
      exit_code=0
    else
      config_status=invalid
    fi
  fi

  if [ "$format" = json ]; then
    printf '{"runtime":'
    rig_json_field '{' version "$RIG_VERSION"
    rig_json_field ',' executable "$RIG_INVOKED_PATH"
    rig_json_field ',' bash_version "$BASH_VERSION"
    rig_json_field ',' platform "$platform"
    printf '},"paths":'
    rig_json_field '{' config "$RIG_DIAG_CONFIG_HOME"
    rig_json_field ',' data "$RIG_DIAG_DATA_HOME"
    rig_json_field ',' state "$RIG_DIAG_STATE_HOME"
    rig_json_field ',' cache "$RIG_DIAG_CACHE_HOME"
    printf '},"configuration":'
    rig_json_field '{' root "$root_file"
    rig_json_field ',' status "$config_status"
    printf ',"fragment_count":%s' "$fragment_count"
    if [ "$config_status" = valid ]; then
      rig_json_field ',' schema "$schema"
      rig_json_field ',' default_profile "$default_profile"
      rig_json_field ',' selection_mode "$RIG_PROFILE_SELECTION_MODE"
      printf ',"profiles":%s,"tools":%s,"skills":%s,"resources":%s,"ports":%s,"variants":%s' \
        "$profiles" "$tools" "$skills" "$resources" "$ports" "$variants"
    fi
    printf '}}'
    return 0
  fi

  printf 'Runtime:\n  Rig version: %s\n  Executable: %s\n  Bash version: %s\n  Platform: %s\n' \
    "$RIG_VERSION" "$RIG_INVOKED_PATH" "$BASH_VERSION" "$platform"
  printf 'Paths:\n  Config home: %s\n  Data home: %s\n  State home: %s\n  Cache home: %s\n' \
    "$RIG_DIAG_CONFIG_HOME" "$RIG_DIAG_DATA_HOME" "$RIG_DIAG_STATE_HOME" "$RIG_DIAG_CACHE_HOME"
  printf 'Configuration:\n  Root config: %s\n  Fragment count: %s\n  Status: %s\n' \
    "$root_display" "$fragment_count" "$config_status"
  if [ "$config_status" = valid ]; then
    printf '  Schema: %s\n  Default profile: %s\n  Selection mode: %s\n' \
      "$schema" "$default_profile" "$RIG_PROFILE_SELECTION_MODE"
    printf '  Profiles: %s\n  Tools: %s\n  Skills: %s\n  Managed resources: %s\n  Ports: %s\n  Tool variants: %s\n' \
      "$profiles" "$tools" "$skills" "$resources" "$ports" "$variants"
  fi
  return 0
}

rig_sort_query_items() {
  local index scan value previous
  local LC_ALL=C

  index=1
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    value=${RIG_QUERY_ITEMS[$index]}
    scan=$index
    while [ "$scan" -gt 0 ]; do
      previous=${RIG_QUERY_ITEMS[$((scan - 1))]}
      [[ "$value" < "$previous" ]] || break
      RIG_QUERY_ITEMS[$scan]=$previous
      scan=$((scan - 1))
    done
    RIG_QUERY_ITEMS[$scan]=$value
    index=$((index + 1))
  done
}

rig_collect_section_ids() {
  local wanted_type index

  wanted_type=$1
  RIG_QUERY_ITEMS=()
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = "$wanted_type" ]; then
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=${RIG_SECTION_IDS[$index]}
    fi
    index=$((index + 1))
  done
  rig_sort_query_items
}

rig_collect_field_values() {
  local section_name key section_index field_index field_end

  section_name=$1
  key=$2
  RIG_QUERY_ITEMS=()
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = "$key" ]; then
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=${RIG_FIELD_VALUES[$field_index]}
    fi
    field_index=$((field_index + 1))
  done
  rig_sort_query_items
}

rig_collect_all_tool_artifacts() {
  local section_name section_index field_index field_end key

  section_name=$1
  rig_section_index "$section_name" || return 1
  section_index=$RIG_INDEX
  RIG_QUERY_ITEMS=()
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    case "$key" in artifact|variant:*:artifact)
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=${RIG_FIELD_VALUES[$field_index]}
      ;;
    esac
    field_index=$((field_index + 1))
  done
}

rig_collect_tool_artifacts() {
  local tool platform section_name section_index field_index field_end variant variant_key key

  tool=$1
  platform=$2
  section_name=tool.$tool
  rig_select_compatible_variant "$section_name" "$platform" || return
  variant=$RIG_VALUE
  variant_key=variant:$variant:artifact
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  RIG_QUERY_ITEMS=()
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    if [ "$key" = artifact ] || { [ -n "$variant" ] && [ "$key" = "$variant_key" ]; }; then
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=${RIG_FIELD_VALUES[$field_index]}
    fi
    field_index=$((field_index + 1))
  done
}

rig_join_query_items() {
  local index item joined

  joined=
  index=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    item=${RIG_QUERY_ITEMS[$index]}
    if [ -n "$joined" ]; then
      joined="$joined, $item"
    else
      joined=$item
    fi
    index=$((index + 1))
  done
  RIG_VALUE=${joined:-none}
}

rig_join_query_tool_names() {
  local index item name joined

  joined=
  index=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    item=${RIG_QUERY_ITEMS[$index]}
    rig_get_value "tool.$item" name || return 2
    name=$RIG_VALUE
    if [ -n "$joined" ]; then
      joined="$joined, $item ($name)"
    else
      joined="$item ($name)"
    fi
    index=$((index + 1))
  done
  RIG_VALUE=${joined:-none}
}

rig_repeat_character() {
  local character count repeated

  character=$1
  count=$2
  repeated=
  while [ "${#repeated}" -lt "$count" ]; do
    repeated=$repeated$character
  done
  RIG_VALUE=$repeated
}

rig_ellipsize() {
  local value width prefix_width

  value=$1
  width=$2
  if [ "${#value}" -le "$width" ]; then
    RIG_VALUE=$value
    return
  fi

  prefix_width=$((width - 3))
  RIG_VALUE=${value:0:prefix_width}...
}

rig_ellipsize_middle() {
  local value width content_width prefix_width suffix_width suffix_offset

  value=$1
  width=$2
  if [ "${#value}" -le "$width" ]; then
    RIG_VALUE=$value
    return
  fi

  content_width=$((width - 3))
  prefix_width=$(((content_width + 1) / 2))
  suffix_width=$((content_width - prefix_width))
  suffix_offset=$((${#value} - suffix_width))
  RIG_VALUE=${value:0:prefix_width}...${value:$suffix_offset:$suffix_width}
}

rig_table_reset() {
  RIG_TABLE_HEADERS=()
  RIG_TABLE_MAX_WIDTHS=()
  RIG_TABLE_WIDTHS=()
  RIG_TABLE_ELLIPSIS=()
  RIG_TABLE_KEEP=()
  RIG_TABLE_CELLS=()
  RIG_TABLE_ROW_COUNT=0
}

rig_table_add_column() {
  local header maximum ellipsis keep index width

  header=$1
  maximum=$2
  ellipsis=${3:-end}
  keep=${4:-shrink}
  index=${#RIG_TABLE_HEADERS[@]}
  width=${#header}
  [ "$width" -le "$maximum" ] || width=$maximum
  RIG_TABLE_HEADERS[$index]=$header
  RIG_TABLE_MAX_WIDTHS[$index]=$maximum
  RIG_TABLE_WIDTHS[$index]=$width
  RIG_TABLE_ELLIPSIS[$index]=$ellipsis
  RIG_TABLE_KEEP[$index]=$keep
}

rig_table_fit_widths() {
  local index total overflow minimum available reduction

  total=$(((${#RIG_TABLE_HEADERS[@]} - 1) * 2))
  index=0
  while [ "$index" -lt "${#RIG_TABLE_WIDTHS[@]}" ]; do
    total=$((total + ${RIG_TABLE_WIDTHS[$index]}))
    index=$((index + 1))
  done
  overflow=$((total - 120))
  [ "$overflow" -gt 0 ] || return 0
  index=$((${#RIG_TABLE_WIDTHS[@]} - 1))
  while [ "$index" -ge 0 ] && [ "$overflow" -gt 0 ]; do
    if [ "${RIG_TABLE_KEEP[$index]}" != keep ]; then
      minimum=${#RIG_TABLE_HEADERS[$index]}
      available=$((${RIG_TABLE_WIDTHS[$index]} - minimum))
      if [ "$available" -gt 0 ]; then
        reduction=$available
        [ "$reduction" -le "$overflow" ] || reduction=$overflow
        RIG_TABLE_WIDTHS[$index]=$((${RIG_TABLE_WIDTHS[$index]} - reduction))
        overflow=$((overflow - reduction))
      fi
    fi
    index=$((index - 1))
  done
}

rig_table_add_row() {
  local index cell width maximum

  [ "$#" -eq "${#RIG_TABLE_HEADERS[@]}" ] || return 2
  index=0
  for cell in "$@"; do
    cell=${cell//$'\t'/\\t}
    cell=${cell//$'\n'/\\n}
    RIG_TABLE_CELLS[${#RIG_TABLE_CELLS[@]}]=$cell
    width=${#cell}
    maximum=${RIG_TABLE_MAX_WIDTHS[$index]}
    if [ "${RIG_TABLE_KEEP[$index]}" != keep ]; then
      [ "$width" -le "$maximum" ] || width=$maximum
    fi
    [ "$width" -le "${RIG_TABLE_WIDTHS[$index]}" ] || RIG_TABLE_WIDTHS[$index]=$width
    index=$((index + 1))
  done
  RIG_TABLE_ROW_COUNT=$((RIG_TABLE_ROW_COUNT + 1))
}

rig_table_print_row() {
  local offset index cell width

  offset=$1
  index=0
  while [ "$index" -lt "${#RIG_TABLE_HEADERS[@]}" ]; do
    if [ "$offset" -lt 0 ]; then
      cell=${RIG_TABLE_HEADERS[$index]}
    else
      cell=${RIG_TABLE_CELLS[$((offset + index))]}
    fi
    width=${RIG_TABLE_WIDTHS[$index]}
    if [ "${RIG_TABLE_ELLIPSIS[$index]}" = middle ]; then
      rig_ellipsize_middle "$cell" "$width"
    else
      rig_ellipsize "$cell" "$width"
    fi
    [ "$index" -eq 0 ] || printf '  '
    if [ "$index" -eq $((${#RIG_TABLE_HEADERS[@]} - 1)) ]; then
      printf '%s' "$RIG_VALUE"
    else
      printf '%-*s' "$width" "$RIG_VALUE"
    fi
    index=$((index + 1))
  done
  printf '\n'
}

rig_table_print() {
  local index offset

  rig_table_fit_widths
  rig_table_print_row -1
  index=0
  while [ "$index" -lt "${#RIG_TABLE_HEADERS[@]}" ]; do
    [ "$index" -eq 0 ] || printf '  '
    rig_repeat_character - "${RIG_TABLE_WIDTHS[$index]}"
    printf '%s' "$RIG_VALUE"
    index=$((index + 1))
  done
  printf '\n'
  offset=0
  index=0
  while [ "$index" -lt "$RIG_TABLE_ROW_COUNT" ]; do
    rig_table_print_row "$offset"
    offset=$((offset + ${#RIG_TABLE_HEADERS[@]}))
    index=$((index + 1))
  done
}

rig_mutation_split_row() {
  local rest count scope_last index first detail scope

  rest=$1
  count=$2
  scope_last=$3
  RIG_MUTATION_CELLS=()
  index=0
  while [ "$index" -lt "$((count - 1 - scope_last))" ]; do
    case "$rest" in *$'\t'*) ;; *) return 1 ;; esac
    first=${rest%%$'\t'*}
    rest=${rest#*$'\t'}
    RIG_MUTATION_CELLS[${#RIG_MUTATION_CELLS[@]}]=$first
    index=$((index + 1))
  done
  if [ "$scope_last" -eq 1 ]; then
    case "$rest" in *$'\t'*) ;; *) return 1 ;; esac
    detail=${rest%$'\t'*}
    scope=${rest##*$'\t'}
    RIG_MUTATION_CELLS[${#RIG_MUTATION_CELLS[@]}]=$detail
    RIG_MUTATION_CELLS[${#RIG_MUTATION_CELLS[@]}]=$scope
  else
    RIG_MUTATION_CELLS[${#RIG_MUTATION_CELLS[@]}]=$rest
  fi
}

rig_render_mutation_report() {
  local report line column table_active scope_last
  local -a columns

  report=$1
  table_active=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      $'TOOL\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'SKILL\tAUTHORITY\tRESULT\tDETAIL\tSCOPE'|\
      $'RESOURCE\tKIND\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'MANAGER\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'TARGET\tPROVIDER\tRESULT\tDETAIL'|\
      $'PROVIDER\tRESULT\tDETAIL')
        [ "$table_active" -eq 0 ] || rig_table_print
        rig_table_reset
        IFS=$'\t' read -r -a columns <<< "$line"
        for column in "${columns[@]}"; do
          case "$column" in
            TOOL|SKILL|RESOURCE|MANAGER|TARGET|PROVIDER|AUTHORITY)
              rig_table_add_column "$column" 28 end keep ;;
            KIND|RESULT|SCOPE) rig_table_add_column "$column" 16 ;;
            DETAIL) rig_table_add_column DETAIL 64 ;;
          esac
        done
        scope_last=0
        [ "${columns[$((${#columns[@]} - 1))]}" != SCOPE ] || scope_last=1
        table_active=1
        ;;
      *)
        if [ "$table_active" -eq 1 ] && [[ "$line" == *$'\t'* ]]; then
          if rig_mutation_split_row "$line" "${#RIG_TABLE_HEADERS[@]}" "$scope_last"; then
            rig_table_add_row "${RIG_MUTATION_CELLS[@]}"
            continue
          fi
        fi
        if [ "$table_active" -eq 1 ]; then
          rig_table_print
          table_active=0
        fi
        printf '%s\n' "$line"
        ;;
    esac
  done <<< "$report"
  [ "$table_active" -eq 0 ] || rig_table_print
}

rig_mutation_json() {
  local command report line profile platform table_open section_separator row_separator column_separator cell scope_last
  local -a columns

  command=$1
  report=$2
  profile=
  platform=
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'Profile: '*) profile=${line#Profile: } ;;
      'Platform: '*) platform=${line#Platform: } ;;
    esac
  done <<< "$report"
  [ -n "$profile" ] || profile=$RIG_RESOLVED_PROFILE
  [ -n "$platform" ] || platform=$RIG_RESOLVED_PLATFORM
  RIG_RESOLVED_PROFILE=$profile
  RIG_RESOLVED_PLATFORM=$platform
  rig_json_envelope "$command"
  printf ',"sections":['
  table_open=0
  section_separator=
  row_separator=
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      $'TOOL\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'SKILL\tAUTHORITY\tRESULT\tDETAIL\tSCOPE'|\
      $'RESOURCE\tKIND\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'MANAGER\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'TARGET\tPROVIDER\tRESULT\tDETAIL'|\
      $'PROVIDER\tRESULT\tDETAIL')
        if [ "$table_open" -eq 1 ]; then printf ']}'; fi
        printf '%s{"columns":[' "$section_separator"
        IFS=$'\t' read -r -a columns <<< "$line"
        column_separator=
        for cell in "${columns[@]}"; do
          rig_json_escape "$cell"
          printf '%s"%s"' "$column_separator" "$RIG_VALUE"
          column_separator=,
        done
        printf '],"rows":['
        scope_last=0
        [ "${columns[$((${#columns[@]} - 1))]}" != SCOPE ] || scope_last=1
        table_open=1
        section_separator=,
        row_separator=
        ;;
      *)
        if [ "$table_open" -eq 1 ] && [[ "$line" == *$'\t'* ]]; then
          if rig_mutation_split_row "$line" "${#columns[@]}" "$scope_last"; then
            printf '%s[' "$row_separator"
            column_separator=
            for cell in "${RIG_MUTATION_CELLS[@]}"; do
              rig_json_escape "$cell"
              printf '%s"%s"' "$column_separator" "$RIG_VALUE"
              column_separator=,
            done
            printf ']'
            row_separator=,
            continue
          fi
        fi
        if [ "$table_open" -eq 1 ]; then
          printf ']}'
          table_open=0
        fi
        ;;
    esac
  done <<< "$report"
  if [ "$table_open" -eq 1 ]; then printf ']}'; fi
  printf '],"notes":['
  column_separator=
  table_open=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      $'TOOL\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'SKILL\tAUTHORITY\tRESULT\tDETAIL\tSCOPE'|\
      $'RESOURCE\tKIND\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'MANAGER\tPROVIDER\tRESULT\tDETAIL\tSCOPE'|\
      $'TARGET\tPROVIDER\tRESULT\tDETAIL'|\
      $'PROVIDER\tRESULT\tDETAIL') table_open=1; continue ;;
    esac
    if [ "$table_open" -eq 1 ] && [[ "$line" == *$'\t'* ]]; then continue; fi
    table_open=0
    [ -n "$line" ] || continue
    rig_json_escape "$line"
    printf '%s"%s"' "$column_separator" "$RIG_VALUE"
    column_separator=,
  done <<< "$report"
  printf ']'
  rig_json_field ',' report "$report"
  printf '}\n'
}

rig_capture_report_context() {
  local captured metadata status progress_command

  progress_command=$RIG_PROGRESS_COMMAND
  if captured=$(
    # Command substitution resets caught traps. This shell, not main's
    # parent, owns any footer drawn while assembling a mutation report.
    rig_progress_reset
    RIG_PROGRESS_COMMAND=$progress_command
    trap rig_progress_cleanup EXIT
    trap 'rig_progress_signal 129' HUP
    trap 'rig_progress_signal 130' INT
    trap 'rig_progress_signal 143' TERM
    trap rig_progress_resize WINCH
    "$@"
    status=$?
    if [ "$status" -eq 0 ]; then
      rig_progress_finish
    else
      rig_progress_fail
    fi
    rig_progress_cleanup
    printf '\036%s\037%s\037%s\037%s\n' \
      "$RIG_OUTCOME_RESULT" "$RIG_OUTCOME_DETAIL" \
      "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
    exit "$status"
  ); then
    status=0
  else
    status=$?
  fi
  case "$captured" in
    *$'\036'*) ;;
    *)
      RIG_CAPTURED_REPORT=$captured
      RIG_CAPTURED_STATUS=$status
      return "$status"
      ;;
  esac
  metadata=${captured##*$'\036'}
  RIG_CAPTURED_REPORT=${captured%$'\036'*}
  RIG_CAPTURED_REPORT=${RIG_CAPTURED_REPORT%$'\n'}
  RIG_CAPTURED_STATUS=$status
  IFS=$'\037' read -r RIG_OUTCOME_RESULT RIG_OUTCOME_DETAIL \
    RIG_RESOLVED_PROFILE RIG_RESOLVED_PLATFORM <<< "$metadata"
  return "$status"
}

rig_buffer_mutation_report() {
  local command backend format format_seen report status
  local -a args

  command=$1
  backend=$2
  shift 2
  format=text
  format_seen=0
  args=()
  while [ "$#" -gt 0 ]; do
    if [ "$1" = --format ]; then
      if [ "$format_seen" -eq 1 ] || [ "$#" -lt 2 ]; then
        rig_command_syntax_error "$command" || return
      fi
      case "$2" in
        text|json) format=$2 ;;
        *) rig_command_syntax_error "$command" || return ;;
      esac
      format_seen=1
      shift 2
    else
      args[${#args[@]}]=$1
      shift
    fi
  done
  if rig_capture_report_context "$backend" "${args[@]+"${args[@]}"}"; then
    status=0
  else
    status=$?
  fi
  rig_progress_cleanup
  report=$RIG_CAPTURED_REPORT
  if [ -n "$report" ]; then
    if [ "$format" = json ] && [ "${args[0]-}" != --help ]; then
      rig_mutation_json "$command" "$report"
    else
      rig_render_mutation_report "$report"
    fi
  fi
  return "$status"
}

rig_print_profile_tools() {
  local index tool name category purpose

  rig_table_reset
  rig_table_add_column ID 24 end keep
  rig_table_add_column NAME 24
  rig_table_add_column CATEGORY 16
  rig_table_add_column PURPOSE 72
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    tool=${RIG_SELECTED_TOOLS[$index]}
    rig_get_value "tool.$tool" name || return
    name=$RIG_VALUE
    rig_get_value "tool.$tool" category || return
    category=$RIG_VALUE
    rig_get_value "tool.$tool" purpose || return
    purpose=$RIG_VALUE
    rig_table_add_row "$tool" "$name" "$category" "$purpose"
    index=$((index + 1))
  done
  rig_table_print
}

rig_profile_declares_tool() {
  local profile tool section_index field_index field_end

  profile=$1
  tool=$2
  if [ "$RIG_PROFILE_SELECTION_MODE" = item ]; then
    rig_item_declares_profile "tool.$tool" "$profile"
    return
  fi
  rig_section_index "profile.$profile" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = tool ] &&
      [ "${RIG_FIELD_VALUES[$field_index]}" = "$tool" ]; then
      return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_profile_contains_declared_tool() {
  local profile tool section_index field_index field_end child

  profile=$1
  tool=$2
  rig_profile_declares_tool "$profile" "$tool" && return 0
  rig_section_index "profile.$profile" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] && {
      [ "${RIG_FIELD_KEYS[$field_index]}" = profile ] ||
        [ "${RIG_FIELD_KEYS[$field_index]}" = inherit ];
    }; then
      child=${RIG_FIELD_VALUES[$field_index]}
      rig_profile_contains_declared_tool "$child" "$tool" && return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_tool_requires_tool() {
  local tool wanted section_index field_index field_end child

  tool=$1
  wanted=$2
  rig_section_index "tool.$tool" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ] &&
      [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
      child=${RIG_FIELD_VALUES[$field_index]}
      [ "$child" != "$wanted" ] || return 0
      rig_tool_requires_tool "$child" "$wanted" && return 0
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_profile_requires_tool() {
  local profile tool section_index field_index field_end key target index candidate result
  local -a saved_active_profiles

  profile=$1
  tool=$2
  if [ "$RIG_PROFILE_SELECTION_MODE" = item ]; then
    saved_active_profiles=("${RIG_ACTIVE_PROFILES[@]+"${RIG_ACTIVE_PROFILES[@]}"}")
    RIG_ACTIVE_PROFILES=()
    rig_activate_profile "$profile" || return
    result=1
    index=0
    while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
      if [ "${RIG_SECTION_TYPES[$index]}" = tool ]; then
        candidate=${RIG_SECTION_IDS[$index]}
        if rig_item_selected_by_active_profiles "tool.$candidate" &&
          rig_tool_requires_tool "$candidate" "$tool"; then
          result=0
          break
        fi
      fi
      index=$((index + 1))
    done
    RIG_ACTIVE_PROFILES=("${saved_active_profiles[@]+"${saved_active_profiles[@]}"}")
    return "$result"
  fi
  rig_section_index "profile.$profile" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ]; then
      key=${RIG_FIELD_KEYS[$field_index]}
      target=${RIG_FIELD_VALUES[$field_index]}
      case "$key" in
        profile|inherit) rig_profile_requires_tool "$target" "$tool" && return 0 ;;
        tool) rig_tool_requires_tool "$target" "$tool" && return 0 ;;
      esac
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_collect_profile_memberships() {
  local tool profile index membership
  local -a profiles

  tool=$1
  rig_collect_section_ids profile
  profiles=()
  index=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    profiles[$index]=${RIG_QUERY_ITEMS[$index]}
    index=$((index + 1))
  done
  RIG_QUERY_ITEMS=()
  index=0
  while [ "$index" -lt "${#profiles[@]}" ]; do
    profile=${profiles[$index]}
    membership=
    if rig_profile_declares_tool "$profile" "$tool"; then
      membership=direct
    elif rig_profile_contains_declared_tool "$profile" "$tool"; then
      membership=inherited
    elif rig_profile_requires_tool "$profile" "$tool"; then
      membership=required
    fi
    if [ -n "$membership" ]; then
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]="$profile ($membership)"
    fi
    index=$((index + 1))
  done
}

rig_describe_compatible_binding() {
  local tool platform section_index total matches binding_index provider kind locator

  tool=$1
  platform=$2
  section_index=0
  total=0
  matches=0
  binding_index=
  while [ "$section_index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$section_index]}" = binding ] &&
      [ "${RIG_SECTION_IDS[$section_index]}" = "$tool" ]; then
      total=$((total + 1))
      if rig_binding_supports_platform "$section_index" "$platform"; then
        matches=$((matches + 1))
        binding_index=$section_index
      fi
    fi
    section_index=$((section_index + 1))
  done

  if [ "$matches" -gt 1 ]; then
    rig_fail "tool '$tool' has ambiguous installations for platform '$platform'" || return
  fi
  if [ "$matches" -eq 0 ]; then
    if [ "$total" -eq 0 ]; then
      RIG_VALUE=none
    else
      RIG_VALUE="none for $platform"
    fi
    return
  fi

  provider=${RIG_SECTION_SECONDARY_IDS[$binding_index]}
  rig_get_value "${RIG_SECTION_NAMES[$binding_index]}" kind || return
  kind=$RIG_VALUE
  rig_get_value "${RIG_SECTION_NAMES[$binding_index]}" locator || return
  locator=$RIG_VALUE
  RIG_VALUE="$provider ($kind: $locator)"
}

rig_resource_schedule_summary() {
  local section_name section_index field_index field_end joined

  section_name=$1
  if rig_get_value "$section_name" schedule-interval; then
    RIG_VALUE=interval:$RIG_VALUE
    return
  fi
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  joined=
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = schedule-calendar ]; then
      if [ -n "$joined" ]; then
        joined="$joined;${RIG_FIELD_VALUES[$field_index]}"
      else
        joined=${RIG_FIELD_VALUES[$field_index]}
      fi
    fi
    field_index=$((field_index + 1))
  done
  RIG_VALUE=calendar:$joined
}

rig_print_profile_resource_tables() {
  local wanted label count section_name section_index id name provider desired schedule detail

  for wanted in service scheduled-job setting dock; do
    count=0
    for section_name in "${RIG_SELECTED_RESOURCE_SECTIONS[@]+"${RIG_SELECTED_RESOURCE_SECTIONS[@]}"}"; do
      [ "${section_name%%.*}" = "$wanted" ] && count=$((count + 1))
    done
    case "$wanted" in
      service) label=Services ;;
      scheduled-job) label='Scheduled jobs' ;;
      setting) label=Settings ;;
      dock) label='Dock layouts' ;;
    esac
    printf '\n%s: %s\n' "$label" "$count"
    [ "$count" -gt 0 ] || continue
    rig_table_reset
    rig_table_add_column ID 24 end keep
    rig_table_add_column NAME 24
    rig_table_add_column PROVIDER 20 end keep
    case "$wanted" in
      service) rig_table_add_column DESIRED 36 ;;
      scheduled-job) rig_table_add_column DESIRED 24; rig_table_add_column SCHEDULE 40 ;;
      setting) rig_table_add_column VALUE 64 ;;
      dock) rig_table_add_column ITEMS 8 ;;
    esac
    for section_name in "${RIG_SELECTED_RESOURCE_SECTIONS[@]+"${RIG_SELECTED_RESOURCE_SECTIONS[@]}"}"; do
      [ "${section_name%%.*}" = "$wanted" ] || continue
      rig_section_index "$section_name" || return 2
      section_index=$RIG_INDEX
      id=${RIG_SECTION_IDS[$section_index]}
      rig_get_value "$section_name" name || return 2
      name=$RIG_VALUE
      rig_get_value "$section_name" provider || return 2
      provider=$RIG_VALUE
      case "$wanted" in
        service)
          rig_get_value "$section_name" desired-state || return 2
          rig_table_add_row "$id" "$name" "$provider" "$RIG_VALUE"
          ;;
        scheduled-job)
          rig_get_value "$section_name" desired-state || return 2
          desired=$RIG_VALUE
          rig_resource_schedule_summary "$section_name" || return
          schedule=$RIG_VALUE
          rig_table_add_row "$id" "$name" "$provider" "$desired" "$schedule"
          ;;
        setting)
          rig_get_value "$section_name" value || return 2
          rig_table_add_row "$id" "$name" "$provider" "$RIG_VALUE"
          ;;
        dock)
          rig_collect_field_values "$section_name" item
          detail=${#RIG_QUERY_ITEMS[@]}
          rig_table_add_row "$id" "$name" "$provider" "$detail"
          ;;
      esac
    done
    rig_table_print
  done
}

rig_print_profile_ports() {
  local port section_name name number scope mode owner

  printf '\nPorts: %s\n' "${#RIG_SELECTED_PORTS[@]}"
  [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ] || return 0
  rig_table_reset
  rig_table_add_column ID 24 end keep
  rig_table_add_column NAME 24
  rig_table_add_column PORT 8
  rig_table_add_column SCOPE 20
  rig_table_add_column MODE 16
  rig_table_add_column OWNER 24 end keep
  for port in "${RIG_SELECTED_PORTS[@]+"${RIG_SELECTED_PORTS[@]}"}"; do
    section_name=port.$port
    rig_get_value "$section_name" name || return 2
    name=$RIG_VALUE
    rig_get_value "$section_name" port || return 2
    number=$RIG_VALUE
    rig_get_value "$section_name" scope || return 2
    scope=$RIG_VALUE
    rig_get_value "$section_name" mode || return 2
    mode=$RIG_VALUE
    rig_get_value "$section_name" owner || return 2
    owner=$RIG_VALUE
    rig_table_add_row "$port" "$name" "$number" "$scope" "$mode" "$owner"
  done
  rig_table_print
}

rig_print_profile_skills() {
  local skill name authority runtimes

  printf '\nSkills: %s\n' "${#RIG_SELECTED_SKILLS[@]}"
  [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ] || return 0
  rig_table_reset
  rig_table_add_column ID 24 end keep
  rig_table_add_column NAME 24
  rig_table_add_column AUTHORITY 24 end keep
  rig_table_add_column RUNTIMES 56
  for skill in "${RIG_SELECTED_SKILLS[@]}"; do
    rig_get_value "skill.$skill" name || return 2
    name=$RIG_VALUE
    rig_get_value "skill.$skill" authority || return 2
    authority=$RIG_VALUE
    rig_collect_field_values "skill.$skill" runtime
    rig_join_query_items
    runtimes=$RIG_VALUE
    rig_table_add_row "$skill" "$name" "$authority" "$runtimes"
  done
  rig_table_print
}

rig_show_json() {
  local index tool name category purpose skill authority runtimes section_name section_index id kind provider value
  local separator

  rig_json_envelope show
  printf ',"tools":['
  separator=
  for tool in "${RIG_SELECTED_TOOLS[@]+"${RIG_SELECTED_TOOLS[@]}"}"; do
    rig_get_value "tool.$tool" name || return 2; name=$RIG_VALUE
    rig_get_value "tool.$tool" category || return 2; category=$RIG_VALUE
    rig_get_value "tool.$tool" purpose || return 2; purpose=$RIG_VALUE
    rig_json_field "$separator{" id "$tool"
    rig_json_field ',' name "$name"
    rig_json_field ',' category "$category"
    rig_json_field ',' purpose "$purpose"
    printf '}'
    separator=,
  done
  printf '],"skills":['
  separator=
  for skill in "${RIG_SELECTED_SKILLS[@]+"${RIG_SELECTED_SKILLS[@]}"}"; do
    rig_get_value "skill.$skill" name || return 2; name=$RIG_VALUE
    rig_get_value "skill.$skill" authority || return 2; authority=$RIG_VALUE
    rig_collect_field_values "skill.$skill" runtime
    rig_join_query_items
    runtimes=$RIG_VALUE
    rig_json_field "$separator{" id "$skill"
    rig_json_field ',' name "$name"
    rig_json_field ',' authority "$authority"
    rig_json_field ',' runtimes "$runtimes"
    printf '}'
    separator=,
  done
  printf '],"resources":['
  separator=
  for section_name in "${RIG_SELECTED_RESOURCE_SECTIONS[@]+"${RIG_SELECTED_RESOURCE_SECTIONS[@]}"}"; do
    rig_section_index "$section_name" || return 2
    section_index=$RIG_INDEX
    id=${RIG_SECTION_IDS[$section_index]}
    kind=${RIG_SECTION_TYPES[$section_index]}
    rig_get_value "$section_name" name || return 2; name=$RIG_VALUE
    rig_get_value "$section_name" provider || return 2; provider=$RIG_VALUE
    rig_json_field "$separator{" id "$id"
    rig_json_field ',' kind "$kind"
    rig_json_field ',' name "$name"
    rig_json_field ',' provider "$provider"
    case "$kind" in
      service|scheduled-job)
        rig_get_value "$section_name" desired-state || return 2
        rig_json_field ',' desired "$RIG_VALUE"
        if [ "$kind" = scheduled-job ]; then
          rig_resource_schedule_summary "$section_name" || return
          rig_json_field ',' schedule "$RIG_VALUE"
        fi
        ;;
      setting)
        rig_get_value "$section_name" value || return 2
        rig_json_field ',' value "$RIG_VALUE"
        ;;
      dock)
        rig_collect_field_values "$section_name" item
        printf ',"items":['
        index=0
        while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
          [ "$index" -eq 0 ] || printf ','
          rig_json_escape "${RIG_QUERY_ITEMS[$index]}"
          printf '"%s"' "$RIG_VALUE"
          index=$((index + 1))
        done
        printf ']'
        ;;
    esac
    printf '}'
    separator=,
  done
  printf '],"ports":['
  separator=
  for id in "${RIG_SELECTED_PORTS[@]+"${RIG_SELECTED_PORTS[@]}"}"; do
    section_name=port.$id
    rig_json_field "$separator{" id "$id"
    for value in name port scope mode owner; do
      rig_get_value "$section_name" "$value" || return 2
      rig_json_field ',' "$value" "$RIG_VALUE"
    done
    printf '}'
    separator=,
  done
  printf ']}\n'
}

rig_command_show() {
  local profile platform format profile_seen format_seen category category_seen all item
  local -a catalogue_args

  category=
  category_seen=0
  all=0
  item=
  catalogue_args=()
  profile=
  format=text
  profile_seen=0
  format_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        [ "$#" -eq 1 ] || rig_command_syntax_error show || return
        rig_command_help show; return ;;
      --all)
        [ "$all" -eq 0 ] || rig_command_syntax_error show || return
        all=1; shift ;;
      --category)
        [ "$category_seen" -eq 0 ] && [ "$#" -ge 2 ] && [ -n "$2" ] ||
          rig_command_syntax_error show || return
        category=$2; category_seen=1; shift 2 ;;
      --profile)
        [ "$profile_seen" -eq 0 ] && [ "$#" -ge 2 ] && [ -n "$2" ] ||
          rig_command_syntax_error show || return
        profile=$2; profile_seen=1; shift 2 ;;
      --format)
        [ "$format_seen" -eq 0 ] && [ "$#" -ge 2 ] ||
          rig_command_syntax_error show || return
        case "$2" in text|json) format=$2 ;; *) rig_command_syntax_error show || return ;; esac
        format_seen=1; shift 2 ;;
      -*) rig_command_syntax_error show || return ;;
      *)
        [ -z "$item" ] && [ -n "$1" ] || rig_command_syntax_error show || return
        item=$1; shift ;;
    esac
  done

  if [ -n "$item" ]; then
    [ "$all" -eq 0 ] && [ "$category_seen" -eq 0 ] && [ "$profile_seen" -eq 0 ] ||
      rig_command_syntax_error show || return
    rig_show_item "$item" --format "$format"
    return
  fi
  [ "$all" -eq 0 ] || [ "$profile_seen" -eq 0 ] || rig_command_syntax_error show || return
  if [ "$all" -eq 1 ] || [ "$category_seen" -eq 1 ]; then
    [ "$all" -eq 0 ] || catalogue_args[${#catalogue_args[@]}]=--all
    if [ "$category_seen" -eq 1 ]; then
      catalogue_args[${#catalogue_args[@]}]=--category
      catalogue_args[${#catalogue_args[@]}]=$category
    fi
    if [ "$profile_seen" -eq 1 ]; then
      catalogue_args[${#catalogue_args[@]}]=--profile
      catalogue_args[${#catalogue_args[@]}]=$profile
    fi
    rig_show_catalogue "${catalogue_args[@]+"${catalogue_args[@]}"}" --format "$format"
    return
  fi

  rig_load_config || return
  rig_current_platform || return
  platform=$RIG_VALUE
  rig_resolve_profile "$profile" "$platform" || return
  if [ "$format" = json ]; then
    rig_show_json
    return
  fi
  printf 'Profile:  %s\nPlatform: %s\nTools:    %s\n\n' \
    "$RIG_RESOLVED_PROFILE" "$platform" "${#RIG_SELECTED_TOOLS[@]}"
  rig_print_profile_tools
  rig_print_profile_skills || return
  if [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -gt 0 ]; then
    rig_print_profile_resource_tables
  fi
  if [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ]; then
    rig_print_profile_ports
  fi
}

rig_list_select() {
  local category profile platform category_seen profile_seen tool index declared_category all
  local -a tools

  all=0
  category=
  profile=
  category_seen=0
  profile_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) all=1; shift ;;
      --category)
        [ "$category_seen" -eq 0 ] && [ "$#" -ge 2 ] && [ -n "$2" ] ||
          rig_command_syntax_error show || return
        category=$2
        category_seen=1
        shift 2
        ;;
      --profile)
        [ "$profile_seen" -eq 0 ] && [ "$#" -ge 2 ] && [ -n "$2" ] ||
          rig_command_syntax_error show || return
        profile=$2
        profile_seen=1
        shift 2
        ;;
      *) rig_command_syntax_error show || return ;;
    esac
  done

  rig_load_config || return
  if [ -n "$category" ]; then
    rig_valid_id "$category" && rig_section_index "category.$category" ||
      rig_fail "unknown category '$category'" || return
  fi
  rig_current_platform || return
  platform=$RIG_VALUE
  RIG_RESOLVED_PLATFORM=$platform
  if [ "$all" -eq 0 ]; then
    rig_resolve_profile "$profile" "$platform" || return
    tools=("${RIG_SELECTED_TOOLS[@]+"${RIG_SELECTED_TOOLS[@]}"}")
  else
    rig_collect_section_ids tool
    tools=("${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}")
  fi

  RIG_LIST_TOOLS=()
  index=0
  while [ "$index" -lt "${#tools[@]}" ]; do
    tool=${tools[$index]}
    if [ -n "$category" ]; then
      rig_get_value "tool.$tool" category || return
      declared_category=$RIG_VALUE
      if [ "$declared_category" != "$category" ]; then
        index=$((index + 1))
        continue
      fi
    fi
    RIG_LIST_TOOLS[${#RIG_LIST_TOOLS[@]}]=$tool
    index=$((index + 1))
  done
}

rig_profile_contains_resource() {
  local profile wanted section_index field_index field_end key target result
  local -a saved_active_profiles

  profile=$1
  wanted=$2
  if [ "$RIG_PROFILE_SELECTION_MODE" = item ]; then
    saved_active_profiles=("${RIG_ACTIVE_PROFILES[@]+"${RIG_ACTIVE_PROFILES[@]}"}")
    RIG_ACTIVE_PROFILES=()
    rig_activate_profile "$profile" || return
    result=1
    rig_item_selected_by_active_profiles "$wanted" && result=0
    RIG_ACTIVE_PROFILES=("${saved_active_profiles[@]+"${saved_active_profiles[@]}"}")
    return "$result"
  fi
  rig_section_index "profile.$profile" || return 1
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_SECTIONS[$field_index]}" -eq "$section_index" ]; then
      key=${RIG_FIELD_KEYS[$field_index]}
      target=${RIG_FIELD_VALUES[$field_index]}
      case "$key" in
        profile|inherit) rig_profile_contains_resource "$target" "$wanted" && return 0 ;;
        skill|service|scheduled-job|setting|dock|port) [ "$key.$target" = "$wanted" ] && return 0 ;;
      esac
    fi
    field_index=$((field_index + 1))
  done
  return 1
}

rig_collect_resource_memberships() {
  local section_name profile index
  local -a profiles

  section_name=$1
  rig_collect_section_ids profile
  profiles=()
  index=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    profiles[$index]=${RIG_QUERY_ITEMS[$index]}
    index=$((index + 1))
  done
  RIG_QUERY_ITEMS=()
  for profile in "${profiles[@]+"${profiles[@]}"}"; do
    if rig_profile_contains_resource "$profile" "$section_name"; then
      RIG_QUERY_ITEMS[${#RIG_QUERY_ITEMS[@]}]=$profile
    fi
  done
}

rig_explain_dock_items() {
  local section_name section_index field_index field_end item item_section position value

  section_name=$1
  rig_section_index "$section_name" || return 2
  section_index=$RIG_INDEX
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  position=0
  while [ "$field_index" -lt "$field_end" ]; do
    if [ "${RIG_FIELD_KEYS[$field_index]}" = item ]; then
      position=$((position + 1))
      item=${RIG_FIELD_VALUES[$field_index]}
      item_section=dock-item.$item
      printf 'dock-item.%s.id=%s\n' "$position" "$item"
      rig_get_value "$item_section" kind || return 2
      printf 'dock-item.%s.kind=%s\n' "$position" "$RIG_VALUE"
      rig_get_value "$item_section" path || return 2
      printf 'dock-item.%s.path=%s\n' "$position" "$RIG_VALUE"
      if rig_get_value "$item_section" view; then
        value=$RIG_VALUE
        printf 'dock-item.%s.view=%s\n' "$position" "$value"
      fi
      if rig_get_value "$item_section" display; then
        value=$RIG_VALUE
        printf 'dock-item.%s.display=%s\n' "$position" "$value"
      fi
    fi
    field_index=$((field_index + 1))
  done
}

rig_explain_resource() {
  local target kind id section_name section_index field_index field_end key value profiles

  target=$1
  kind=${target%%:*}
  id=${target#*:}
  [ "$target" != "$id" ] && rig_valid_id "$id" ||
    rig_fail "unknown resource '$target'" || return
  case "$kind" in service|scheduled-job|setting|dock|port) ;; *)
    rig_fail "unknown resource '$target'" || return ;;
  esac
  section_name=$kind.$id
  rig_section_index "$section_name" || rig_fail "unknown resource '$target'" || return
  section_index=$RIG_INDEX
  rig_collect_resource_memberships "$section_name"
  rig_join_query_items
  profiles=$RIG_VALUE
  printf 'Resource: %s\nKind: %s\nID: %s\nProfiles: %s\n' "$target" "$kind" "$id" "$profiles"
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    value=${RIG_FIELD_VALUES[$field_index]}
    [ "$key" != resource-dependency ] || key=depends-on
    printf '%s=%s\n' "$key" "$value"
    field_index=$((field_index + 1))
  done
  if [ "$kind" = dock ]; then
    rig_explain_dock_items "$section_name" || return
  fi
  if [ "$kind" = service ]; then
    rig_get_value "$section_name" restart-policy || printf '%s\n' 'restart-policy=never'
    rig_get_value "$section_name" start-policy || printf '%s\n' 'start-policy=load'
  elif [ "$kind" = scheduled-job ]; then
    rig_get_value "$section_name" run-policy || printf '%s\n' 'run-policy=scheduled-only'
    rig_get_value "$section_name" priority || printf '%s\n' 'priority=background'
  fi
}

rig_explain_skill() {
  local target id section_name name purpose rationale authority source source_skill trust
  local platforms runtimes requires profiles public_source

  target=$1
  id=${target#skill:}
  [ "$target" != "$id" ] && rig_valid_id "$id" && rig_section_index "skill.$id" ||
    rig_fail "unknown skill '$target'" || return
  section_name=skill.$id
  rig_get_value "$section_name" name || return 2; name=$RIG_VALUE
  rig_get_value "$section_name" purpose || return 2; purpose=$RIG_VALUE
  rig_get_value "$section_name" rationale || return 2; rationale=$RIG_VALUE
  rig_get_value "$section_name" authority || return 2; authority=$RIG_VALUE
  rig_get_value "$section_name" source || return 2; source=$RIG_VALUE
  if rig_get_value "$section_name" source-skill; then source_skill=$RIG_VALUE; else source_skill=$id; fi
  rig_get_value "$section_name" trust || return 2; trust=$RIG_VALUE
  if rig_get_value "$section_name" public-source; then public_source=$RIG_VALUE; else public_source=-; fi
  rig_collect_field_values "$section_name" platform; rig_join_query_items; platforms=$RIG_VALUE
  rig_collect_field_values "$section_name" runtime; rig_join_query_items; runtimes=$RIG_VALUE
  rig_collect_field_values "$section_name" requires; rig_join_query_items; requires=$RIG_VALUE
  rig_collect_resource_memberships "$section_name"; rig_join_query_items; profiles=$RIG_VALUE
  printf 'Skill: %s\nName: %s\nPurpose: %s\nRationale: %s\n' "$id" "$name" "$purpose" "$rationale"
  printf 'Authority: %s\nSource: %s\nSource skill: %s\nTrust: %s\n' "$authority" "$source" "$source_skill" "$trust"
  printf 'Platforms: %s\nRuntimes: %s\nRequires: %s\nProfiles: %s\nPublic source: %s\n' \
    "$platforms" "$runtimes" "$requires" "$profiles" "$public_source"
}

rig_command_explain_impl() {
  local tool name category category_name purpose rationale platforms requires related alternatives profiles platform binding
  local artifacts

  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help) rig_command_help show; return ;;
    esac
  fi
  [ "$#" -eq 1 ] || rig_command_syntax_error show || return
  tool=$1
  rig_load_config || return
  case "$tool" in
    skill:*) rig_explain_skill "$tool"; return ;;
    service:*|scheduled-job:*|setting:*|dock:*|port:*) rig_explain_resource "$tool"; return ;;
  esac
  rig_valid_id "$tool" && rig_section_index "tool.$tool" ||
    rig_fail "unknown tool '$tool'" || return
  rig_current_platform || return
  platform=$RIG_VALUE
  RIG_RESOLVED_PLATFORM=$platform
  rig_describe_compatible_binding "$tool" "$platform" || return
  binding=$RIG_VALUE

  rig_get_value "tool.$tool" name || return
  name=$RIG_VALUE
  rig_get_value "tool.$tool" category || return
  category=$RIG_VALUE
  rig_get_value "category.$category" name || return
  category_name=$RIG_VALUE
  rig_get_value "tool.$tool" purpose || return
  purpose=$RIG_VALUE
  rig_get_value "tool.$tool" rationale || return
  rationale=$RIG_VALUE

  rig_collect_field_values "tool.$tool" platform
  rig_join_query_items
  platforms=$RIG_VALUE
  rig_collect_field_values "tool.$tool" requires
  rig_join_query_tool_names || return
  requires=$RIG_VALUE
  rig_collect_field_values "tool.$tool" related
  rig_join_query_tool_names || return
  related=$RIG_VALUE
  rig_collect_field_values "tool.$tool" alternative
  rig_join_query_tool_names || return
  alternatives=$RIG_VALUE
  rig_collect_tool_artifacts "$tool" "$platform" || return
  rig_join_query_items
  artifacts=$RIG_VALUE
  rig_collect_profile_memberships "$tool"
  rig_join_query_items
  profiles=$RIG_VALUE

  printf 'Tool: %s\nName: %s\nCategory: %s (%s)\nPurpose: %s\nRationale: %s\n' \
    "$tool" "$name" "$category" "$category_name" "$purpose" "$rationale"
  printf 'Platforms: %s\nRequires: %s\nRelated: %s\nAlternatives: %s\nProfiles: %s\n' \
    "$platforms" "$requires" "$related" "$alternatives" "$profiles"
  printf 'Installation: %s\n' "$binding"
    printf 'Artifacts: %s\n' "$artifacts"
}

rig_render_list_report() {
  local id name category purpose

  rig_table_reset
  rig_table_add_column ID 28 end keep
  rig_table_add_column NAME 24
  rig_table_add_column CATEGORY 20
  rig_table_add_column PURPOSE 64
  for id in "${RIG_LIST_TOOLS[@]+"${RIG_LIST_TOOLS[@]}"}"; do
    rig_get_value "tool.$id" name || return 2; name=$RIG_VALUE
    rig_get_value "tool.$id" category || return 2; category=$RIG_VALUE
    rig_get_value "tool.$id" purpose || return 2; purpose=$RIG_VALUE
    rig_table_add_row "$id" "$name" "$category" "$purpose"
  done
  rig_table_print
}

rig_show_catalogue() {
  local format format_seen id name category purpose separator
  local -a args

  format=text
  format_seen=0
  args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --format)
        [ "$format_seen" -eq 0 ] && [ "$#" -ge 2 ] || rig_command_syntax_error show || return
        case "$2" in text|json) format=$2 ;; *) rig_command_syntax_error show || return ;; esac
        format_seen=1
        shift 2 ;;
      *)
        args[${#args[@]}]=$1
        shift ;;
    esac
  done
  case "${args[0]-}" in
    -h|--help)
      [ "${#args[@]}" -eq 1 ] || rig_command_syntax_error show || return
      rig_command_help show
      return ;;
  esac
  rig_list_select "${args[@]+"${args[@]}"}" || return
  if [ "$format" = text ]; then
    rig_render_list_report
    return
  fi
  rig_json_envelope show
  printf ',"tools":['
  separator=
  for id in "${RIG_LIST_TOOLS[@]+"${RIG_LIST_TOOLS[@]}"}"; do
    rig_get_value "tool.$id" name || return 2; name=$RIG_VALUE
    rig_get_value "tool.$id" category || return 2; category=$RIG_VALUE
    rig_get_value "tool.$id" purpose || return 2; purpose=$RIG_VALUE
    rig_json_field "$separator{" id "$id"
    rig_json_field ',' name "$name"
    rig_json_field ',' category "$category"
    rig_json_field ',' purpose "$purpose"
    printf '}'
    separator=,
  done
  printf ']}\n'
}

rig_show_item() {
  local format format_seen report status line label value separator target
  local -a args

  format=text
  format_seen=0
  args=()
  while [ "$#" -gt 0 ]; do
    if [ "$1" = --format ]; then
      [ "$format_seen" -eq 0 ] && [ "$#" -ge 2 ] || rig_command_syntax_error show || return
      case "$2" in text|json) format=$2 ;; *) rig_command_syntax_error show || return ;; esac
      format_seen=1
      shift 2
    else
      args[${#args[@]}]=$1
      shift
    fi
  done
  case "${args[0]-}" in
    -h|--help)
      [ "${#args[@]}" -eq 1 ] || rig_command_syntax_error show || return
      rig_command_help show
      return ;;
  esac
  if [ "$format" = text ]; then
    rig_command_explain_impl "${args[@]+"${args[@]}"}"
    return
  fi
  if rig_capture_report_context rig_command_explain_impl "${args[@]+"${args[@]}"}"; then status=0; else status=$?; fi
  [ "$status" -eq 0 ] || return "$status"
  report=$RIG_CAPTURED_REPORT
  target=${args[0]-}
  rig_json_envelope show
  rig_json_field ',' target "$target"
  printf ',"fields":['
  separator=
  label=
  value=
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "${line#*:}" != "$line" ]; then
      if [ -n "$label" ]; then
        rig_json_field "$separator{" label "$label"
        rig_json_field ',' value "$value"
        printf '}'
        separator=,
      fi
      label=${line%%:*}
      value=${line#*:}
      value=${value# }
    elif [ -n "$label" ]; then
      value=$value$'\n'$line
    fi
  done <<< "$report"
  if [ -n "$label" ]; then
    rig_json_field "$separator{" label "$label"
    rig_json_field ',' value "$value"
    printf '}'
  fi
  printf ']'
  rig_json_field ',' report "$report"
  printf '}\n'
}
