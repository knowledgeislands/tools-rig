# rig-module: 24-app-clis
# shellcheck shell=bash
# Cross-module results deliberately use distinct globals rather than RIG_VALUE.
# shellcheck disable=SC2034

rig_toml_cli_field() {
  local key rest id field
  key=$1
  case "$key" in cli.*.*) ;; *) return 1 ;; esac
  rest=${key#cli.}
  id=${rest%%.*}
  field=${rest#*.}
  rig_valid_id "$id" || return 1
  case "$field" in source|destination|owner) ;; *) return 1 ;; esac
  RIG_TOML_FIELD_KEY=cli:$id:$field
  RIG_TOML_FIELD_TYPE=string
}

rig_collect_tool_clis() {
  local tool mode platform variant section_index index end key group
  tool=$1
  mode=${2:-selected}
  platform=${3:-${RIG_RESOLVED_PLATFORM:-}}
  RIG_CLI_GROUPS=()
  rig_section_index "tool.$tool" || return 2
  section_index=$RIG_INDEX
  variant=unresolved
  index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$index" -lt "$end" ]; do
    key=${RIG_FIELD_KEYS[$index]}
    group=
    case "$key" in
      cli:*:*) group=${key%:*} ;;
      variant:*:cli:*:*)
        if [ "$mode" != all ] && [ "$variant" = unresolved ]; then
          rig_select_compatible_variant "tool.$tool" "$platform" || return
          variant=$RIG_VALUE
        fi
        if [ "$mode" = all ] || { [ -n "$variant" ] && [[ "$key" == variant:"$variant":cli:*:* ]]; }; then
          group=${key%:*}
        fi
        ;;
    esac
    if [ -n "$group" ] && ! rig_array_contains "$group" "${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}"; then
      RIG_CLI_GROUPS[${#RIG_CLI_GROUPS[@]}]=$group
    fi
    index=$((index + 1))
  done
}

rig_cli_fields() {
  local section group
  section=$1
  group=$2
  RIG_CLI_ID=${group##*:}
  rig_require_field "$section" "$group:source" || return
  rig_normalize_artifact_identity "$RIG_VALUE"
  RIG_CLI_SOURCE=$RIG_VALUE
  rig_require_field "$section" "$group:destination" || return
  rig_normalize_artifact_identity "$RIG_VALUE"
  RIG_CLI_DESTINATION=$RIG_VALUE
  rig_require_field "$section" "$group:owner" || return
  RIG_CLI_OWNER=$RIG_VALUE
}

rig_cli_valid_path() {
  case "$1" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    /|*/|*//*|*/./*|*/../*|*/.|*/..|*$'\n'*|*$'\r'*|*$'\t'*) return 1 ;;
  esac
}

rig_validate_tool_clis() {
  local section tool group prefix provider kind adapter
  local -a groups
  section=$1
  tool=${section#tool.}
  rig_collect_tool_clis "$tool" all || return
  groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
  for group in "${groups[@]+"${groups[@]}"}"; do
    rig_cli_fields "$section" "$group" || return
    rig_cli_valid_path "$RIG_CLI_SOURCE" && rig_cli_valid_path "$RIG_CLI_DESTINATION" ||
      rig_fail "[$section] CLI '$RIG_CLI_ID' requires absolute source and destination paths without traversal" || return
    [ "$RIG_CLI_SOURCE" != "$RIG_CLI_DESTINATION" ] ||
      rig_fail "[$section] CLI '$RIG_CLI_ID' source and destination must differ" || return
    case "$RIG_CLI_OWNER" in provider|link) ;; *)
      rig_fail "[$section] CLI '$RIG_CLI_ID' owner must be 'provider' or 'link'" || return ;;
    esac
    prefix=${group%cli:*}
    if rig_get_value "$section" "${prefix}install-provider"; then
      provider=$RIG_VALUE
      rig_require_field "$section" "${prefix}install-kind" || return
    elif rig_get_value "$section" install-provider; then
      provider=$RIG_VALUE
      rig_require_field "$section" install-kind || return
    else
      rig_fail "[$section] CLI '$RIG_CLI_ID' requires an application installation" || return
    fi
    kind=$RIG_VALUE
    if [ "$RIG_CLI_OWNER" = provider ]; then
      rig_provider_adapter "$provider" || return 2
      adapter=$RIG_VALUE
      [ "$adapter:$kind" = homebrew:cask ] ||
        rig_fail "[$section] provider-owned CLI '$RIG_CLI_ID' requires a Homebrew cask installation" || return
    fi
  done
}

rig_validate_selected_cli_destinations() {
  local tool group destination previous index
  local -a groups destinations owners
  destinations=()
  owners=()
  for tool in "${RIG_PLAN_TOOLS[@]+"${RIG_PLAN_TOOLS[@]}"}"; do
    rig_collect_tool_clis "$tool" || return
    groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
    for group in "${groups[@]+"${groups[@]}"}"; do
      rig_cli_fields "tool.$tool" "$group" || return
      destination=$RIG_CLI_DESTINATION
      index=0
      for previous in "${destinations[@]+"${destinations[@]}"}"; do
        [ "$previous" != "$destination" ] ||
          rig_fail "CLI destination '$destination' is shared by '${owners[$index]}' and '$tool:$RIG_CLI_ID'" || return
        index=$((index + 1))
      done
      destinations[${#destinations[@]}]=$destination
      owners[${#owners[@]}]=$tool:$RIG_CLI_ID
    done
  done
}

rig_cli_safe_parent() {
  local path parent
  path=${1%/*}
  [ -n "$path" ] || path=/
  parent=$path
  while [ "$parent" != / ]; do
    [ ! -L "$parent" ] && [ -d "$parent" ] || return 1
    parent=${parent%/*}
    [ -n "$parent" ] || parent=/
  done
  [ -d / ] && [ -x "$path" ]
}

rig_cli_link_matches() {
  local destination source target parent
  destination=$1
  source=$2
  [ -L "$destination" ] || return 1
  target=$(readlink "$destination") || return 1
  case "$target" in /*) ;; *) target=${destination%/*}/$target ;; esac
  [ "$target" != "$source" ] || return 0
  # Equal physical files also admit relative native installer links.
  if [ -f "$source" ] && [ "$destination" -ef "$source" ]; then return 0; fi
  parent=${target%/*}
  if [ -d "$parent" ]; then
    parent=$(cd "$parent" 2>/dev/null && pwd -P) || return 1
    [ "$parent/${target##*/}" = "$source" ] && return 0
  fi
  return 1
}

rig_observe_cli() {
  RIG_CLI_STATE=present
  RIG_CLI_DETAIL=-
  if ! rig_cli_safe_parent "$RIG_CLI_DESTINATION"; then
    RIG_CLI_STATE=unavailable
    RIG_CLI_DETAIL=cli-unsafe-parent:$RIG_CLI_ID
  elif [ -L "$RIG_CLI_DESTINATION" ] && ! rig_cli_link_matches "$RIG_CLI_DESTINATION" "$RIG_CLI_SOURCE"; then
    RIG_CLI_STATE=drifted
    RIG_CLI_DETAIL=cli-target-mismatch:$RIG_CLI_ID
  elif [ -e "$RIG_CLI_DESTINATION" ] && [ ! -L "$RIG_CLI_DESTINATION" ]; then
    RIG_CLI_STATE=drifted
    RIG_CLI_DETAIL=cli-destination-conflict:$RIG_CLI_ID
  elif [ ! -f "$RIG_CLI_SOURCE" ] || [ ! -x "$RIG_CLI_SOURCE" ]; then
    RIG_CLI_STATE=missing
    RIG_CLI_DETAIL=cli-source-unavailable:$RIG_CLI_ID
  elif [ ! -L "$RIG_CLI_DESTINATION" ]; then
    RIG_CLI_STATE=missing
    RIG_CLI_DETAIL=cli-missing:$RIG_CLI_ID
  fi
}

rig_observe_tool_clis() {
  local tool group
  local -a groups
  tool=$1
  rig_collect_tool_clis "$tool" || return
  groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
  RIG_CLI_STATE=present
  RIG_CLI_DETAIL=-
  for group in "${groups[@]+"${groups[@]}"}"; do
    rig_cli_fields "tool.$tool" "$group" || return
    rig_observe_cli
    [ "$RIG_CLI_STATE" = present ] || return 0
  done
}

rig_preflight_tool_clis() {
  local tool group parent
  local -a groups
  tool=$1
  rig_collect_tool_clis "$tool" || return
  groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
  for group in "${groups[@]+"${groups[@]}"}"; do
    rig_cli_fields "tool.$tool" "$group" || return
    rig_observe_cli
    case "$RIG_CLI_STATE" in
      drifted|unavailable)
        rig_fail "tool '$tool' refuses CLI '$RIG_CLI_ID': $RIG_CLI_DETAIL" || return ;;
    esac
    parent=${RIG_CLI_DESTINATION%/*}
    [ -n "$parent" ] || parent=/
    [ -w "$parent" ] || rig_fail "tool '$tool' CLI '$RIG_CLI_ID' destination directory is not writable" || return
    if [ "$RIG_CLI_OWNER" = link ]; then
      rig_executable_available ln && rig_executable_available readlink ||
        rig_fail "tool '$tool' CLI '$RIG_CLI_ID' link executables are unavailable" || return
    fi
  done
}

rig_apply_tool_clis() {
  local tool binding provider group repair executable nested created
  local -a groups
  tool=$1
  binding=$2
  provider=$3
  rig_preflight_tool_clis "$tool" "$binding" "$provider" || return
  rig_collect_tool_clis "$tool" || return
  groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
  repair=0
  for group in "${groups[@]+"${groups[@]}"}"; do
    rig_cli_fields "tool.$tool" "$group" || return
    rig_observe_cli
    if [ "$RIG_CLI_OWNER" = provider ] && [ "$RIG_CLI_STATE" != present ]; then repair=1; fi
  done
  if [ "$repair" -eq 1 ]; then
    # Reuse the installer's literal argument handling; never force an overwrite.
    rig_prepare_builtin_invocation repair "$binding" "$provider" || return
    executable=$RIG_EXECUTABLE
    "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2 || return
  fi
  for group in "${groups[@]+"${groups[@]}"}"; do
    created=0
    rig_cli_fields "tool.$tool" "$group" || return
    rig_observe_cli
    if [ "$RIG_CLI_OWNER" = link ] && [ "$RIG_CLI_STATE" = missing ]; then
      [ -f "$RIG_CLI_SOURCE" ] && [ -x "$RIG_CLI_SOURCE" ] ||
        rig_fail "tool '$tool' CLI '$RIG_CLI_ID' source is not executable after installation" || return
      rig_cli_safe_parent "$RIG_CLI_DESTINATION" || return 1
      if [ ! -e "$RIG_CLI_DESTINATION" ] && [ ! -L "$RIG_CLI_DESTINATION" ]; then
        # No -f; -n prevents following a competing leaf link into a directory.
        ln -s -n "$RIG_CLI_SOURCE" "$RIG_CLI_DESTINATION" || return
        created=1
        if [ ! -L "$RIG_CLI_DESTINATION" ]; then
          # Native ln treats a directory arriving during the call as a target
          # directory. Remove only the link this successful call just made.
          nested=$RIG_CLI_DESTINATION/${RIG_CLI_SOURCE##*/}
          if [ -d "$RIG_CLI_DESTINATION" ] && [ -L "$nested" ] &&
            [ "$(readlink "$nested")" = "$RIG_CLI_SOURCE" ]; then rm "$nested" || return; fi
          rig_fail "tool '$tool' CLI '$RIG_CLI_ID' destination changed during link creation" || return
        fi
      fi
      rig_observe_cli
    fi
    if [ "$created" -eq 1 ] && [ "$RIG_CLI_STATE" != present ] &&
      [ -L "$RIG_CLI_DESTINATION" ] && [ "$(readlink "$RIG_CLI_DESTINATION")" = "$RIG_CLI_SOURCE" ]; then
      rm "$RIG_CLI_DESTINATION" || return
    fi
    [ "$RIG_CLI_STATE" = present ] ||
      rig_fail "tool '$tool' CLI '$RIG_CLI_ID' remains unhealthy after installation: $RIG_CLI_DETAIL" || return
  done
}

rig_cli_plan_summary() {
  local tool group summary
  local -a groups
  tool=$1
  summary=
  rig_collect_tool_clis "$tool" || return
  groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
  for group in "${groups[@]+"${groups[@]}"}"; do
    rig_cli_fields "tool.$tool" "$group" || return
    [ -z "$summary" ] || summary=$summary,
    summary=${summary}cli:$RIG_CLI_ID:$RIG_CLI_OWNER
    case "$RIG_CLI_OWNER" in
      provider) summary=$summary\(reinstall-if-needed\) ;;
      link) summary=$summary\(create-if-missing\) ;;
    esac
  done
  RIG_VALUE=$summary
}

rig_show_tool_clis() {
  local tool platform group
  local -a groups
  tool=$1
  platform=$2
  rig_collect_tool_clis "$tool" selected "$platform" || return
  groups=("${RIG_CLI_GROUPS[@]+"${RIG_CLI_GROUPS[@]}"}")
  for group in "${groups[@]+"${groups[@]}"}"; do
    rig_cli_fields "tool.$tool" "$group" || return
    printf 'CLI: %s (owner=%s) %s -> %s\n' "$RIG_CLI_ID" "$RIG_CLI_OWNER" "$RIG_CLI_DESTINATION" "$RIG_CLI_SOURCE"
  done
}
