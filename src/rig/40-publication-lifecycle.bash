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
  local publication title profile base_url tool category index
  local -a categories

  publication=$1
  title=$2
  profile=$3
  base_url=$4

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

  printf '{\n  "format": "rig-publication",\n  "version": 2,\n  "publication": {\n'
  rig_json_escape "$publication"
  printf '    "id": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$title"
  printf '    "title": "%s",\n' "$RIG_VALUE"
  rig_json_escape "$base_url"
  printf '    "canonical_url": "%s"\n  },\n  "profile": {\n' "$RIG_VALUE"
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
  trap rig_export_cleanup EXIT
  trap 'rig_export_interrupted 129' HUP
  trap 'rig_export_interrupted 130' INT
  trap 'rig_export_interrupted 143' TERM
  rig_render_publication_json \
    "$RIG_EXPORT_PUBLICATION" "$RIG_EXPORT_TITLE" "$RIG_RESOLVED_PROFILE" "$RIG_PUBLICATION_BASE_URL" \
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
  trap - EXIT HUP INT TERM
  if [ "$report" = yes ]; then
    printf 'Exported %s to %s\n' "$RIG_EXPORT_PUBLICATION" "$target"
  fi
}

rig_command_export() {
  local publication output profile platform title base_url native_status

  if [ "$#" -eq 1 ]; then
    case "$1" in
      -h|--help)
        printf '%s\n' 'Usage: rig export PUBLICATION --output DIRECTORY'
        return
        ;;
    esac
  fi
  [ "$#" -eq 3 ] && [ "$2" = --output ] && [ -n "$1" ] && [ -n "$3" ] ||
    syntax_error 'usage: rig export PUBLICATION --output DIRECTORY' || return
  publication=$1
  output=$3
  rig_load_config || return
  rig_valid_id "$publication" && rig_section_index "publication.$publication" ||
    rig_fail "unknown publication '$publication'" || return
  rig_get_value "publication.$publication" profile || return
  profile=$RIG_VALUE
  rig_get_value "publication.$publication" title || return
  title=$RIG_VALUE
  rig_get_value "publication.$publication" base-url || return
  base_url=$RIG_VALUE
  rig_publication_base_url "$base_url" || return
  RIG_PUBLICATION_BASE_URL=$RIG_VALUE
  rig_current_platform || return
  platform=$RIG_VALUE
  rig_resolve_publication_profile "$profile" "$platform" || return
  RIG_EXPORT_PUBLICATION=$publication
  RIG_EXPORT_TITLE=$title
  (
    umask 022
    rig_progress_start 'publication export' 1
    rig_progress_begin "$publication" declaration
    if rig_replace_export_tree "$output"; then
      rig_progress_result succeeded "$publication" declaration
      rig_progress_finish
    else
      native_status=$?
      rig_progress_result failed "$publication" declaration
      rig_progress_finish
      return "$native_status"
    fi
  )
}

rig_cleanup_publish_stage() {
  local stage_name entry

  if [ -z "${RIG_PUBLISH_STAGE:-}" ]; then
    return 0
  fi
  case "$RIG_PUBLISH_STAGE" in
    "$RIG_PUBLISH_STAGING_ROOT"/*.rig-publish.*) ;;
    *) rig_fail "refusing unsafe publication staging cleanup: $RIG_PUBLISH_STAGE" || return ;;
  esac

  stage_name=${RIG_PUBLISH_STAGE##*/}
  if ! (
    cd "$RIG_PUBLISH_STAGING_ROOT" || exit 2
    [ "$(pwd -P)" = "$RIG_PUBLISH_STAGING_ROOT" ] || exit 2
    [ ! -L "$stage_name" ] || exit 2
    if [ ! -e "$stage_name" ]; then
      exit 0
    fi
    [ -d "$stage_name" ] || exit 2
    cd "$stage_name" || exit 2
    [ "$(pwd -P)" = "$RIG_PUBLISH_STAGE" ] || exit 2
    [ ! -L rig.json ] || exit 2
    [ ! -e rig.json ] || [ -f rig.json ] || exit 2
    for entry in ./* ./.[!.]* ./..?*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      case "$entry" in
        ./rig.json) ;;
        *) exit 2 ;;
      esac
    done
    [ ! -e rig.json ] || rm -f -- rig.json || exit 2
    cd .. || exit 2
    rmdir -- "$stage_name" || exit 2
  ); then
    rig_fail "cannot safely remove publication staging directory: $RIG_PUBLISH_STAGE" || return
  fi
  RIG_PUBLISH_STAGE=
  RIG_PUBLISH_COMPLETE=0
}

rig_retain_publish_stage() {
  local stage_name retained

  [ -n "${RIG_PUBLISH_STAGE:-}" ] || return 0
  case "$RIG_PUBLISH_STAGE" in
    "$RIG_PUBLISH_STAGING_ROOT"/*.rig-publish.*) ;;
    "$RIG_PUBLISH_RETAINED_ROOT"/*.rig-publish.*) return 0 ;;
    *) rig_fail "refusing unsafe publication retention: $RIG_PUBLISH_STAGE" || return ;;
  esac
  stage_name=${RIG_PUBLISH_STAGE##*/}
  retained=$RIG_PUBLISH_RETAINED_ROOT/$stage_name
  [ ! -e "$retained" ] && [ ! -L "$retained" ] ||
    rig_fail "publication retention target already exists: $retained" || return
  if ! (
    cd "$RIG_PUBLISH_ROOT" || exit 2
    [ "$(pwd -P)" = "$RIG_PUBLISH_ROOT" ] || exit 2
    [ -d staging ] && [ ! -L staging ] || exit 2
    [ -d retained ] && [ ! -L retained ] || exit 2
    [ "$(cd staging && pwd -P)" = "$RIG_PUBLISH_STAGING_ROOT" ] || exit 2
    [ "$(cd retained && pwd -P)" = "$RIG_PUBLISH_RETAINED_ROOT" ] || exit 2
    [ -d "staging/$stage_name" ] && [ ! -L "staging/$stage_name" ] || exit 2
    mv -- "staging/$stage_name" "retained/$stage_name" || exit 2
  ); then
    rig_fail "cannot safely retain publication staging directory: $RIG_PUBLISH_STAGE" || return
  fi
  RIG_PUBLISH_STAGE=$retained
}

rig_publish_interrupted() {
  local exit_code

  exit_code=$1
  trap - HUP INT TERM
  rig_progress_interrupted
  if [ "${RIG_PUBLISH_COMPLETE:-0}" -eq 1 ]; then
    rig_retain_publish_stage || true
    printf 'rig: publish interrupted; retained export: %s\n' "$RIG_PUBLISH_STAGE" >&2
  else
    if rig_cleanup_publish_stage; then
      printf 'rig: publish interrupted before publisher handoff\n' >&2
    else
      printf 'rig: publish interrupted before publisher handoff; staging cleanup failed\n' >&2
    fi
  fi
  exit "$exit_code"
}

rig_prepare_publish_stage() {
  local publication publish_root staging_root retained_root stage suffix absolute_stage

  publication=$1
  rig_effective_paths || return 2
  publish_root=$RIG_DIAG_CACHE_HOME/publish
  if [ -e "$publish_root" ] || [ -L "$publish_root" ]; then
    [ -d "$publish_root" ] && [ ! -L "$publish_root" ] ||
      rig_fail "publication cache path must be a directory, not a symlink: $publish_root" || return
  else
    mkdir -p -- "$publish_root" ||
      rig_fail "cannot create publication cache directory: $publish_root" || return
  fi
  [ -d "$publish_root" ] && [ ! -L "$publish_root" ] ||
    rig_fail "publication cache path must be a directory, not a symlink: $publish_root" || return
  RIG_PUBLISH_ROOT=$(cd "$publish_root" && pwd -P) ||
    rig_fail "cannot resolve publication cache directory: $publish_root" || return

  staging_root=$RIG_PUBLISH_ROOT/staging
  retained_root=$RIG_PUBLISH_ROOT/retained
  if [ ! -e "$staging_root" ] && [ ! -L "$staging_root" ]; then
    mkdir -- "$staging_root" ||
      rig_fail "cannot create publication staging cache directory: $staging_root" || return
  fi
  if [ ! -e "$retained_root" ] && [ ! -L "$retained_root" ]; then
    mkdir -- "$retained_root" ||
      rig_fail "cannot create publication retained cache directory: $retained_root" || return
  fi
  [ -d "$staging_root" ] && [ ! -L "$staging_root" ] ||
    rig_fail "publication staging cache path must be a directory, not a symlink: $staging_root" || return
  [ -d "$retained_root" ] && [ ! -L "$retained_root" ] ||
    rig_fail "publication retained cache path must be a directory, not a symlink: $retained_root" || return
  RIG_PUBLISH_STAGING_ROOT=$(cd "$staging_root" && pwd -P) ||
    rig_fail "cannot resolve publication staging cache directory: $staging_root" || return
  RIG_PUBLISH_RETAINED_ROOT=$(cd "$retained_root" && pwd -P) ||
    rig_fail "cannot resolve publication retained cache directory: $retained_root" || return

  suffix=$$
  stage=$RIG_PUBLISH_STAGING_ROOT/$publication.rig-publish.$suffix
  while [ -e "$stage" ] || [ -L "$stage" ] ||
    [ -e "$RIG_PUBLISH_RETAINED_ROOT/${stage##*/}" ] ||
    [ -L "$RIG_PUBLISH_RETAINED_ROOT/${stage##*/}" ]; do
    suffix=$((suffix + 1))
    stage=$RIG_PUBLISH_STAGING_ROOT/$publication.rig-publish.$suffix
  done
  RIG_PUBLISH_STAGE=$stage
  if ! mkdir -- "$stage"; then
    rig_cleanup_publish_stage || true
    rig_fail "cannot create publication staging directory: $stage" || return
    return 2
  fi
  if ! rig_render_publication_json \
    "$publication" "$RIG_EXPORT_TITLE" "$RIG_RESOLVED_PROFILE" "$RIG_PUBLICATION_BASE_URL" \
    >"$stage/rig.json"; then
    rig_cleanup_publish_stage || true
    rig_fail "cannot render publication data: $stage/rig.json" || return
    return 2
  fi
  if [ ! -f "$stage/rig.json" ] || [ -L "$stage/rig.json" ]; then
    rig_cleanup_publish_stage || true
    rig_fail "publication export is incomplete: $stage" || return
  fi
  [ ! -L "$stage" ] || {
    rig_cleanup_publish_stage || true
    rig_fail "publication staging directory became a symlink: $stage" || return
  }
  if ! absolute_stage=$(cd "$stage" && pwd -P); then
    rig_cleanup_publish_stage || true
    rig_fail "cannot resolve publication staging directory: $stage" || return
  fi
  case "$absolute_stage" in
    "$RIG_PUBLISH_STAGING_ROOT"/*.rig-publish.*) ;;
    *)
      rig_cleanup_publish_stage || true
      rig_fail "publication staging directory escaped the cache: $absolute_stage" || return
      ;;
  esac
  RIG_PUBLISH_STAGE=$absolute_stage
  RIG_PUBLISH_COMPLETE=1
  RIG_VALUE=$absolute_stage
}

rig_command_publish() {
  (
    local publication section_name profile title base_url publisher adapter executable platform
    local stage exit_code

    RIG_PUBLISH_STAGE=
    RIG_PUBLISH_ROOT=
    RIG_PUBLISH_STAGING_ROOT=
    RIG_PUBLISH_RETAINED_ROOT=
    RIG_PUBLISH_COMPLETE=0
    trap 'rig_publish_interrupted 129' HUP
    trap 'rig_publish_interrupted 130' INT
    trap 'rig_publish_interrupted 143' TERM

    if [ "$#" -eq 1 ]; then
      case "$1" in
        -h|--help)
          printf '%s\n' 'Usage: rig publish PUBLICATION'
          return
          ;;
      esac
    fi
    [ "$#" -eq 1 ] && [ -n "$1" ] ||
      syntax_error 'usage: rig publish PUBLICATION' || return
    publication=$1

    rig_load_config || return
    rig_valid_id "$publication" && rig_section_index "publication.$publication" ||
      rig_fail "unknown publication '$publication'" || return
    section_name=publication.$publication
    rig_get_value "$section_name" profile || return 2
    profile=$RIG_VALUE
    rig_get_value "$section_name" title || return 2
    title=$RIG_VALUE
    rig_get_value "$section_name" base-url || return 2
    base_url=$RIG_VALUE
    rig_publication_base_url "$base_url" || return
    RIG_PUBLICATION_BASE_URL=$RIG_VALUE
    rig_get_value "$section_name" publisher || return 2
    publisher=$RIG_VALUE
    rig_provider_adapter "$publisher" || return 2
    adapter=$RIG_VALUE
    [ "$adapter" = custom ] ||
      rig_fail "publication '$publication' requires a custom publisher" || return
    rig_provider_has_capability "$publisher" publish ||
      rig_fail "publisher '$publisher' does not declare capability 'publish'" || return
  rig_custom_provider_executable "$publisher" || return 2
    executable=$RIG_VALUE
    rig_executable_available "$executable" ||
      rig_fail "publisher '$publisher' executable unavailable: $executable" || return

    rig_current_platform || return
    platform=$RIG_VALUE
    rig_resolve_publication_profile "$profile" "$platform" || return
    RIG_EXPORT_PUBLICATION=$publication
    RIG_EXPORT_TITLE=$title
    umask 077
    rig_progress_start 'publication staging' 1
    rig_progress_begin "$publication" declaration
    rig_prepare_publish_stage "$publication" || return
    stage=$RIG_VALUE
    rig_progress_result succeeded "$publication" declaration
    rig_progress_finish
    if ! rig_prepare_custom_invocation publish "$publisher" "$publication" directory "$stage"; then
      rig_cleanup_publish_stage || true
      return 2
  fi
    executable=$RIG_VALUE

    rig_progress_start publishing 1
    rig_progress_begin "$publication via $publisher" declaration
    if "$executable" "${RIG_INVOKE_ARGUMENTS[@]}"; then
      exit_code=0
      rig_progress_result succeeded "$publication via $publisher" declaration
    else
      exit_code=$?
      rig_progress_result failed "$publication via $publisher" declaration
    fi
  rig_progress_finish

    if [ "$exit_code" -ne 0 ]; then
      rig_retain_publish_stage || true
      printf 'rig: publish failed; retained export: %s\n' "$RIG_PUBLISH_STAGE" >&2
      return "$exit_code"
    fi
    if ! rig_cleanup_publish_stage; then
      printf 'rig: publisher succeeded but publication staging cleanup failed\n' >&2
      return 2
    fi
    printf 'Published %s via %s\n' "$publication" "$publisher"
  )
}

rig_clean_add() {
  RIG_CLEAN_PATHS[${#RIG_CLEAN_PATHS[@]}]=$1
  RIG_CLEAN_STATES[${#RIG_CLEAN_STATES[@]}]=$2
}

rig_clean_artifact_shape() {
  local root path name basename publication suffix entry absolute

  root=$1
  path=$2
  case "$path" in
    "$root"/*.rig-publish.*) ;;
    *) return 1 ;;
  esac
  basename=${path##*/}
  publication=${basename%%.rig-publish.*}
  suffix=${basename#*.rig-publish.}
  rig_valid_id "$publication" || return 1
  case "$suffix" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ -d "$path" ] && [ ! -L "$path" ] || return 1
  absolute=$(cd "$path" 2>/dev/null && pwd -P) || return 1
  [ "$absolute" = "$path" ] || return 1
  [ -f "$path/rig.json" ] && [ ! -L "$path/rig.json" ] || return 1
  for entry in "$path"/* "$path"/.[!.]* "$path"/..?*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name=${entry##*/}
    [ "$name" = rig.json ] || return 1
  done
  return 0
}

rig_clean_collect_namespace() {
  local root state path

  root=$1
  state=$2
  [ -e "$root" ] || [ -L "$root" ] || return 0
  [ -d "$root" ] && [ ! -L "$root" ] ||
    rig_fail "cache namespace must be a directory, not a symlink: $root" || return 2
  [ "$(cd "$root" && pwd -P)" = "$root" ] ||
    rig_fail "cache namespace escaped its canonical parent: $root" || return 2
  for path in "$root"/* "$root"/.[!.]* "$root"/..?*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    if rig_clean_artifact_shape "$root" "$path"; then
      rig_clean_add "$path" "$state"
    else
      rig_clean_add "$path" unsafe
    fi
  done
}

rig_clean_collect_legacy() {
  local path basename

  for path in "$RIG_CLEAN_ROOT"/* "$RIG_CLEAN_ROOT"/.[!.]* "$RIG_CLEAN_ROOT"/..?*; do
    [ -e "$path" ] || [ -L "$path" ] || continue
    basename=${path##*/}
    case "$basename" in
      staging|retained|cleanup) continue ;;
      *.rig-publish.*) rig_clean_add "$path" legacy-unclassified ;;
      *) rig_clean_add "$path" unsafe ;;
    esac
  done
}

rig_clean_claim() {
  local path basename target

  path=$1
  basename=${path##*/}
  target=$RIG_CLEAN_ROOT/cleanup/$basename
  [ -d "$RIG_CLEAN_ROOT/retained" ] && [ ! -L "$RIG_CLEAN_ROOT/retained" ] || return 1
  if [ ! -e "$RIG_CLEAN_ROOT/cleanup" ] && [ ! -L "$RIG_CLEAN_ROOT/cleanup" ]; then
    mkdir -- "$RIG_CLEAN_ROOT/cleanup" || return 1
  fi
  [ -d "$RIG_CLEAN_ROOT/cleanup" ] && [ ! -L "$RIG_CLEAN_ROOT/cleanup" ] || return 1
  [ "$(cd "$RIG_CLEAN_ROOT/cleanup" && pwd -P)" = "$RIG_CLEAN_ROOT/cleanup" ] || return 1
  [ ! -e "$target" ] && [ ! -L "$target" ] || return 1
  if ! (
    cd "$RIG_CLEAN_ROOT" || exit 1
    [ "$(pwd -P)" = "$RIG_CLEAN_ROOT" ] || exit 1
    mv -- "retained/$basename" "cleanup/$basename"
  ); then
    return 1
  fi
  RIG_CLEAN_CLAIM=$target
  return 0
}

rig_clean_remove_claim() {
  local path basename entry

  path=$1
  basename=${path##*/}
  rig_clean_artifact_shape "$RIG_CLEAN_ROOT/cleanup" "$path" || return 1
  RIG_CLEAN_CLAIM=$path
  if ! (
    cd "$RIG_CLEAN_ROOT/cleanup" || exit 1
    [ "$(pwd -P)" = "$RIG_CLEAN_ROOT/cleanup" ] || exit 1
    [ -d "$basename" ] && [ ! -L "$basename" ] || exit 1
    cd "$basename" || exit 1
    [ "$(pwd -P)" = "$path" ] || exit 1
    [ -f rig.json ] && [ ! -L rig.json ] || exit 1
    for entry in ./* ./.[!.]* ./..?*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      [ "$entry" = ./rig.json ] || exit 1
    done
    rm -f -- rig.json || exit 1
    cd .. || exit 1
    rmdir -- "$basename" || exit 1
  ); then
    return 1
  fi
  RIG_CLEAN_CLAIM=
  return 0
}

rig_clean_interrupted() {
  local exit_code

  exit_code=$1
  trap - HUP INT TERM
  rig_progress_interrupted
  if [ -n "${RIG_CLEAN_CLAIM:-}" ]; then
    printf 'rig: clean interrupted; resumable claim: %s\n' "$RIG_CLEAN_CLAIM" >&2
  else
    printf 'rig: clean interrupted\n' >&2
  fi
  exit "$exit_code"
}

rig_lifecycle_supported() {
  case "$1:$2" in
    update:homebrew|update:uv|update:mise|update:npm|update:skills-cli|\
      maintain:homebrew|maintain:uv|maintain:mise|maintain:npm|\
      capture:homebrew) return 0 ;;
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
      if [ "$action" = maintain ]; then
        key=$provider
        label=$provider
      elif [ "$adapter" = homebrew ] && rig_get_value "provider.$provider" manifest; then
        key=homebrew:manifest
        label=manifest
      else
        key=$provider:$binding
        label=$tool
      fi
      rig_lifecycle_add_task "$key" "$label" "$provider" "$binding" "$supported" "$tool"
    fi
    index=$((index + 1))
  done
  if [ "$action" = update ]; then
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

rig_lifecycle_manifest() {
  local provider

  provider=$1
  rig_get_value "provider.$provider" manifest || return 1
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
  if [ "$adapter" = homebrew ] && rig_lifecycle_manifest "$provider"; then
    kind=formula
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
  local action provider binding adapter executable manifest parent

  action=$1
  provider=$2
  binding=$3
  case "$binding" in
    skill.*)
      rig_preflight_skill "${binding#skill.}" ||
        rig_lifecycle_unavailable "${RIG_SKILL_PREFLIGHT_DETAIL:-preflight-failed}" \
          "skill '${binding#skill.}' update unavailable: ${RIG_SKILL_PREFLIGHT_DETAIL:-preflight-failed}" || return
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
  RIG_VALUE=$executable
  if [ "$adapter" = homebrew ] && rig_lifecycle_manifest "$provider"; then
    manifest=$RIG_VALUE
    if [ "$action" = capture ]; then
      if [ -L "$manifest" ] || { [ -e "$manifest" ] && [ ! -f "$manifest" ]; }; then
        rig_fail "provider '$provider' manifest is not a safe regular-file target: $manifest" || return
      fi
      parent=${manifest%/*}
      [ -n "$parent" ] || parent=/
      [ -d "$parent" ] && [ -w "$parent" ] ||
        rig_fail "provider '$provider' manifest directory unavailable: $parent" || return
    else
      [ -f "$manifest" ] && [ -r "$manifest" ] ||
        rig_fail "provider '$provider' manifest is not readable regular file: $manifest" || return
    fi
    RIG_VALUE=$executable
  elif [ "$action" = capture ]; then
    rig_fail "provider '$provider' does not declare a native manifest" || return
  fi
}

rig_lifecycle_homebrew_exclusions() {
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--no-go
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--no-cargo
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--no-uv
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--no-krew
  RIG_INVOKE_ARGUMENTS[${#RIG_INVOKE_ARGUMENTS[@]}]=--no-npm
}

rig_execute_lifecycle_task() {
  local action provider binding executable adapter kind locator manifest normalized

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
  kind=
  locator=
  if [ -n "$binding" ]; then
    rig_get_value "$binding" kind || return 2
    kind=$RIG_VALUE
    rig_get_value "$binding" locator || return 2
    locator=$RIG_VALUE
  fi

  case "$action:$adapter" in
    update:homebrew)
      if rig_lifecycle_manifest "$provider"; then
        manifest=$RIG_VALUE
        "$executable" bundle install --upgrade "--file=$manifest" 1>&2
      elif [ "$kind" = mas ]; then
        "$executable" upgrade "$locator" 1>&2
      else
        "$executable" upgrade "--$kind" "$locator" 1>&2
      fi
      ;;
    update:uv)
      rig_normalize_provider_identity "$adapter" "$kind" "$locator"
      normalized=$RIG_VALUE
      "$executable" tool upgrade "$normalized" 1>&2
      ;;
    update:mise)
      "$executable" upgrade "$locator" 1>&2
      ;;
    update:npm)
      "$executable" install --global "$locator" 1>&2
      ;;
    maintain:homebrew)
      "$executable" cleanup 1>&2 || return
      if rig_lifecycle_manifest "$provider"; then
        manifest=$RIG_VALUE
        RIG_INVOKE_ARGUMENTS=(bundle cleanup --force "--file=$manifest")
        rig_lifecycle_homebrew_exclusions
        "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2 || return
      fi
      "$executable" doctor 1>&2
      ;;
    maintain:uv)
      "$executable" cache prune 1>&2
      ;;
    maintain:mise)
      "$executable" reshim 1>&2
      ;;
    maintain:npm)
      "$executable" cache verify 1>&2
      ;;
    capture:homebrew)
      rig_lifecycle_manifest "$provider" || return 2
      manifest=$RIG_VALUE
      RIG_INVOKE_ARGUMENTS=(bundle dump --force --no-describe "--file=$manifest")
      rig_lifecycle_homebrew_exclusions
      "$executable" "${RIG_INVOKE_ARGUMENTS[@]}" 1>&2
      ;;
    *) return 2 ;;
  esac
}

rig_run_lifecycle_tasks() {
  local action dry_run index label provider binding supported executable native_status progress_scope
  local planned completed failed unavailable skipped supported_total exit_code preflight_status

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
    rig_progress_begin "$label via $provider"
    if [ "${RIG_LIFECYCLE_SUPPORTED[$index]}" -eq 1 ]; then
      binding=${RIG_LIFECYCLE_BINDINGS[$index]}
      RIG_LIFECYCLE_PREFLIGHT_DETAIL=
      RIG_LIFECYCLE_PREFLIGHT_SOFT=1
      rig_preflight_lifecycle_task "$action" "$provider" "$binding"
      preflight_status=$?
      RIG_LIFECYCLE_PREFLIGHT_SOFT=0
      case "$preflight_status" in
        0)
          RIG_LIFECYCLE_EXECUTABLES[$index]=$RIG_VALUE
          supported_total=$((supported_total + 1))
          rig_progress_result succeeded "$label via $provider"
          ;;
        1)
          RIG_LIFECYCLE_EXECUTABLES[$index]=-
          RIG_LIFECYCLE_DETAILS[$index]=${RIG_LIFECYCLE_PREFLIGHT_DETAIL:-preflight-failed}
          rig_progress_result skipped "$label via $provider"
          ;;
        *) return "$preflight_status" ;;
      esac
    else
      RIG_LIFECYCLE_EXECUTABLES[$index]=-
      rig_progress_result skipped "$label via $provider"
    fi
    index=$((index + 1))
  done
  rig_progress_finish

  printf 'Profile: %s\nPlatform: %s\n' "$RIG_RESOLVED_PROFILE" "$RIG_RESOLVED_PLATFORM"
  case "$action" in
    update) printf 'Operation scopes: declaration, manifest\n' ;;
    maintain) printf 'Operation scope: provider-wide\n' ;;
  esac
  printf 'TARGET\tPROVIDER\tRESULT\tDETAIL\n'
  [ "$dry_run" -eq 1 ] || rig_progress_start "$action" "$supported_total"
  index=0
  while [ "$index" -lt "${#RIG_LIFECYCLE_KEYS[@]}" ]; do
    label=${RIG_LIFECYCLE_LABELS[$index]}
    provider=${RIG_LIFECYCLE_PROVIDERS[$index]}
    binding=${RIG_LIFECYCLE_BINDINGS[$index]}
    supported=${RIG_LIFECYCLE_SUPPORTED[$index]}
    executable=${RIG_LIFECYCLE_EXECUTABLES[$index]}
    if [ "$supported" -ne 1 ]; then
      printf '%s\t%s\tskipped\tunsupported-%s\n' "$label" "$provider" "$action"
      skipped=$((skipped + 1))
    elif [ -n "${RIG_LIFECYCLE_DETAILS[$index]-}" ]; then
      printf '%s\t%s\tunavailable\t%s\n' "$label" "$provider" "${RIG_LIFECYCLE_DETAILS[$index]}"
      unavailable=$((unavailable + 1))
      exit_code=1
    elif [ "$dry_run" -eq 1 ]; then
      printf '%s\t%s\tplanned\t%s\n' "$label" "$provider" "$action"
      planned=$((planned + 1))
    else
      if [ "$action" = maintain ]; then
        progress_scope='provider-wide'
      elif rig_lifecycle_manifest "$provider"; then
        progress_scope=manifest
      else
        progress_scope=declaration
      fi
      rig_progress_begin "$label via $provider" "$progress_scope"
      rig_execute_lifecycle_task "$action" "$provider" "$binding" "$executable"
      native_status=$?
      if [ "$native_status" -eq 0 ]; then
        printf '%s\t%s\tcompleted\t%s\n' "$label" "$provider" "$action"
        completed=$((completed + 1))
        rig_progress_result succeeded "$label via $provider" "$progress_scope"
      else
        printf '%s\t%s\tfailed\texit:%s\n' "$label" "$provider" "$native_status"
        failed=$((failed + 1))
        exit_code=1
        rig_progress_result failed "$label via $provider" "$progress_scope"
      fi
    fi
    index=$((index + 1))
  done
  rig_progress_finish
  printf 'Summary: planned=%s completed=%s failed=%s unavailable=%s skipped=%s\n' \
    "$planned" "$completed" "$failed" "$unavailable" "$skipped"
  if [ "$exit_code" -eq 0 ]; then
    rig_outcome_note succeeded "planned=$planned completed=$completed skipped=$skipped"
  else
    rig_outcome_note incomplete \
      "planned=$planned completed=$completed failed=$failed unavailable=$unavailable"
  fi
  return "$exit_code"
}

rig_command_lifecycle() {
  local action profile dry_run profile_seen dry_run_seen

  action=$1
  shift
  profile=
  dry_run=0
  profile_seen=0
  dry_run_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        [ "$#" -eq 1 ] || { syntax_error "usage: rig $action [--profile NAME] [--dry-run]"; return; }
        printf 'Usage: rig %s [--profile NAME] [--dry-run]\n' "$action"
        return
        ;;
      --profile)
        if [ "$profile_seen" -ne 0 ] || [ "$#" -lt 2 ] || [ -z "$2" ]; then
          syntax_error "usage: rig $action [--profile NAME] [--dry-run]"
          return
        fi
        profile=$2
        profile_seen=1
        shift 2
        ;;
      --dry-run)
        if [ "$dry_run_seen" -ne 0 ]; then
          syntax_error "usage: rig $action [--profile NAME] [--dry-run]"
          return
        fi
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      *) syntax_error "usage: rig $action [--profile NAME] [--dry-run]"; return ;;
    esac
  done
  rig_resolve_operational_plan "$profile" || return
  [ "$RIG_RESOLVED_PROFILE_KIND" = complete ] ||
    rig_fail "profile '$RIG_RESOLVED_PROFILE' is a non-appliable view" || return
  rig_collect_lifecycle_tasks "$action" || return
  rig_run_lifecycle_tasks "$action" "$dry_run"
}

rig_command_capture() {
  local provider dry_run dry_run_seen adapter executable native_status

  provider=
  dry_run=0
  dry_run_seen=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        [ "$#" -eq 1 ] || { syntax_error 'usage: rig capture PROVIDER [--dry-run]'; return; }
        printf '%s\n' 'Usage: rig capture PROVIDER [--dry-run]'
        return
        ;;
      --dry-run)
        if [ "$dry_run_seen" -ne 0 ]; then
          syntax_error 'usage: rig capture PROVIDER [--dry-run]'
          return
        fi
        dry_run=1
        dry_run_seen=1
        shift
        ;;
      *)
        if [ -n "$provider" ]; then
          syntax_error 'usage: rig capture PROVIDER [--dry-run]'
          return
        fi
        provider=$1
        shift
        ;;
    esac
  done
  [ -n "$provider" ] || { syntax_error 'usage: rig capture PROVIDER [--dry-run]'; return; }
  rig_load_config || return
  rig_current_platform || return
  RIG_RESOLVED_PROFILE=-
  RIG_RESOLVED_PLATFORM=$RIG_VALUE
  rig_provider_exists "$provider" || rig_fail "unknown provider '$provider'" || return
  rig_provider_adapter "$provider" || return 2
  adapter=$RIG_VALUE
  rig_lifecycle_supported capture "$adapter" ||
    rig_fail "provider '$provider' does not support capture" || return
  rig_progress_start preflight 1
  rig_progress_begin "$provider"
  rig_preflight_lifecycle_task capture "$provider" '' || return
  rig_progress_result succeeded "$provider"
  rig_progress_finish
  executable=$RIG_VALUE
  printf 'Operation scope: manifest\n'
  printf 'PROVIDER\tRESULT\tDETAIL\n'
  if [ "$dry_run" -eq 1 ]; then
    printf '%s\tplanned\tcapture\n' "$provider"
    return 0
  fi
  rig_progress_start capturing 1
  rig_progress_begin "$provider" manifest
  rig_execute_lifecycle_task capture "$provider" '' "$executable"
  native_status=$?
  if [ "$native_status" -eq 0 ]; then
    rig_progress_result succeeded "$provider" manifest
  else
    rig_progress_result failed "$provider" manifest
  fi
  rig_progress_finish
  if [ "$native_status" -eq 0 ]; then
    printf '%s\tcompleted\tcapture\n' "$provider"
  else
    printf '%s\tfailed\texit:%s\n' "$provider" "$native_status"
  fi
  return "$native_status"
}

rig_command_clean() {
  (
    local dry_run cache_root publish_root path state action index eligible removed skipped
    local exit_code
    local LC_ALL=C

    dry_run=no
    if [ "$#" -eq 1 ]; then
      case "$1" in
        -h|--help)
          printf '%s\n' 'Usage: rig clean [--dry-run]'
          return
          ;;
        --dry-run) dry_run=yes ;;
        *) syntax_error 'usage: rig clean [--dry-run]' || return ;;
      esac
    elif [ "$#" -ne 0 ]; then
      syntax_error 'usage: rig clean [--dry-run]' || return
    fi

    rig_effective_paths || return 2
    cache_root=$RIG_DIAG_CACHE_HOME
    printf '%s\n' $'CLASS\tSTATE\tACTION\tPATH'
    if [ ! -e "$cache_root" ] && [ ! -L "$cache_root" ]; then
      printf 'Summary: eligible=0 removed=0 skipped=0\n'
      return 0
    fi
    [ -d "$cache_root" ] && [ ! -L "$cache_root" ] ||
      rig_fail "cache root must be a directory, not a symlink: $cache_root" || return 2
    cache_root=$(cd "$cache_root" && pwd -P) ||
      rig_fail "cannot resolve cache root: $cache_root" || return 2
    publish_root=$cache_root/publish
    if [ ! -e "$publish_root" ] && [ ! -L "$publish_root" ]; then
      printf 'Summary: eligible=0 removed=0 skipped=0\n'
      return 0
    fi
    [ -d "$publish_root" ] && [ ! -L "$publish_root" ] ||
      rig_fail "publication cache path must be a directory, not a symlink: $publish_root" || return 2
    RIG_CLEAN_ROOT=$(cd "$publish_root" && pwd -P) ||
      rig_fail "cannot resolve publication cache directory: $publish_root" || return 2
    [ "$RIG_CLEAN_ROOT" = "$publish_root" ] ||
      rig_fail "publication cache escaped the effective Rig cache root: $publish_root" || return 2

    RIG_CLEAN_PATHS=()
    RIG_CLEAN_STATES=()
    rig_clean_collect_namespace "$RIG_CLEAN_ROOT/cleanup" cleanup-claim || return 2
    rig_clean_collect_namespace "$RIG_CLEAN_ROOT/retained" retained || return 2
    rig_clean_collect_legacy

    eligible=0
    removed=0
    skipped=0
    index=0
    while [ "$index" -lt "${#RIG_CLEAN_PATHS[@]}" ]; do
      state=${RIG_CLEAN_STATES[$index]}
      case "$state" in
        retained|cleanup-claim) eligible=$((eligible + 1)) ;;
        *) skipped=$((skipped + 1)) ;;
      esac
      index=$((index + 1))
    done

    if [ "$dry_run" = yes ]; then
      index=0
      while [ "$index" -lt "${#RIG_CLEAN_PATHS[@]}" ]; do
        path=${RIG_CLEAN_PATHS[$index]}
        state=${RIG_CLEAN_STATES[$index]}
        case "$state" in
          retained|cleanup-claim) action=would-remove ;;
          *) action=skipped ;;
        esac
        printf 'publication\t%s\t%s\t%s\n' "$state" "$action" "$path"
        index=$((index + 1))
      done
      printf 'Summary: eligible=%s removed=0 skipped=%s\n' "$eligible" "$skipped"
      [ "$skipped" -eq 0 ] && return 0
      return 1
    fi

    trap 'rig_clean_interrupted 129' HUP
    trap 'rig_clean_interrupted 130' INT
    trap 'rig_clean_interrupted 143' TERM
    rig_progress_start cleaning "$eligible"
    index=0
    exit_code=0
    while [ "$index" -lt "${#RIG_CLEAN_PATHS[@]}" ]; do
      path=${RIG_CLEAN_PATHS[$index]}
      state=${RIG_CLEAN_STATES[$index]}
      action=skipped
      case "$state" in
        cleanup-claim)
          rig_progress_begin 'publication artifact' declaration
          if rig_clean_remove_claim "$path"; then
            action=removed
            removed=$((removed + 1))
            rig_progress_result succeeded 'publication artifact' declaration
          else
            skipped=$((skipped + 1))
            exit_code=1
            rig_progress_result failed 'publication artifact' declaration
          fi
          ;;
        retained)
          rig_progress_begin 'publication artifact' declaration
          if rig_clean_claim "$path" && rig_clean_remove_claim "$RIG_CLEAN_CLAIM"; then
            action=removed
            removed=$((removed + 1))
            rig_progress_result succeeded 'publication artifact' declaration
          else
            skipped=$((skipped + 1))
            exit_code=1
            rig_progress_result failed 'publication artifact' declaration
          fi
          ;;
        *) exit_code=1 ;;
      esac
      printf 'publication\t%s\t%s\t%s\n' "$state" "$action" "$path"
      index=$((index + 1))
    done
    rig_progress_finish
    trap - HUP INT TERM
    printf 'Summary: eligible=%s removed=%s skipped=%s\n' "$eligible" "$removed" "$skipped"
    return "$exit_code"
  )
}
