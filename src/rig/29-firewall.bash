# rig-module: 29-firewall
# shellcheck shell=bash
# Cross-module native observations and apply state are shared deliberately.
# shellcheck disable=SC2034

# A firewall declaration restricts named listeners to loopback and to tailnet
# sources addressing the Mac's own tailnet addresses, with a pf child anchor
# beneath Apple's com.apple/* anchor point. Rig owns the anchor file and a
# system LaunchDaemon that reloads it at boot and whenever /etc/pf.conf
# changes; it never edits /etc/pf.conf, never calls socketfilterfw and never
# flushes an anchor it does not own. Every system path is resolved
# beneath RIG_SYSTEM_ROOT so fixtures can redirect them; the rendered content
# always names the real paths.
RIG_FIREWALL_TAILNET_IPV4=100.64.0.0/10
RIG_FIREWALL_TAILNET_IPV6=fd7a:115c:a1e0::/48
RIG_FIREWALL_ANCHOR_DIRECTORY=/etc/pf.anchors
RIG_FIREWALL_DAEMON_DIRECTORY=/Library/LaunchDaemons
RIG_FIREWALL_PFCTL_PATH=/sbin/pfctl
RIG_FIREWALL_INSTALL=/usr/bin/install
RIG_FIREWALL_RM=/bin/rm

rig_firewall_locator_valid() {
  case "$1" in
    ''|.*|*.|*..*|*[!A-Za-z0-9.-]*|com.apple.*) return 1 ;;
    *.*) return 0 ;;
  esac
  return 1
}

rig_firewall_port_valid() {
  local protocol number

  protocol=${1%%:*}
  number=${1#*:}
  case "$protocol" in tcp|udp) ;; *) return 1 ;; esac
  case "$number" in ''|0*|*[!0-9]*|??????*) return 1 ;; esac
  [ "$number" -le 65535 ]
}

rig_validate_firewall() {
  local section index provider locator field end value seen count other

  section=$1; index=$2
  rig_require_field "$section" name || return
  rig_require_field "$section" purpose || return
  rig_require_field "$section" rationale || return
  rig_require_field "$section" provider || return
  provider=$RIG_VALUE
  case "$provider" in
    macos-pf|linux-nftables) ;;
    *) rig_fail "[$section] provider must be 'macos-pf' or 'linux-nftables'" || return ;;
  esac
  rig_require_field "$section" locator || return
  locator=$RIG_VALUE
  rig_firewall_locator_valid "$locator" ||
    rig_fail "[$section] locator must be a reverse-DNS label outside com.apple" || return
  if [ "$provider" = linux-nftables ]; then
    rig_nftables_validate_platforms "$section" "$index" || return
  else
    rig_validate_macos_platforms "$section" || return
  fi
  rig_validate_references_for_field "$index" requires tool || return
  field=${RIG_SECTION_FIELD_STARTS[$index]}; end=${RIG_SECTION_FIELD_ENDS[$index]}
  seen=' '; count=0
  while [ "$field" -lt "$end" ]; do
    value=${RIG_FIELD_VALUES[$field]}
    case "${RIG_FIELD_KEYS[$field]}" in
      port)
        rig_firewall_port_valid "$value" ||
          rig_fail "[$section] ports entries must be 'tcp:N' or 'udp:N' with N from 1 to 65535" || return
        case "$value" in tcp:22|udp:22)
          rig_fail "[$section] must not restrict port 22; SSH is the recovery path" || return ;;
        esac
        case "$seen" in *" $value "*) rig_fail "[$section] duplicates port '$value'" || return ;; esac
        seen="$seen$value "
        ;;
      allow)
        [ "$value" = tailnet ] || rig_fail "[$section] allow accepts only 'tailnet'" || return
        count=$((count + 1))
        ;;
    esac
    field=$((field + 1))
  done
  [ "$seen" != ' ' ] || rig_fail "[$section] requires field 'ports'" || return
  [ "$count" -eq 1 ] || rig_fail "[$section] allow must be [\"tailnet\"]" || return
  other=0
  while [ "$other" -lt "$index" ]; do
    if [ "${RIG_SECTION_TYPES[$other]}" = firewall ] &&
      rig_get_value "${RIG_SECTION_NAMES[$other]}" locator && [ "$RIG_VALUE" = "$locator" ]; then
      rig_fail "[$section] duplicates firewall locator from [${RIG_SECTION_NAMES[$other]}]" || return
    fi
    other=$((other + 1))
  done
  [ "$provider" != linux-nftables ] || rig_nftables_validate_table "$section" "$index" "$locator"
}

rig_firewall_ports() {
  local section index field end

  section=$1
  rig_section_index "$section" || return 2
  index=$RIG_INDEX
  RIG_FIREWALL_PORTS=()
  field=${RIG_SECTION_FIELD_STARTS[$index]}; end=${RIG_SECTION_FIELD_ENDS[$index]}
  while [ "$field" -lt "$end" ]; do
    [ "${RIG_FIELD_KEYS[$field]}" != port ] ||
      RIG_FIREWALL_PORTS[${#RIG_FIREWALL_PORTS[@]}]=${RIG_FIELD_VALUES[$field]}
    field=$((field + 1))
  done
}

# Report the first protocol and port two firewall declarations both restrict.
rig_firewall_shared_port() {
  local first port

  rig_firewall_ports "$1" || return 2
  first=" ${RIG_FIREWALL_PORTS[*]} "
  rig_firewall_ports "$2" || return 2
  for port in "${RIG_FIREWALL_PORTS[@]}"; do
    case "$first" in *" $port "*) RIG_VALUE=$port; return 0 ;; esac
  done
  return 1
}

rig_firewall_system_path() {
  local root

  root=${RIG_SYSTEM_ROOT:-/}
  while [ "${root%/}" != "$root" ]; do root=${root%/}; done
  RIG_VALUE=$root$1
}

rig_firewall_paths() {
  local locator

  locator=$1
  rig_firewall_system_path "$RIG_FIREWALL_ANCHOR_DIRECTORY/$locator" || return
  RIG_FIREWALL_ANCHOR=$RIG_VALUE
  rig_firewall_system_path "$RIG_FIREWALL_DAEMON_DIRECTORY/$locator.plist" || return
  RIG_FIREWALL_DAEMON=$RIG_VALUE
}

rig_firewall_ifconfig() {
  RIG_VALUE=${RIG_IFCONFIG_COMMAND:-/sbin/ifconfig}
}

# Discover the Mac's own tailnet addresses read-only. The tailnet interface is
# the single interface holding an address in Tailscale's IPv6 ULA prefix; its
# one IPv4 address in 100.64.0.0/10 and its one ULA address are the result. A
# local network that hands out 100.64.0.0/10 never adds Tailscale's ULA, so the
# pairing separates the two. Anything else is undiscoverable, never guessed.
rig_firewall_tailnet_addresses() {
  local command output line interface address tailnet ipv4 ipv6 count4 count6

  RIG_FIREWALL_SELF_IPV4=
  RIG_FIREWALL_SELF_IPV6=
  rig_firewall_ifconfig
  command=$RIG_VALUE
  RIG_VALUE='tailnet-address-undiscoverable'
  [ -x "$command" ] || return 1
  output=$("$command" 2>/dev/null) || return 1
  interface=; tailnet=
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in [[:space:]]*) ;; *) interface=${line%%:*}; continue ;; esac
    # shellcheck disable=SC2086
    set -- $line
    case "${1:-}:${2:-}" in inet6:fd7a:115c:a1e0:*) ;; *) continue ;; esac
    [ -z "$tailnet" ] || [ "$tailnet" = "$interface" ] || return 1
    tailnet=$interface
  done <<< "$output"
  [ -n "$tailnet" ] || return 1
  interface=; ipv4=; ipv6=; count4=0; count6=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in [[:space:]]*) ;; *) interface=${line%%:*}; continue ;; esac
    [ "$interface" = "$tailnet" ] || continue
    # shellcheck disable=SC2086
    set -- $line
    address=${2:-}
    case "${1:-}:$address" in
      inet:*[!0-9.]*|inet6:*[!0-9a-f:]*) ;;
      inet:100.6[4-9].*|inet:100.[7-9][0-9].*|inet:100.1[01][0-9].*|inet:100.12[0-7].*)
        ipv4=$address; count4=$((count4 + 1)) ;;
      inet6:fd7a:115c:a1e0:*) ipv6=$address; count6=$((count6 + 1)) ;;
    esac
  done <<< "$output"
  [ "$count4" -eq 1 ] && [ "$count6" -eq 1 ] || return 1
  RIG_FIREWALL_SELF_IPV4=$ipv4
  RIG_FIREWALL_SELF_IPV6=$ipv6
  RIG_VALUE=
}

# Render from the addresses rig_firewall_tailnet_addresses discovered.
rig_firewall_render_anchor() {
  local section port protocol number state

  section=$1
  [ -n "${RIG_FIREWALL_SELF_IPV4:-}" ] && [ -n "${RIG_FIREWALL_SELF_IPV6:-}" ] || return 1
  rig_firewall_ports "$section" || return
  printf '# Managed by rig from %s. Generated file; rig apply replaces edits.\n' "$section"
  printf '# Declared ports accept loopback, and tailnet sources addressing this Mac'"'"'s own tailnet addresses.\n'
  for port in "${RIG_FIREWALL_PORTS[@]}"; do
    protocol=${port%%:*}
    number=${port#*:}
    state='keep state'
    [ "$protocol" != tcp ] || state='flags S/SA keep state'
    printf 'pass in quick on lo0 proto %s from any to any port = %s %s\n' "$protocol" "$number" "$state"
    printf 'pass in quick inet proto %s from %s to %s port = %s %s\n' "$protocol" \
      "$RIG_FIREWALL_TAILNET_IPV4" "$RIG_FIREWALL_SELF_IPV4" "$number" "$state"
    printf 'pass in quick inet6 proto %s from %s to %s port = %s %s\n' "$protocol" \
      "$RIG_FIREWALL_TAILNET_IPV6" "$RIG_FIREWALL_SELF_IPV6" "$number" "$state"
    printf 'block drop in quick proto %s from any to any port = %s\n' "$protocol" "$number"
  done
}

rig_firewall_render_daemon() {
  local section locator

  section=$1
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
  printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  printf '<!-- Managed by rig from %s. Generated file; rig apply replaces edits. -->\n' "$section"
  printf '%s\n' '<plist version="1.0">' '<dict>'
  printf '  <key>Label</key>\n  <string>%s</string>\n' "$locator"
  printf '%s\n' '  <key>ProgramArguments</key>' '  <array>'
  printf '    <string>%s</string>\n' "$RIG_FIREWALL_PFCTL_PATH" -E -a "com.apple/$locator" \
    -f "$RIG_FIREWALL_ANCHOR_DIRECTORY/$locator"
  printf '%s\n' '  </array>' '  <key>RunAtLoad</key>' '  <true/>' \
    '  <key>WatchPaths</key>' '  <array>' '    <string>/etc/pf.conf</string>' '  </array>' \
    '</dict>' '</plist>'
}

# Compare pf rules without the state options pfctl adds or elides on display.
rig_firewall_normalise_rules() {
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    line=${line// flags S\/SA/}
    line=${line// keep state/}
    # Collapse runs of whitespace to single spaces.
    # shellcheck disable=SC2086
    set -- $line
    printf '%s\n' "$*"
  done
}

# Replace the destination of each tailnet pass rule, so two anchors that differ
# only in the Mac's own addresses compare equal.
rig_firewall_mask_destinations() {
  local line rest

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'pass in quick inet'*' from '*' to '*' port = '*)
        rest=${line#* to }
        line="${line%% to *} to - ${rest#* }" ;;
    esac
    printf '%s\n' "$line"
  done
}

rig_firewall_launchctl() {
  RIG_VALUE=${RIG_LAUNCHCTL:-/bin/launchctl}
}

rig_firewall_pfctl() {
  RIG_VALUE=${RIG_PFCTL:-$RIG_FIREWALL_PFCTL_PATH}
}

rig_firewall_netstat() {
  rig_native_command netstat "${RIG_NETSTAT_COMMAND:-}"
}

# Run one native command through the attended grant; sudo never prompts here.
rig_firewall_sudo() {
  "${RIG_SUDO:-sudo}" -n -- "$@" </dev/null
}

rig_firewall_load_state() {
  local locator command output native_status line

  locator=$1
  rig_firewall_launchctl
  command=$RIG_VALUE
  RIG_FIREWALL_LOAD_STATE=absent
  RIG_FIREWALL_LAST_EXIT=-
  output=$("$command" print "system/$locator" 2>&1)
  native_status=$?
  if [ "$native_status" -eq 0 ]; then
    RIG_FIREWALL_LOAD_STATE=loaded
    while IFS= read -r line; do
      case "$line" in *'last exit code = '*)
        RIG_FIREWALL_LAST_EXIT=${line##*last exit code = }
        break ;;
      esac
    done <<< "$output"
    return 0
  fi
  case "$native_status:$output" in
    113:*|*'Could not find service'*|*'Could not find specified service'*) return 0 ;;
  esac
  RIG_OBSERVATION_DETAIL=launchctl-exit:$native_status
  return 1
}

# Set RIG_VALUE to the declared ports that listen on every address.
rig_firewall_exposed_ports() {
  local section command output port protocol number proto local_address state exposed

  section=$1
  rig_firewall_netstat || { RIG_OBSERVATION_DETAIL=netstat-unavailable; return 1; }
  command=$RIG_VALUE
  if ! output=$("$command" -an 2>/dev/null); then
    RIG_OBSERVATION_DETAIL=netstat-failed
    return 1
  fi
  rig_firewall_ports "$section" || return 2
  exposed=
  for port in "${RIG_FIREWALL_PORTS[@]}"; do
    protocol=${port%%:*}
    number=${port#*:}
    while read -r proto _ _ local_address _ state _; do
      [ "$local_address" = "*.$number" ] || continue
      case "$protocol:$proto:$state" in
        tcp:tcp4:LISTEN|tcp:tcp6:LISTEN|tcp:tcp46:LISTEN|udp:udp4:*|udp:udp6:*|udp:udp46:*)
          exposed="$exposed${exposed:+,}$port"
          break
          ;;
      esac
    done <<< "$output"
  done
  RIG_VALUE=$exposed
}

rig_firewall_unsafe_path() {
  [ -L "$1" ] || { [ -e "$1" ] && [ ! -f "$1" ]; }
}

rig_firewall_render_files() {
  local section

  section=$1
  RIG_FIREWALL_RENDERED_ANCHOR=
  RIG_FIREWALL_RENDERED_DAEMON=
  RIG_FIREWALL_RENDERED_ANCHOR=$(mktemp "${TMPDIR:-/tmp}/rig-firewall-anchor.XXXXXX") || return 1
  RIG_FIREWALL_RENDERED_DAEMON=$(mktemp "${TMPDIR:-/tmp}/rig-firewall-daemon.XXXXXX") || {
    rig_firewall_discard_files; return 1; }
  if ! rig_firewall_render_anchor "$section" >"$RIG_FIREWALL_RENDERED_ANCHOR" ||
    ! rig_firewall_render_daemon "$section" >"$RIG_FIREWALL_RENDERED_DAEMON" ||
    ! chmod 0644 "$RIG_FIREWALL_RENDERED_ANCHOR" "$RIG_FIREWALL_RENDERED_DAEMON"; then
    rig_firewall_discard_files
    return 1
  fi
}

rig_firewall_discard_files() {
  [ -z "${RIG_FIREWALL_RENDERED_ANCHOR:-}" ] || rm -f "$RIG_FIREWALL_RENDERED_ANCHOR"
  [ -z "${RIG_FIREWALL_RENDERED_DAEMON:-}" ] || rm -f "$RIG_FIREWALL_RENDERED_DAEMON"
  RIG_FIREWALL_RENDERED_ANCHOR=
  RIG_FIREWALL_RENDERED_DAEMON=
}

# Observe files, daemon and listener exposure without privilege. pf state needs
# root, so a present restriction says its kernel rules are unverified.
rig_firewall_observe() {
  local section locator reasons exposed

  section=$1
  rig_get_value "$section" provider || return 2
  [ "$RIG_VALUE" != linux-nftables ] || { rig_nftables_observe "$section"; return; }
  RIG_OBSERVATION=unavailable
  RIG_OBSERVATION_DETAIL=-
  RIG_FIREWALL_ANCHOR_STATE=-
  RIG_FIREWALL_DAEMON_STATE=-
  RIG_FIREWALL_EXPOSED=
  if [ "${RIG_RESOLVED_PLATFORM:-macos}" != macos ]; then
    RIG_OBSERVATION_DETAIL=unsupported-platform
    return 0
  fi
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_firewall_paths "$locator" || return
  if rig_firewall_unsafe_path "$RIG_FIREWALL_ANCHOR"; then RIG_OBSERVATION_DETAIL=unsafe-anchor; return 0; fi
  if rig_firewall_unsafe_path "$RIG_FIREWALL_DAEMON"; then RIG_OBSERVATION_DETAIL=unsafe-daemon; return 0; fi
  rig_firewall_exposed_ports "$section" || return 0
  exposed=$RIG_VALUE
  RIG_FIREWALL_EXPOSED=$exposed
  if ! rig_firewall_tailnet_addresses; then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL=$RIG_VALUE
    return 0
  fi
  if ! rig_firewall_render_files "$section"; then
    RIG_OBSERVATION=unknown
    RIG_OBSERVATION_DETAIL=render-failed
    return 0
  fi
  reasons=
  if [ ! -f "$RIG_FIREWALL_ANCHOR" ]; then
    RIG_FIREWALL_ANCHOR_STATE=missing; reasons=anchor-missing
  elif cmp -s "$RIG_FIREWALL_RENDERED_ANCHOR" "$RIG_FIREWALL_ANCHOR"; then
    RIG_FIREWALL_ANCHOR_STATE=current
  elif [ "$(rig_firewall_mask_destinations <"$RIG_FIREWALL_RENDERED_ANCHOR")" = \
    "$(rig_firewall_mask_destinations <"$RIG_FIREWALL_ANCHOR")" ]; then
    RIG_FIREWALL_ANCHOR_STATE=changed; reasons='tailnet-address-stale'
  else
    RIG_FIREWALL_ANCHOR_STATE=changed; reasons=anchor-changed
  fi
  if [ ! -f "$RIG_FIREWALL_DAEMON" ]; then
    RIG_FIREWALL_DAEMON_STATE=missing; reasons="$reasons${reasons:+,}daemon-missing"
  elif ! cmp -s "$RIG_FIREWALL_RENDERED_DAEMON" "$RIG_FIREWALL_DAEMON"; then
    RIG_FIREWALL_DAEMON_STATE=changed; reasons="$reasons${reasons:+,}daemon-changed"
  else
    RIG_FIREWALL_DAEMON_STATE=current
  fi
  rig_firewall_discard_files
  if ! rig_firewall_load_state "$locator"; then
    RIG_OBSERVATION=unknown
    return 0
  fi
  if [ "$RIG_FIREWALL_LOAD_STATE" = absent ]; then
    [ "$RIG_FIREWALL_DAEMON_STATE" = missing ] || reasons="$reasons${reasons:+,}daemon-not-loaded"
  else
    case "$RIG_FIREWALL_LAST_EXIT" in
      0|-|'(never exited)') ;;
      *) reasons="$reasons${reasons:+,}daemon-last-exit:$RIG_FIREWALL_LAST_EXIT" ;;
    esac
  fi
  if [ -z "$reasons" ]; then
    RIG_OBSERVATION=present
    RIG_OBSERVATION_DETAIL=kernel-rules-unverified
    return 0
  fi
  if [ "$RIG_FIREWALL_ANCHOR_STATE.$RIG_FIREWALL_DAEMON_STATE.$RIG_FIREWALL_LOAD_STATE" = missing.missing.absent ]; then
    RIG_OBSERVATION=missing
    reasons=-
  else
    RIG_OBSERVATION=drifted
  fi
  if [ -n "$exposed" ]; then
    [ "$reasons" != - ] || reasons=
    reasons="$reasons${reasons:+,}listening-all-addresses,kernel-rules-unverified"
  fi
  RIG_OBSERVATION_DETAIL=$reasons
}

rig_firewall_preflight() {
  local section verb locator command

  section=$1; verb=$2
  RIG_RESOURCE_PREFLIGHT_DETAIL=
  if [ "${RIG_RESOLVED_PLATFORM:-macos}" != macos ]; then
    RIG_RESOURCE_PREFLIGHT_DETAIL=unsupported-platform
    return 1
  fi
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_firewall_paths "$locator" || return
  if rig_firewall_unsafe_path "$RIG_FIREWALL_ANCHOR" || rig_firewall_unsafe_path "$RIG_FIREWALL_DAEMON"; then
    RIG_RESOURCE_PREFLIGHT_DETAIL=unsafe-firewall-file
    return 1
  fi
  rig_firewall_launchctl
  rig_executable_available "$RIG_VALUE" || { RIG_RESOURCE_PREFLIGHT_DETAIL='launchctl-unavailable'; return 1; }
  if [ "$verb" = apply-resource ]; then
    rig_firewall_pfctl
    command=$RIG_VALUE
    rig_executable_available "$command" || { RIG_RESOURCE_PREFLIGHT_DETAIL='pfctl-unavailable'; return 1; }
  fi
  rig_firewall_netstat || { RIG_RESOURCE_PREFLIGHT_DETAIL=netstat-unavailable; return 1; }
  rig_firewall_launchctl
}

rig_firewall_preflight_retirement() {
  local locator

  locator=$1
  [ "${RIG_RESOLVED_PLATFORM:-macos}" = macos ] ||
    rig_fail "provider 'macos-pf' requires platform 'macos'" || return
  rig_firewall_locator_valid "$locator" ||
    rig_fail "provider 'macos-pf' has invalid locator '$locator'" || return
  rig_firewall_paths "$locator" || return
  if rig_firewall_unsafe_path "$RIG_FIREWALL_ANCHOR" || rig_firewall_unsafe_path "$RIG_FIREWALL_DAEMON"; then
    rig_fail "provider 'macos-pf' refuses unsafe firewall file for '$locator'" || return
  fi
  rig_firewall_launchctl
  rig_executable_available "$RIG_VALUE" ||
    rig_fail "provider 'macos-pf' executable is unavailable: $RIG_VALUE" || return
  rig_firewall_pfctl
  rig_executable_available "$RIG_VALUE" ||
    rig_fail "provider 'macos-pf' executable is unavailable: $RIG_VALUE" || return
}

# An absent grant leaves a firewall that needs work untouched; a present one is
# already satisfied, so apply needs no grant to leave it alone. An undiscoverable
# tailnet address leaves it untouched with or without the grant.
rig_firewall_apply_ready() {
  RIG_VALUE=-
  rig_firewall_observe "$1" || return
  [ "$RIG_OBSERVATION" != present ] || return 0
  if [ "$RIG_OBSERVATION_DETAIL" = tailnet-address-undiscoverable ]; then
    RIG_VALUE=$RIG_OBSERVATION_DETAIL
    return 1
  fi
  [ "${RIG_SUDO_GRANTED:-0}" -ne 1 ] || return 0
  RIG_VALUE=administrator-grant-required
  return 1
}

rig_firewall_loaded_rules_match() {
  local locator pfctl loaded

  locator=$1
  rig_firewall_pfctl
  pfctl=$RIG_VALUE
  loaded=$(rig_firewall_sudo "$pfctl" -a "com.apple/$locator" -s rules 2>/dev/null) || return 1
  [ "$(printf '%s\n' "$loaded" | rig_firewall_normalise_rules)" = \
    "$(rig_firewall_normalise_rules <"$RIG_FIREWALL_ANCHOR")" ]
}

rig_firewall_wait_unloaded() {
  local locator waited timeout

  locator=$1
  waited=0
  timeout=${RIG_LAUNCHD_UNLOAD_TIMEOUT:-30}
  while :; do
    rig_firewall_load_state "$locator" || return
    [ "$RIG_FIREWALL_LOAD_STATE" != absent ] || return 0
    [ "$waited" -lt "$timeout" ] || break
    sleep 1
    waited=$((waited + 1))
  done
  printf 'rig: %s: launchctl-unload-timeout:%s\n' "$locator" "$timeout" >&2
  return 1
}

rig_firewall_apply() {
  local section locator launchctl pfctl replace

  section=$1
  [ "${RIG_SUDO_GRANTED:-0}" -eq 1 ] || {
    rig_firewall_observe "$section" || return
    [ "$RIG_OBSERVATION" = present ] && return 0
    printf 'rig: %s: administrator-grant-required\n' "$section" >&2
    return 1
  }
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_firewall_observe "$section" || return
  case "$RIG_OBSERVATION" in
    present)
      rig_firewall_loaded_rules_match "$locator" && return 0
      printf 'rig: %s: loaded rules differ from the rendered anchor; reloading.\n' "$section" >&2
      ;;
    missing|drifted) ;;
    *) printf 'rig: %s: %s\n' "$section" "$RIG_OBSERVATION_DETAIL" >&2; return 1 ;;
  esac
  rig_firewall_launchctl; launchctl=$RIG_VALUE
  rig_firewall_pfctl; pfctl=$RIG_VALUE
  rig_firewall_render_files "$section" || return 1
  if ! rig_firewall_sudo "$pfctl" -n -f "$RIG_FIREWALL_RENDERED_ANCHOR" 1>&2; then
    printf 'rig: %s: pfctl rejected the rendered anchor; nothing installed.\n' "$section" >&2
    rig_firewall_discard_files
    return 1
  fi
  if [ "$RIG_FIREWALL_ANCHOR_STATE" != current ] &&
    ! rig_firewall_sudo "$RIG_FIREWALL_INSTALL" -o root -g wheel -m 0644 \
      "$RIG_FIREWALL_RENDERED_ANCHOR" "$RIG_FIREWALL_ANCHOR" 1>&2; then
    rig_firewall_discard_files
    return 1
  fi
  replace=0
  [ "$RIG_FIREWALL_DAEMON_STATE" = current ] || replace=1
  case "$RIG_FIREWALL_LAST_EXIT" in 0|-|'(never exited)') ;; *) replace=1 ;; esac
  if [ "$replace" -eq 1 ] && [ "$RIG_FIREWALL_LOAD_STATE" = loaded ]; then
    if ! rig_firewall_sudo "$launchctl" bootout "system/$locator" 1>&2 ||
      ! rig_firewall_wait_unloaded "$locator"; then
      rig_firewall_discard_files
      return 1
    fi
    RIG_FIREWALL_LOAD_STATE=absent
  fi
  if [ "$RIG_FIREWALL_DAEMON_STATE" != current ] &&
    ! rig_firewall_sudo "$RIG_FIREWALL_INSTALL" -o root -g wheel -m 0644 \
      "$RIG_FIREWALL_RENDERED_DAEMON" "$RIG_FIREWALL_DAEMON" 1>&2; then
    rig_firewall_discard_files
    return 1
  fi
  rig_firewall_discard_files
  if [ "$RIG_FIREWALL_LOAD_STATE" != loaded ]; then
    rig_firewall_sudo "$launchctl" bootstrap system "$RIG_FIREWALL_DAEMON" 1>&2 || return
  fi
  rig_firewall_sudo "$pfctl" -E -a "com.apple/$locator" -f "$RIG_FIREWALL_ANCHOR" 1>&2 || return
  rig_firewall_loaded_rules_match "$locator" && return 0
  printf 'rig: %s: loaded rules do not match the rendered anchor.\n' "$section" >&2
  return 1
}

# Retirement removes only Rig's own anchor and daemon. pf stays enabled: other
# components hold their own references, and Apple's anchors alone filter nothing.
rig_firewall_retire() {
  local locator launchctl pfctl

  locator=$1
  [ "${RIG_SUDO_GRANTED:-0}" -eq 1 ] || {
    printf 'rig: firewall %s: administrator-grant-required\n' "$locator" >&2
    return 1
  }
  rig_firewall_paths "$locator" || return
  rig_firewall_launchctl; launchctl=$RIG_VALUE
  rig_firewall_pfctl; pfctl=$RIG_VALUE
  rig_firewall_load_state "$locator" || return
  if [ "$RIG_FIREWALL_LOAD_STATE" = loaded ]; then
    rig_firewall_sudo "$launchctl" bootout "system/$locator" 1>&2 || return
    rig_firewall_wait_unloaded "$locator" || return
  fi
  rig_firewall_sudo "$pfctl" -a "com.apple/$locator" -F all 1>&2 || return
  rig_firewall_sudo "$RIG_FIREWALL_RM" -f -- "$RIG_FIREWALL_DAEMON" "$RIG_FIREWALL_ANCHOR" 1>&2
}

rig_firewall_print_projection() {
  local section locator line

  section=$1
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_firewall_paths "$locator" || return
  printf '  anchor=%s\n' "$RIG_FIREWALL_ANCHOR"
  printf '  daemon=%s\n' "$RIG_FIREWALL_DAEMON"
  if ! rig_firewall_tailnet_addresses; then
    printf '  destinations=unknown (%s); apply installs nothing\n' "$RIG_VALUE"
    return 0
  fi
  printf '  destinations=%s %s\n' "$RIG_FIREWALL_SELF_IPV4" "$RIG_FIREWALL_SELF_IPV6"
  while IFS= read -r line; do
    case "$line" in '#'*) continue ;; esac
    printf '  rule=%s\n' "$line"
  done < <(rig_firewall_render_anchor "$section")
  printf '  command=sudo -n pfctl -n -f %s\n' "$RIG_FIREWALL_ANCHOR"
  printf '  command=sudo -n install -o root -g wheel -m 0644 %s\n' "$RIG_FIREWALL_ANCHOR"
  printf '  command=sudo -n install -o root -g wheel -m 0644 %s\n' "$RIG_FIREWALL_DAEMON"
  printf '  command=sudo -n launchctl bootstrap system %s\n' "$RIG_FIREWALL_DAEMON"
  printf '  command=sudo -n pfctl -E -a com.apple/%s -f %s\n' "$locator" "$RIG_FIREWALL_ANCHOR"
  printf '  command=sudo -n pfctl -a com.apple/%s -s rules\n' "$locator"
}

rig_explain_firewall() {
  local section locator state

  section=$1
  rig_get_value "$section" provider || return 2
  [ "$RIG_VALUE" != linux-nftables ] || { rig_nftables_explain "$section"; return; }
  rig_get_value "$section" locator || return 2
  locator=$RIG_VALUE
  rig_firewall_paths "$locator" || return
  printf 'Allowed sources: lo0, %s, %s\n' "$RIG_FIREWALL_TAILNET_IPV4" "$RIG_FIREWALL_TAILNET_IPV6"
  if rig_firewall_tailnet_addresses; then
    printf 'Allowed destinations: %s, %s\n' "$RIG_FIREWALL_SELF_IPV4" "$RIG_FIREWALL_SELF_IPV6"
  else
    printf 'Allowed destinations: unknown (%s)\n' "$RIG_VALUE"
  fi
  printf 'pf anchor: com.apple/%s\nAnchor file: %s\nDaemon file: %s\n' \
    "$locator" "$RIG_FIREWALL_ANCHOR" "$RIG_FIREWALL_DAEMON"
  rig_current_platform || return
  RIG_RESOLVED_PLATFORM=$RIG_VALUE
  rig_firewall_observe "$section" || return
  state=$RIG_OBSERVATION
  printf 'Observed state: %s (%s)\n' "$state" "$RIG_OBSERVATION_DETAIL"
  rig_firewall_explain_listeners
}

# The listener row is this run's netstat or ss snapshot, not the loaded rules.
rig_firewall_explain_listeners() {
  [ -n "$RIG_FIREWALL_EXPOSED" ] || return 0
  printf 'Listener evidence: %s seen listening on every address in this run; loaded rules unread (kernel-rules-unverified), so this is not proof of reachability.\n' \
    "$RIG_FIREWALL_EXPOSED"
}
