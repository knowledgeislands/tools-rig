# rig-module: 27-software-removal
# shellcheck shell=bash
# Cross-module results are consumed by doctor and the mutation renderer.
# shellcheck disable=SC2034

rig_removal_supported() {
  case "$1:$2" in homebrew:formula|homebrew:cask|mas:app|uv:tool|npm:global|mise:tool) return 0 ;; esac
  return 1
}

# uv installs requirements but uninstalls distribution names. Accept only named
# requirements whose identity is explicit; paths, URLs and other ambiguous
# sources must block removal rather than guess which retained tool they own.
rig_removal_uv_identity() {
  local identity suffix extras name_pattern version_pattern index
  local uppercase=ABCDEFGHIJKLMNOPQRSTUVWXYZ lowercase=abcdefghijklmnopqrstuvwxyz LC_ALL=C
  name_pattern='[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?'
  version_pattern='(===|==|!=|~=|<=|>=|<|>)[[:blank:]]*[A-Za-z0-9.*+!_-]+'
  rig_trim "$1"
  if ! [[ "$RIG_VALUE" =~ ^($name_pattern)(.*)$ ]]; then
    rig_fail 'uv removal cannot safely establish a distribution identity'; return
  fi
  identity=${BASH_REMATCH[1]}
  suffix=${BASH_REMATCH[3]}
  rig_trim "$suffix"
  suffix=$RIG_VALUE
  if [[ "$suffix" = \[* ]]; then
    extras="^\[[[:blank:]]*$name_pattern([[:blank:]]*,[[:blank:]]*$name_pattern)*[[:blank:]]*\]"
    if ! [[ "$suffix" =~ $extras ]]; then
      rig_fail 'uv removal cannot safely establish a distribution identity'; return
    fi
    suffix=${suffix#*\]}
    rig_trim "$suffix"
    suffix=$RIG_VALUE
  fi
  if [[ "$suffix" = \(*\) ]]; then
    suffix=${suffix#\(}; suffix=${suffix%\)}
    rig_trim "$suffix"
    suffix=$RIG_VALUE
    [ -n "$suffix" ] || { rig_fail 'uv removal cannot safely establish a distribution identity'; return; }
  fi
  if [ -n "$suffix" ] && ! [[ "$suffix" =~ ^$version_pattern([[:blank:]]*,[[:blank:]]*$version_pattern)*[[:blank:]]*$ ]]; then
    rig_fail 'uv removal cannot safely establish a distribution identity'; return
  fi
  # Python distribution identity is case-insensitive and treats each run of
  # hyphens, underscores and full stops as one hyphen. Stay Bash 3.2 compatible.
  index=0
  while [ "$index" -lt 26 ]; do
    identity=${identity//"${uppercase:$index:1}"/"${lowercase:$index:1}"}
    index=$((index + 1))
  done
  # A bare archive filename can also look like a valid distribution name.
  # Its filename is not evidence of the distribution installed from it.
  case "$identity" in
    *.whl|*.zip|*.tar|*.tar.gz|*.tar.bz2|*.tar.xz|*.tgz)
      rig_fail 'uv removal cannot safely establish a distribution identity'; return ;;
  esac
  identity=${identity//_/-}
  identity=${identity//./-}
  while [[ "$identity" = *--* ]]; do identity=${identity//--/-}; done
  RIG_VALUE=$identity
}

# Compare the native package identity, not a version selector that an uninstall
# may ignore. Conservatively protect every retained version of the same tool.
rig_removal_normalize_identity() {
  local adapter kind locator
  adapter=$1; kind=$2; locator=$3
  case "$adapter:$kind" in
    uv:tool) rig_removal_uv_identity "$locator" || return ;;
    homebrew:formula|homebrew:cask)
      rig_homebrew_normalize_identity "$kind:$locator"
      RIG_VALUE=${RIG_VALUE#*:}
      ;;
    npm:global)
      case "$locator" in
        @*/*@*|[!@]*@*) RIG_VALUE=${locator%@*} ;;
        *) RIG_VALUE=$locator ;;
      esac
      ;;
    mise:tool) RIG_VALUE=${locator%%@*} ;;
    *) rig_normalize_provider_identity "$adapter" "$kind" "$locator" ;;
  esac
}

rig_validate_removal() {
  local section index provider adapter kind locator other other_kind other_provider other_adapter other_locator scan
  section=$1
  index=$2
  rig_require_field "$section" name || return
  rig_require_field "$section" provider || return
  provider=$RIG_VALUE
  rig_provider_adapter "$provider" || rig_fail "[$section] unknown removal provider '$provider'" || return
  adapter=$RIG_VALUE
  if rig_field_declared "provider.$provider" argument; then
    rig_fail "[$section] native removal does not permit provider arguments"; return
  fi
  rig_require_field "$section" kind || return
  kind=$RIG_VALUE
  rig_removal_supported "$adapter" "$kind" || rig_fail "[$section] unsupported native removal '$adapter:$kind'" || return
  rig_require_field "$section" locator || return
  locator=$RIG_VALUE
  if [ "$adapter:$kind" = mas:app ]; then
    case "$locator" in ''|*[!0-9]*) rig_fail "[$section] App Store removal requires a numeric app ID"; return ;; esac
  fi
  case "$locator" in -*) rig_fail "[$section] removal locator must not be an option"; return ;; esac
  case "$locator" in *[[:cntrl:]]*) rig_fail "[$section] removal locator must not contain control characters"; return ;; esac
  rig_removal_normalize_identity "$adapter" "$kind" "$locator" || return
  locator=$RIG_VALUE
  rig_field_count "$index" platform
  [ "$RIG_COUNT" -gt 0 ] || rig_fail "[$section] requires platforms" || return
  if [ "$adapter:$kind" = homebrew:cask ] || [ "$adapter:$kind" = mas:app ]; then
    scan=1
    while rig_get_value "$section" platform "$scan"; do
      [ "$RIG_VALUE" = macos ] || rig_fail "[$section] cask and App Store removals support only macOS" || return
      scan=$((scan + 1))
    done
  fi
  rig_validate_references_for_field "$index" member-profile profile || return
  scan=0
  while [ "$scan" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    other=${RIG_SECTION_NAMES[$scan]}
    if [ "${RIG_SECTION_TYPES[$scan]}" = binding ]; then
      other_provider=${RIG_SECTION_SECONDARY_IDS[$scan]}
      rig_provider_adapter "$other_provider" || return 2
      other_adapter=$RIG_VALUE
      if [ "$adapter" = "$other_adapter" ]; then
        rig_get_value "$other" kind || return 2
        other_kind=$RIG_VALUE
        rig_get_value "$other" locator || return 2
        other_locator=$RIG_VALUE
        if [ "$kind" = "$other_kind" ]; then
          rig_removal_normalize_identity "$adapter" "$kind" "$locator" || return
          locator=$RIG_VALUE
          rig_removal_normalize_identity "$adapter" "$kind" "$other_locator" || return
          [ "$locator" != "$RIG_VALUE" ] || rig_fail "[$section] cannot remove an installation still declared by $other" || return
        fi
      fi
    elif [ "${RIG_SECTION_TYPES[$scan]}" = remove ] && [ "$scan" -lt "$index" ]; then
      rig_get_value "$other" provider || return 2
      other_provider=$RIG_VALUE
      rig_provider_adapter "$other_provider" || return 2
      other_adapter=$RIG_VALUE
      if [ "$other_adapter" = "$adapter" ] && rig_get_value "$other" kind && [ "$RIG_VALUE" = "$kind" ] &&
        rig_get_value "$other" locator; then
        other_locator=$RIG_VALUE
        rig_removal_normalize_identity "$adapter" "$kind" "$locator" || return
        locator=$RIG_VALUE
        rig_removal_normalize_identity "$adapter" "$kind" "$other_locator" || return
        [ "$locator" != "$RIG_VALUE" ] || rig_fail "[$section] duplicates removal $other" || return
      fi
    fi
    scan=$((scan + 1))
  done
}

rig_collect_removals() {
  local index section
  RIG_REMOVALS=()
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = remove ]; then
      section=${RIG_SECTION_NAMES[$index]}
      if rig_operation_supports_platform "$section" "$RIG_RESOLVED_PLATFORM" &&
        rig_item_selected_by_active_profiles "$section"; then
        RIG_REMOVALS[${#RIG_REMOVALS[@]}]=$section
      fi
    fi
    index=$((index + 1))
  done
}

rig_removal_identity_declared() {
  local provider identity index section kind locator adapter
  provider=$1
  identity=$2
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = remove ]; then
      section=${RIG_SECTION_NAMES[$index]}
      if rig_get_value "$section" provider && [ "$RIG_VALUE" = "$provider" ]; then
        rig_get_value "$section" kind || return 2
        kind=$RIG_VALUE
        rig_get_value "$section" locator || return 2
        locator=$RIG_VALUE
        rig_provider_adapter "$provider" || return 2
        adapter=$RIG_VALUE
        rig_removal_normalize_identity "$adapter" "$kind" "$locator" || return 2
        locator=$RIG_VALUE
        if [ "$adapter" = homebrew ]; then locator=$kind:$locator; fi
        [ "$locator" != "$identity" ] || return 0
      fi
    fi
    index=$((index + 1))
  done
  return 1
}

rig_observe_removals() {
  local section provider index detail
  rig_collect_removals
  RIG_REMOVAL_STATES=()
  RIG_REMOVAL_DETAILS=()
  RIG_REMOVAL_FINDINGS=
  RIG_REMOVAL_FINDING_COUNT=0
  index=0
  for section in "${RIG_REMOVALS[@]+"${RIG_REMOVALS[@]}"}"; do
    rig_get_value "$section" provider || return 2
    provider=$RIG_VALUE
    rig_observe_provider "${section#remove.}" "$section" "$provider" || return
    RIG_REMOVAL_STATES[index]=$RIG_OBSERVATION
    RIG_REMOVAL_DETAILS[index]=$RIG_OBSERVATION_DETAIL
    if [ "$RIG_OBSERVATION" != missing ]; then
      detail=$RIG_OBSERVATION
      [ "$detail" != present ] || detail=removal-pending
      RIG_REMOVAL_FINDINGS="${RIG_REMOVAL_FINDINGS}  ${section}: ${detail} (${RIG_OBSERVATION_DETAIL}); owner=${provider}; action=preview-rig-remove"$'\n'
      RIG_REMOVAL_FINDING_COUNT=$((RIG_REMOVAL_FINDING_COUNT + 1))
    fi
    index=$((index + 1))
  done
  RIG_REMOVAL_FINDINGS=${RIG_REMOVAL_FINDINGS%$'\n'}
}

rig_remove_native() {
  local section provider adapter kind locator executable
  section=$1
  rig_get_value "$section" provider || return 2
  provider=$RIG_VALUE
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_get_value "$section" kind || return 2
  kind=$RIG_VALUE
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_provider_executable "$provider" "$adapter" "$kind" || return 2
  executable=$RIG_VALUE
  RIG_INVOKE_ARGUMENTS=()
  rig_append_arguments "provider.$provider" || return 2
  case "$adapter:$kind" in
    homebrew:formula|homebrew:cask) RIG_INVOKE_ARGUMENTS+=(uninstall "--$kind" "$locator") ;;
    mas:app)
      # mas documents a root requirement. Never acquire or prompt for a grant:
      # a person must already have authorised sudo in this terminal.
      "${RIG_SUDO:-sudo}" -n -- "$executable" uninstall "$locator" </dev/null 1>&2
      return
      ;;
    uv:tool)
      rig_removal_normalize_identity "$adapter" "$kind" "$locator" || return 2
      RIG_INVOKE_ARGUMENTS+=(tool uninstall "$RIG_VALUE") ;;
    npm:global) RIG_INVOKE_ARGUMENTS+=(uninstall --global "$locator") ;;
    mise:tool) RIG_INVOKE_ARGUMENTS+=(uninstall "$locator") ;;
    *) return 2 ;;
  esac
  "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" </dev/null 1>&2
}

rig_command_remove_impl() {
  local profile mode target operation_acquired status
  profile=
  mode=preview
  target=
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h) [ "$#" -eq 1 ] || rig_command_syntax_error remove || return; rig_command_help remove; return ;;
      --profile) [ -z "$profile" ] && [ "$#" -ge 2 ] && [ -n "$2" ] || rig_command_syntax_error remove || return; profile=$2; shift 2 ;;
      --target) [ -z "$target" ] && [ "$#" -ge 2 ] && [ -n "$2" ] || rig_command_syntax_error remove || return; target=$2; shift 2 ;;
      --dry-run) [ "$mode" = preview ] || rig_command_syntax_error remove || return; mode=dry-run; shift ;;
      --apply) [ "$mode" = preview ] || rig_command_syntax_error remove || return; mode=apply; shift ;;
      *) rig_command_syntax_error remove; return ;;
    esac
  done
  rig_resolve_operational_plan "$profile" defer || return
  [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] || rig_fail 'removal requires a complete profile' || return
  # A confirmed removal runs native uninstallers, so it holds the operation lock
  # from before its first observation; preview and dry run take none.
  operation_acquired=0
  if [ "$mode" = apply ]; then
    rig_acquire_operation_lock \
      "$RIG_RESOLVED_PLATFORM" "$RIG_RESOLVED_PROFILE" remove || return
    operation_acquired=$RIG_OPERATION_LOCK_ACQUIRED
  fi
  if rig_remove_selected "$mode" "$target"; then
    status=0
  else
    status=$?
  fi
  if [ "$operation_acquired" -eq 1 ]; then
    rig_release_operation_lock || return
  fi
  return "$status"
}

rig_remove_selected() {
  local mode target section index provider state detail answer pending failed completed native_status
  mode=$1
  target=$2
  rig_collect_removals
  if [ -n "$target" ]; then
    case "$target" in remove.*) ;; *) target=remove.$target ;; esac
    rig_array_contains "$target" "${RIG_REMOVALS[@]+"${RIG_REMOVALS[@]}"}" ||
      rig_fail "target '$target' is not declared for removal in the selected profile/platform" || return
  fi
  rig_observe_removals || return
  pending=0
  failed=0
  index=0
  printf 'Profile: %s\nPlatform: %s\nTARGET\tPROVIDER\tRESULT\tDETAIL\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  for section in "${RIG_REMOVALS[@]+"${RIG_REMOVALS[@]}"}"; do
    if [ -n "$target" ] && [ "$target" != "$section" ]; then index=$((index + 1)); continue; fi
    rig_get_value "$section" provider || return 2
    provider=$RIG_VALUE
    state=${RIG_REMOVAL_STATES[index]}
    detail=${RIG_REMOVAL_DETAILS[index]}
    case "$state" in
      present) state=planned; pending=$((pending + 1)); rig_get_value "$section" locator || return 2; detail=$RIG_VALUE ;;
      missing) state=skipped; detail=already-absent ;;
      *) failed=$((failed + 1)) ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$section" "$provider" "$state" "$detail"
    index=$((index + 1))
  done
  if [ "$failed" -gt 0 ]; then
    rig_outcome_note incomplete 'removal observation unavailable; nothing removed'
    return 1
  fi
  if [ "$mode" != apply ] || [ "$pending" -eq 0 ]; then
    printf 'Summary: planned=%s completed=0 failed=0\n' "$pending"
    rig_outcome_note succeeded "previewed=$pending"
    return 0
  fi
  # The report is buffered, so repeat the exact selected preview on stderr BEFORE
  # asking. EOF/refusal changes nothing; no unattended confirmation bypass exists.
  printf 'Removal preview (native uninstall only; retained data is not targeted):\n' >&2
  index=0
  for section in "${RIG_REMOVALS[@]+"${RIG_REMOVALS[@]}"}"; do
    if { [ -z "$target" ] || [ "$target" = "$section" ]; } && [ "${RIG_REMOVAL_STATES[index]}" = present ]; then
      rig_get_value "$section" locator || return 2
      printf '  %s: %s\n' "$section" "$RIG_VALUE" >&2
      if rig_get_value "$section" provider && rig_provider_adapter "$RIG_VALUE" && [ "$RIG_VALUE" = mas ]; then
        printf '    App Store removal requires an existing administrator grant; sudo will not prompt.\n' >&2
      fi
    fi
    index=$((index + 1))
  done
  printf 'Type remove to execute this preview: ' >&2
  answer=
  if ! IFS= read -r answer || [ "$answer" != remove ]; then
    printf '\nRemoval refused; nothing removed.\n' >&2
    rig_outcome_note incomplete 'removal refused'
    return 1
  fi
  completed=0
  index=0
  for section in "${RIG_REMOVALS[@]+"${RIG_REMOVALS[@]}"}"; do
    if { [ -z "$target" ] || [ "$target" = "$section" ]; } && [ "${RIG_REMOVAL_STATES[index]}" = present ]; then
      rig_get_value "$section" provider || return 2
      provider=$RIG_VALUE
      # Recheck presence after confirmation; never turn unknown evidence into deletion.
      RIG_OBSERVATION_CACHE_KEYS=()
      RIG_OBSERVATION_CACHE_OUTPUTS=()
      RIG_OBSERVATION_CACHE_STATUSES=()
      rig_observe_provider "${section#remove.}" "$section" "$provider" || return
      if [ "$RIG_OBSERVATION" = missing ]; then
        printf '%s\t%s\tskipped\talready-absent\n' "$section" "$provider"
      elif [ "$RIG_OBSERVATION" != present ]; then
        printf '%s\t%s\tfailed\tobservation-changed\n' "$section" "$provider"
        failed=$((failed + 1))
      else
        rig_remove_native "$section"
        native_status=$?
        if [ "$native_status" -eq 0 ]; then
          printf '%s\t%s\tcompleted\tnative-uninstall\n' "$section" "$provider"
          completed=$((completed + 1))
        else
          printf '%s\t%s\tfailed\texit:%s\n' "$section" "$provider" "$native_status"
          failed=$((failed + 1))
        fi
      fi
    fi
    index=$((index + 1))
  done
  printf 'Summary: planned=%s completed=%s failed=%s\n' "$pending" "$completed" "$failed"
  if [ "$failed" -gt 0 ]; then rig_outcome_note incomplete "completed=$completed failed=$failed"; return 1; fi
  rig_outcome_note succeeded "completed=$completed"
}
