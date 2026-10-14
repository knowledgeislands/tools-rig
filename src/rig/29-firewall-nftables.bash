# rig-module: 29-firewall-nftables
# shellcheck shell=bash
# Cross-module native observations and apply state are shared deliberately.
# shellcheck disable=SC2034

# The linux-nftables provider restricts the same declared listeners with a
# Rig-owned nftables table. Its one input chain accepts by policy and drops
# only declared ports from outside loopback and the tailnet, so it never
# loosens another firewall and never blocks an undeclared port. A Rig-owned
# systemd unit loads the table at boot after nftables.service and ufw.service.
# Rig never runs ufw or iptables, never edits /etc/nftables.conf and never
# flushes the ruleset. System paths resolve beneath RIG_SYSTEM_ROOT exactly as
# for macos-pf; the rendered content always names the real paths.
RIG_NFTABLES_RULES_DIRECTORY=/etc/rig/firewall
RIG_NFTABLES_UNIT_DIRECTORY=/etc/systemd/system
RIG_NFTABLES_NFT_PATH=/usr/sbin/nft
RIG_NFTABLES_INSTALL=/usr/bin/install
RIG_NFTABLES_RM=/bin/rm

rig_nftables_table() {
  RIG_VALUE=rig_${1//[.-]/_}
}

rig_nftables_validate_platforms() {
  local section index field end count

  section=$1; index=$2
  field=${RIG_SECTION_FIELD_STARTS[$index]}; end=${RIG_SECTION_FIELD_ENDS[$index]}
  count=0
  while [ "$field" -lt "$end" ]; do
    if [ "${RIG_FIELD_KEYS[$field]}" = platform ]; then
      count=$((count + 1))
      [ "${RIG_FIELD_VALUES[$field]}" = linux ] ||
        rig_fail "[$section] supports only platform 'linux'" || return
    fi
    field=$((field + 1))
  done
  [ "$count" -gt 0 ] || rig_fail "[$section] requires field 'platform'" || return
}

# Two locators differing only in '.' and '-' would share one nftables table.
rig_nftables_validate_table() {
  local section index locator table other

  section=$1; index=$2; locator=$3
  rig_nftables_table "$locator"
  table=$RIG_VALUE
  other=0
  while [ "$other" -lt "$index" ]; do
    if [ "${RIG_SECTION_TYPES[$other]}" = firewall ] &&
      rig_get_value "${RIG_SECTION_NAMES[$other]}" provider && [ "$RIG_VALUE" = linux-nftables ] &&
      rig_get_value "${RIG_SECTION_NAMES[$other]}" locator && rig_nftables_table "$RIG_VALUE" &&
      [ "$RIG_VALUE" = "$table" ]; then
      rig_fail "[$section] shares nftables table '$table' with [${RIG_SECTION_NAMES[$other]}]" || return
    fi
    other=$((other + 1))
  done
}

rig_nftables_paths() {
  local locator

  locator=$1
  rig_firewall_system_path "$RIG_NFTABLES_RULES_DIRECTORY/$locator.nft" || return
  RIG_NFTABLES_RULES=$RIG_VALUE
  rig_firewall_system_path "$RIG_NFTABLES_UNIT_DIRECTORY/$locator.service" || return
  RIG_NFTABLES_UNIT=$RIG_VALUE
  rig_nftables_table "$locator"
  RIG_NFTABLES_TABLE=$RIG_VALUE
}

rig_nftables_render_rules() {
  local section table port protocol number

  section=$1
  rig_get_value "$section" locator || return 2
  rig_nftables_table "$RIG_VALUE"
  table=$RIG_VALUE
  rig_firewall_ports "$section" || return
  printf '# Managed by rig from %s. Generated file; rig apply replaces edits.\n' "$section"
  printf '# Declared ports accept loopback and tailnet-to-tailnet traffic only.\n'
  # Declaring then deleting the table lets one nft -f replace it atomically.
  printf 'table inet %s\ndelete table inet %s\n' "$table" "$table"
  printf 'table inet %s {\n\tchain input {\n' "$table"
  printf '\t\ttype filter hook input priority filter; policy accept;\n'
  for port in "${RIG_FIREWALL_PORTS[@]}"; do
    protocol=${port%%:*}
    number=${port#*:}
    printf '\t\tiif "lo" %s dport %s accept\n' "$protocol" "$number"
    printf '\t\tip saddr %s ip daddr %s %s dport %s accept\n' \
      "$RIG_FIREWALL_TAILNET_IPV4" "$RIG_FIREWALL_TAILNET_IPV4" "$protocol" "$number"
    printf '\t\tip6 saddr %s ip6 daddr %s %s dport %s accept\n' \
      "$RIG_FIREWALL_TAILNET_IPV6" "$RIG_FIREWALL_TAILNET_IPV6" "$protocol" "$number"
    printf '\t\t%s dport %s drop\n' "$protocol" "$number"
  done
  printf '\t}\n}\n'
}

rig_nftables_render_unit() {
  local section locator table

  section=$1
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_nftables_table "$locator"
  table=$RIG_VALUE
  printf '# Managed by rig from %s. Generated file; rig apply replaces edits.\n' "$section"
  printf '%s\n' '[Unit]'
  printf 'Description=Rig tailnet-only firewall %s\n' "$locator"
  printf '%s\n' 'DefaultDependencies=no' 'Wants=network-pre.target' \
    'After=nftables.service ufw.service' 'Before=network-pre.target shutdown.target' \
    'Conflicts=shutdown.target' '' '[Service]' 'Type=oneshot' 'RemainAfterExit=yes'
  printf 'ExecStart=%s -f %s/%s.nft\n' "$RIG_NFTABLES_NFT_PATH" "$RIG_NFTABLES_RULES_DIRECTORY" "$locator"
  printf 'ExecStop=-%s delete table inet %s\n' "$RIG_NFTABLES_NFT_PATH" "$table"
  printf '%s\n' '' '[Install]' 'WantedBy=multi-user.target'
}

# Compare rules as nft lists them: no comments, preamble or indentation.
# Callers run it in a command substitution, so disabling globbing stays local.
rig_nftables_normalise_rules() {
  local table line

  table=$1
  set -f
  while IFS= read -r line || [ -n "$line" ]; do
    # Collapse runs of whitespace to single spaces.
    # shellcheck disable=SC2086
    set -- $line
    line=$*
    case "$line" in ''|'#'*|"table inet $table"|"delete table inet $table") continue ;; esac
    printf '%s\n' "$line"
  done
}

rig_nftables_nft() {
  RIG_VALUE=${RIG_NFT:-$RIG_NFTABLES_NFT_PATH}
}

rig_nftables_systemctl() {
  RIG_VALUE=${RIG_SYSTEMCTL:-/usr/bin/systemctl}
}

rig_nftables_ss() {
  if [ -n "${RIG_SS_COMMAND:-}" ]; then
    [ -x "$RIG_SS_COMMAND" ] || return 1
    RIG_VALUE=$RIG_SS_COMMAND
    return 0
  fi
  RIG_VALUE=/usr/bin/ss
  [ -x "$RIG_VALUE" ]
}

# Read the unit's load, activity, enablement and last result without privilege.
rig_nftables_unit_state() {
  local locator command output native_status key value

  locator=$1
  rig_nftables_systemctl
  command=$RIG_VALUE
  RIG_NFTABLES_LOAD_STATE=not-found
  RIG_NFTABLES_ACTIVE_STATE=inactive
  RIG_NFTABLES_FILE_STATE=
  RIG_NFTABLES_RESULT=success
  output=$("$command" show "$locator.service" --property=LoadState,ActiveState,UnitFileState,Result 2>&1)
  native_status=$?
  if [ "$native_status" -ne 0 ]; then
    RIG_OBSERVATION_DETAIL=systemctl-exit:$native_status
    return 1
  fi
  while IFS='=' read -r key value; do
    case "$key" in
      LoadState) RIG_NFTABLES_LOAD_STATE=$value ;;
      ActiveState) RIG_NFTABLES_ACTIVE_STATE=$value ;;
      UnitFileState) RIG_NFTABLES_FILE_STATE=$value ;;
      Result) RIG_NFTABLES_RESULT=$value ;;
    esac
  done <<< "$output"
}

# Set RIG_VALUE to the declared ports that listen on every address.
rig_nftables_exposed_ports() {
  local section command output port protocol number netid local_address host exposed

  section=$1
  rig_nftables_ss || { RIG_OBSERVATION_DETAIL=ss-unavailable; return 1; }
  command=$RIG_VALUE
  if ! output=$("$command" -Hltun 2>/dev/null); then
    RIG_OBSERVATION_DETAIL=ss-failed
    return 1
  fi
  rig_firewall_ports "$section" || return 2
  exposed=
  for port in "${RIG_FIREWALL_PORTS[@]}"; do
    protocol=${port%%:*}
    number=${port#*:}
    while read -r netid _ _ _ local_address _; do
      [ "$netid" = "$protocol" ] || continue
      [ "${local_address##*:}" = "$number" ] || continue
      host=${local_address%:*}
      case "$host" in *%lo) continue ;; esac
      case "${host%%\%*}" in
        '*'|0.0.0.0|'[::]')
          exposed="$exposed${exposed:+,}$port"
          break
          ;;
      esac
    done <<< "$output"
  done
  RIG_VALUE=$exposed
}

rig_nftables_render_files() {
  local section

  section=$1
  RIG_NFTABLES_RENDERED_RULES=
  RIG_NFTABLES_RENDERED_UNIT=
  RIG_NFTABLES_RENDERED_RULES=$(mktemp "${TMPDIR:-/tmp}/rig-firewall-rules.XXXXXX") || return 1
  RIG_NFTABLES_RENDERED_UNIT=$(mktemp "${TMPDIR:-/tmp}/rig-firewall-unit.XXXXXX") || {
    rig_nftables_discard_files; return 1; }
  if ! rig_nftables_render_rules "$section" >"$RIG_NFTABLES_RENDERED_RULES" ||
    ! rig_nftables_render_unit "$section" >"$RIG_NFTABLES_RENDERED_UNIT" ||
    ! chmod 0644 "$RIG_NFTABLES_RENDERED_RULES" "$RIG_NFTABLES_RENDERED_UNIT"; then
    rig_nftables_discard_files
    return 1
  fi
}

rig_nftables_discard_files() {
  [ -z "${RIG_NFTABLES_RENDERED_RULES:-}" ] || rm -f "$RIG_NFTABLES_RENDERED_RULES"
  [ -z "${RIG_NFTABLES_RENDERED_UNIT:-}" ] || rm -f "$RIG_NFTABLES_RENDERED_UNIT"
  RIG_NFTABLES_RENDERED_RULES=
  RIG_NFTABLES_RENDERED_UNIT=
}

# Observe files, unit and listener exposure without privilege. Listing the
# table needs root, so a present restriction says its kernel rules are
# unverified.
rig_nftables_observe() {
  local section locator reasons exposed

  section=$1
  RIG_OBSERVATION=unavailable
  RIG_OBSERVATION_DETAIL=-
  RIG_NFTABLES_RULES_STATE=-
  RIG_NFTABLES_UNIT_STATE=-
  RIG_FIREWALL_EXPOSED=
  if [ "${RIG_RESOLVED_PLATFORM:-linux}" != linux ]; then
    RIG_OBSERVATION_DETAIL=unsupported-platform
    return 0
  fi
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_nftables_paths "$locator" || return
  if rig_firewall_unsafe_path "$RIG_NFTABLES_RULES"; then RIG_OBSERVATION_DETAIL=unsafe-rules; return 0; fi
  if rig_firewall_unsafe_path "$RIG_NFTABLES_UNIT"; then RIG_OBSERVATION_DETAIL=unsafe-unit; return 0; fi
  rig_nftables_exposed_ports "$section" || return 0
  exposed=$RIG_VALUE
  RIG_FIREWALL_EXPOSED=$exposed
  if ! rig_nftables_render_files "$section"; then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL=render-failed
    return 0
  fi
  reasons=
  if [ ! -f "$RIG_NFTABLES_RULES" ]; then
    RIG_NFTABLES_RULES_STATE=missing; reasons=rules-missing
  elif ! cmp -s "$RIG_NFTABLES_RENDERED_RULES" "$RIG_NFTABLES_RULES"; then
    RIG_NFTABLES_RULES_STATE=changed; reasons=rules-changed
  else
    RIG_NFTABLES_RULES_STATE=current
  fi
  if [ ! -f "$RIG_NFTABLES_UNIT" ]; then
    RIG_NFTABLES_UNIT_STATE=missing; reasons="$reasons${reasons:+,}unit-missing"
  elif ! cmp -s "$RIG_NFTABLES_RENDERED_UNIT" "$RIG_NFTABLES_UNIT"; then
    RIG_NFTABLES_UNIT_STATE=changed; reasons="$reasons${reasons:+,}unit-changed"
  else
    RIG_NFTABLES_UNIT_STATE=current
  fi
  rig_nftables_discard_files
  if ! rig_nftables_unit_state "$locator"; then
    RIG_OBSERVATION=unknown
    return 0
  fi
  if [ "$RIG_NFTABLES_UNIT_STATE" != missing ]; then
    [ "$RIG_NFTABLES_FILE_STATE" = enabled ] || reasons="$reasons${reasons:+,}unit-not-enabled"
    if [ "$RIG_NFTABLES_ACTIVE_STATE" != active ]; then
      if [ "$RIG_NFTABLES_RESULT" != success ]; then
        reasons="$reasons${reasons:+,}unit-result:$RIG_NFTABLES_RESULT"
      else
        reasons="$reasons${reasons:+,}unit-not-active"
      fi
    fi
  fi
  if [ -z "$reasons" ]; then
    RIG_OBSERVATION=present
    RIG_OBSERVATION_DETAIL=kernel-rules-unverified
    return 0
  fi
  if [ "$RIG_NFTABLES_RULES_STATE.$RIG_NFTABLES_UNIT_STATE.$RIG_NFTABLES_ACTIVE_STATE" = missing.missing.inactive ]; then
    RIG_OBSERVATION=missing
    reasons=-
  else
    RIG_OBSERVATION=drifted
  fi
  if [ -n "$exposed" ]; then
    [ "$reasons" != - ] || reasons=
    reasons="$reasons${reasons:+,}exposed-beyond-tailnet"
  fi
  RIG_OBSERVATION_DETAIL=$reasons
}

rig_nftables_preflight() {
  local section verb locator

  section=$1; verb=$2
  RIG_RESOURCE_PREFLIGHT_DETAIL=
  if [ "${RIG_RESOLVED_PLATFORM:-linux}" != linux ]; then
    RIG_RESOURCE_PREFLIGHT_DETAIL=unsupported-platform
    return 1
  fi
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_nftables_paths "$locator" || return
  if rig_firewall_unsafe_path "$RIG_NFTABLES_RULES" || rig_firewall_unsafe_path "$RIG_NFTABLES_UNIT"; then
    RIG_RESOURCE_PREFLIGHT_DETAIL=unsafe-firewall-file
    return 1
  fi
  rig_nftables_systemctl
  rig_executable_available "$RIG_VALUE" || { RIG_RESOURCE_PREFLIGHT_DETAIL='systemctl-unavailable'; return 1; }
  if [ "$verb" = apply-resource ]; then
    rig_nftables_nft
    rig_executable_available "$RIG_VALUE" || { RIG_RESOURCE_PREFLIGHT_DETAIL='nft-unavailable'; return 1; }
  fi
  rig_nftables_ss || { RIG_RESOURCE_PREFLIGHT_DETAIL=ss-unavailable; return 1; }
  rig_nftables_systemctl
}

rig_nftables_preflight_retirement() {
  local locator

  locator=$1
  [ "${RIG_RESOLVED_PLATFORM:-linux}" = linux ] ||
    rig_fail "provider 'linux-nftables' requires platform 'linux'" || return
  rig_firewall_locator_valid "$locator" ||
    rig_fail "provider 'linux-nftables' has invalid locator '$locator'" || return
  rig_nftables_paths "$locator" || return
  if rig_firewall_unsafe_path "$RIG_NFTABLES_RULES" || rig_firewall_unsafe_path "$RIG_NFTABLES_UNIT"; then
    rig_fail "provider 'linux-nftables' refuses unsafe firewall file for '$locator'" || return
  fi
  rig_nftables_systemctl
  rig_executable_available "$RIG_VALUE" ||
    rig_fail "provider 'linux-nftables' executable is unavailable: $RIG_VALUE" || return
  rig_nftables_nft
  rig_executable_available "$RIG_VALUE" ||
    rig_fail "provider 'linux-nftables' executable is unavailable: $RIG_VALUE" || return
}

rig_nftables_loaded_rules_match() {
  local table nft loaded

  table=$1
  rig_nftables_nft
  nft=$RIG_VALUE
  loaded=$(rig_firewall_sudo "$nft" list table inet "$table" 2>/dev/null) || return 1
  [ "$(printf '%s\n' "$loaded" | rig_nftables_normalise_rules "$table")" = \
    "$(rig_nftables_normalise_rules "$table" <"$RIG_NFTABLES_RULES")" ]
}

rig_nftables_apply() {
  local section locator systemctl nft unit

  section=$1
  [ "${RIG_SUDO_GRANTED:-0}" -eq 1 ] || {
    rig_nftables_observe "$section" || return
    [ "$RIG_OBSERVATION" = present ] && return 0
    printf 'rig: %s: administrator-grant-required\n' "$section" >&2
    return 1
  }
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  unit=$locator.service
  rig_nftables_observe "$section" || return
  case "$RIG_OBSERVATION" in
    present)
      rig_nftables_loaded_rules_match "$RIG_NFTABLES_TABLE" && return 0
      printf 'rig: %s: loaded rules differ from the rendered table; reloading.\n' "$section" >&2
      ;;
    missing|drifted) ;;
    *) printf 'rig: %s: %s\n' "$section" "$RIG_OBSERVATION_DETAIL" >&2; return 1 ;;
  esac
  rig_nftables_systemctl; systemctl=$RIG_VALUE
  rig_nftables_nft; nft=$RIG_VALUE
  rig_nftables_render_files "$section" || return 1
  if ! rig_firewall_sudo "$nft" -c -f "$RIG_NFTABLES_RENDERED_RULES" 1>&2; then
    printf 'rig: %s: nft rejected the rendered table; nothing installed.\n' "$section" >&2
    rig_nftables_discard_files
    return 1
  fi
  if [ "$RIG_NFTABLES_RULES_STATE" != current ] &&
    ! rig_firewall_sudo "$RIG_NFTABLES_INSTALL" -D -o root -g root -m 0644 \
      "$RIG_NFTABLES_RENDERED_RULES" "$RIG_NFTABLES_RULES" 1>&2; then
    rig_nftables_discard_files
    return 1
  fi
  if [ "$RIG_NFTABLES_UNIT_STATE" != current ]; then
    if ! rig_firewall_sudo "$RIG_NFTABLES_INSTALL" -D -o root -g root -m 0644 \
      "$RIG_NFTABLES_RENDERED_UNIT" "$RIG_NFTABLES_UNIT" 1>&2; then
      rig_nftables_discard_files
      return 1
    fi
    rig_firewall_sudo "$systemctl" daemon-reload 1>&2 || { rig_nftables_discard_files; return 1; }
  fi
  rig_nftables_discard_files
  if [ "$RIG_NFTABLES_FILE_STATE" != enabled ] || [ "$RIG_NFTABLES_UNIT_STATE" != current ]; then
    rig_firewall_sudo "$systemctl" enable "$unit" 1>&2 || return
  fi
  rig_firewall_sudo "$systemctl" restart "$unit" 1>&2 || return
  rig_nftables_loaded_rules_match "$RIG_NFTABLES_TABLE" && return 0
  printf 'rig: %s: loaded rules do not match the rendered table.\n' "$section" >&2
  return 1
}

# Retirement removes only Rig's own unit, table and files; every other table,
# ufw and the distribution's nftables configuration stay untouched.
rig_nftables_retire() {
  local locator systemctl nft

  locator=$1
  [ "${RIG_SUDO_GRANTED:-0}" -eq 1 ] || {
    printf 'rig: firewall %s: administrator-grant-required\n' "$locator" >&2
    return 1
  }
  rig_nftables_paths "$locator" || return
  rig_nftables_systemctl; systemctl=$RIG_VALUE
  rig_nftables_nft; nft=$RIG_VALUE
  if [ -f "$RIG_NFTABLES_UNIT" ]; then
    rig_firewall_sudo "$systemctl" disable --now "$locator.service" 1>&2 || return
  fi
  if rig_firewall_sudo "$nft" list table inet "$RIG_NFTABLES_TABLE" >/dev/null 2>&1; then
    rig_firewall_sudo "$nft" delete table inet "$RIG_NFTABLES_TABLE" 1>&2 || return
  fi
  rig_firewall_sudo "$RIG_NFTABLES_RM" -f -- "$RIG_NFTABLES_UNIT" "$RIG_NFTABLES_RULES" 1>&2 || return
  rig_firewall_sudo "$systemctl" daemon-reload 1>&2
}

rig_nftables_print_projection() {
  local section locator line

  section=$1
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_nftables_paths "$locator" || return
  printf '  rules=%s\n' "$RIG_NFTABLES_RULES"
  printf '  unit=%s\n' "$RIG_NFTABLES_UNIT"
  while IFS= read -r line; do
    # shellcheck disable=SC2086
    set -- $line
    line=$*
    case "$line" in ''|'#'*) continue ;; esac
    printf '  rule=%s\n' "$line"
  done < <(rig_nftables_render_rules "$section")
  printf '  command=sudo -n nft -c -f %s\n' "$RIG_NFTABLES_RULES"
  printf '  command=sudo -n install -D -o root -g root -m 0644 %s\n' "$RIG_NFTABLES_RULES"
  printf '  command=sudo -n install -D -o root -g root -m 0644 %s\n' "$RIG_NFTABLES_UNIT"
  printf '  command=sudo -n systemctl daemon-reload\n'
  printf '  command=sudo -n systemctl enable %s.service\n' "$locator"
  printf '  command=sudo -n systemctl restart %s.service\n' "$locator"
  printf '  command=sudo -n nft list table inet %s\n' "$RIG_NFTABLES_TABLE"
}

rig_nftables_explain() {
  local section locator

  section=$1
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_nftables_paths "$locator" || return
  printf 'Allowed sources: lo, %s, %s\n' "$RIG_FIREWALL_TAILNET_IPV4" "$RIG_FIREWALL_TAILNET_IPV6"
  printf 'nftables table: inet %s\nRules file: %s\nUnit file: %s\n' \
    "$RIG_NFTABLES_TABLE" "$RIG_NFTABLES_RULES" "$RIG_NFTABLES_UNIT"
  rig_current_platform || return
  RIG_RESOLVED_PLATFORM=$RIG_VALUE
  rig_nftables_observe "$section" || return
  printf 'Observed state: %s (%s)\n' "$RIG_OBSERVATION" "$RIG_OBSERVATION_DETAIL"
}
