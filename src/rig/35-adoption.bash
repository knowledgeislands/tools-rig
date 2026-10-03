# rig-module: 35-adoption
# shellcheck shell=bash
# Cross-module state is intentionally consumed by the assembled runtime.
# shellcheck disable=SC2034

rig_adoption_config_home() {
  if [ -n "${RIG_CONFIG_HOME:-}" ]; then
    RIG_VALUE=$RIG_CONFIG_HOME
  else
    [ -n "${HOME:-}" ] || rig_fail 'HOME is required when RIG_CONFIG_HOME is not set' || return
    RIG_VALUE=${XDG_CONFIG_HOME:-$HOME/.config}/rig
  fi
}

rig_init_content() {
  printf '%s\n' '[rig]' 'default-profile = "default"' '' \
    '[profile.default]' 'name = "Default"' 'kind = "complete"'
}

rig_schema_repair_render() {
  local source omit line number
  source=$1; omit=$2; number=0
  while IFS= read -r line; do
    number=$((number + 1))
    [ "$number" -eq "$omit" ] || printf '%s\n' "$line"
  done <"$source"
  if [ -n "$line" ]; then
    number=$((number + 1))
    [ "$number" -eq "$omit" ] || printf '%s' "$line"
  fi
}

rig_schema_repair() {
  local dry_run output config_home source line stripped section key value number found source_file source_line
  dry_run=$1; output=$2
  rig_load_config || return
  if ! rig_get_value rig schema; then
    printf '%s\n' 'Configuration is already unversioned; no repair needed.'
    return 0
  fi
  rig_adoption_config_home || return
  config_home=$RIG_VALUE
  found=0; source_file=; source_line=0
  for source in "$config_home/rig.toml" "$config_home"/conf.d/*.toml; do
    [ -f "$source" ] || continue
    section=; number=0
    while IFS= read -r line || [ -n "$line" ]; do
      number=$((number + 1))
      rig_toml_strip_comment "$line" || return
      rig_trim "$RIG_VALUE"
      stripped=$RIG_VALUE
      case "$stripped" in
        \[*\]) section=${stripped#\[}; section=${section%\]} ;;
        *=*)
          [ "$section" = rig ] || continue
          key=${stripped%%=*}; value=${stripped#*=}
          rig_trim "$key"; key=$RIG_VALUE
          rig_trim "$value"; value=$RIG_VALUE
          if [ "$key" = schema ] && [ "$value" = 1 ]; then
            found=$((found + 1)); source_file=$source; source_line=$number
          fi
          ;;
      esac
    done <"$source"
  done
  [ "$found" -eq 1 ] || rig_fail 'cannot isolate one recognised legacy schema field for repair' || return
  if [ "$dry_run" -eq 1 ]; then
    printf 'Would remove the legacy schema field at %s:%s; active configuration is unchanged.\n' "$source_file" "$source_line"
    rig_schema_repair_render "$source_file" "$source_line"
    return
  fi
  [ -n "$output" ] || rig_fail 'repair requires --output PATH outside active configuration; preview with --dry-run' || return
  rig_capture_output_path "$output" || return
  output=$RIG_VALUE
  (umask 077; set -C; rig_schema_repair_render "$source_file" "$source_line" >"$output") || {
    rig_fail "could not create repaired proposal: $output"; return;
  }
  printf 'Created repaired proposal: %s\nReview it, then replace %s manually.\n' "$output" "$source_file"
}

rig_command_init() {
  local dry_run repair output config_home target fragment

  dry_run=0; repair=0; output=
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help) [ "$#" -eq 1 ] || rig_command_syntax_error init || return
        rig_command_help init; return ;;
      --dry-run) [ "$dry_run" -eq 0 ] || rig_command_syntax_error init || return
        dry_run=1; shift ;;
      --repair-schema) [ "$repair" -eq 0 ] || rig_command_syntax_error init || return
        repair=1; shift ;;
      --output) [ "$#" -ge 2 ] && [ -n "$2" ] && [ -z "$output" ] || rig_command_syntax_error init || return
        output=$2; shift 2 ;;
      *) rig_command_syntax_error init; return ;;
    esac
  done
  if [ "$repair" -eq 1 ]; then
    [ "$dry_run" -eq 0 ] || [ -z "$output" ] || rig_command_syntax_error init || return
    rig_schema_repair "$dry_run" "$output"
    return
  fi
  [ -z "$output" ] || rig_command_syntax_error init || return
  rig_adoption_config_home || return
  config_home=$RIG_VALUE
  while :; do
    case "$config_home" in
      /) break ;;
      */) config_home=${config_home%/} ;;
      */.) config_home=${config_home%/.} ;;
      *) break ;;
    esac
  done
  [ "$config_home" != / ] || rig_fail 'init configuration directory must not be the filesystem root' || return
  [ -n "$config_home" ] || rig_fail 'init configuration directory must not be the filesystem root' || return
  [ ! -L "$config_home" ] || rig_fail "init configuration directory must not be a symlink: $config_home" || return
  target=$config_home/rig.toml
  [ ! -e "$target" ] && [ ! -L "$target" ] || rig_fail "init will not overwrite existing configuration: $target" || return
  [ ! -L "$config_home/conf.d" ] || rig_fail 'init will not initialise an existing symlinked conf.d' || return
  for fragment in "$config_home"/conf.d/*.toml; do
    [ ! -e "$fragment" ] && [ ! -L "$fragment" ] || rig_fail "init found existing configuration: $fragment" || return
  done
  if [ "$dry_run" -eq 1 ]; then
    printf 'Would create: %s\n' "$target"
    rig_init_content
    return
  fi
  (umask 077; mkdir -p -- "$config_home") || return
  [ ! -L "$config_home" ] || rig_fail 'init configuration directory became a symlink' || return
  (umask 077; set -C; rig_init_content >"$target") || {
    rig_fail "init could not exclusively create configuration: $target"; return;
  }
  printf 'Created: %s\n' "$target"
}

rig_homebrew_normalize_identity() {
  local kind locator
  kind=${1%%:*}
  locator=${1#*:}
  case "$kind:$locator" in
    formula:homebrew/core/*) locator=${locator#homebrew/core/} ;;
    cask:homebrew/cask/*) locator=${locator#homebrew/cask/} ;;
  esac
  RIG_VALUE=$kind:$locator
}

rig_homebrew_identity_declared() {
  local wanted index section kind locator
  rig_homebrew_normalize_identity "$1"
  wanted=$RIG_VALUE
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = binding ] &&
      [ "${RIG_SECTION_SECONDARY_IDS[$index]}" = homebrew ]; then
      section=${RIG_SECTION_NAMES[$index]}
      rig_get_value "$section" kind || return 2
      kind=$RIG_VALUE
      rig_get_value "$section" locator || return 2
      locator=$RIG_VALUE
      rig_homebrew_normalize_identity "$kind:$locator"
      [ "$RIG_VALUE" != "$wanted" ] || return 0
    fi
    index=$((index + 1))
  done
  return 1
}

rig_homebrew_identity_ambiguous() {
  local identity wanted_kind wanted_locator index section kind locator
  identity=$1; wanted_kind=${identity%%:*}; wanted_locator=${identity#*:}
  case "$wanted_locator" in */*) ;; *) return 1 ;; esac
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = binding ] &&
      [ "${RIG_SECTION_SECONDARY_IDS[$index]}" = homebrew ]; then
      section=${RIG_SECTION_NAMES[$index]}
      rig_get_value "$section" kind || return 2; kind=$RIG_VALUE
      rig_get_value "$section" locator || return 2; locator=$RIG_VALUE
      case "$locator" in
        */*) ;;
        *) [ "$kind" != "$wanted_kind" ] || [ "$locator" != "${wanted_locator##*/}" ] || return 0 ;;
      esac
    fi
    index=$((index + 1))
  done
  return 1
}

rig_homebrew_inventory() {
  local provider executable formulae casks locator kind content rows
  local -a provider_arguments
  provider=$1
  RIG_CAPTURED_OUTPUT=
  RIG_NATIVE_STATUS=0
  rig_provider_executable "$provider" homebrew formula || return 2
  executable=$RIG_VALUE
  RIG_INVOKE_ARGUMENTS=()
  rig_append_arguments "provider.$provider" || return
  provider_arguments=("${RIG_INVOKE_ARGUMENTS[@]+"${RIG_INVOKE_ARGUMENTS[@]}"}")
  if ! rig_executable_available "$executable"; then
    RIG_NATIVE_STATUS=127
    return 0
  fi
  formulae=$("$executable" "${provider_arguments[@]+"${provider_arguments[@]}"}" list --formula --installed-on-request --full-name)
  RIG_NATIVE_STATUS=$?
  [ "$RIG_NATIVE_STATUS" -eq 0 ] || return 0
  casks=$("$executable" "${provider_arguments[@]+"${provider_arguments[@]}"}" list --cask --full-name)
  RIG_NATIVE_STATUS=$?
  [ "$RIG_NATIVE_STATUS" -eq 0 ] || return 0
  rows=
  for kind in formula cask; do
    if [ "$kind" = formula ]; then content=$formulae; else content=$casks; fi
    [ -n "$content" ] || continue
    while IFS= read -r locator; do
      # Never turn malformed provider output into declarations or options.
      case "$locator" in
        ''|[!a-zA-Z0-9]*|*[!a-zA-Z0-9@+._/-]*) RIG_NATIVE_STATUS=2; RIG_CAPTURED_OUTPUT=; return 0 ;;
      esac
      rig_homebrew_normalize_identity "$kind:$locator"
      rows=$rows$RIG_VALUE$'\t'
      if [ "$kind" = formula ]; then rows=${rows}installed-on-request; else rows=${rows}installed-cask; fi
      rows=$rows$'\n'
    done <<< "$content"
  done
  RIG_CAPTURED_OUTPUT=${rows%$'\n'}
}

rig_adoption_quote() {
  local value character index
  value=$1
  printf '"'
  index=0
  while [ "$index" -lt "${#value}" ]; do
    character=${value:$index:1}
    case "$character" in
      '"') printf '\\"' ;;
      \\) printf '%s%s' "$character" "$character" ;;
      $'\n') printf '\\n' ;;
      $'\r') printf '\\r' ;;
      $'\t') printf '\\t' ;;
      $'\b') printf '\\b' ;;
      $'\f') printf '\\f' ;;
      *) printf '%s' "$character" ;;
    esac
    index=$((index + 1))
  done
  printf '"'
}

rig_adoption_validate_text() {
  local value character index
  local LC_ALL=C
  value=$1
  index=0
  while [ "$index" -lt "${#value}" ]; do
    character=${value:$index:1}
    case "$character" in
      $'\n'|$'\r'|$'\t'|$'\b'|$'\f') ;;
      [[:cntrl:]]) rig_fail 'capture metadata contains an unsupported control character' || return ;;
    esac
    index=$((index + 1))
  done
}

rig_adoption_tool_id() {
  local identity character index id
  identity=$1
  id=homebrew-
  index=0
  while [ "$index" -lt "${#identity}" ]; do
    character=${identity:$index:1}
    case "$character" in [a-z0-9-]) id=$id$character ;; *) id=$id- ;; esac
    index=$((index + 1))
  done
  RIG_VALUE=$id
}

rig_capture_fragment() {
  local identity id kind locator
  printf '%s\n' '# Review this additive proposal, then copy it into Rig conf.d to adopt it.'
  for identity in "${RIG_CAPTURE_IDENTITIES[@]+"${RIG_CAPTURE_IDENTITIES[@]}"}"; do
    rig_adoption_tool_id "$identity"
    id=$RIG_VALUE
    kind=${identity%%:*}
    locator=${identity#*:}
    printf '\n[tool.%s]\nname = ' "$id"
    rig_adoption_quote "${locator##*/}"
    printf '\ncategory = '; rig_adoption_quote "$RIG_CAPTURE_CATEGORY"
    printf '\npurpose = '; rig_adoption_quote "$RIG_CAPTURE_PURPOSE"
    printf '\nrationale = '; rig_adoption_quote "$RIG_CAPTURE_RATIONALE"
    printf '\nplatforms = ['; rig_adoption_quote "$RIG_CAPTURE_PLATFORM"; printf ']'
    printf '\nprofiles = ['; rig_adoption_quote "$RIG_CAPTURE_PROFILE"; printf ']'
    printf '\ninstall.provider = "homebrew"\ninstall.kind = '; rig_adoption_quote "$kind"
    printf '\ninstall.locator = '; rig_adoption_quote "$locator"
    printf '\n'
  done
}

rig_capture_output_path() {
  local target parent basename config_home physical_config physical_fragments
  target=$1
  [ ! -e "$target" ] && [ ! -L "$target" ] || rig_fail "capture will not overwrite an existing output: $target" || return
  case "$target" in */*) parent=${target%/*}; basename=${target##*/}; [ -n "$parent" ] || parent=/ ;; *) parent=.; basename=$target ;; esac
  case "$basename" in ''|.|..) rig_fail 'capture output must name a new file' || return ;; esac
  parent=$(CDPATH='' cd -- "$parent" 2>/dev/null && pwd -P) || rig_fail 'capture output parent must already exist' || return
  rig_adoption_config_home || return
  config_home=$RIG_VALUE
  physical_config=$(CDPATH='' cd -- "$config_home" 2>/dev/null && pwd -P) || return 2
  case "$parent/" in "$physical_config/"*) rig_fail 'capture output must be outside active Rig configuration; review and adopt the proposal manually' || return ;; esac
  if [ -d "$config_home/conf.d" ]; then
    physical_fragments=$(CDPATH='' cd -- "$config_home/conf.d" && pwd -P) || return 2
    case "$parent/" in "$physical_fragments/"*) rig_fail 'capture output must be outside active Rig configuration fragments; review and adopt the proposal manually' || return ;; esac
  fi
  RIG_VALUE=$parent/$basename
}

rig_command_capture() {
  local provider profile category purpose rationale output dry_run arg seen option
  local inventory identity detail item match count id existing status_value
  local -a items selected ids
  provider=homebrew; profile=; category=; purpose=; rationale=; output=; dry_run=0; seen=' '
  items=(); selected=(); ids=()
  while [ "$#" -gt 0 ]; do
    arg=$1
    case "$arg" in
      -h|--help) [ "$#" -eq 1 ] || rig_command_syntax_error capture || return
        rig_command_help capture; return ;;
      --dry-run) [ "$dry_run" -eq 0 ] || rig_command_syntax_error capture || return
        dry_run=1; shift ;;
      --provider|--profile|--category|--purpose|--rationale|--output)
        [ "$#" -ge 2 ] && [ -n "$2" ] || rig_command_syntax_error capture || return
        case "$seen" in *" $arg "*) rig_command_syntax_error capture; return ;; esac
        seen=$seen$arg' '; option=$2
        case "$arg" in
          --provider) provider=$option ;; --profile) profile=$option ;; --category) category=$option ;;
          --purpose) purpose=$option ;; --rationale) rationale=$option ;; --output) output=$option ;;
        esac
        shift 2 ;;
      -*) rig_command_syntax_error capture; return ;;
      *) items[${#items[@]}]=$arg; shift ;;
    esac
  done
  [ "$provider" = homebrew ] || rig_fail "capture discovery is currently supported only for Homebrew, not '$provider'" || return
  rig_adoption_validate_text "$purpose" || return
  rig_adoption_validate_text "$rationale" || return
  rig_load_config || return
  rig_current_platform || return
  RIG_CAPTURE_PLATFORM=$RIG_VALUE
  [ -n "$profile" ] || { rig_get_value rig default-profile || return; profile=$RIG_VALUE; }
  rig_valid_id "$profile" && rig_reference_exists profile "$profile" || rig_fail "capture references unknown profile '$profile'" || return
  rig_profile_kind "$profile" || return
  [ "$RIG_VALUE" = complete ] || rig_fail 'capture requires a complete profile, not a publication view' || return
  if [ -n "$category" ]; then
    rig_valid_id "$category" && rig_reference_exists category "$category" || rig_fail "capture requires an existing category: $category" || return
  fi
  if [ "${#items[@]}" -gt 0 ] && [ -n "$category" ] && [ -n "$purpose" ] && [ -n "$rationale" ] &&
    [ "$RIG_PROFILE_SELECTION_MODE" = central ]; then
    rig_fail 'capture proposals require item-owned profile membership; convert central profile tools/skills/resources lists to item profiles first, or adopt the selected installation manually' || return
  fi
  if [ -n "$output" ]; then
    [ "${#items[@]}" -gt 0 ] && [ -n "$category" ] && [ -n "$purpose" ] && [ -n "$rationale" ] ||
      rig_fail 'capture --output requires explicit items, category, purpose and rationale' || return
    rig_capture_output_path "$output" || return
    output=$RIG_VALUE
  fi
  rig_homebrew_inventory "$provider" || return
  if [ "$RIG_NATIVE_STATUS" -ne 0 ]; then
    rig_fail "capture could not read Homebrew inventory (exit $RIG_NATIVE_STATUS); no proposal written"
    return 1
  fi
  inventory=$RIG_CAPTURED_OUTPUT
  for item in "${items[@]+"${items[@]}"}"; do
    count=0; match=
    while IFS=$'\t' read -r identity detail; do
      [ -n "$identity" ] || continue
      existing=${identity#*:}
      if [ "$item" = "$identity" ] || [ "$item" = "$existing" ] || [ "$item" = "${existing##*/}" ]; then
        count=$((count + 1)); match=$identity
      fi
    done <<< "$inventory"
    [ "$count" -gt 0 ] || rig_fail "capture item is not in supported installed inventory: $item" || return
    [ "$count" -eq 1 ] || rig_fail "capture item '$item' is ambiguous; use a kind-qualified identity such as formula:NAME or cask:NAME" || return
    rig_array_contains "$match" "${selected[@]+"${selected[@]}"}" || selected[${#selected[@]}]=$match
  done
  if [ "${#items[@]}" -eq 0 ] || [ -z "$category" ] || [ -z "$purpose" ] || [ -z "$rationale" ]; then
    printf '%s\n' 'Discovery only: no configuration written.' \
      'Homebrew scope: formulae installed on request and installed casks; dependency-only formulae are excluded.' \
      'Select items and supply --category, --purpose and --rationale to prepare an additive TOML proposal.'
    rig_table_reset
    rig_table_add_column PROVIDER 18 end keep
    rig_table_add_column IDENTITY 80 end keep
    rig_table_add_column STATE 24 end keep
    while IFS=$'\t' read -r identity detail; do
      [ -n "$identity" ] || continue
      if [ "${#items[@]}" -gt 0 ]; then rig_array_contains "$identity" "${selected[@]+"${selected[@]}"}" || continue; fi
      status_value=unmanaged
      rig_homebrew_identity_declared "$identity" && status_value=declared
      if [ "$status_value" = unmanaged ] && rig_homebrew_identity_ambiguous "$identity"; then status_value=ambiguous-declaration; fi
      rig_table_add_row homebrew "$identity" "$status_value" || return 2
    done <<< "$inventory"
    rig_table_print
    return 0
  fi
  RIG_CAPTURE_IDENTITIES=()
  for identity in "${selected[@]+"${selected[@]}"}"; do
    if rig_homebrew_identity_declared "$identity"; then
      printf 'capture: already declared, skipped %s\n' "$identity" >&2
      continue
    fi
    if rig_homebrew_identity_ambiguous "$identity"; then
      rig_fail "capture identity '$identity' may match an unqualified declaration; resolve its tap namespace manually before adoption" || return
    fi
    rig_adoption_tool_id "$identity"; id=$RIG_VALUE
    if rig_section_index "tool.$id" || rig_array_contains "$id" "${ids[@]+"${ids[@]}"}"; then
      rig_fail "capture generated tool id '$id' conflicts with existing or proposed intent; adopt this identity manually" || return
    fi
    ids[${#ids[@]}]=$id
    RIG_CAPTURE_IDENTITIES[${#RIG_CAPTURE_IDENTITIES[@]}]=$identity
  done
  if [ "${#RIG_CAPTURE_IDENTITIES[@]}" -eq 0 ]; then
    printf '%s\n' '# No additions: selected identities are already declared.'
    return 0
  fi
  RIG_CAPTURE_CATEGORY=$category; RIG_CAPTURE_PURPOSE=$purpose; RIG_CAPTURE_RATIONALE=$rationale; RIG_CAPTURE_PROFILE=$profile
  if [ -z "$output" ] || [ "$dry_run" -eq 1 ]; then
    rig_capture_fragment
    [ -z "$output" ] || printf 'capture: would create review file %s\n' "$output" >&2
    return 0
  fi
  (umask 077; set -C; rig_capture_fragment >"$output") || {
    rig_fail "capture could not exclusively create review file: $output"; return;
  }
  printf 'Proposal: %s\nReview it, then copy it into Rig conf.d to adopt it.\n' "$output"
}
