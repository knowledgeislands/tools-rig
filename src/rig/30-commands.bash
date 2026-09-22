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

  rig_progress_start running 1
  rig_progress_step "launchd $action"
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
  rig_progress_finish
  return "$native_status"
}

rig_command_run_action() {
  local provider action section_name platform mode verb adapter executable argument argument_policy native_status
  local resource_count target kind id resource_section resource_index locator index
  local -a caller_arguments remaining_arguments

  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help)
        printf '%s\n' 'Usage: rig run PROVIDER ACTION [-- ARGUMENT...]'
        return
        ;;
    esac
  fi

  [ "$#" -ge 2 ] ||
    syntax_error 'usage: rig run PROVIDER ACTION [-- ARGUMENT...]' || return
  provider=$1
  action=$2
  shift 2
  caller_arguments=()
  if [ "$#" -gt 0 ]; then
    [ "$1" = -- ] ||
      syntax_error 'usage: rig run PROVIDER ACTION [-- ARGUMENT...]' || return
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
  rig_progress_start running 1
  rig_progress_step "$provider $action"
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}"
  native_status=$?
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

rig_command_diag() {
  local platform root_file root_display fragment_count config_status schema default_profile exit_code
  local index key profiles tools skills resources ports variants variant rest
  local -a seen_variants

  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help) printf '%s\n' 'Usage: rig diag'; return ;;
    esac
  fi
  [ "$#" -eq 0 ] || syntax_error 'usage: rig diag' || return

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
    if rig_load_config 2>/dev/null; then
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
  return "$exit_code"
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

rig_print_tool_row() {
  local tool name category purpose

  tool=$1
  rig_get_value "tool.$tool" name || return
  name=$RIG_VALUE
  rig_get_value "tool.$tool" category || return
  category=$RIG_VALUE
  rig_get_value "tool.$tool" purpose || return
  purpose=$RIG_VALUE
  printf '  %s\t%s\t%s\t%s\n' "$tool" "$name" "$category" "$purpose"
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

rig_print_profile_tool_table() {
  local index tool name category purpose
  local display_tool display_name display_category display_purpose
  local id_width name_width category_width purpose_width
  local purpose_limit
  local id_rule name_rule category_rule purpose_rule

  id_width=4
  name_width=4
  category_width=8
  purpose_width=7

  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    tool=${RIG_SELECTED_TOOLS[$index]}
    rig_get_value "tool.$tool" name || return
    name=$RIG_VALUE
    rig_get_value "tool.$tool" category || return
    category=$RIG_VALUE
    rig_get_value "tool.$tool" purpose || return
    purpose=$RIG_VALUE

    [ "${#tool}" -le "$id_width" ] || id_width=${#tool}
    [ "${#name}" -le "$name_width" ] || name_width=${#name}
    [ "${#category}" -le "$category_width" ] || category_width=${#category}
    [ "${#purpose}" -le "$purpose_width" ] || purpose_width=${#purpose}
    index=$((index + 1))
  done

  [ "$id_width" -le 24 ] || id_width=24
  [ "$name_width" -le 24 ] || name_width=24
  [ "$category_width" -le 16 ] || category_width=16
  purpose_limit=$((120 - id_width - name_width - category_width - 6))
  [ "$purpose_width" -le "$purpose_limit" ] || purpose_width=$purpose_limit

  rig_repeat_character - "$id_width"
  id_rule=$RIG_VALUE
  rig_repeat_character - "$name_width"
  name_rule=$RIG_VALUE
  rig_repeat_character - "$category_width"
  category_rule=$RIG_VALUE
  rig_repeat_character - "$purpose_width"
  purpose_rule=$RIG_VALUE

  printf '%-*s  %-*s  %-*s  %s\n' \
    "$id_width" ID "$name_width" NAME "$category_width" CATEGORY PURPOSE
  printf '%s  %s  %s  %s\n' \
    "$id_rule" "$name_rule" "$category_rule" "$purpose_rule"

  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    tool=${RIG_SELECTED_TOOLS[$index]}
    rig_get_value "tool.$tool" name || return
    name=$RIG_VALUE
    rig_get_value "tool.$tool" category || return
    category=$RIG_VALUE
    rig_get_value "tool.$tool" purpose || return
    purpose=$RIG_VALUE

    rig_ellipsize "$tool" "$id_width"
    display_tool=$RIG_VALUE
    rig_ellipsize "$name" "$name_width"
    display_name=$RIG_VALUE
    rig_ellipsize "$category" "$category_width"
    display_category=$RIG_VALUE
    rig_ellipsize "$purpose" "$purpose_width"
    display_purpose=$RIG_VALUE

    printf '%-*s  %-*s  %-*s  %s\n' \
      "$id_width" "$display_tool" "$name_width" "$display_name" \
      "$category_width" "$display_category" "$display_purpose"
    index=$((index + 1))
  done
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
    case "$wanted" in
      service) printf 'ID\tNAME\tPROVIDER\tDESIRED\n' ;;
      scheduled-job) printf 'ID\tNAME\tPROVIDER\tDESIRED\tSCHEDULE\n' ;;
      setting) printf 'ID\tNAME\tPROVIDER\tVALUE\n' ;;
      dock) printf 'ID\tNAME\tPROVIDER\tITEMS\n' ;;
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
          printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$provider" "$RIG_VALUE"
          ;;
        scheduled-job)
          rig_get_value "$section_name" desired-state || return 2
          desired=$RIG_VALUE
          rig_resource_schedule_summary "$section_name" || return
          schedule=$RIG_VALUE
          printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$name" "$provider" "$desired" "$schedule"
          ;;
        setting)
          rig_get_value "$section_name" value || return 2
          printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$provider" "$RIG_VALUE"
          ;;
        dock)
          rig_collect_field_values "$section_name" item
          detail=${#RIG_QUERY_ITEMS[@]}
          printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$provider" "$detail"
          ;;
      esac
    done
  done
}

rig_print_profile_ports() {
  local port section_name name number scope mode owner

  printf '\nPorts: %s\n' "${#RIG_SELECTED_PORTS[@]}"
  [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ] || return 0
  printf 'ID\tNAME\tPORT\tSCOPE\tMODE\tOWNER\n'
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
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$port" "$name" "$number" "$scope" "$mode" "$owner"
  done
}

rig_print_profile_skills() {
  local skill name authority runtimes

  printf '\nSkills: %s\n' "${#RIG_SELECTED_SKILLS[@]}"
  [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ] || return 0
  printf 'ID\tNAME\tAUTHORITY\tRUNTIMES\n'
  for skill in "${RIG_SELECTED_SKILLS[@]}"; do
    rig_get_value "skill.$skill" name || return 2
    name=$RIG_VALUE
    rig_get_value "skill.$skill" authority || return 2
    authority=$RIG_VALUE
    rig_collect_field_values "skill.$skill" runtime
    rig_join_query_items
    runtimes=$RIG_VALUE
    printf '%s\t%s\t%s\t%s\n' "$skill" "$name" "$authority" "$runtimes"
  done
}

rig_command_show() {
  local profile platform

  profile=
  case "$#" in
    0) ;;
    1)
      case "$1" in
        -h|--help) printf '%s\n' 'Usage: rig show [--profile NAME]'; return ;;
        *) syntax_error 'usage: rig show [--profile NAME]' || return ;;
      esac
      ;;
    2)
      [ "$1" = --profile ] && [ -n "$2" ] ||
        syntax_error 'usage: rig show [--profile NAME]' || return
      profile=$2
      ;;
    *) syntax_error 'usage: rig show [--profile NAME]' || return ;;
  esac

  rig_load_config || return
  rig_current_platform || return
  platform=$RIG_VALUE
  rig_resolve_profile "$profile" "$platform" || return
  printf 'Profile:  %s\nPlatform: %s\nTools:    %s\n\n' \
    "$RIG_RESOLVED_PROFILE" "$platform" "${#RIG_SELECTED_TOOLS[@]}"
  rig_print_profile_tool_table
  rig_print_profile_skills || return
  if [ "${#RIG_SELECTED_RESOURCE_SECTIONS[@]}" -gt 0 ]; then
    rig_print_profile_resource_tables
  fi
  if [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ]; then
    rig_print_profile_ports
  fi
}

rig_command_list() {
  local category profile platform category_seen profile_seen tool index declared_category
  local -a tools

  category=
  profile=
  category_seen=0
  profile_seen=0
  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help) printf '%s\n' 'Usage: rig list [--category ID] [--profile NAME]'; return ;;
    esac
  fi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --category)
        [ "$category_seen" -eq 0 ] && [ "$#" -ge 2 ] && [ -n "$2" ] ||
          syntax_error 'usage: rig list [--category ID] [--profile NAME]' || return
        category=$2
        category_seen=1
        shift 2
        ;;
      --profile)
        [ "$profile_seen" -eq 0 ] && [ "$#" -ge 2 ] && [ -n "$2" ] ||
          syntax_error 'usage: rig list [--category ID] [--profile NAME]' || return
        profile=$2
        profile_seen=1
        shift 2
        ;;
      *) syntax_error 'usage: rig list [--category ID] [--profile NAME]' || return ;;
    esac
  done

  rig_load_config || return
  if [ -n "$category" ]; then
    rig_valid_id "$category" && rig_section_index "category.$category" ||
      rig_fail "unknown category '$category'" || return
  fi
  if [ -n "$profile" ]; then
    rig_current_platform || return
    platform=$RIG_VALUE
    rig_resolve_profile "$profile" "$platform" || return
    tools=()
    index=0
    while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
      tools[$index]=${RIG_SELECTED_TOOLS[$index]}
      index=$((index + 1))
    done
  else
    rig_collect_section_ids tool
    tools=()
    index=0
    while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
      tools[$index]=${RIG_QUERY_ITEMS[$index]}
      index=$((index + 1))
    done
  fi

  printf '%s\n' $'ID\tNAME\tCATEGORY\tPURPOSE'
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
    rig_print_tool_row "$tool" || return
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

rig_command_explain() {
  local tool name category category_name purpose rationale platforms requires related alternatives profiles platform binding
  local artifacts

  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help) printf '%s\n' 'Usage: rig explain TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID'; return ;;
    esac
  fi
  [ "$#" -eq 1 ] || syntax_error 'usage: rig explain TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID' || return
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
  rig_join_query_items
  requires=$RIG_VALUE
  rig_collect_field_values "tool.$tool" related
  rig_join_query_items
  related=$RIG_VALUE
  rig_collect_field_values "tool.$tool" alternative
  rig_join_query_items
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
