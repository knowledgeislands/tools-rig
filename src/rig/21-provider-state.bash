# rig-module: 21-provider-state
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

rig_resolve_operational_plan() {
  local profile receipt_mode platform index load_mode

  profile=$1
  receipt_mode=${2:-load}
  load_mode=${3:-load}
  if [ "$load_mode" != preloaded ]; then
    rig_load_config || return
  fi
  rig_progress_start resolution 2
  rig_progress_begin platform
  rig_current_platform || return
  platform=$RIG_VALUE
  rig_progress_result succeeded platform
  rig_progress_begin profile
  rig_resolve_profile "$profile" "$platform" || return
  rig_progress_result succeeded profile
  rig_progress_finish

  rig_progress_start planning 2
  rig_progress_begin bindings
  rig_resolve_bindings || return
  rig_progress_result succeeded bindings
  rig_progress_begin dependencies
  rig_build_plan || return
  rig_progress_result succeeded dependencies
  rig_progress_finish
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
  rig_progress_interrupted
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

rig_declared_resource_has_locator() {
  local provider kind locator platform index section_name current_provider current_locator

  provider=$1
  kind=$2
  locator=$3
  platform=$4
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = "$kind" ]; then
      section_name=${RIG_SECTION_NAMES[$index]}
      if rig_resource_supports_platform "$section_name" "$platform"; then
        rig_get_value "$section_name" provider || return 2
        current_provider=$RIG_VALUE
        rig_get_value "$section_name" locator || return 2
        current_locator=$RIG_VALUE
        [ "$provider" = "$current_provider" ] && [ "$locator" = "$current_locator" ] && return 0
      fi
    fi
    index=$((index + 1))
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
    # Retirement follows the catalogue, not the selected profile. A resource the
    # catalogue still declares for this platform lies outside this invocation's
    # selection rather than behind it: unloading it because a narrower profile
    # was applied would tear down services the run never examined.
    if rig_declared_resource_has_locator "$provider" "$kind" "$locator" "$platform"; then
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
  local kind id provider locator old_umask extra status written

  platform=$1
  rig_resource_receipt_path "$platform" || return
  receipt=$RIG_VALUE
  directory=${receipt%/*}
  old_umask=$(umask)
  umask 077
  mkdir -p "$directory" || { umask "$old_umask"; return 1; }
  temporary=$(mktemp "$directory/.resources.XXXXXX") || { umask "$old_umask"; return 1; }
  written=()
  # A targeted apply must record only resources it actually reconciled; the
  # selected profile can contain other resources that this invocation skipped.
  for section_name in "${RIG_RESOURCE_PLAN_SECTIONS[@]+"${RIG_RESOURCE_PLAN_SECTIONS[@]}"}"; do
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
    written[${#written[@]}]=$provider.$kind.$locator
  done
  # A narrow selection reconciles part of the catalogue, so the receipt carries
  # forward every record this platform still declares. Keeping only the selected
  # records would forget which resources this rig materialised, leaving a later
  # apply unable to observe or retire them.
  if [ -f "$receipt" ] && [ -r "$receipt" ]; then
    while IFS=$'\t' read -r provider kind id locator extra ||
      [ -n "$provider$kind$id$locator$extra" ]; do
      [ -n "$provider" ] || continue
      rig_array_contains "$provider.$kind.$locator" \
        "${written[@]+"${written[@]}"}" && continue
      status=0
      rig_declared_resource_has_locator "$provider" "$kind" "$locator" "$platform" ||
        status=$?
      [ "$status" -ne 1 ] || continue
      [ "$status" -eq 0 ] || { rm -f "$temporary"; umask "$old_umask"; return 2; }
      printf '%s\t%s\t%s\t%s\n' "$provider" "$kind" "$id" "$locator" >>"$temporary" ||
        { rm -f "$temporary"; umask "$old_umask"; return 1; }
      written[${#written[@]}]=$provider.$kind.$locator
    done <"$receipt"
  fi
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

rig_artifact_home_form() {
  local path

  path=$1
  if [ -n "${HOME:-}" ] && [ "$path" != "${path#"$HOME"/}" ]; then
    # shellcheck disable=SC2088 # the literal tilde is the reported display form
    RIG_VALUE='~/'${path#"$HOME"/}
  else
    RIG_VALUE=$path
  fi
}

rig_resolve_artifact_link() {
  local path hops target parent

  path=$1
  hops=0
  while [ -L "$path" ]; do
    if [ "$hops" -ge 40 ]; then
      RIG_VALUE=$path
      return 1
    fi
    target=$(readlink "$path" 2>/dev/null) || target=
    [ -n "$target" ] || { RIG_VALUE=$path; return 1; }
    case "$target" in
      /*) path=$target ;;
      *)
        parent=${path%/*}
        [ "$parent" != "$path" ] || parent=.
        path=$parent/$target
        ;;
    esac
    hops=$((hops + 1))
  done
  RIG_VALUE=$path
  return 0
}

rig_observe_tool_artifacts() {
  local tool section_name section_index field_index field_end declared artifact variant artifact_key
  local state detail rank candidate_state candidate_detail candidate_rank info_plist
  local macos_dir app_exec app_exec_found resolved evidence

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
      resolved=$artifact
      if [ -L "$artifact" ]; then
        if rig_resolve_artifact_link "$artifact"; then
          resolved=$RIG_VALUE
        else
          candidate_state=unavailable
          candidate_detail=unresolved-link
          candidate_rank=3
        fi
      fi
      if [ -n "$candidate_state" ]; then
        :
      elif [ ! -e "$resolved" ]; then
        candidate_state=missing
        candidate_detail=missing
        candidate_rank=1
      elif [ ! -f "$resolved" ] && [ ! -d "$resolved" ]; then
        candidate_state=unavailable
        candidate_detail=unsafe
        candidate_rank=3
      elif [ -d "$resolved" ]; then
        case "$resolved" in
        *.app|*.app/)
          info_plist=${resolved%/}/Contents/Info.plist
          if [ ! -f "$info_plist" ] || [ ! -r "$info_plist" ]; then
            candidate_state=drifted
            candidate_detail=damaged-app
            candidate_rank=2
          else
            macos_dir=${resolved%/}/Contents/MacOS
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
        evidence=$declared
        if [ "$resolved" != "$artifact" ]; then
          rig_artifact_home_form "$resolved"
          evidence="$declared->$RIG_VALUE"
        fi
        rig_artifact_detail "$candidate_detail" "$evidence"
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
    # The built-in scanner emits canonical app paths. Merge only an exact
    # path already observed by a provider, never names in separate namespaces.
    if [ "$provider" = macos-applications ] &&
      rig_array_contains "$identity" "${RIG_UNMANAGED_IDENTITIES[@]+"${RIG_UNMANAGED_IDENTITIES[@]}"}"; then
      continue
    fi
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
  if [ "$RIG_RESOLVED_PLATFORM" = macos ]; then
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
    rig_progress_begin "$provider"
    rig_inventory_provider "$provider" || return
    if [ "$RIG_INVENTORY_STATE" != observed ]; then
      RIG_UNMANAGED_PROBLEMS[${#RIG_UNMANAGED_PROBLEMS[@]}]="$provider	$RIG_INVENTORY_STATE	$RIG_INVENTORY_DETAIL"
      rig_progress_result failed "$provider"
    else
      rig_progress_result succeeded "$provider"
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
