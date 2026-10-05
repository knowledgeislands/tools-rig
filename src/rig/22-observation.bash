# rig-module: 22-observation
# shellcheck shell=bash
# Cross-module state is intentionally consumed by later assembled modules.
# shellcheck disable=SC2004,SC2034,SC2094

rig_observe_resource_plan() {
  local index section_name state detail

  RIG_RESOURCE_PLAN_RESULTS=()
  RIG_RESOURCE_PLAN_DETAILS=()
  RIG_RESOURCE_PLAN_STATES=()
  rig_progress_start 'resource observation' "${#RIG_RESOURCE_PLAN_SECTIONS[@]}"
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" ]; do
    section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
    rig_progress_begin "$section_name"
    if rig_resource_blocker "$section_name"; then
      state=unknown
      detail=blocked-by:$RIG_VALUE
      rig_progress_result skipped "$section_name"
    else
      rig_observe_resource "$section_name" || return
      state=$RIG_OBSERVATION
      detail=$RIG_OBSERVATION_DETAIL
      case "$state" in
        unknown|unavailable) rig_progress_result failed "$section_name" ;;
        *) rig_progress_result succeeded "$section_name" ;;
      esac
    fi
    RIG_RESOURCE_PLAN_STATES[$index]=$state
    RIG_RESOURCE_PLAN_DETAILS[$index]=$detail
    case "$state" in
      present) RIG_RESOURCE_PLAN_RESULTS[$index]=observed ;;
      *) RIG_RESOURCE_PLAN_RESULTS[$index]=failed ;;
    esac
    index=$((index + 1))
  done
  rig_progress_finish
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

rig_ps_command() {
  if [ -n "${RIG_PS_COMMAND:-}" ]; then
    [ -x "$RIG_PS_COMMAND" ] || return 1
    RIG_VALUE=$RIG_PS_COMMAND
    return 0
  fi

  RIG_VALUE=$(command -v ps 2>/dev/null) || return 1
  [ -n "$RIG_VALUE" ]
}

rig_load_listener_argvs() {
  local command output line pid argv listener_index

  RIG_LISTENER_ARGVS=()
  listener_index=0
  while [ "$listener_index" -lt "${#RIG_LISTENER_PIDS[@]}" ]; do
    RIG_LISTENER_ARGVS[${#RIG_LISTENER_ARGVS[@]}]=
    listener_index=$((listener_index + 1))
  done

  rig_ps_command || return 0
  command=$RIG_VALUE
  output=$("$command" -axo pid=,command= 2>/dev/null) || return 0

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+(.+)$ ]]; then
      pid=${BASH_REMATCH[1]}
      argv=${BASH_REMATCH[2]}
      listener_index=0
      while [ "$listener_index" -lt "${#RIG_LISTENER_PIDS[@]}" ]; do
        if [ "${RIG_LISTENER_PIDS[$listener_index]}" = "$pid" ]; then
          RIG_LISTENER_ARGVS[$listener_index]=$argv
        fi
        listener_index=$((listener_index + 1))
      done
    fi
  done <<< "$output"
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
    *) RIG_VALUE='all-interfaces' ;;
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
  RIG_LISTENER_ARGVS=()
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
  rig_load_listener_argvs
  RIG_LISTENER_OBSERVATION_AVAILABLE=1
}

rig_expected_owner_identity() {
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
          rig_expand_home_value "$value" || return 1
          RIG_OWNER_IDENTITY=$RIG_VALUE
          RIG_OWNER_COMMAND=${RIG_VALUE##*/}
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
            value=${value%%\[*}
            value=${value##*/}
            value=${value##*:}
            RIG_OWNER_IDENTITY=$value
            RIG_OWNER_COMMAND=$value
            return 0
          fi
          break
        fi
        index=$((index + 1))
      done
      RIG_OWNER_IDENTITY=$id
      RIG_OWNER_COMMAND=$id
      return 0
      ;;
  esac
  return 1
}

rig_owner_matches_listener() {
  local argv process identity command

  argv=$1
  process=$2
  identity=$3
  command=$4
  if [ -n "$argv" ]; then
    case "$argv" in
      "$identity"|"$identity "*|*" $identity"|*" $identity "*|*"/$identity/"*|*"/$identity"|*"/$identity "*) return 0 ;;
    esac
    return 1
  fi

  [ -n "$process" ] && [ "$process" = "$command" ]
}

rig_observe_ports() {
  local index port section_name number expected_scope mode owner expected_identity expected_command
  local listener_index found actual_scope observed_command observed_argv foreign_command
  local owner_match owner_foreign owner_unverified
  local state detail

  RIG_PORT_STATES=()
  RIG_PORT_DETAILS=()
  rig_load_listeners || return
  rig_progress_start 'port observation' "${#RIG_SELECTED_PORTS[@]}"
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_PORTS[@]}" ]; do
    port=${RIG_SELECTED_PORTS[$index]}
    section_name=port.$port
    rig_progress_begin "$section_name"
    if [ "$RIG_LISTENER_OBSERVATION_AVAILABLE" -ne 1 ]; then
      RIG_PORT_STATES[$index]=unavailable
      RIG_PORT_DETAILS[$index]=$([ "$RIG_RESOLVED_PLATFORM" = macos ] && printf listener-observation-unavailable || printf unsupported-platform)
      rig_progress_result succeeded "$section_name"
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
    rig_expected_owner_identity "$owner" || return 2
    expected_identity=$RIG_OWNER_IDENTITY
    expected_command=$RIG_OWNER_COMMAND
    found=0
    actual_scope=loopback
    observed_command=
    observed_argv=
    foreign_command=
    owner_match=0
    owner_foreign=0
    owner_unverified=0
    listener_index=0
    while [ "$listener_index" -lt "${#RIG_LISTENER_PORTS[@]}" ]; do
      if [ "${RIG_LISTENER_PORTS[$listener_index]}" = "$number" ]; then
        found=$((found + 1))
        [ "${RIG_LISTENER_SCOPES[$listener_index]}" != all-interfaces ] || actual_scope='all-interfaces'
        observed_command=${RIG_LISTENER_COMMANDS[$listener_index]}
        observed_argv=${RIG_LISTENER_ARGVS[$listener_index]}
        if rig_owner_matches_listener "$observed_argv" "$observed_command" "$expected_identity" "$expected_command"; then
          owner_match=$((owner_match + 1))
        elif [ -n "$observed_argv" ]; then
          owner_foreign=$((owner_foreign + 1))
          [ -n "$foreign_command" ] || foreign_command=${observed_command:--}
        else
          owner_unverified=$((owner_unverified + 1))
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
    elif [ "$owner_foreign" -gt 0 ] && [ "$owner_match" -gt 0 ]; then
      state=conflicting
      detail=multiple-owners
    elif [ "$owner_foreign" -gt 0 ]; then
      state=conflicting
      detail="owner:${foreign_command:--};expected:$expected_command"
    elif [ "$owner_unverified" -gt 0 ]; then
      if [ "$mode" = allocated ]; then
        state=present
        detail='occupied:owner-unverified'
      else
        state=unknown
        detail='owner-unavailable'
      fi
    else
      state=present
      detail="listening:$actual_scope;owner:$expected_command"
    fi
    RIG_PORT_STATES[$index]=$state
    RIG_PORT_DETAILS[$index]=$detail
    rig_progress_result succeeded "$section_name"
    index=$((index + 1))
  done
  rig_progress_finish
}

rig_print_port_status() {
  local index port section_name number mode owner state detail unhealthy problems

  problems=${1:-0}
  rig_table_reset
  rig_table_add_column PORT 16 end keep
  rig_table_add_column NUMBER 6
  rig_table_add_column PROTOCOL 8
  rig_table_add_column MODE 10
  rig_table_add_column OWNER 16 end keep
  rig_table_add_column STATE 12
  rig_table_add_column DETAIL 40
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
    if [ "$problems" -eq 0 ] || [ "$state" != present ]; then
      rig_table_add_row "$port" "$number" tcp "$mode" "$owner" "$state" "$detail" || return 2
    fi
    index=$((index + 1))
  done
  if [ "$problems" -eq 0 ] || [ "$RIG_TABLE_ROW_COUNT" -gt 0 ]; then
    printf '\n'
    rig_table_print
    printf 'Port summary: selected=%s unhealthy=%s\n' \
      "${#RIG_SELECTED_PORTS[@]}" "$unhealthy"
  fi
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
  local index number row previous port scope command pid count

  rig_load_listeners || return
  printf '\n'
  rig_table_reset
  rig_table_add_column LISTENER 14 end keep
  rig_table_add_column PROTOCOL 8
  rig_table_add_column SCOPE 18
  rig_table_add_column STATE 12
  rig_table_add_column DETAIL 60
  if [ "$RIG_LISTENER_OBSERVATION_AVAILABLE" -ne 1 ]; then
    rig_table_add_row - tcp - unavailable \
      "$([ "$RIG_RESOLVED_PLATFORM" = macos ] && printf listener-observation-unavailable || printf unsupported-platform)" || return 2
    rig_table_print
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
  previous=
  for row in "${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}"; do
    # One process listening on both the IPv4 and the IPv6 socket of a port
    # renders an identical row, so reporting it twice would inflate the count
    # rather than name a second listener.
    [ "$row" != "$previous" ] || continue
    previous=$row
    port=${row%%$'\t'*}
    row=${row#*$'\t'}
    scope=${row%%$'\t'*}
    row=${row#*$'\t'}
    command=${row%%$'\t'*}
    pid=${row#*$'\t'}
    rig_table_add_row "$port" tcp "$scope" unmanaged \
      "owner:${command:--};pid:${pid:--}" || return 2
    count=$((count + 1))
  done
  rig_table_print
  printf 'Unmanaged listeners: %s\n' "$count"
}

rig_print_resource_status() {
  local index section_name section_index kind id provider state detail unhealthy
  local problems

  problems=${1:-0}
  unhealthy=0
  rig_table_reset
  rig_table_add_column RESOURCE 26 end keep
  rig_table_add_column KIND 14
  rig_table_add_column PROVIDER 18 end keep
  rig_table_add_column STATE 12
  rig_table_add_column DETAIL 42
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
    if [ "$problems" -eq 0 ] || [ "$state" != present ]; then
      rig_table_add_row "$id" "$kind" "$provider" "$state" "$detail" || return 2
    fi
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_STALE_RESOURCE_IDS[@]}" ]; do
    rig_table_add_row \
      "${RIG_STALE_RESOURCE_IDS[$index]}" \
      "${RIG_STALE_RESOURCE_KINDS[$index]}" \
      "${RIG_STALE_RESOURCE_PROVIDERS[$index]}" \
      drifted \
      "retire-pending:${RIG_STALE_RESOURCE_LOCATORS[$index]}" || return 2
    unhealthy=$((unhealthy + 1))
    index=$((index + 1))
  done
  if [ "$problems" -eq 0 ] || [ "$RIG_TABLE_ROW_COUNT" -gt 0 ]; then
    printf '\n'
    rig_table_print
    printf 'Resource summary: selected=%s retire-pending=%s unhealthy=%s\n' \
      "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" "${#RIG_STALE_RESOURCE_IDS[@]}" "$unhealthy"
  fi
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
  RIG_SKILLS_INVENTORY_DETAIL='inventory-unavailable'
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
  if [ "$depth" -ne 0 ] || [ "$quoted" -ne 0 ]; then
    RIG_SKILLS_INVENTORY_DETAIL='malformed-json'
    return 0
  fi
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
      RIG_OBSERVATION_DETAIL='inventory-unavailable'
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
  rig_progress_start 'skill observation' "${#RIG_SELECTED_SKILLS[@]}"
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    skill=${RIG_SELECTED_SKILLS[$index]}
    rig_progress_begin "skill.$skill"
    rig_observe_skill "$skill" || return
    RIG_SKILL_STATES[$index]=$RIG_OBSERVATION
    RIG_SKILL_DETAILS[$index]=$RIG_OBSERVATION_DETAIL
    case "$RIG_OBSERVATION" in
      unknown|unavailable) rig_progress_result failed "skill.$skill" ;;
      *) rig_progress_result succeeded "skill.$skill" ;;
    esac
    index=$((index + 1))
  done
  rig_progress_finish
}

rig_print_skill_status() {
  local index skill authority state detail unhealthy problems

  problems=${1:-0}
  rig_table_reset
  rig_table_add_column SKILL 28 end keep
  rig_table_add_column AUTHORITY 20 end keep
  rig_table_add_column STATE 12
  rig_table_add_column DETAIL 54
  unhealthy=0
  index=0
  while [ "$index" -lt "${#RIG_SELECTED_SKILLS[@]}" ]; do
    skill=${RIG_SELECTED_SKILLS[$index]}
    rig_get_value "skill.$skill" authority || return 2
    authority=$RIG_VALUE
    state=${RIG_SKILL_STATES[$index]}
    detail=${RIG_SKILL_DETAILS[$index]}
    [ "$state" = present ] || unhealthy=$((unhealthy + 1))
    if [ "$problems" -eq 0 ] || [ "$state" != present ]; then
      rig_table_add_row "$skill" "$authority" "$state" "$detail" || return 2
    fi
    index=$((index + 1))
  done
  if [ "$problems" -eq 0 ] || [ "$RIG_TABLE_ROW_COUNT" -gt 0 ]; then
    printf '\n'
    rig_table_print
    printf 'Skill summary: selected=%s unhealthy=%s\n' \
      "${#RIG_SELECTED_SKILLS[@]}" "$unhealthy"
  fi
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
  printf '\n'
  rig_table_reset
  rig_table_add_column SKILL 28 end keep
  rig_table_add_column AUTHORITY 20 end keep
  rig_table_add_column STATE 12
  rig_table_add_column DETAIL 54
  index=0
  while [ "$index" -lt "${#RIG_SKILLS_INVENTORY_NAMES[@]}" ]; do
    name=${RIG_SKILLS_INVENTORY_NAMES[$index]}
    if ! rig_skill_source_is_declared "$name"; then
      rig_table_add_row "$name" skills-cli unmanaged global || return 2
      count=$((count + 1))
    fi
    index=$((index + 1))
  done
  rig_table_print
  printf 'Unmanaged skills: %s\n' "$count"
}

rig_status_tool_state() {
  if [ "${RIG_PLAN_RESULTS[$1]}" = neutral ]; then
    RIG_VALUE=catalogue-only
  else
    RIG_VALUE=${RIG_PLAN_STATES[$1]}
  fi
}

rig_status_totals() {
  local index state

  RIG_STATUS_TOOL_UNHEALTHY=0
  RIG_STATUS_SKILL_UNHEALTHY=0
  RIG_STATUS_RESOURCE_UNHEALTHY=0
  RIG_STATUS_PORT_UNHEALTHY=0
  RIG_STATUS_SELECTED=0
  RIG_STATUS_PRESENT=0
  RIG_STATUS_MISSING=0
  RIG_STATUS_DRIFTED=0
  RIG_STATUS_UNAVAILABLE=0
  RIG_STATUS_UNKNOWN=0
  RIG_STATUS_CATALOGUE_ONLY=0
  RIG_STATUS_UNHEALTHY=0
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    rig_status_tool_state "$index"
    state=$RIG_VALUE
    case "$state" in
      present) RIG_STATUS_PRESENT=$((RIG_STATUS_PRESENT + 1)) ;;
      missing) RIG_STATUS_MISSING=$((RIG_STATUS_MISSING + 1)) ;;
      drifted) RIG_STATUS_DRIFTED=$((RIG_STATUS_DRIFTED + 1)) ;;
      unavailable) RIG_STATUS_UNAVAILABLE=$((RIG_STATUS_UNAVAILABLE + 1)) ;;
      catalogue-only) RIG_STATUS_CATALOGUE_ONLY=$((RIG_STATUS_CATALOGUE_ONLY + 1)) ;;
      unknown) RIG_STATUS_UNKNOWN=$((RIG_STATUS_UNKNOWN + 1)) ;;
    esac
    rig_status_needs_attention "$index" &&
      RIG_STATUS_TOOL_UNHEALTHY=$((RIG_STATUS_TOOL_UNHEALTHY + 1))
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_SKILL_STATES[@]}" ]; do
    [ "${RIG_SKILL_STATES[$index]}" = present ] ||
      RIG_STATUS_SKILL_UNHEALTHY=$((RIG_STATUS_SKILL_UNHEALTHY + 1))
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_STATES[@]}" ]; do
    [ "${RIG_RESOURCE_PLAN_STATES[$index]}" = present ] ||
      RIG_STATUS_RESOURCE_UNHEALTHY=$((RIG_STATUS_RESOURCE_UNHEALTHY + 1))
    index=$((index + 1))
  done
  RIG_STATUS_RESOURCE_UNHEALTHY=$((RIG_STATUS_RESOURCE_UNHEALTHY \
    + ${#RIG_STALE_RESOURCE_IDS[@]}))
  index=0
  while [ "$index" -lt "${#RIG_PORT_STATES[@]}" ]; do
    [ "${RIG_PORT_STATES[$index]}" = present ] ||
      RIG_STATUS_PORT_UNHEALTHY=$((RIG_STATUS_PORT_UNHEALTHY + 1))
    index=$((index + 1))
  done
  RIG_STATUS_UNHEALTHY=$((RIG_STATUS_TOOL_UNHEALTHY + RIG_STATUS_SKILL_UNHEALTHY \
    + RIG_STATUS_RESOURCE_UNHEALTHY + RIG_STATUS_PORT_UNHEALTHY))
  RIG_STATUS_SELECTED=$((${#RIG_PLAN_TOOLS[@]} + ${#RIG_SKILL_STATES[@]} \
    + ${#RIG_RESOURCE_PLAN_STATES[@]} + ${#RIG_STALE_RESOURCE_IDS[@]} \
    + ${#RIG_PORT_STATES[@]}))
}

# A catalogue-only tool is observed by artefact and materialises through no
# provider, so a state other than present is the truth about it rather than
# work for a person. The apply result records that neutrality.
rig_status_needs_attention() {
  local index

  index=$1
  [ "${RIG_PLAN_RESULTS[$index]}" != neutral ] || return 1
  [ "${RIG_PLAN_STATES[$index]}" != present ] || return 1
}

# The verdict a reader wants before any table: how much of the selection needs
# them, and where. Sections with nothing outstanding are not named.
rig_print_status_verdict() {
  local breakdown noun

  breakdown=
  noun=entries
  [ "$RIG_STATUS_SELECTED" -ne 1 ] || noun=entry
  if [ "$RIG_STATUS_UNHEALTHY" -gt 0 ]; then
    [ "$RIG_STATUS_TOOL_UNHEALTHY" -eq 0 ] ||
      breakdown="tools $RIG_STATUS_TOOL_UNHEALTHY"
    if [ "$RIG_STATUS_SKILL_UNHEALTHY" -gt 0 ]; then
      [ -z "$breakdown" ] || breakdown="$breakdown, "
      breakdown="${breakdown}skills $RIG_STATUS_SKILL_UNHEALTHY"
    fi
    if [ "$RIG_STATUS_RESOURCE_UNHEALTHY" -gt 0 ]; then
      [ -z "$breakdown" ] || breakdown="$breakdown, "
      breakdown="${breakdown}resources $RIG_STATUS_RESOURCE_UNHEALTHY"
    fi
    if [ "$RIG_STATUS_PORT_UNHEALTHY" -gt 0 ]; then
      [ -z "$breakdown" ] || breakdown="$breakdown, "
      breakdown="${breakdown}ports $RIG_STATUS_PORT_UNHEALTHY"
    fi
  fi
  if [ -n "$breakdown" ]; then
    printf 'Needs attention: %s of %s %s (%s)\n' \
      "$RIG_STATUS_UNHEALTHY" "$RIG_STATUS_SELECTED" "$noun" "$breakdown"
  else
    printf 'Needs attention: %s of %s %s\n' \
      "$RIG_STATUS_UNHEALTHY" "$RIG_STATUS_SELECTED" "$noun"
  fi
}

rig_json_envelope() {
  rig_json_escape "$RIG_VERSION"
  printf '{"schema":1,"rig":"%s","command":"%s"' "$RIG_VALUE" "$1"
  rig_json_field ',' profile "$RIG_RESOLVED_PROFILE"
  rig_json_field ',' platform "$RIG_RESOLVED_PLATFORM"
  RIG_VALUE=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null) || RIG_VALUE=
  if [ -n "$RIG_VALUE" ]; then
    printf ',"observed_at":"%s"' "$RIG_VALUE"
  else
    printf ',"observed_at":null'
  fi
}

rig_status_json() {
  local unmanaged_requested retired_requested index separator healthy port section_name number mode owner state

  unmanaged_requested=$1
  retired_requested=${2:-0}
  rig_json_envelope status
  if [ "$RIG_STATUS_UNHEALTHY" -eq 0 ] && rig_history_healthy; then healthy=true; else healthy=false; fi
  printf ',"healthy":%s' "$healthy"
  printf ',"summary":{"present":%s,"missing":%s,"drifted":%s,"unavailable":%s,"unknown":%s,"catalogue_only":%s,"unhealthy":%s}' \
    "$RIG_STATUS_PRESENT" "$RIG_STATUS_MISSING" "$RIG_STATUS_DRIFTED" \
    "$RIG_STATUS_UNAVAILABLE" "$RIG_STATUS_UNKNOWN" "$RIG_STATUS_CATALOGUE_ONLY" \
    "$RIG_STATUS_UNHEALTHY"
  printf ',"historical_failure_count":%s' "${#RIG_APPLY_FAILURE_KEYS[@]}"

  printf ',"tools":['
  index=0
  separator=
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    rig_status_tool_state "$index"
    state=$RIG_VALUE
    rig_json_field "$separator{" id "${RIG_PLAN_TOOLS[$index]}"
    rig_json_field ',' provider "${RIG_PLAN_PROVIDERS[$index]}"
    rig_json_field ',' state "$state"
    rig_json_field ',' detail "${RIG_PLAN_DETAILS[$index]}"
    printf '}'
    separator=,
    index=$((index + 1))
  done
  printf ']'

  printf ',"skills":['
  index=0
  separator=
  while [ "$index" -lt "${#RIG_SKILL_STATES[@]}" ]; do
    rig_get_value "skill.${RIG_SELECTED_SKILLS[$index]}" authority || return 2
    rig_json_field "$separator{" id "${RIG_SELECTED_SKILLS[$index]}"
    rig_json_field ',' authority "$RIG_VALUE"
    rig_json_field ',' state "${RIG_SKILL_STATES[$index]}"
    rig_json_field ',' detail "${RIG_SKILL_DETAILS[$index]}"
    printf '}'
    separator=,
    index=$((index + 1))
  done
  printf ']'

  printf ',"resources":['
  index=0
  separator=
  while [ "$index" -lt "${#RIG_RESOURCE_PLAN_STATES[@]}" ]; do
    section_name=${RIG_RESOURCE_PLAN_SECTIONS[$index]}
    rig_section_index "$section_name" || return 2
    rig_get_value "$section_name" provider || return 2
    owner=$RIG_VALUE
    rig_json_field "$separator{" id "${RIG_SECTION_IDS[$RIG_INDEX]}"
    rig_json_field ',' kind "${RIG_SECTION_TYPES[$RIG_INDEX]}"
    rig_json_field ',' provider "$owner"
    rig_json_field ',' state "${RIG_RESOURCE_PLAN_STATES[$index]}"
    rig_json_field ',' detail "${RIG_RESOURCE_PLAN_DETAILS[$index]}"
    printf '}'
    separator=,
    index=$((index + 1))
  done
  index=0
  while [ "$index" -lt "${#RIG_STALE_RESOURCE_IDS[@]}" ]; do
    rig_json_field "$separator{" id "${RIG_STALE_RESOURCE_IDS[$index]}"
    rig_json_field ',' kind "${RIG_STALE_RESOURCE_KINDS[$index]}"
    rig_json_field ',' provider "${RIG_STALE_RESOURCE_PROVIDERS[$index]}"
    rig_json_field ',' state drifted
    rig_json_field ',' detail "retire-pending:${RIG_STALE_RESOURCE_LOCATORS[$index]}"
    printf '}'
    separator=,
    index=$((index + 1))
  done
  printf ']'

  printf ',"ports":['
  index=0
  separator=
  while [ "$index" -lt "${#RIG_PORT_STATES[@]}" ]; do
    port=${RIG_SELECTED_PORTS[$index]}
    section_name=port.$port
    rig_get_value "$section_name" port || return 2
    number=$RIG_VALUE
    rig_get_value "$section_name" mode || return 2
    mode=$RIG_VALUE
    rig_get_value "$section_name" owner || return 2
    owner=$RIG_VALUE
    rig_json_field "$separator{" id "$port"
    printf ',"number":%s' "$number"
    rig_json_field ',' protocol tcp
    rig_json_field ',' mode "$mode"
    rig_json_field ',' owner "$owner"
    rig_json_field ',' state "${RIG_PORT_STATES[$index]}"
    rig_json_field ',' detail "${RIG_PORT_DETAILS[$index]}"
    printf '}'
    separator=,
    index=$((index + 1))
  done
  printf ']'

  if [ "$unmanaged_requested" -eq 1 ]; then
    printf ',"unmanaged":['
    index=0
    separator=
    while [ "$index" -lt "${#RIG_UNMANAGED_IDENTITIES[@]}" ]; do
      rig_json_field "$separator{" id "${RIG_UNMANAGED_IDENTITIES[$index]}"
      rig_json_field ',' provider "${RIG_UNMANAGED_PROVIDERS[$index]}"
      rig_json_field ',' state unmanaged
      rig_json_field ',' detail "${RIG_UNMANAGED_DETAILS[$index]}"
      printf '}'
      separator=,
      index=$((index + 1))
    done
    printf '],"unmanaged_problems":['
    index=0
    separator=
    while [ "$index" -lt "${#RIG_UNMANAGED_PROBLEMS[@]}" ]; do
      rig_json_escape "${RIG_UNMANAGED_PROBLEMS[$index]}"
      printf '%s"%s"' "$separator" "$RIG_VALUE"
      separator=,
      index=$((index + 1))
    done
    printf ']'
  else
    printf ',"unmanaged":null,"unmanaged_problems":null'
  fi
  if [ "$retired_requested" -eq 1 ]; then
    rig_retired_json
  fi
  rig_history_json
  printf '}\n'
  [ "$RIG_STATUS_UNHEALTHY" -eq 0 ] && rig_history_healthy
}

rig_command_status() {
  local profile index tool provider state detail unmanaged_requested format
  local problems retired_requested

  profile=
  unmanaged_requested=0
  retired_requested=0
  format=text
  problems=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        rig_command_help status
        return
        ;;
      --unmanaged)
        unmanaged_requested=1
        shift
        ;;
      --retired)
        retired_requested=1
        shift
        ;;
      --problems)
        problems=1
        shift
        ;;
      --profile)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          rig_command_syntax_error status
          return
        fi
        profile=$2
        shift 2
        ;;
      --format)
        case "${2:-}" in
          text|json) format=$2 ;;
          *)
            rig_command_syntax_error status
            return
            ;;
        esac
        shift 2
        ;;
      *)
        rig_command_syntax_error status
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
  if [ "$unmanaged_requested" -eq 1 ]; then
    rig_collect_unmanaged || return
  fi
  if [ "$retired_requested" -eq 1 ]; then
    rig_collect_retired_applications || return
  fi
  rig_status_totals
  rig_history_project || return
  if [ "$RIG_STATUS_UNHEALTHY" -eq 0 ] && rig_history_healthy; then
    rig_outcome_note healthy "present=$RIG_STATUS_PRESENT"
  else
    rig_outcome_note unhealthy "unhealthy=$RIG_STATUS_UNHEALTHY present=$RIG_STATUS_PRESENT historical=${#RIG_APPLY_FAILURE_KEYS[@]} history-unavailable=${RIG_APPLY_HISTORY_UNAVAILABLE:-no}"
  fi
  if [ "$format" = json ]; then
    rig_status_json "$unmanaged_requested" "$retired_requested"
    return
  fi
  rig_print_status_verdict
  if ! rig_history_healthy; then
    printf 'Historical attention: failures=%s history-unavailable=%s (separate from current observations)\n' \
      "${#RIG_APPLY_FAILURE_KEYS[@]}" "${RIG_APPLY_HISTORY_UNAVAILABLE:-no}"
  fi
  printf 'Profile: %s\nPlatform: %s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  rig_table_reset
  rig_table_add_column TOOL 28 end keep
  rig_table_add_column PROVIDER 18 end keep
  rig_table_add_column STATE 14
  rig_table_add_column DETAIL 56
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    rig_status_tool_state "$index"
    state=$RIG_VALUE
    detail=${RIG_PLAN_DETAILS[$index]}
    if [ "$problems" -eq 0 ] || rig_status_needs_attention "$index"; then
      rig_table_add_row "$tool" "$provider" "$state" "$detail" || return 2
    fi
    index=$((index + 1))
  done
  if [ "$problems" -eq 0 ] || [ "$RIG_TABLE_ROW_COUNT" -gt 0 ]; then
    rig_table_print
    printf 'Summary: present=%s missing=%s drifted=%s unavailable=%s unknown=%s catalogue-only=%s\n' \
      "$RIG_STATUS_PRESENT" "$RIG_STATUS_MISSING" "$RIG_STATUS_DRIFTED" \
      "$RIG_STATUS_UNAVAILABLE" "$RIG_STATUS_UNKNOWN" "$RIG_STATUS_CATALOGUE_ONLY"
  fi
  if [ "${#RIG_SELECTED_SKILLS[@]}" -gt 0 ]; then
    rig_print_skill_status "$problems" || return
  fi
  if [ "${#RIG_RESOURCE_PLAN_SECTIONS[@]}" -gt 0 ] ||
    [ "${#RIG_STALE_RESOURCE_IDS[@]}" -gt 0 ]; then
    rig_print_resource_status "$problems" || return
  fi
  if [ "${#RIG_SELECTED_PORTS[@]}" -gt 0 ]; then
    rig_print_port_status "$problems" || return
  fi
  if [ "$unmanaged_requested" -eq 1 ]; then
    printf '\n'
    rig_table_reset
    rig_table_add_column IDENTITY 32 end keep
    rig_table_add_column PROVIDER 18 end keep
    rig_table_add_column STATE 12
    rig_table_add_column DETAIL 52
    index=0
    while [ "$index" -lt "${#RIG_UNMANAGED_IDENTITIES[@]}" ]; do
      rig_table_add_row \
        "${RIG_UNMANAGED_IDENTITIES[$index]}" \
        "${RIG_UNMANAGED_PROVIDERS[$index]}" \
        unmanaged \
        "${RIG_UNMANAGED_DETAILS[$index]}" || return 2
      index=$((index + 1))
    done
    rig_table_print
    index=0
    while [ "$index" -lt "${#RIG_UNMANAGED_PROBLEMS[@]}" ]; do
      printf '%s\n' "${RIG_UNMANAGED_PROBLEMS[$index]}"
      index=$((index + 1))
    done
    printf 'Unmanaged: %s\n' "${#RIG_UNMANAGED_IDENTITIES[@]}"
    rig_print_unmanaged_listeners || return
    rig_print_unmanaged_skills || return
  fi
  if [ "$retired_requested" -eq 1 ]; then
    rig_retired_print || return
  fi
  rig_history_print || return
  [ "$RIG_STATUS_UNHEALTHY" -eq 0 ] && rig_history_healthy
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

rig_doctor_competing_autoupdate() {
  local platform declared

  platform=$1
  RIG_VALUE=
  [ "$platform" = macos ] || return 0
  [ -n "${HOME:-}" ] || return 0
  [ -f "$HOME/Library/LaunchAgents/com.github.domt4.homebrew-autoupdate.plist" ] || return 0
  declared=0
  ! rig_get_value provider.homebrew autoupdate-interval || declared=1
  # A declared interval is Rig's own agent; an undeclared one advances Homebrew
  # alone on a private timer, which is the person's call to keep or retire.
  [ "$declared" -eq 0 ] || { RIG_VALUE=; return 0; }
  RIG_VALUE='  homebrew: autoupdate-agent; owner=homebrew; action=none'
}

rig_doctor_incompatible_tools() {
  local profile platform index tool count information
  local -a tools

  profile=$1
  platform=$2
  count=0
  information=
  rig_collect_section_ids tool
  tools=("${RIG_QUERY_ITEMS[@]+"${RIG_QUERY_ITEMS[@]}"}")
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
  local findings_output progress_label

  findings=0
  present=0
  catalogue_only=0
  findings_output=
  RIG_PLAN_RESULTS=()
  RIG_PLAN_DETAILS=()
  RIG_PLAN_STATES=()
  rig_progress_start 'tool observation' "${#RIG_PLAN_TOOLS[@]}"
  index=0
  while [ "$index" -lt "${#RIG_PLAN_TOOLS[@]}" ]; do
    tool=${RIG_PLAN_TOOLS[$index]}
    binding=${RIG_PLAN_BINDINGS[$index]}
    provider=${RIG_PLAN_PROVIDERS[$index]}
    # A catalogue-only tool records its provider as the empty marker, and a
    # qualified identity that names no provider is worse than a bare one.
    progress_label=$tool
    case "$provider" in
    ''|-) ;;
    *) progress_label="$provider:$tool" ;;
    esac
    rig_progress_begin "$progress_label"
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
    case "${RIG_PLAN_RESULTS[$index]}" in
      neutral|skipped) rig_progress_result skipped "$progress_label" ;;
      observed) rig_progress_result succeeded "$progress_label" ;;
      *) rig_progress_result failed "$progress_label" ;;
    esac
    index=$((index + 1))
  done
  rig_progress_finish
  RIG_VALUE=${findings_output%$'\n'}
  RIG_DOCTOR_FINDINGS=$findings
  RIG_DOCTOR_PRESENT=$present
  RIG_DOCTOR_CATALOGUE_ONLY=$catalogue_only
}

rig_json_lines() {
  local blob line separator

  blob=$1
  printf '['
  separator=
  if [ -n "$blob" ]; then
    while IFS= read -r line; do
      line=${line#"${line%%[![:space:]]*}"}
      [ -n "$line" ] || continue
      rig_json_escape "$line"
      printf '%s"%s"' "$separator" "$RIG_VALUE"
      separator=,
    done <<< "$blob"
  fi
  printf ']'
}

rig_doctor_native_availability() {
  local executable state

  for executable in brew uv mise npm chezmoi; do
    if rig_executable_available "$executable"; then
      state=available
    else
      state=unavailable
    fi
    printf '  %s: %s; owner=environment; action=none\n' "$executable" "$state"
  done
}

rig_command_doctor() {
  local profile findings incompatible xdg_findings tool_findings resource_findings port_findings skill_findings
  local index section_name state detail port owner action skill authority format information config_finding config_loaded
  local verbose profile_seen format_seen checks_passed checks_skipped checks_total checks_coverage

  profile=
  format=text
  verbose=0
  profile_seen=0
  format_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        [ "$#" -eq 1 ] || rig_command_syntax_error doctor || return
        rig_command_help doctor
        return
        ;;
      --profile)
        if [ "$profile_seen" -eq 1 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
          rig_command_syntax_error doctor
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --format)
        [ "$format_seen" -eq 0 ] || rig_command_syntax_error doctor || return
        case "${2:-}" in
          text|json) format=$2 ;;
          *)
            rig_command_syntax_error doctor
            return
            ;;
        esac
        format_seen=1
        shift 2
        ;;
      --verbose)
        [ "$verbose" -eq 0 ] || rig_command_syntax_error doctor || return
        verbose=1
        shift
        ;;
      *)
        rig_command_syntax_error doctor
        return
        ;;
    esac
  done

  RIG_CAPTURED_ERROR=
  RIG_CAPTURE_ERROR=1
  if rig_load_config; then
    config_loaded=1
  else
    config_loaded=0
  fi
  RIG_CAPTURE_ERROR=0
  config_finding=
  if [ "$config_loaded" -eq 1 ]; then
    rig_resolve_operational_plan "$profile" load preloaded || return
  else
    config_finding="  ${RIG_CAPTURED_ERROR:-configuration could not be loaded}; owner=configuration; action=correct-configuration"
    RIG_RESOLVED_PROFILE=${profile:--}
    rig_diagnostic_platform
    RIG_RESOLVED_PLATFORM=$RIG_VALUE
  fi
  rig_effective_paths || return 2
  tool_findings=
  resource_findings=
  port_findings=
  skill_findings=
  findings=0
  incompatible=0
  information=
  if [ "$config_loaded" -eq 0 ]; then
    findings=1
    RIG_DOCTOR_PRESENT=0
    RIG_DOCTOR_CATALOGUE_ONLY=0
    information=$(printf '  config path: %s\n  data path: %s\n  state path: %s\n  cache path: %s\n' \
      "$RIG_DIAG_CONFIG_HOME" "$RIG_DIAG_DATA_HOME" "$RIG_DIAG_STATE_HOME" "$RIG_DIAG_CACHE_HOME"; \
      rig_doctor_native_availability)
  else
  rig_observe_plan || return
  tool_findings=$RIG_VALUE
  findings=$RIG_DOCTOR_FINDINGS
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
  rig_doctor_incompatible_tools "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  incompatible=$RIG_COUNT
  information=$RIG_VALUE
  rig_doctor_competing_autoupdate "$RIG_RESOLVED_PLATFORM"
  if [ -n "$RIG_VALUE" ]; then
    if [ -n "$information" ]; then
      information="${information}"$'\n'"$RIG_VALUE"
    else
      information=$RIG_VALUE
    fi
  fi
  fi
  xdg_findings=$(rig_doctor_path_finding config "$RIG_DIAG_CONFIG_HOME"; \
    rig_doctor_path_finding data "$RIG_DIAG_DATA_HOME"; \
    rig_doctor_path_finding state "$RIG_DIAG_STATE_HOME"; \
    rig_doctor_path_finding cache "$RIG_DIAG_CACHE_HOME")
  if [ -n "$xdg_findings" ]; then
    while IFS= read -r _; do findings=$((findings + 1)); done <<< "$xdg_findings"
  fi
  RIG_APPLY_FAILURE_KEYS=(); RIG_APPLY_FAILURE_TIMES=(); RIG_APPLY_FAILURE_STATUSES=(); RIG_APPLY_FAILURE_AGES=()
  RIG_APPLY_HISTORY_UNAVAILABLE=
  if [ "$config_loaded" -eq 1 ]; then
    rig_history_project || return
    findings=$((findings + ${#RIG_APPLY_FAILURE_KEYS[@]}))
  elif ! rig_history_load "$RIG_RESOLVED_PLATFORM"; then
    RIG_APPLY_HISTORY_UNAVAILABLE=$RIG_HISTORY_ERROR
  fi
  [ -z "$RIG_APPLY_HISTORY_UNAVAILABLE" ] || findings=$((findings + 1))

  # Counts use one evaluated item/configuration/path/history check as the unit,
  # not individual subprocess calls or progress events. Neutral selections skip.
  checks_total=6
  checks_skipped=0
  checks_coverage=configuration,xdg,apply-history
  if [ "$config_loaded" -eq 1 ]; then
    checks_total=$((checks_total + ${#RIG_PLAN_TOOLS[@]} + ${#RIG_RESOURCE_PLAN_SECTIONS[@]} + \
      ${#RIG_STALE_RESOURCE_IDS[@]} + ${#RIG_SELECTED_PORTS[@]} + ${#RIG_SELECTED_SKILLS[@]} + \
      ${#RIG_APPLY_FAILURE_KEYS[@]} + incompatible))
    checks_skipped=$((RIG_DOCTOR_CATALOGUE_ONLY + incompatible))
    checks_coverage=configuration,xdg,tools,resources,ports,skills,apply-history
  else
    # One dependent selection group could not be evaluated at all.
    checks_total=$((checks_total + 1))
    checks_skipped=1
  fi
  checks_passed=$((checks_total - checks_skipped - findings))
  rig_diagnostic_context || return

  if [ "$format" = json ]; then
    rig_json_envelope doctor
    printf ',"context":'
    rig_diagnostic_context_json
    [ "$findings" -eq 0 ] && state=healthy || state=unhealthy
    rig_json_field ',' verdict "$state"
    printf ',"checks":{"pass":%s,"warn":0,"fail":%s,"skipped":%s,"unit":"item","coverage":' \
      "$checks_passed" "$findings" "$checks_skipped"
    rig_json_escape "$checks_coverage"
    printf '"%s"' "$RIG_VALUE"
    printf ',"read_only":true,"freshness":"not-checked"}'
    [ "$findings" -eq 0 ] && state=true || state=false
    printf ',"healthy":%s' "$state"
    printf ',"summary":{"findings":%s,"present":%s,"catalogue_only":%s,"incompatible_platform":%s}' \
      "$findings" "$RIG_DOCTOR_PRESENT" "$RIG_DOCTOR_CATALOGUE_ONLY" "$incompatible"
    printf ',"historical_failure_count":%s' "${#RIG_APPLY_FAILURE_KEYS[@]}"
    printf ',"findings":{"configuration":'
    rig_json_lines "$config_finding"
    printf ',"xdg":'
    rig_json_lines "$xdg_findings"
    printf ',"tools":'
    rig_json_lines "$tool_findings"
    printf ',"resources":'
    rig_json_lines "$resource_findings"
    printf ',"ports":'
    rig_json_lines "$port_findings"
    printf ',"skills":'
    rig_json_lines "$skill_findings"
    printf '},"information":'
    rig_json_lines "$information"
    if [ "$verbose" -eq 1 ]; then
      printf ',"diagnostics":'
      rig_doctor_diagnostics "$config_loaded" json || return
    fi
    rig_history_json
    printf '}\n'
    [ "$findings" -eq 0 ]
    return
  fi
  printf 'Verdict: %s\nProfile: %s\nSelected platform: %s\n' \
    "$([ "$findings" -eq 0 ] && printf healthy || printf unhealthy)" \
    "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  rig_diagnostic_context_text
  printf 'Scope: read-only declared setup health; package updates not checked\nCoverage: %s\nChecks: pass=%s warn=0 fail=%s skipped=%s (unit=item)\n' \
    "$checks_coverage" "$checks_passed" "$findings" "$checks_skipped"
  if [ -n "$config_finding" ]; then
    printf 'Configuration findings:\n%s\n' "$config_finding"
  fi
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
  if [ -n "$information" ]; then
    printf 'Information:\n%s\n' "$information"
  fi
  rig_history_print || return
  printf 'Summary: findings=%s present=%s catalogue-only=%s incompatible-platform=%s\n' \
    "$findings" "$RIG_DOCTOR_PRESENT" "$RIG_DOCTOR_CATALOGUE_ONLY" "$incompatible"
  if [ "$verbose" -eq 1 ]; then
    rig_doctor_diagnostics "$config_loaded" text || return
  fi
  if [ "$findings" -eq 0 ]; then
    rig_outcome_note healthy "findings=0 present=$RIG_DOCTOR_PRESENT"
  else
    rig_outcome_note unhealthy "findings=$findings"
  fi
  [ "$findings" -eq 0 ]
}
