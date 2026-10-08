# rig-module: 40-publication-lifecycle
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

rig_publication_base_url() {
  local base_url authority host port remainder

  base_url=$1
  case "$base_url" in
    http://*|https://*) ;;
    *) rig_fail "publication base-url must be an absolute HTTP or HTTPS URL" || return ;;
  esac
  case "$base_url" in
    *\?*|*\#*)
      rig_fail "publication base-url must not contain a query or fragment" || return
      ;;
  esac
  case "$base_url" in
    *[[:space:]\<\>\"\']*)
      rig_fail "publication base-url contains an unsafe character" || return
      ;;
  esac
  authority=${base_url#*://}
  authority=${authority%%/*}
  [ -n "$authority" ] || rig_fail "publication base-url must name a host" || return
  case "$authority" in
    *@*) rig_fail "publication base-url must not contain user information" || return ;;
    \[*\]*)
      host=${authority#\[}
      remainder=${host#*\]}
      host=${host%%\]*}
      [ -n "$host" ] || rig_fail "publication base-url must name a host" || return
      case "$host" in
        *[!0-9A-Fa-f:.]*) rig_fail "publication base-url has invalid IPv6 host" || return ;;
      esac
      case "$remainder" in
        '') ;;
        :*)
          port=${remainder#:}
          case "$port" in
            ''|*[!0-9]*) rig_fail "publication base-url has invalid port" || return ;;
          esac
          ;;
        *) rig_fail "publication base-url has invalid authority" || return ;;
      esac
      ;;
    *:*)
      host=${authority%%:*}
      port=${authority#*:}
      case "$port" in
        ''|*[!0-9]*|*:* ) rig_fail "publication base-url has invalid port" || return ;;
      esac
      ;;
    *) host=$authority ;;
  esac
  case "$host" in
    ''|.*|*.|*..*|-*|*-|*[!A-Za-z0-9._~-]*)
      rig_fail "publication base-url has invalid host" || return
      ;;
  esac
  case "$base_url" in
    */) ;;
    *) base_url=$base_url/ ;;
  esac
  RIG_VALUE=$base_url
}

rig_render_json_values() {
  local section_name field selected_only index value printed

  section_name=$1
  field=$2
  selected_only=$3
  rig_collect_field_values "$section_name" "$field" || return
  printf '['
  index=0
  printed=0
  while [ "$index" -lt "${#RIG_QUERY_ITEMS[@]}" ]; do
    value=${RIG_QUERY_ITEMS[$index]}
    if [ "$selected_only" = no ] ||
      rig_array_contains "$value" "${RIG_SELECTED_TOOLS[@]}"; then
      [ "$printed" -eq 0 ] || printf ', '
      rig_json_escape "$value"
      printf '"%s"' "$RIG_VALUE"
      printed=$((printed + 1))
    fi
    index=$((index + 1))
  done
  printf ']'
}

rig_render_public_category() {
  local category name purpose

  category=$1
  rig_get_value "category.$category" name || return
  name=$RIG_VALUE
  rig_get_value "category.$category" purpose || return
  purpose=$RIG_VALUE
  rig_json_escape "$category"
  printf '        {"id": "%s", ' "$RIG_VALUE"
  rig_json_escape "$name"
  printf '"name": "%s", ' "$RIG_VALUE"
  rig_json_escape "$purpose"
  printf '"purpose": "%s"}' "$RIG_VALUE"
}

rig_render_public_tool() {
  local tool name category purpose rationale

  tool=$1
  rig_get_value "tool.$tool" name || return
  name=$RIG_VALUE
  rig_get_value "tool.$tool" category || return
  category=$RIG_VALUE
  rig_get_value "tool.$tool" purpose || return
  purpose=$RIG_VALUE
  rig_get_value "tool.$tool" rationale || return
  rationale=$RIG_VALUE

  rig_json_escape "$tool"
  printf '        {\n          "id": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$name"
  printf '          "name": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$category"
  printf '          "category": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$purpose"
  printf '          "purpose": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$rationale"
  printf '          "rationale": "%s",\n' "$RIG_VALUE"
  printf '          "platforms": '
  rig_render_json_values "tool.$tool" platform no || return
  printf ',\n          "relationships": {\n'
  printf '            "requires": '
  rig_render_json_values "tool.$tool" requires yes || return
  printf ',\n            "related": '
  rig_render_json_values "tool.$tool" related yes || return
  printf ',\n            "alternatives": '
  rig_render_json_values "tool.$tool" alternative yes || return
  printf '\n          }\n        }'
}

rig_render_public_skill() {
  local skill name purpose rationale public_source

  skill=$1
  rig_get_value "skill.$skill" name || return
  name=$RIG_VALUE
  rig_get_value "skill.$skill" purpose || return
  purpose=$RIG_VALUE
  rig_get_value "skill.$skill" rationale || return
  rationale=$RIG_VALUE
  public_source=
  if rig_get_value "skill.$skill" public-source; then public_source=$RIG_VALUE; fi
  rig_json_escape "$skill"; printf '        {"id": "%s", ' "$RIG_VALUE"
  rig_json_escape "$name"; printf '"name": "%s", ' "$RIG_VALUE"
  rig_json_escape "$purpose"; printf '"purpose": "%s", ' "$RIG_VALUE"
  rig_json_escape "$rationale"; printf '"rationale": "%s"' "$RIG_VALUE"
  if [ -n "$public_source" ]; then
    rig_json_escape "$public_source"; printf ', "source": "%s"' "$RIG_VALUE"
  fi
  printf '}'
}

rig_render_publication_json() {
  local title profile base_url tool category index
  local -a categories

  title=$1
  profile=$2
  base_url=$3

  categories=()
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    tool=${RIG_SELECTED_TOOLS[$index]}
    rig_get_value "tool.$tool" category || return
    category=$RIG_VALUE
    if [ "${#categories[@]}" -eq 0 ] ||
      ! rig_array_contains "$category" "${categories[@]}"; then
      categories[${#categories[@]}]=$category
    fi
    index=$((index + 1))
  done
  RIG_QUERY_ITEMS=("${categories[@]+"${categories[@]}"}")
  rig_sort_query_items
  categories=("${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}")

  printf '{\n  "format": "rig-publication",\n  "version": 1,\n  "publication": {\n'
  rig_json_escape "$profile"
  printf '    "id": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$title"
  printf '    "title": "%s",\n' "$RIG_VALUE"
  if [ -n "$base_url" ]; then
    rig_json_escape "$base_url"
    printf '    "canonical_url": "%s"\n  },\n  "profile": {\n' "$RIG_VALUE"
  else
    printf '    "canonical_url": null\n  },\n  "profile": {\n'
  fi
  rig_json_escape "$profile"
  printf '    "id": "%s",\n    "categories": [\n' "$RIG_VALUE"
  index=0
  while [ "$index" -lt "${#categories[@]}" ]; do
    [ "$index" -eq 0 ] || printf ',\n'
    rig_render_public_category "${categories[$index]}" || return
    index=$((index + 1))
  done
  printf '\n    ],\n    "tools": [\n'
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_TOOLS[@]}" ]; do
    [ "$index" -eq 0 ] || printf ',\n'
    rig_render_public_tool "${RIG_SELECTED_TOOLS[$index]}" || return
    index=$((index + 1))
  done
  printf '\n    ],\n    "skills": [\n'
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    [ "$index" -eq 0 ] || printf ',\n'
    rig_render_public_skill "${RIG_SELECTED_SKILLS[$index]}" || return
    index=$((index + 1))
  done
  printf '\n    ]\n  }\n}\n'
}

rig_export_cleanup() {
  if [ -n "${RIG_EXPORT_TEMP:-}" ] && [ "$RIG_EXPORT_TEMP" != / ]; then
    rm -rf -- "$RIG_EXPORT_TEMP"
  fi
}

rig_export_interrupted() {
  local exit_code

  exit_code=$1
  trap - HUP INT TERM
  rig_progress_interrupted
  rig_export_cleanup
  exit "$exit_code"
}

rig_replace_export_tree() {
  local target report parent basename temporary backup suffix

  target=$1
  report=${2:-yes}
  while [ "$target" != / ] && [ "${target%/}" != "$target" ]; do
    target=${target%/}
  done
  case "$target" in
    ''|/|.|..)
      rig_fail "unsafe export output directory: $1" || return
      ;;
  esac
  basename=${target##*/}
  case "$basename" in
    ''|.|..)
      rig_fail "unsafe export output directory: $1" || return
      ;;
  esac
  if [ "$target" = "$basename" ]; then
    parent=.
  else
    parent=${target%/*}
    [ -n "$parent" ] || parent=/
  fi
  [ -d "$parent" ] || rig_fail "export output parent is not a directory: $parent" || return
  [ ! -L "$target" ] || rig_fail "export output must not be a symlink: $target" || return
  if [ -e "$target" ] && [ ! -d "$target" ]; then
    rig_fail "export output is not a directory: $target" || return
  fi

  suffix=$$
  temporary=$parent/.$basename.rig-export.$suffix
  while [ -e "$temporary" ] || [ -L "$temporary" ]; do
    suffix=$((suffix + 1))
    temporary=$parent/.$basename.rig-export.$suffix
  done
  mkdir -- "$temporary" || rig_fail "cannot create export staging directory: $temporary" || return
  RIG_EXPORT_TEMP=$temporary
  trap 'rig_progress_cleanup; rig_export_cleanup' EXIT
  trap 'rig_export_interrupted 129' HUP
  trap 'rig_export_interrupted 130' INT
  trap 'rig_export_interrupted 143' TERM
  rig_render_publication_json \
    "$RIG_EXPORT_TITLE" "$RIG_RESOLVED_PROFILE" "$RIG_PUBLICATION_BASE_URL" \
    >"$temporary/rig.json" || return

  [ ! -L "$target" ] || rig_fail "export output became a symlink: $target" || return
  if [ -e "$target" ]; then
    [ -d "$target" ] || rig_fail "export output is not a directory: $target" || return
    backup=$parent/.$basename.rig-previous.$suffix
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      suffix=$((suffix + 1))
      backup=$parent/.$basename.rig-previous.$suffix
    done
    mv -- "$target" "$backup" || rig_fail "cannot replace export output: $target" || return
    if ! mv -- "$temporary" "$target"; then
      mv -- "$backup" "$target" || true
      rig_fail "cannot install export output: $target" || return
    fi
    RIG_EXPORT_TEMP=
    rm -rf -- "$backup" || rig_fail "cannot remove replaced export tree: $backup" || return
  else
    mv -- "$temporary" "$target" || rig_fail "cannot install export output: $target" || return
    RIG_EXPORT_TEMP=
  fi
  trap rig_progress_cleanup EXIT
  trap 'rig_progress_signal 129' HUP
  trap 'rig_progress_signal 130' INT
  trap 'rig_progress_signal 143' TERM
  if [ "$report" = yes ]; then
    printf 'Exported profile %s to %s\n' "$RIG_RESOLVED_PROFILE" "$target"
  fi
}

rig_command_export() {
  local output profile platform title base_url native_status

  profile=
  output=
  title=
  base_url=
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        rig_command_help export
        return
        ;;
      --profile|--output|--title|--base-url)
        [ "$#" -ge 2 ] && [ -n "$2" ] ||
          syntax_error "$1 requires a value" || return
        case "$1" in
          --profile) profile=$2 ;;
          --output) output=$2 ;;
          --title) title=$2 ;;
          --base-url) base_url=$2 ;;
        esac
        shift 2
        ;;
      *) syntax_error "unexpected $1" || return ;;
    esac
  done
  [ -n "$profile" ] && [ -n "$output" ] ||
    rig_command_syntax_error export ||
    return
  rig_load_config || return
  rig_valid_id "$profile" && rig_reference_exists profile "$profile" ||
    rig_fail "unknown profile '$profile'" || return
  rig_profile_kind "$profile" || return
  [ "$RIG_VALUE" = view ] ||
    rig_fail "profile '$profile' must be a non-appliable view to export" || return
  if [ -n "$base_url" ]; then
    rig_publication_base_url "$base_url" || return
    RIG_PUBLICATION_BASE_URL=$RIG_VALUE
  else
    RIG_PUBLICATION_BASE_URL=
  fi
  if [ -z "$title" ]; then
    if rig_get_value "profile.$profile" name; then
      title=$RIG_VALUE
    else
      title=$profile
    fi
  fi
  rig_current_platform || return
  platform=$RIG_VALUE
  rig_resolve_publication_profile "$profile" "$platform" || return
  RIG_EXPORT_TITLE=$title
  (
    umask 022
    trap rig_progress_cleanup EXIT
    trap 'rig_progress_signal 129' HUP
    trap 'rig_progress_signal 130' INT
    trap 'rig_progress_signal 143' TERM
    trap rig_progress_resize WINCH
    rig_progress_start 'public data export' 1
    rig_progress_begin "$profile" declaration
    if rig_replace_export_tree "$output"; then
      rig_progress_result succeeded "$profile" declaration
      rig_progress_finish
    else
      native_status=$?
      rig_progress_result failed "$profile" declaration
      rig_progress_finish
      return "$native_status"
    fi
  )
}

rig_lifecycle_supported() {
  case "$1:$2" in
    upgrade:homebrew|upgrade:uv|upgrade:mise|upgrade:npm|upgrade:skills-cli) return 0 ;;
  esac
  return 1
}

rig_lifecycle_add_task() {
  local key label provider binding supported tool index

  key=$1
  label=$2
  provider=$3
  binding=$4
  supported=$5
  tool=$6
  index=0
  while [ "$index" -lt "${#RIG_LIFECYCLE_KEYS[@]}" ]; do
    [ "${RIG_LIFECYCLE_KEYS[$index]}" != "$key" ] || return 0
    index=$((index + 1))
  done
  RIG_LIFECYCLE_KEYS[${#RIG_LIFECYCLE_KEYS[@]}]=$key
  RIG_LIFECYCLE_LABELS[${#RIG_LIFECYCLE_LABELS[@]}]=$label
  RIG_LIFECYCLE_PROVIDERS[${#RIG_LIFECYCLE_PROVIDERS[@]}]=$provider
  RIG_LIFECYCLE_BINDINGS[${#RIG_LIFECYCLE_BINDINGS[@]}]=$binding
  RIG_LIFECYCLE_SUPPORTED[${#RIG_LIFECYCLE_SUPPORTED[@]}]=$supported
  RIG_LIFECYCLE_TOOLS[${#RIG_LIFECYCLE_TOOLS[@]}]=$tool
}

rig_collect_lifecycle_tasks() {
  local action index tool binding provider adapter key label supported skill authority

  action=$1
  RIG_LIFECYCLE_KEYS=()
  RIG_LIFECYCLE_LABELS=()
  RIG_LIFECYCLE_PROVIDERS=()
  RIG_LIFECYCLE_BINDINGS=()
  RIG_LIFECYCLE_SUPPORTED=()
  RIG_LIFECYCLE_EXECUTABLES=()
  RIG_LIFECYCLE_TOOLS=()
  RIG_LIFECYCLE_DETAILS=()
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    if [ -n "$binding" ]; then
      rig_provider_adapter "$provider" || return 2
      adapter=$RIG_VALUE
      supported=0
      rig_lifecycle_supported "$action" "$adapter" && supported=1
      key=$provider:$binding
      label=$tool
      rig_lifecycle_add_task "$key" "$label" "$provider" "$binding" "$supported" "$tool"
    fi
    index=$((index + 1))
  done
  if [ "$action" = upgrade ]; then
    for skill in "${RIG_SELECTED_SKILLS[@]+"${RIG_SELECTED_SKILLS[@]}"}"; do
      rig_get_value "skill.$skill" authority || return 2
      authority=$RIG_VALUE
      supported=0
      [ "$authority" != skills-cli ] || supported=1
      rig_lifecycle_add_task "skill:$skill" "skill:$skill" "$authority" "skill.$skill" \
        "$supported" "$skill"
    done
  fi
}

rig_lifecycle_executable() {
  local provider binding adapter kind

  provider=$1
  binding=$2
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  kind=tool
  if [ -n "$binding" ] && rig_get_value "$binding" kind; then
    kind=$RIG_VALUE
  fi
  rig_provider_executable "$provider" "$adapter" "$kind"
}

rig_lifecycle_unavailable() {
  local detail message

  detail=$1
  message=$2
  RIG_LIFECYCLE_PREFLIGHT_DETAIL=$detail
  [ "${RIG_LIFECYCLE_PREFLIGHT_SOFT:-0}" -eq 0 ] || return 1
  rig_fail "$message"
}

rig_preflight_lifecycle_task() {
  local action provider binding adapter executable tool

  action=$1
  provider=$2
  binding=$3
  case "$binding" in
    skill.*)
      rig_preflight_skill "${binding#skill.}" ||
        rig_lifecycle_unavailable "${RIG_SKILL_PREFLIGHT_DETAIL:-preflight-failed}" \
          "skill '${binding#skill.}' upgrade unavailable: ${RIG_SKILL_PREFLIGHT_DETAIL:-preflight-failed}" || return
      rig_provider_executable skills-cli skills-cli skill || return 2
      return 0
      ;;
  esac
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_lifecycle_supported "$action" "$adapter" || return 0
  rig_lifecycle_executable "$provider" "$binding" || return 2
  executable=$RIG_VALUE
  rig_executable_available "$executable" ||
    rig_lifecycle_unavailable executable-unavailable \
      "provider '$provider' lifecycle executable unavailable: $executable" || return
  if [ -n "$binding" ]; then
    rig_section_index "$binding" || return 2
    tool=${RIG_SECTION_IDS[$RIG_INDEX]}
    rig_preflight_tool_clis "$tool" "$binding" "$provider" ||
      rig_lifecycle_unavailable cli-preflight-failed "tool '$tool' CLI preflight failed" || return
  fi
  RIG_VALUE=$executable
  RIG_VALUE=$executable
}

rig_execute_lifecycle_task() {
  local action provider binding executable adapter kind locator normalized native_status tool

  action=$1
  provider=$2
  binding=$3
  executable=$4
  case "$binding" in
    skill.*)
      rig_skill_source_name "${binding#skill.}" || return 2
      "$executable" update "$RIG_VALUE" --global --yes 1>&2
      return
      ;;
  esac
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  # Homebrew's own documented way to say that nobody is watching.
  if [ "$RIG_UNATTENDED" -eq 1 ] && [ "$adapter" = homebrew ]; then
    export NONINTERACTIVE=1
  fi
  kind=
  locator=
  if [ -n "$binding" ]; then
    rig_get_value "$binding" kind || return 2
    kind=$RIG_VALUE
    rig_get_value "$binding" locator || return 2
    locator=$RIG_VALUE
  fi

  case "$action:$adapter" in
    upgrade:homebrew)
      if [ "$kind" = mas ]; then
        "$executable" upgrade "$locator" 1>&2
      else
        "$executable" upgrade "--$kind" "$locator" 1>&2
      fi
      ;;
    upgrade:uv)
      rig_normalize_provider_identity "$adapter" "$kind" "$locator"
      normalized=$RIG_VALUE
      "$executable" tool upgrade "$normalized" 1>&2
      ;;
    upgrade:mise)
      "$executable" upgrade "$locator" 1>&2
      ;;
    upgrade:npm)
      "$executable" install --global "$locator" 1>&2
      ;;
    *) return 2 ;;
  esac
  native_status=$?
  [ "$native_status" -eq 0 ] || return "$native_status"
  if [ -n "$binding" ]; then
    rig_section_index "$binding" || return 2
    tool=${RIG_SECTION_IDS[$RIG_INDEX]}
    rig_apply_tool_clis "$tool" "$binding" "$provider"
  fi
}

rig_lifecycle_requires_person() {
  local provider binding kind

  provider=$1
  binding=$2
  case "$binding" in
    ''|skill.*) return 1 ;;
  esac
  rig_get_value "$binding" kind || return 1
  kind=$RIG_VALUE
  # A Mac App Store upgrade needs a person signed in to the App Store, which a
  # run with nobody watching cannot supply.
  [ "$kind" = mas ]
}

rig_write_last_run_report() {
  local action status result detail summary rows state_home target staging observed

  action=$1
  status=$2
  result=$3
  detail=$4
  summary=$5
  rows=$6
  rig_effective_state_home || return 0
  state_home=$RIG_VALUE
  target=$state_home/last-upgrade
  mkdir -p "$state_home" 2>/dev/null || return 0
  [ -d "$state_home" ] || return 0
  if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
    printf 'rig: warning: last-run report target is not a regular file\n' >&2
    return 0
  fi
  observed=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null) || observed=
  staging=$state_home/.last-upgrade.$$
  {
    printf 'rig-last-run\t1\n'
    printf 'action\t%s\n' "$action"
    printf 'profile\t%s\n' "$RIG_RESOLVED_PROFILE"
    printf 'platform\t%s\n' "$RIG_RESOLVED_PLATFORM"
    printf 'finished\t%s\n' "$observed"
    printf 'status\t%s\n' "$status"
    printf 'result\t%s\n' "$result"
    printf 'detail\t%s\n' "$detail"
    printf 'summary\t%s\n' "$summary"
    printf 'TARGET\tPROVIDER\tRESULT\tDETAIL\n'
    [ -z "$rows" ] || printf '%s\n' "$rows"
  } >"$staging" 2>/dev/null || { rm -f "$staging"; return 0; }
  mv -f "$staging" "$target" 2>/dev/null || rm -f "$staging"
  return 0
}

rig_run_lifecycle_tasks() {
  local action dry_run index label provider binding supported executable native_status progress_scope
  local planned completed failed unavailable skipped supported_total exit_code preflight_status
  local rows row outcome_result outcome_detail summary preflight_executable

  action=$1
  dry_run=$2
  planned=0
  completed=0
  failed=0
  unavailable=0
  skipped=0
  supported_total=0
  exit_code=0
  rig_progress_start "$action preflight" "${#RIG_LIFECYCLE_KEYS[@]}"
  index=0
  while [ "$index" -lt "${#RIG_LIFECYCLE_KEYS[@]}" ]; do
    label=${RIG_LIFECYCLE_LABELS[$index]}
    provider=${RIG_LIFECYCLE_PROVIDERS[$index]}
    rig_progress_begin "$provider:$label"
    if [ "${RIG_LIFECYCLE_SUPPORTED[$index]}" -eq 1 ]; then
      binding=${RIG_LIFECYCLE_BINDINGS[$index]}
      RIG_LIFECYCLE_PREFLIGHT_DETAIL=
      RIG_LIFECYCLE_PREFLIGHT_SOFT=1
      rig_preflight_lifecycle_task "$action" "$provider" "$binding"
      preflight_status=$?
      RIG_LIFECYCLE_PREFLIGHT_SOFT=0
      case "$preflight_status" in
        0)
          # The predicate reads configuration, so keep the resolved executable
          # before anything else can overwrite RIG_VALUE.
          preflight_executable=$RIG_VALUE
          if [ "$RIG_UNATTENDED" -eq 1 ] && rig_lifecycle_requires_person "$provider" "$binding"; then
            RIG_LIFECYCLE_EXECUTABLES[$index]=-
            RIG_LIFECYCLE_DETAILS[$index]=interactive-required
            rig_progress_result skipped "$provider:$label"
          else
            RIG_LIFECYCLE_EXECUTABLES[$index]=$preflight_executable
            supported_total=$((supported_total + 1))
            rig_progress_result succeeded "$provider:$label"
          fi
          ;;
        1)
          RIG_LIFECYCLE_EXECUTABLES[$index]=-
          RIG_LIFECYCLE_DETAILS[$index]=${RIG_LIFECYCLE_PREFLIGHT_DETAIL:-preflight-failed}
          rig_progress_result skipped "$provider:$label"
          ;;
        *) return "$preflight_status" ;;
      esac
    else
      RIG_LIFECYCLE_EXECUTABLES[$index]=-
      rig_progress_result skipped "$provider:$label"
    fi
    index=$((index + 1))
  done
  rig_progress_finish

  printf 'Profile: %s\nPlatform: %s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  printf 'Operation scope: declaration\n'
  printf 'TARGET\tPROVIDER\tRESULT\tDETAIL\n'
  rows=
  [ "$dry_run" -eq 1 ] || rig_progress_start "$action" "$supported_total" passthrough
  index=0
  while [ "$index" -lt "${#RIG_LIFECYCLE_KEYS[@]}" ]; do
    label=${RIG_LIFECYCLE_LABELS[$index]}
    provider=${RIG_LIFECYCLE_PROVIDERS[$index]}
    binding=${RIG_LIFECYCLE_BINDINGS[$index]}
    supported=${RIG_LIFECYCLE_SUPPORTED[$index]}
    executable=${RIG_LIFECYCLE_EXECUTABLES[$index]}
    row=
    if [ "$supported" -ne 1 ]; then
      row=$(printf '%s\t%s\tskipped\tunsupported-%s' "$label" "$provider" "$action")
      printf '%s\n' "$row"
      skipped=$((skipped + 1))
    elif [ -n "${RIG_LIFECYCLE_DETAILS[$index]-}" ]; then
      row=$(printf '%s\t%s\tunavailable\t%s' "$label" "$provider" "${RIG_LIFECYCLE_DETAILS[$index]}")
      printf '%s\n' "$row"
      unavailable=$((unavailable + 1))
      exit_code=1
    elif [ "$dry_run" -eq 1 ]; then
      row=$(printf '%s\t%s\tplanned\t%s' "$label" "$provider" "$action")
      printf '%s\n' "$row"
      planned=$((planned + 1))
    else
      progress_scope=declaration
      rig_progress_begin "$provider:$label" "$progress_scope"
      # Standard-input questions receive EOF in an unattended invocation.
      # Native programs may still use a terminal or another authentication surface.
      if [ "$RIG_UNATTENDED" -eq 1 ]; then
        rig_execute_lifecycle_task "$action" "$provider" "$binding" "$executable" </dev/null
      else
        rig_execute_lifecycle_task "$action" "$provider" "$binding" "$executable"
      fi
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        row=$(printf '%s\t%s\tcompleted\t%s' "$label" "$provider" "$action")
        printf '%s\n' "$row"
        completed=$((completed + 1))
        rig_progress_result succeeded "$provider:$label" "$progress_scope"
      else
        row=$(printf '%s\t%s\tfailed\texit:%s' "$label" "$provider" "$native_status")
        printf '%s\n' "$row"
        failed=$((failed + 1))
        exit_code=1
        rig_progress_result failed "$provider:$label" "$progress_scope"
      fi
    fi
    if [ "$RIG_UNATTENDED" -eq 1 ] && [ -n "$row" ]; then
      rows="${rows}${row}"$'\n'
    fi
    index=$((index + 1))
  done
  rig_progress_finish
  summary="planned=$planned completed=$completed failed=$failed unavailable=$unavailable skipped=$skipped"
  printf 'Summary: %s\n' "$summary"
  if [ "$exit_code" -eq 0 ]; then
    outcome_result=succeeded
    outcome_detail="planned=$planned completed=$completed skipped=$skipped"
  else
    outcome_result=incomplete
    outcome_detail="planned=$planned completed=$completed failed=$failed unavailable=$unavailable"
  fi
  rig_outcome_note "$outcome_result" "$outcome_detail"
  if [ "$RIG_UNATTENDED" -eq 1 ] && [ "$dry_run" -ne 1 ]; then
    rig_write_last_run_report "$action" "$exit_code" "$outcome_result" \
      "$outcome_detail" "$summary" "${rows%$'\n'}"
  fi
  return "$exit_code"
}

rig_command_lifecycle_impl() {
  local action profile dry_run profile_seen dry_run_seen unattended_seen usage

  action=$1
  shift
  profile=
  dry_run=0
  profile_seen=0
  dry_run_seen=0
  unattended_seen=0
  RIG_UNATTENDED=0
  usage=$(rig_command_usage "$action")
  usage="usage: ${usage#Usage: }"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        [ "$#" -eq 1 ] || { syntax_error "$usage"; return; }
        rig_command_help "$action"
        return
        ;;
      --profile)
        if [ "$profile_seen" -ne 0 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
          syntax_error "$usage"
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --dry-run)
        if [ "$dry_run_seen" -ne 0 ]; then
          syntax_error "$usage"
          return
        fi
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      --unattended)
        if [ "$unattended_seen" -ne 0 ]; then
          syntax_error "$usage"
          return
        fi
        RIG_UNATTENDED=1
        unattended_seen=1
        shift
        ;;
      *) syntax_error "$usage"; return ;;
    esac
  done
  rig_resolve_operational_plan "$profile" || return
  [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
    rig_fail "profile '$RIG_RESOLVED_PROFILE' is a non-appliable view" || return
  rig_collect_lifecycle_tasks "$action" || return
  rig_run_lifecycle_tasks "$action" "$dry_run"
}

rig_command_lifecycle() {
  rig_buffer_mutation_report "$1" rig_command_lifecycle_impl "$@"
}
