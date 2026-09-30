# rig-module: 23-application
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

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
  local dry_run index skill authority blocker native_status row_scope

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
    [ "$dry_run" -eq 1 ] || rig_progress_begin "$authority:skill.$skill" declaration
    if [ -n "${RIG_SKILL_PREFLIGHT_DETAILS[$index]:-}" ]; then
      RIG_SKILL_RESULTS[$index]=failed
      RIG_SKILL_DETAILS[$index]=preflight:${RIG_SKILL_PREFLIGHT_DETAILS[$index]}
      RIG_SKILL_APPLY_FAILURE=1
      RIG_SKILL_FAILED=$((RIG_SKILL_FAILED + 1))
      [ "$dry_run" -eq 1 ] || rig_progress_result failed "$authority:skill.$skill" declaration
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
      rig_progress_result skipped "$authority:skill.$skill" declaration
    else
      rig_apply_skill "$skill"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        RIG_SKILL_RESULTS[$index]=completed
        RIG_SKILL_DETAILS[$index]=-
        RIG_SKILL_COMPLETED=$((RIG_SKILL_COMPLETED + 1))
        rig_progress_result succeeded "$authority:skill.$skill" declaration
      else
        RIG_SKILL_RESULTS[$index]=failed
        RIG_SKILL_DETAILS[$index]=exit:$native_status
        RIG_SKILL_APPLY_FAILURE=1
        RIG_SKILL_FAILED=$((RIG_SKILL_FAILED + 1))
        rig_progress_result failed "$authority:skill.$skill" declaration
      fi
    fi
    rig_apply_row_scope "skill:$skill"
    row_scope=$RIG_VALUE
    printf '%s\t%s\t%s\t%s\t%s\n' "$skill" "$authority" \
      "${RIG_SKILL_RESULTS[$index]}" "${RIG_SKILL_DETAILS[$index]}" "$row_scope"
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

rig_apply_mark_tool() {
  if ! rig_array_contains "$1" "${RIG_APPLY_KEEP_TOOLS[@]+"${RIG_APPLY_KEEP_TOOLS[@]}"}"; then
    RIG_APPLY_KEEP_TOOLS[${#RIG_APPLY_KEEP_TOOLS[@]}]=$1
    RIG_APPLY_CHANGED=1
  fi
}

rig_apply_mark_resource() {
  if ! rig_array_contains "$1" "${RIG_APPLY_KEEP_RESOURCES[@]+"${RIG_APPLY_KEEP_RESOURCES[@]}"}"; then
    RIG_APPLY_KEEP_RESOURCES[${#RIG_APPLY_KEEP_RESOURCES[@]}]=$1
    RIG_APPLY_CHANGED=1
  fi
}

rig_apply_tool_needs_dispatch() {
  local index
  rig_plan_index "$1" || return 2
  index=$RIG_INDEX
  [ -n "${RIG_PLAN_BINDINGS[$index]}" ] || return 0
  rig_observe_provider "${RIG_PLAN_TOOLS[$index]}" \
    "${RIG_PLAN_BINDINGS[$index]}" "${RIG_PLAN_PROVIDERS[$index]}" || return 2
  [ "$RIG_OBSERVATION" != present ]
}

rig_apply_resource_needs_dispatch() {
  rig_observe_resource "$1" || return 2
  [ "$RIG_OBSERVATION" != present ]
}

rig_apply_include_tool_dependency() {
  local result
  rig_array_contains "$1" "${RIG_APPLY_KEEP_TOOLS[@]+"${RIG_APPLY_KEEP_TOOLS[@]}"}" && return 0
  rig_apply_tool_needs_dispatch "$1"
  result=$?
  case "$result" in
    0) rig_apply_mark_tool "$1" ;;
    1) return 0 ;;
    *) return "$result" ;;
  esac
}

rig_apply_include_resource_dependency() {
  local result
  rig_array_contains "$1" "${RIG_APPLY_KEEP_RESOURCES[@]+"${RIG_APPLY_KEEP_RESOURCES[@]}"}" && return 0
  rig_apply_resource_needs_dispatch "$1"
  result=$?
  case "$result" in
    0) rig_apply_mark_resource "$1" ;;
    1) return 0 ;;
    *) return "$result" ;;
  esac
}

rig_apply_mark_dependencies() {
  local section_name section_index field_index field_end dependency reference
  local tool skill resource

  RIG_APPLY_CHANGED=1
  while [ "$RIG_APPLY_CHANGED" -eq 1 ]; do
    RIG_APPLY_CHANGED=0
    for tool in "${RIG_APPLY_KEEP_TOOLS[@]+"${RIG_APPLY_KEEP_TOOLS[@]}"}"; do
      section_name=tool.$tool
      rig_section_index "$section_name" || return 2
      section_index=$RIG_INDEX
      field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
      field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
      while [ "$field_index" -lt "$field_end" ]; do
        if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
          dependency=${RIG_FIELD_VALUES[$field_index]}
          rig_apply_include_tool_dependency "$dependency" || return
        fi
        field_index=$((field_index + 1))
      done
    done
    for skill in "${RIG_APPLY_KEEP_SKILLS[@]+"${RIG_APPLY_KEEP_SKILLS[@]}"}"; do
      section_name=skill.$skill
      rig_section_index "$section_name" || return 2
      section_index=$RIG_INDEX
      field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
      field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
      while [ "$field_index" -lt "$field_end" ]; do
        if [ "${RIG_FIELD_KEYS[$field_index]}" = requires ]; then
          dependency=${RIG_FIELD_VALUES[$field_index]}
          rig_apply_include_tool_dependency "$dependency" || return
        fi
        field_index=$((field_index + 1))
      done
    done
    for resource in "${RIG_APPLY_KEEP_RESOURCES[@]+"${RIG_APPLY_KEEP_RESOURCES[@]}"}"; do
      rig_section_index "$resource" || return 2
      section_index=$RIG_INDEX
      field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
      field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
      while [ "$field_index" -lt "$field_end" ]; do
        case "${RIG_FIELD_KEYS[$field_index]}" in
          requires)
            dependency=${RIG_FIELD_VALUES[$field_index]}
            rig_apply_include_tool_dependency "$dependency" || return
            ;;
          resource-dependency)
            reference=${RIG_FIELD_VALUES[$field_index]}
            rig_resource_reference "$reference" || return 2
            dependency=$RIG_VALUE
            rig_apply_include_resource_dependency "$dependency" || return
            ;;
        esac
        field_index=$((field_index + 1))
      done
    done
  done
}

rig_apply_select_targets() {
  local scope target id section_name owner index
  local -a tools bindings providers skills resources

  scope=$1
  RIG_APPLY_DIRECT=()
  RIG_APPLY_KEEP_TOOLS=()
  RIG_APPLY_KEEP_SKILLS=()
  RIG_APPLY_KEEP_RESOURCES=()
  RIG_APPLY_PORT_TARGETS=()
  for target in "${RIG_APPLY_TARGETS[@]}"; do
    case "$target" in
      skill:*)
        id=${target#skill:}
        rig_array_contains "$id" "${RIG_SELECTED_SKILLS[@]+"${RIG_SELECTED_SKILLS[@]}"}" ||
          { syntax_error "unknown target '$target' in profile '$RIG_RESOLVED_PROFILE'"; return 2; }
        if [ "$scope" = all ] || [ "$scope" = skills ]; then
          RIG_APPLY_KEEP_SKILLS[${#RIG_APPLY_KEEP_SKILLS[@]}]=$id
          RIG_APPLY_DIRECT[${#RIG_APPLY_DIRECT[@]}]=$target
        fi
        ;;
      port:*)
        id=${target#port:}
        rig_array_contains "$id" "${RIG_SELECTED_PORTS[@]+"${RIG_SELECTED_PORTS[@]}"}" ||
          { syntax_error "unknown target '$target' in profile '$RIG_RESOLVED_PROFILE'"; return 2; }
        rig_get_value "port.$id" owner || return 2
        owner=$RIG_VALUE
        case "$owner" in
          tool:*) rig_plan_index "${owner#tool:}" ||
            { syntax_error "port target '$target' owner '$owner' is not selected in profile '$RIG_RESOLVED_PROFILE'"; return 2; } ;;
          service:*|scheduled-job:*)
            section_name=${owner/:/.}
            rig_array_contains "$section_name" "${RIG_RESOURCE_PLAN_SECTIONS[@]+"${RIG_RESOURCE_PLAN_SECTIONS[@]}"}" ||
              { syntax_error "port target '$target' owner '$owner' is not selected in profile '$RIG_RESOLVED_PROFILE'"; return 2; }
            ;;
        esac
        case "$owner:$scope" in
          tool:*:all|tool:*:tools)
            rig_apply_mark_tool "${owner#tool:}"
            owner=${owner#tool:}
            ;;
          service:*:all|service:*:resources|scheduled-job:*:all|scheduled-job:*:resources)
            rig_apply_mark_resource "${owner/:/.}"
            ;;
          *) continue ;;
        esac
        RIG_APPLY_PORT_TARGETS[${#RIG_APPLY_PORT_TARGETS[@]}]=$target
        RIG_APPLY_DIRECT[${#RIG_APPLY_DIRECT[@]}]=$owner
        ;;
      service:*|scheduled-job:*|setting:*|dock:*)
        section_name=${target/:/.}
        rig_array_contains "$section_name" "${RIG_RESOURCE_PLAN_SECTIONS[@]+"${RIG_RESOURCE_PLAN_SECTIONS[@]}"}" ||
          { syntax_error "unknown target '$target' in profile '$RIG_RESOLVED_PROFILE'"; return 2; }
        if [ "$scope" = all ] || [ "$scope" = resources ]; then
          rig_apply_mark_resource "$section_name"
          RIG_APPLY_DIRECT[${#RIG_APPLY_DIRECT[@]}]=$target
        fi
        ;;
      *)
        rig_plan_index "$target" ||
          { syntax_error "unknown target '$target' in profile '$RIG_RESOLVED_PROFILE'"; return 2; }
        if [ "$scope" = all ] || [ "$scope" = tools ]; then
          rig_apply_mark_tool "$target"
          RIG_APPLY_DIRECT[${#RIG_APPLY_DIRECT[@]}]=$target
        fi
        ;;
    esac
  done
  rig_apply_mark_dependencies || return
  tools=()
  bindings=()
  providers=()
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    if rig_array_contains "${RIG_PLAN_TOOLS[$index]}" "${RIG_APPLY_KEEP_TOOLS[@]+"${RIG_APPLY_KEEP_TOOLS[@]}"}"; then
      tools[${#tools[@]}]=${RIG_PLAN_TOOLS[$index]}
      bindings[${#bindings[@]}]=${RIG_PLAN_BINDINGS[$index]}
      providers[${#providers[@]}]=${RIG_PLAN_PROVIDERS[$index]}
    fi
    index=$((index + 1))
  done
  RIG_PLAN_TOOLS=("${tools[@]+"${tools[@]}"}")
  RIG_PLAN_BINDINGS=("${bindings[@]+"${bindings[@]}"}")
  RIG_PLAN_PROVIDERS=("${providers[@]+"${providers[@]}"}")
  RIG_PLAN_RESULTS=()
  RIG_PLAN_DETAILS=()
  skills=()
  for id in "${RIG_SELECTED_SKILLS[@]+"${RIG_SELECTED_SKILLS[@]}"}"; do
    rig_array_contains "$id" "${RIG_APPLY_KEEP_SKILLS[@]+"${RIG_APPLY_KEEP_SKILLS[@]}"}" &&
      skills[${#skills[@]}]=$id
  done
  RIG_SELECTED_SKILLS=("${skills[@]+"${skills[@]}"}")
  resources=()
  for section_name in "${RIG_RESOURCE_PLAN_SECTIONS[@]+"${RIG_RESOURCE_PLAN_SECTIONS[@]}"}"; do
    rig_array_contains "$section_name" "${RIG_APPLY_KEEP_RESOURCES[@]+"${RIG_APPLY_KEEP_RESOURCES[@]}"}" &&
      resources[${#resources[@]}]=$section_name
  done
  RIG_RESOURCE_PLAN_SECTIONS=("${resources[@]+"${resources[@]}"}")
  RIG_STALE_RESOURCE_PROVIDERS=()
  RIG_STALE_RESOURCE_KINDS=()
  RIG_STALE_RESOURCE_IDS=()
  RIG_STALE_RESOURCE_LOCATORS=()
}

rig_apply_row_scope() {
  local target
  RIG_VALUE=declaration
  [ "${#RIG_APPLY_TARGETS[@]}" -gt 0 ] || return 0
  RIG_VALUE=dependency
  for target in "${RIG_APPLY_DIRECT[@]+"${RIG_APPLY_DIRECT[@]}"}"; do
    [ "$target" = "$1" ] || continue
    RIG_VALUE=target
    return 0
  done
}

rig_command_apply() {
  local profile scope dry_run profile_seen scope_seen dry_run_seen index tool binding provider
  local blocker native_status planned completed failed skipped operational_failure
  local section_name section_index kind id locator resource_total lock_acquired exit_code
  local row_scope

  profile=
  scope=all
  dry_run=0
  profile_seen=0
  scope_seen=0
  dry_run_seen=0
  RIG_APPLY_TARGETS=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
      [ "$#" -eq 1 ] || { rig_command_syntax_error apply; return; }
      rig_command_help apply
        return
        ;;
      --profile)
        if [ "$profile_seen" -ne 0 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        rig_command_syntax_error apply
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --scope)
        if [ "$scope_seen" -ne 0 ] || [ "$#" -lt 2 ]; then
        rig_command_syntax_error apply
          return
        fi
        case "$2" in tools|skills|resources|all) scope=$2 ;; *)
          rig_command_syntax_error apply
          return ;;
        esac
        scope_seen=1
        shift 2
        ;;
      --dry-run)
      [ "$dry_run_seen" -eq 0 ] ||
        { rig_command_syntax_error apply; return; }
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      --target)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          rig_command_syntax_error apply
          return
        fi
        RIG_APPLY_TARGETS[${#RIG_APPLY_TARGETS[@]}]=$2
        shift 2
        ;;
      *) rig_command_syntax_error apply; return ;;
    esac
  done

  rig_resolve_operational_plan "$profile" defer || return
  [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
    rig_fail "profile '$RIG_RESOLVED_PROFILE' is a non-appliable view" || return
  if [ "${#RIG_APPLY_TARGETS[@]}" -gt 0 ]; then
    rig_apply_select_targets "$scope" || return
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
  lock_acquired=0
  if { [ "$scope" = resources ] || [ "$scope" = all ]; } && {
    if [ "${#RIG_APPLY_TARGETS[@]}" -gt 0 ]; then
      [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ]
    else
      rig_reconciliation_needed "$RIG_RESOLVED_PLATFORM"
    fi
  }; then
    if [ "$dry_run" -eq 0 ]; then
      rig_acquire_reconciliation_lock \
        "$RIG_RESOLVED_PLATFORM" "$RIG_RESOLVED_PROFILE" apply || return
      lock_acquired=$RIG_RECONCILIATION_LOCK_ACQUIRED
    fi
    rig_load_resource_receipt "$RIG_RESOLVED_PLATFORM" || return
    if [ "${#RIG_APPLY_TARGETS[@]}" -gt 0 ]; then
      RIG_STALE_RESOURCE_PROVIDERS=()
      RIG_STALE_RESOURCE_KINDS=()
      RIG_STALE_RESOURCE_IDS=()
      RIG_STALE_RESOURCE_LOCATORS=()
    fi
  fi
  rig_progress_start preflight 1
  rig_progress_begin 'selected plan'
  rig_preflight_apply "$scope" || return
  rig_progress_result succeeded 'selected plan'
  rig_progress_finish
  printf 'Profile: %s\nPlatform: %s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  if [ "${#RIG_APPLY_TARGETS[@]}" -gt 0 ]; then
    printf 'Operation scope: target (dependencies marked separately)\n'
  else
    printf 'Operation scope: declaration\n'
  fi
  for tool in "${RIG_APPLY_PORT_TARGETS[@]+"${RIG_APPLY_PORT_TARGETS[@]}"}"; do
    printf 'Target %s: observational-only; reconciling its owner\n' "$tool"
  done
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
    rig_progress_start applying \
      "$((planned + ${#RIG_SELECTED_SKILLS[@]} + resource_total))" passthrough
  fi

  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    if [ "$dry_run" -eq 0 ] && [ -n "$binding" ]; then
      rig_progress_begin "$provider:$tool" declaration
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
      rig_progress_result skipped "$provider:$tool" declaration
    else
      rig_apply_provider "$tool" "$binding" "$provider"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        RIG_PLAN_RESULTS[$index]=completed
        RIG_PLAN_DETAILS[$index]=-
        completed=$((completed + 1))
        rig_progress_result succeeded "$provider:$tool" declaration
      else
        RIG_PLAN_RESULTS[$index]=failed
        RIG_PLAN_DETAILS[$index]=exit:$native_status
        failed=$((failed + 1))
        operational_failure=1
        rig_progress_result failed "$provider:$tool" declaration
      fi
    fi
    rig_apply_row_scope "$tool"
    row_scope=$RIG_VALUE
    printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$provider" \
      "${RIG_PLAN_RESULTS[$index]}" "${RIG_PLAN_DETAILS[$index]}" "$row_scope"
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
    [ "$dry_run" -eq 1 ] || rig_progress_begin "$provider:$kind.$id" declaration
    if [ -n "${RIG_RESOURCE_PREFLIGHT_DETAILS[$index]:-}" ]; then
      RIG_RESOURCE_PLAN_RESULTS[$index]=failed
      RIG_RESOURCE_PLAN_DETAILS[$index]=preflight:${RIG_RESOURCE_PREFLIGHT_DETAILS[$index]}
      failed=$((failed + 1))
      operational_failure=1
      [ "$dry_run" -eq 1 ] || rig_progress_result failed "$provider:$kind.$id" declaration
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
      rig_progress_result skipped "$provider:$kind.$id" declaration
    else
      rig_apply_resource "$section_name"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        RIG_RESOURCE_PLAN_RESULTS[$index]=completed
        RIG_RESOURCE_PLAN_DETAILS[$index]=reconciled:$locator
        completed=$((completed + 1))
        rig_progress_result succeeded "$provider:$kind.$id" declaration
      else
        RIG_RESOURCE_PLAN_RESULTS[$index]=failed
        RIG_RESOURCE_PLAN_DETAILS[$index]=exit:$native_status
        failed=$((failed + 1))
        operational_failure=1
        rig_progress_result failed "$provider:$kind.$id" declaration
      fi
    fi
    rig_apply_row_scope "$kind:$id"
    row_scope=$RIG_VALUE
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$kind" "$provider" \
      "${RIG_RESOURCE_PLAN_RESULTS[$index]}" "${RIG_RESOURCE_PLAN_DETAILS[$index]}" "$row_scope"
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
    [ "$dry_run" -eq 1 ] || rig_progress_begin "retire $provider:$kind.$id" declaration
    if [ "$operational_failure" -ne 0 ]; then
      printf '%s\t%s\t%s\tskipped\tblocked-by:resource-failure\tdeclaration\n' "$id" "$kind" "$provider"
      skipped=$((skipped + 1))
      [ "$dry_run" -eq 1 ] || rig_progress_result skipped "retire $provider:$kind.$id" declaration
    elif [ "$dry_run" -eq 1 ]; then
      printf '%s\t%s\t%s\tplanned\tretire:%s\tdeclaration\n' "$id" "$kind" "$provider" "$locator"
      planned=$((planned + 1))
    else
      rig_retire_resource "$provider" "$kind" "$id" "$locator"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        printf '%s\t%s\t%s\tcompleted\tretired:%s\tdeclaration\n' "$id" "$kind" "$provider" "$locator"
        completed=$((completed + 1))
        rig_progress_result succeeded "retire $provider:$kind.$id" declaration
      else
        printf '%s\t%s\t%s\tfailed\texit:%s\tdeclaration\n' "$id" "$kind" "$provider" "$native_status"
        failed=$((failed + 1))
        operational_failure=1
        rig_progress_result failed "retire $provider:$kind.$id" declaration
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
  if [ "$exit_code" -eq 0 ]; then
    rig_outcome_note succeeded "planned=$planned completed=$completed skipped=$skipped"
  else
    rig_outcome_note incomplete "planned=$planned completed=$completed failed=$failed skipped=$skipped"
  fi
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
          rig_command_syntax_error bootstrap
          return
        }
      rig_command_help bootstrap
        return
        ;;
      --profile)
        if [ "$profile_seen" -ne 0 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
        rig_command_syntax_error bootstrap
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --scope)
        if [ "$scope_seen" -ne 0 ] || [ "$#" -lt 2 ]; then
        rig_command_syntax_error bootstrap
          return
        fi
        case "$2" in tools|skills|resources|all) scope=$2 ;; *)
          rig_command_syntax_error bootstrap
          return ;;
        esac
        scope_seen=1
        shift 2
        ;;
      --dry-run)
        [ "$dry_run_seen" -eq 0 ] || {
          rig_command_syntax_error bootstrap
          return
        }
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      *) rig_command_syntax_error bootstrap; return ;;
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
  rig_progress_start 'bootstrap preflight' 2
  rig_progress_begin 'selected plan'
  rig_preflight_apply "$scope"
  native_status=$?
  if [ "$native_status" -ne 0 ]; then
    rig_progress_result failed 'selected plan'
    rig_progress_finish
    RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=0
    return "$native_status"
  fi
  rig_progress_result succeeded 'selected plan'
  rig_progress_begin 'homebrew policy'
  if rig_bootstrap_preflight_homebrew_manifest "$scope"; then
    rig_progress_result succeeded 'homebrew policy'
  else
    native_status=$?
    rig_progress_result failed 'homebrew policy'
    rig_progress_finish
    return "$native_status"
  fi
  rig_progress_finish
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
      rig_progress_start bootstrapping "$manager_total" passthrough
      if [ -n "$RIG_BOOTSTRAP_MANIFEST" ]; then
        rig_progress_begin 'homebrew manifest' manifest
        rig_bootstrap_apply_homebrew_manifest
        native_status=$?
        if [ "$native_status" -ne 0 ]; then
          rig_progress_result failed 'homebrew manifest' manifest
          rig_progress_finish
          printf 'manifest\thomebrew\tfailed\texit:%s\tmanifest\n' "$native_status"
          return "$native_status"
        fi
        rig_progress_result succeeded 'homebrew manifest' manifest
        printf 'manifest\thomebrew\tcompleted\tbundle:%s\tmanifest\n' "$RIG_BOOTSTRAP_MANIFEST"
      fi
      if [ -n "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL" ]; then
        rig_progress_begin 'homebrew autoupdate' provider-wide
        rig_bootstrap_apply_homebrew_autoupdate
        native_status=$?
        if [ "$native_status" -ne 0 ]; then
          rig_progress_result failed 'homebrew autoupdate' provider-wide
          rig_progress_finish
          printf 'autoupdate\thomebrew\tfailed\texit:%s\tprovider-wide\n' "$native_status"
          return "$native_status"
        fi
        rig_progress_result succeeded 'homebrew autoupdate' provider-wide
        printf 'autoupdate\thomebrew\tcompleted\tinterval:%s\tprovider-wide\n' "$RIG_BOOTSTRAP_AUTOUPDATE_INTERVAL"
      fi
      RIG_BOOTSTRAP_ALLOW_DEFERRED_MANAGERS=0
      if [ "$RIG_BOOTSTRAP_DEFER_MISE" -eq 1 ]; then
        rig_progress_begin 'provider mise' declaration
        if ! rig_bootstrap_verify_deferred_mise; then
          rig_progress_result failed 'provider mise' declaration
          rig_progress_finish
          printf 'provider:mise\thomebrew\tfailed\tunavailable\tdeclaration\n'
          return 1
        fi
        rig_progress_result succeeded 'provider mise' declaration
        printf 'provider:mise\thomebrew\tcompleted\tavailable\tdeclaration\n'
      fi
      if [ "$RIG_BOOTSTRAP_DEFER_NPM" -eq 1 ]; then
        rig_progress_begin 'provider npm' declaration
        rig_bootstrap_apply_npm_prerequisite
        native_status=$?
        if [ "$native_status" -ne 0 ]; then
          rig_progress_result failed 'provider npm' declaration
          rig_progress_finish
          printf 'provider:npm\tmise\tfailed\texit:%s\tdeclaration\n' "$native_status"
          return "$native_status"
        fi
        rig_progress_result succeeded 'provider npm' declaration
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
