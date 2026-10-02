# rig-module: 26-retired-applications
# shellcheck shell=bash
# Cross-module state is intentionally consumed by the status renderer.
# shellcheck disable=SC2004,SC2034

rig_retired_valid_bundle_id() {
  case "$1" in
    ''|*[!a-zA-Z0-9.-]*|.*|*.|*..*) return 1 ;;
    *.*) return 0 ;;
    *) return 1 ;;
  esac
}

# Only literal prefix replacement is permitted. Validate before any filesystem
# observation, including the expanded HOME, without globbing or shell evaluation.
rig_retired_expand_path() {
  local path

  path=$1
  case "$path" in
    \~/*) [ -n "${HOME:-}" ] || return 1; path=$HOME/${path#\~/} ;;
    \$HOME/*) [ -n "${HOME:-}" ] || return 1; path=$HOME/${path#\$HOME/} ;;
    /*) ;;
    *) return 1 ;;
  esac
  case "$path" in
    /|*/|*//*|*/./*|*/../*|*/.|*/..|*\**|*\?*|*\[*|*\]*|*\$*|*\`*|*\\*|*[[:cntrl:]]*) return 1 ;;
  esac
  case "$path" in /*) ;; *) return 1 ;; esac
  RIG_VALUE=$path
}

rig_validate_retired_application() {
  local section_name section_index bundle_id scan field_index field_end key

  section_name=$1
  section_index=$2
  rig_require_field "$section_name" name || return
  [ -n "$RIG_VALUE" ] || rig_fail "[$section_name] name must not be empty" || return
  case "$RIG_VALUE" in *[[:cntrl:]]*)
    rig_fail "[$section_name] name must not contain control characters" || return ;;
  esac
  rig_require_field "$section_name" bundle-id || return
  bundle_id=$RIG_VALUE
  rig_retired_valid_bundle_id "$bundle_id" ||
    rig_fail "[$section_name] invalid bundle-id; use an exact dot-separated bundle identity" || return
  rig_field_count "$section_index" application-path
  [ "$RIG_COUNT" -gt 0 ] ||
    rig_fail "[$section_name] requires non-empty application-paths" || return
  scan=0
  while [ "$scan" -lt "$section_index" ]; do
    if [ "${RIG_SECTION_TYPES[$scan]}" = retired-application ] &&
      rig_get_value "${RIG_SECTION_NAMES[$scan]}" bundle-id &&
      [ "$RIG_VALUE" = "$bundle_id" ]; then
      rig_fail "[$section_name] duplicate retired bundle-id '$bundle_id'" || return
    fi
    scan=$((scan + 1))
  done
  field_index=${RIG_SECTION_FIELD_STARTS[$section_index]}
  field_end=${RIG_SECTION_FIELD_ENDS[$section_index]}
  while [ "$field_index" -lt "$field_end" ]; do
    key=${RIG_FIELD_KEYS[$field_index]}
    case "$key" in application-path|data-path|package-path)
      rig_retired_expand_path "${RIG_FIELD_VALUES[$field_index]}" ||
        rig_fail "[$section_name] invalid ${key}s; require a literal absolute, ~/ or \$HOME/ path without traversal or shell patterns" || return
      ;;
    esac
    field_index=$((field_index + 1))
  done
  return 0
}

# Walk lexical components in order. Never test a descendant until its parent
# was shown to be a searchable non-link directory. Do not canonicalise paths:
# doing so would silently follow links (including /tmp and /var on macOS).
rig_retired_probe_path() {
  local path remaining component prefix

  path=$1
  remaining=${path#/}
  prefix=
  RIG_RETIRED_PATH_STATE=present
  RIG_RETIRED_PATH_REASON='Path is present; contents were not inspected.'
  while [ -n "$remaining" ]; do
    component=${remaining%%/*}
    if [ "$remaining" = "$component" ]; then remaining=; else remaining=${remaining#*/}; fi
    prefix=$prefix/$component
    if [ -L "$prefix" ]; then
      RIG_RETIRED_PATH_STATE=symlink
      RIG_RETIRED_PATH_REASON='Path or ancestor is a symbolic link; target was not followed.'
      return 0
    fi
    if [ ! -e "$prefix" ]; then
      RIG_RETIRED_PATH_STATE=missing
      RIG_RETIRED_PATH_REASON='Path was not found by the filesystem existence check.'
      return 0
    fi
    if [ -n "$remaining" ]; then
      if [ ! -d "$prefix" ] || [ ! -x "$prefix" ]; then
        RIG_RETIRED_PATH_STATE=inaccessible
        RIG_RETIRED_PATH_REASON='An ancestor cannot be traversed; absence cannot be established.'
        return 0
      fi
    elif [ ! -r "$prefix" ] || { [ -d "$prefix" ] && [ ! -x "$prefix" ]; }; then
      RIG_RETIRED_PATH_STATE=inaccessible
      RIG_RETIRED_PATH_REASON='Path is inaccessible; contents were not inspected.'
    fi
  done
  return 0
}

rig_retired_valid_date() {
  local value year month day hour minute second offset_hour offset_minute days

  value=$1
  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [+-][0-9]{4}$ ]] || return 1
  year=$((10#${value:0:4}))
  month=$((10#${value:5:2}))
  day=$((10#${value:8:2}))
  hour=$((10#${value:11:2}))
  minute=$((10#${value:14:2}))
  second=$((10#${value:17:2}))
  offset_hour=$((10#${value:21:2}))
  offset_minute=$((10#${value:23:2}))
  [ "$year" -ge 1 ] && [ "$month" -ge 1 ] && [ "$month" -le 12 ] &&
    [ "$day" -ge 1 ] && [ "$hour" -le 23 ] && [ "$minute" -le 59 ] &&
    [ "$second" -le 59 ] && [ "$offset_hour" -le 14 ] && [ "$offset_minute" -le 59 ] || return 1
  [ "$offset_hour" -ne 14 ] || [ "$offset_minute" -eq 0 ] || return 1
  days=31
  case "$month" in
    4|6|9|11) days=30 ;;
    2)
      days=28
      if [ "$((year % 400))" -eq 0 ] || {
        [ "$((year % 4))" -eq 0 ] && [ "$((year % 100))" -ne 0 ];
      }; then days=29; fi
      ;;
  esac
  [ "$day" -le "$days" ]
}

rig_retired_observe_application() {
  local path bundle_id plist command output

  path=$1
  bundle_id=$2
  RIG_RETIRED_LAST_USED_STATE=unavailable
  RIG_RETIRED_LAST_USED_VALUE=
  rig_retired_probe_path "$path"
  [ "$RIG_RETIRED_PATH_STATE" = present ] || return 0
  if [ ! -d "$path" ]; then
    RIG_RETIRED_PATH_STATE=unavailable
    RIG_RETIRED_PATH_REASON='Declared application location is not a bundle directory.'
    return 0
  fi
  plist=$path/Contents/Info.plist
  rig_retired_probe_path "$plist"
  if [ "$RIG_RETIRED_PATH_STATE" != present ]; then
    if [ "$RIG_RETIRED_PATH_STATE" = missing ]; then
      RIG_RETIRED_PATH_STATE=unavailable
      RIG_RETIRED_PATH_REASON='Bundle metadata is missing; identity cannot be established.'
    fi
    return 0
  fi
  if [ ! -f "$plist" ]; then
    RIG_RETIRED_PATH_STATE=unavailable
    RIG_RETIRED_PATH_REASON='Bundle metadata is not a regular file; identity cannot be established.'
    return 0
  fi
  command=${RIG_PLUTIL:-/usr/bin/plutil}
  if ! output=$("$command" -extract CFBundleIdentifier raw -o - "$plist" 2>/dev/null) ||
    ! rig_retired_valid_bundle_id "$output"; then
    RIG_RETIRED_PATH_STATE=unavailable
    RIG_RETIRED_PATH_REASON='Bundle identity is unavailable: metadata reader failed or metadata is invalid.'
    return 0
  fi
  if [ "$output" != "$bundle_id" ]; then
    RIG_RETIRED_PATH_STATE=mismatched
    RIG_RETIRED_PATH_REASON='Bundle identity differs from the declared identity; no usage metadata was read.'
    return 0
  fi
  RIG_RETIRED_PATH_STATE=matched
  RIG_RETIRED_PATH_REASON='CFBundleIdentifier exactly matches the declared identity.'
  command=${RIG_MDLS:-/usr/bin/mdls}
  if output=$("$command" -raw -name kMDItemLastUsedDate "$path" 2>/dev/null) &&
    rig_retired_valid_date "$output"; then
    RIG_RETIRED_LAST_USED_STATE=available
    RIG_RETIRED_LAST_USED_VALUE=$output
  fi
  return 0
}

rig_retired_add_evidence() {
  local owner kind path source bundle_id index association

  owner=$1
  kind=$2
  path=$3
  source=$4
  bundle_id=$5
  index=0
  while [ "$index" -lt "${#RIG_RETIRED_PATHS[@]}" ]; do
    if [ "${RIG_RETIRED_OWNERS[$index]}" = "$owner" ] &&
      [ "${RIG_RETIRED_PATHS[$index]}" = "$path" ] && {
        [ "$source" = bundle-id-candidate ] ||
        [ "${RIG_RETIRED_KINDS[$index]}" = "$kind" ];
      }; then
      return 0
    fi
    index=$((index + 1))
  done
  RIG_RETIRED_LAST_USED_STATE=unavailable
  RIG_RETIRED_LAST_USED_VALUE=
  if [ "$RIG_RESOLVED_PLATFORM" != macos ]; then
    RIG_RETIRED_PATH_STATE=unavailable
    RIG_RETIRED_PATH_REASON='Retired application observation is unsupported on this platform; no path or metadata probe was performed.'
  elif [ "$kind" = application ]; then
    rig_retired_observe_application "$path" "$bundle_id"
  else
    rig_retired_probe_path "$path"
  fi
  association=
  case "$kind:$source" in
    package:*) association='Declared package association; ownership is unverified by a package manager. ' ;;
    data:declared) association='Declared data association, not proof of ownership. ' ;;
    data:bundle-id-candidate) association='Bundle-ID candidate association, not proof of ownership. ' ;;
  esac
  index=${#RIG_RETIRED_PATHS[@]}
  RIG_RETIRED_OWNERS[$index]=$owner
  RIG_RETIRED_KINDS[$index]=$kind
  RIG_RETIRED_PATHS[$index]=$path
  RIG_RETIRED_SOURCES[$index]=$source
  RIG_RETIRED_STATES[$index]=$RIG_RETIRED_PATH_STATE
  RIG_RETIRED_REASONS[$index]=$association$RIG_RETIRED_PATH_REASON
  RIG_RETIRED_USAGE_STATES[$index]=$RIG_RETIRED_LAST_USED_STATE
  RIG_RETIRED_USAGE_VALUES[$index]=$RIG_RETIRED_LAST_USED_VALUE
  return 0
}

rig_collect_retired_applications() {
  local index section_name bundle_id kind field_index field_end suffix path

  RIG_RETIRED_APPLICATIONS=()
  RIG_RETIRED_OWNERS=()
  RIG_RETIRED_KINDS=()
  RIG_RETIRED_PATHS=()
  RIG_RETIRED_SOURCES=()
  RIG_RETIRED_STATES=()
  RIG_RETIRED_REASONS=()
  RIG_RETIRED_USAGE_STATES=()
  RIG_RETIRED_USAGE_VALUES=()
  RIG_RETIRED_CANDIDATES_AVAILABLE=1
  index=0
  while [ "$index" -lt "${#RIG_SECTION_NAMES[@]}" ]; do
    if [ "${RIG_SECTION_TYPES[$index]}" = retired-application ]; then
      section_name=${RIG_SECTION_NAMES[$index]}
      RIG_RETIRED_APPLICATIONS[${#RIG_RETIRED_APPLICATIONS[@]}]=$index
      rig_get_value "$section_name" bundle-id || return 2
      bundle_id=$RIG_VALUE
      for kind in application package data; do
        field_index=${RIG_SECTION_FIELD_STARTS[$index]}
        field_end=${RIG_SECTION_FIELD_ENDS[$index]}
        while [ "$field_index" -lt "$field_end" ]; do
          if [ "${RIG_FIELD_KEYS[$field_index]}" = "$kind-path" ]; then
            rig_retired_expand_path "${RIG_FIELD_VALUES[$field_index]}" || return 2
            path=$RIG_VALUE
            rig_retired_add_evidence "$index" "$kind" "$path" declared "$bundle_id"
          fi
          field_index=$((field_index + 1))
        done
      done
      for suffix in "Application Support/$bundle_id" "Caches/$bundle_id" \
        "Preferences/$bundle_id.plist" "Saved Application State/$bundle_id.savedState" "Containers/$bundle_id"; do
        if rig_retired_expand_path "\$HOME/Library/$suffix"; then
          path=$RIG_VALUE
          rig_retired_add_evidence "$index" data "$path" bundle-id-candidate "$bundle_id"
        else
          RIG_RETIRED_CANDIDATES_AVAILABLE=0
        fi
      done
    fi
    index=$((index + 1))
  done
  return 0
}

rig_retired_json() {
  local app section_index section_name row separator evidence_separator state detail

  printf ',"retired_applications":['
  separator=
  for app in "${RIG_RETIRED_APPLICATIONS[@]+"${RIG_RETIRED_APPLICATIONS[@]}"}"; do
    section_index=$app
    section_name=${RIG_SECTION_NAMES[$section_index]}
    rig_json_field "$separator{" id "${RIG_SECTION_IDS[$section_index]}"
    rig_get_value "$section_name" name
    rig_json_field ',' name "$RIG_VALUE"
    rig_get_value "$section_name" bundle-id
    rig_json_field ',' bundle_id "$RIG_VALUE"
    state=observed
    detail='Informational evidence only; retained data does not affect health or installation intent.'
    if [ "$RIG_RETIRED_CANDIDATES_AVAILABLE" -eq 0 ]; then
      detail="$detail Conventional home-relative candidates unavailable: HOME is missing or unsafe."
    fi
    if [ "$RIG_RESOLVED_PLATFORM" != macos ]; then
      state=unavailable
      detail='Unsupported platform: retired application observation is available only on macOS.'
    fi
    rig_json_field ',' state "$state"
    rig_json_field ',' detail "$detail"
    printf ',"evidence":['
    evidence_separator=
    row=0
    while [ "$row" -lt "${#RIG_RETIRED_PATHS[@]}" ]; do
      if [ "${RIG_RETIRED_OWNERS[$row]}" = "$section_index" ]; then
        rig_json_field "$evidence_separator{" kind "${RIG_RETIRED_KINDS[$row]}"
        rig_json_field ',' source "${RIG_RETIRED_SOURCES[$row]}"
        rig_json_field ',' state "${RIG_RETIRED_STATES[$row]}"
        # RIG-STATE-028 confines private filesystem paths to detail.
        rig_json_field ',' detail "${RIG_RETIRED_PATHS[$row]}"
        rig_json_field ',' reason "${RIG_RETIRED_REASONS[$row]}"
        if [ "${RIG_RETIRED_KINDS[$row]}" = application ]; then
          rig_json_field ',"last_used":{' state "${RIG_RETIRED_USAGE_STATES[$row]}"
          rig_json_field ',' value "${RIG_RETIRED_USAGE_VALUES[$row]}"
          rig_json_field ',' source 'mdls:kMDItemLastUsedDate'
          rig_json_field ',' caveat 'Partial metadata is not proof of use or disuse.'
          printf '}'
        fi
        printf '}'
        evidence_separator=,
      fi
      row=$((row + 1))
    done
    printf ']}'
    separator=,
  done
  printf ']'
}

rig_retired_print() {
  local app section_name row name bundle_id usage

  printf '\nRetired applications: %s (informational; retained data does not affect health)\n' "${#RIG_RETIRED_APPLICATIONS[@]}"
  [ "${#RIG_RETIRED_APPLICATIONS[@]}" -gt 0 ] || return 0
  printf '%s\n' \
    'Declared paths preserve authored associations; package ownership is unverified.' \
    'Bundle-ID candidate paths are associations, not proof of ownership.' \
    'Last-used metadata is partial, never proof of use or disuse. Complete evidence: status --retired --format json.'
  if [ "$RIG_RETIRED_CANDIDATES_AVAILABLE" -eq 0 ]; then
    printf '%s\n' 'Conventional home-relative candidates unavailable: HOME is missing or unsafe.'
  fi
  for app in "${RIG_RETIRED_APPLICATIONS[@]+"${RIG_RETIRED_APPLICATIONS[@]}"}"; do
    section_name=${RIG_SECTION_NAMES[$app]}
    rig_get_value "$section_name" name
    name=$RIG_VALUE
    rig_get_value "$section_name" bundle-id
    bundle_id=$RIG_VALUE
    rig_ellipsize "${RIG_SECTION_IDS[$app]}: $name ($bundle_id)" 118
    printf '  %s\n' "$RIG_VALUE"
    if [ "$RIG_RESOLVED_PLATFORM" != macos ]; then
      printf '    Unsupported platform: observation is available only on macOS.\n'
    fi
    rig_table_reset
    rig_table_add_column KIND 19
    rig_table_add_column STATE 12
    rig_table_add_column DETAIL 85
    row=0
    while [ "$row" -lt "${#RIG_RETIRED_PATHS[@]}" ]; do
      if [ "${RIG_RETIRED_OWNERS[$row]}" = "$app" ]; then
        rig_table_add_row "${RIG_RETIRED_KINDS[$row]}" "${RIG_RETIRED_STATES[$row]}" \
          "${RIG_RETIRED_PATHS[$row]}" || return 2
        rig_table_add_row "${RIG_RETIRED_SOURCES[$row]}" '' "${RIG_RETIRED_REASONS[$row]}" || return 2
        if [ "${RIG_RETIRED_KINDS[$row]}" = application ]; then
          usage=${RIG_RETIRED_USAGE_VALUES[$row]}
          [ -z "$usage" ] || usage="$usage; "
          rig_table_add_row last-used "${RIG_RETIRED_USAGE_STATES[$row]}" \
            "${usage}source=mdls:kMDItemLastUsedDate" || return 2
        fi
      fi
      row=$((row + 1))
    done
    rig_table_print
  done
  return 0
}
