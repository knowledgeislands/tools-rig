#!/usr/bin/env bats

# Every native boundary is a stateful fixture in the test's own tree. sudo
# executes only the fixture pfctl and launchctl or emulates install and rm
# beneath RIG_SYSTEM_ROOT, so nothing reaches /etc, /Library or live pf.

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  export TMPDIR=$BATS_TEST_TMPDIR/tmp
  export FW_STATE=$BATS_TEST_TMPDIR/firewall-state
  export NATIVE_LOG=$BATS_TEST_TMPDIR/native-log
  export RIG_SUDO_REFRESH_SECONDS=60
  export RIG_LAUNCHD_UNLOAD_TIMEOUT=1
  export TERM=xterm-256color
  FW_BIN=$BATS_TEST_TMPDIR/firewall-bin
  ANCHOR=$RIG_SYSTEM_ROOT/etc/pf.anchors/org.rig.test.screen-sharing
  DAEMON=$RIG_SYSTEM_ROOT/Library/LaunchDaemons/org.rig.test.screen-sharing.plist
  RECEIPT=$HOME/.local/state/rig/resources/macos.tsv
  STDOUT=$BATS_TEST_TMPDIR/stdout
  STDERR=$BATS_TEST_TMPDIR/stderr
  mkdir -p "$RIG_CONFIG_HOME" "$TMPDIR" "$FW_STATE" "$FW_BIN"
  : >"$NATIVE_LOG"

  cat >"$FW_BIN/pfctl" <<'SH'
#!/usr/bin/env bash
printf 'pfctl %s\n' "$*" >>"$NATIVE_LOG"
case "$*" in
  '-n -f '*) [ "${FW_PARSE:-ok}" = ok ]; exit $? ;;
  '-E -a com.apple/'*' -f '*) /bin/cp "$5" "$FW_STATE/pf-loaded"; exit $? ;;
  '-a com.apple/'*' -s rules')
    [ -f "$FW_STATE/pf-loaded" ] || exit 0
    [ "${FW_RULES:-ok}" = ok ] || { printf 'pass in all\n'; exit 0; }
    # pfctl elides the default state on display; Rig compares without it.
    /usr/bin/grep -v '^#' "$FW_STATE/pf-loaded" | /usr/bin/sed 's/ keep state$//'
    exit 0 ;;
  '-a com.apple/'*' -F all')
    [ "${FW_FLUSH:-ok}" = ok ] || exit 1
    /bin/rm -f "$FW_STATE/pf-loaded"; exit 0 ;;
esac
exit 99
SH

  cat >"$FW_BIN/launchctl" <<'SH'
#!/usr/bin/env bash
printf 'launchctl %s\n' "$*" >>"$NATIVE_LOG"
case "$1" in
  print)
    [ "${FW_PRINT:-ok}" = ok ] || exit 5
    [ -f "$FW_STATE/loaded" ] || { printf 'Could not find service "%s"\n' "${2#system/}"; exit 113; }
    printf '%s = {\n\tlast exit code = %s\n}\n' "$2" "$(cat "$FW_STATE/last-exit" 2>/dev/null || printf '(never exited)')"
    exit 0 ;;
  bootstrap) [ "$2" = system ] && [ -f "$3" ] || exit 98; : >"$FW_STATE/loaded"; exit 0 ;;
  bootout) /bin/rm -f "$FW_STATE/loaded" "$FW_STATE/last-exit"; exit 0 ;;
esac
exit 99
SH

  cat >"$FW_BIN/netstat" <<'SH'
#!/usr/bin/env bash
printf 'netstat %s\n' "$*" >>"$NATIVE_LOG"
[ "${FW_NETSTAT:-ok}" = ok ] || exit 1
[ ! -f "$FW_STATE/netstat" ] || cat "$FW_STATE/netstat"
SH

  # en0 holds a carrier-grade NAT address, as some hotspots hand out; only the
  # interface that also carries Tailscale's ULA is the tailnet interface.
  cat >"$FW_BIN/ifconfig" <<'SH'
#!/usr/bin/env bash
printf 'ifconfig %s\n' "$*" >>"$NATIVE_LOG"
[ -f "$FW_STATE/ifconfig" ] || exit 1
cat "$FW_STATE/ifconfig"
SH
  write_interfaces "$(en0_interface)" "$(tailnet_interface utun3 100.101.1.2 fd7a:115c:a1e0::1:2)"

  cat >"$RIG_SUDO" <<'SH'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$NATIVE_LOG"
case "$*" in
  -v) [ "${FW_SUDO:-grant}" != refuse ]; exit $? ;;
  '-n -v') exit 0 ;;
esac
[ "$1" = -n ] && [ "$2" = -- ] || exit 99
shift 2
case "$1" in
  /usr/bin/install)
    [ "$2 $3 $4 $5 $6 $7" = '-o root -g wheel -m 0644' ] || exit 99
    case "$9" in "$RIG_SYSTEM_ROOT"/*) ;; *) exit 98 ;; esac
    /bin/mkdir -p "${9%/*}" && /bin/cp "$8" "$9" && /bin/chmod 0644 "$9"
    exit $? ;;
  /bin/rm)
    [ "$2 $3" = '-f --' ] || exit 99
    shift 3
    for path in "$@"; do case "$path" in "$RIG_SYSTEM_ROOT"/*) ;; *) exit 98 ;; esac; done
    /bin/rm -f -- "$@"
    exit $? ;;
  "$RIG_PFCTL"|"$RIG_LAUNCHCTL") exec "$@" ;;
esac
exit 97
SH
  chmod +x "$FW_BIN/pfctl" "$FW_BIN/launchctl" "$FW_BIN/netstat" "$FW_BIN/ifconfig" "$RIG_SUDO"
  export RIG_PFCTL=$FW_BIN/pfctl
  export RIG_LAUNCHCTL=$FW_BIN/launchctl
  export RIG_NETSTAT_COMMAND=$FW_BIN/netstat
  export RIG_IFCONFIG_COMMAND=$FW_BIN/ifconfig
  write_config
}

# Each argument is one interface block of the fixture ifconfig output.
write_interfaces() {
  printf 'lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384\n\tinet 127.0.0.1 netmask 0xff000000\n' \
    >"$FW_STATE/ifconfig"
  [ "$#" -eq 0 ] || printf '%s\n' "$@" >>"$FW_STATE/ifconfig"
}

en0_interface() {
  printf '%s\n' 'en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500' \
    $'\tinet6 fe80::1c%en0 prefixlen 64 secured scopeid 0xf' \
    $'\tinet 100.72.5.9 netmask 0xffc00000 broadcast 100.127.255.255' \
    $'\tstatus: active'
}

# NAME [IPV4] [IPV6] renders one utun interface; an empty address is omitted.
tailnet_interface() {
  printf '%s: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280\n' "$1"
  [ -z "${2:-}" ] || printf '\tinet %s --> %s netmask 0xffffffff\n' "$2" "$2"
  printf '\tinet6 fe80::9%%%s prefixlen 64 scopeid 0x17\n' "$1"
  [ -z "${3:-}" ] || printf '\tinet6 %s prefixlen 48\n' "$3"
}

# Optional overrides replace one field of the fixture declaration.
write_config() {
  local members ports allow platforms
  members='"screen-sharing"'; ports='"tcp:5900", "udp:5900"'; allow='"tailnet"'; platforms='"macos"'
  members=${FW_MEMBERS-$members}; ports=${FW_PORTS:-$ports}
  allow=${FW_ALLOW-$allow}; platforms=${FW_PLATFORMS:-$platforms}
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[profile.default]
name = "Default"
firewalls = [$members]
[tool.viewer]
name = "Viewer"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["macos"]
[category.core]
name = "Core"
purpose = "Fixture"
[firewall.screen-sharing]
name = "Screen Sharing"
purpose = "Keep Screen Sharing on the tailnet"
rationale = "Fixture"
provider = "${FW_PROVIDER:-macos-pf}"
locator = "${FW_LOCATOR:-org.rig.test.screen-sharing}"
ports = [$ports]
allow = [$allow]
platforms = [$platforms]
${FW_EXTRA:-}
TOML
}

native() {
  /usr/bin/sed -E 's#[^ ]*/rig-firewall-(anchor|daemon)\.[A-Za-z0-9]+#RENDERED-\1#g' "$NATIVE_LOG" |
    /usr/bin/sed -e "s#$RIG_SYSTEM_ROOT#ROOT#g" -e "s#$FW_BIN/##g"
}

terminal() {
  run /usr/bin/python3 "$BATS_TEST_DIRNAME/helpers/tty-progress.py" \
    --stdout "$STDOUT" --stderr "$STDERR" --reply unused -- "$RIG" "$@"
  [[ "$output" == *'"restored": true'* ]] || { printf '%s\n' "$output" >&3; false; }
}

# The golden fixtures are the exact files apply installs.
golden_anchor() {
  cat <<'PF'
# Managed by rig from firewall.screen-sharing. Generated file; rig apply replaces edits.
# Declared ports accept loopback, and tailnet sources addressing this Mac's own tailnet addresses.
pass in quick on lo0 proto tcp from any to any port = 5900 flags S/SA keep state
pass in quick inet proto tcp from 100.64.0.0/10 to 100.101.1.2 port = 5900 flags S/SA keep state
pass in quick inet6 proto tcp from fd7a:115c:a1e0::/48 to fd7a:115c:a1e0::1:2 port = 5900 flags S/SA keep state
block drop in quick proto tcp from any to any port = 5900
pass in quick on lo0 proto udp from any to any port = 5900 keep state
pass in quick inet proto udp from 100.64.0.0/10 to 100.101.1.2 port = 5900 keep state
pass in quick inet6 proto udp from fd7a:115c:a1e0::/48 to fd7a:115c:a1e0::1:2 port = 5900 keep state
block drop in quick proto udp from any to any port = 5900
PF
}

golden_daemon() {
  cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Managed by rig from firewall.screen-sharing. Generated file; rig apply replaces edits. -->
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>org.rig.test.screen-sharing</string>
  <key>ProgramArguments</key>
  <array>
    <string>/sbin/pfctl</string>
    <string>-E</string>
    <string>-a</string>
    <string>com.apple/org.rig.test.screen-sharing</string>
    <string>-f</string>
    <string>/etc/pf.anchors/org.rig.test.screen-sharing</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>WatchPaths</key>
  <array>
    <string>/etc/pf.conf</string>
  </array>
</dict>
</plist>
PLIST
}

install_present() {
  mkdir -p "${ANCHOR%/*}" "${DAEMON%/*}"
  golden_anchor >"$ANCHOR"
  golden_daemon >"$DAEMON"
  : >"$FW_STATE/loaded"
  printf '0\n' >"$FW_STATE/last-exit"
}

status_row() {
  run "$RIG" status
  printf '%s\n' "$output" | /usr/bin/grep '^screen-sharing ' | /usr/bin/awk '{ print $4, $5 }'
}

assert_no_global_firewall() {
  ! /usr/bin/grep -E 'pf\.conf|socketfilterfw|pfctl( [^ ]+)* -[dX]( |$)' "$NATIVE_LOG" || false
}

@test "validation rejects unsafe declarations before any native invocation" {
  local case_name
  for case_name in provider locator apple platform zero high padded protocol duplicate ssh-tcp ssh-udp \
    allow-any allow-none missing-ports requires; do
    unset FW_PROVIDER FW_LOCATOR FW_PLATFORMS FW_PORTS FW_ALLOW FW_EXTRA
    case "$case_name" in
      provider) FW_PROVIDER=launchd ;;
      locator) FW_LOCATOR=screen-sharing ;;
      apple) FW_LOCATOR=com.apple.screensharing ;;
      platform) FW_PLATFORMS='"linux"' ;;
      zero) FW_PORTS='"tcp:0"' ;;
      high) FW_PORTS='"tcp:65536"' ;;
      padded) FW_PORTS='"tcp:05900"' ;;
      protocol) FW_PORTS='"sctp:5900"' ;;
      duplicate) FW_PORTS='"tcp:5900", "tcp:5900"' ;;
      ssh-tcp) FW_PORTS='"tcp:5900", "tcp:22"' ;;
      ssh-udp) FW_PORTS='"udp:22"' ;;
      allow-any) FW_ALLOW='"any"' ;;
      allow-none) FW_ALLOW= ;;
      missing-ports) FW_PORTS=' ' ;;
      requires) FW_EXTRA='requires = ["missing"]' ;;
    esac
    write_config
    run "$RIG" show
    [ "$status" -eq 2 ] || { printf '%s: %s\n' "$case_name" "$output" >&3; false; }
    [[ "$output" == *'firewall.screen-sharing'* ]] || { printf '%s: %s\n' "$case_name" "$output" >&3; false; }
  done
  unset FW_PROVIDER FW_LOCATOR FW_PLATFORMS FW_PORTS FW_ALLOW FW_EXTRA
  write_config
  printf '%s\n' '[firewall.other]' 'name = "Other"' 'purpose = "Fixture"' 'rationale = "Fixture"' \
    'provider = "macos-pf"' 'locator = "org.rig.test.screen-sharing"' 'ports = ["tcp:5901"]' \
    'allow = ["tailnet"]' 'platforms = ["macos"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *'duplicates firewall locator'* ]] || false
  [ ! -s "$NATIVE_LOG" ]
}

@test "two profiles may restrict one port but one composed profile may not" {
  printf '%s\n' \
    '[rig]' 'default-profile = "alpha"' \
    '[firewall.alpha]' 'name = "Alpha"' 'purpose = "Fixture"' 'rationale = "Fixture"' \
    'provider = "macos-pf"' 'locator = "org.rig.test.alpha"' 'ports = ["tcp:5900"]' \
    'allow = ["tailnet"]' 'platforms = ["macos"]' 'profiles = ["alpha"]' \
    '[firewall.beta]' 'name = "Beta"' 'purpose = "Fixture"' 'rationale = "Fixture"' \
    'provider = "macos-pf"' 'locator = "org.rig.test.beta"' 'ports = ["udp:5900", "tcp:5900"]' \
    'allow = ["tailnet"]' 'platforms = ["macos"]' 'profiles = ["beta"]' \
    '[profile.alpha]' 'kind = "complete"' \
    '[profile.beta]' 'kind = "complete"' \
    '[profile.combined]' 'kind = "complete"' 'inherits = ["alpha", "beta"]' \
    >"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show --profile alpha
  [ "$status" -eq 0 ]
  run "$RIG" show --profile beta
  [ "$status" -eq 0 ]
  run "$RIG" show --profile combined
  [ "$status" -eq 2 ]
  [[ "$output" == *"conflicts with"*"native target 'macos-pf:port:tcp:5900'"* ]] || false
  [ ! -s "$NATIVE_LOG" ]
}

@test "dry run projects only declared ports to the Mac's own tailnet addresses" {
  local rules
  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  rules=$(printf '%s\n' "$output" | /usr/bin/sed -n 's/^  rule=//p')
  [ "$rules" = "$(golden_anchor | /usr/bin/grep -v '^#')" ]
  ! printf '%s\n' "$rules" | /usr/bin/grep -v 'port = 5900' || false
  ! printf '%s\n' "$rules" | /usr/bin/grep -w 22 || false
  [ "$(printf '%s\n' "$rules" | /usr/bin/grep -c 'from 100.64.0.0/10 to 100.101.1.2 ')" -eq 2 ]
  [ "$(printf '%s\n' "$rules" | /usr/bin/grep -c 'from fd7a:115c:a1e0::/48 to fd7a:115c:a1e0::1:2 ')" -eq 2 ]
  ! printf '%s\n' "$rules" | /usr/bin/grep -E 'to (100\.64\.0\.0/10|fd7a:115c:a1e0::/48) ' || false
  ! printf '%s\n' "$output" | /usr/bin/grep -F 100.72.5.9 || false
  [[ "$output" == *'  destinations=100.101.1.2 fd7a:115c:a1e0::1:2'* ]] || false
  [[ "$output" == *"command=sudo -n pfctl -E -a com.apple/org.rig.test.screen-sharing -f $ANCHOR"* ]] || false
}

@test "read-only commands never escalate write or load with or without a grant" {
  local command
  for state in fresh present; do
    [ "$state" = fresh ] || install_present
    for command in status doctor show 'show firewall:screen-sharing' 'show --format json' 'apply --dry-run' \
      'apply --dry-run --sudo'; do
      # shellcheck disable=SC2086
      run "$RIG" $command
      [ "$status" -le 1 ] || { printf '%s: %s\n' "$command" "$output" >&3; false; }
    done
    ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
  done
  [ "$(cat "$ANCHOR")" = "$(golden_anchor)" ]
  [ "$(cat "$DAEMON")" = "$(golden_daemon)" ]
  local listing
  listing=$(cd "$RIG_SYSTEM_ROOT" && /usr/bin/find . -type f | LC_ALL=C /usr/bin/sort)
  [ "$listing" = $'./Library/LaunchDaemons/org.rig.test.screen-sharing.plist\n./etc/pf.anchors/org.rig.test.screen-sharing' ] ||
    { printf 'system root files:\n%s\n' "$listing" >&3; false; }
  run "$RIG" show firewall:screen-sharing
  [[ "$output" == *'Allowed sources: lo0, 100.64.0.0/10, fd7a:115c:a1e0::/48'* ]] || false
  [[ "$output" == *'Allowed destinations: 100.101.1.2, fd7a:115c:a1e0::1:2'* ]] || false
  [[ "$output" == *'pf anchor: com.apple/org.rig.test.screen-sharing'* ]] || false
  [[ "$output" == *'Observed state: present (kernel-rules-unverified)'* ]] || false
  run "$RIG" show --format json
  [[ "$output" == *'"locator":"org.rig.test.screen-sharing"'* ]] || false
  [[ "$output" == *'"allow":["tailnet"]'* ]] || false
}

@test "observation distinguishes present missing drifted exposed and unavailable" {
  [ "$(status_row)" = 'missing -' ]
  printf '%s\n' 'tcp46      0      0  *.5900                 *.*                    LISTEN' >"$FW_STATE/netstat"
  [ "$(status_row)" = 'missing exposed-beyond-tailnet' ]
  printf '%s\n' 'tcp4       0      0  100.101.1.2.5900       *.*                    LISTEN' >"$FW_STATE/netstat"
  [ "$(status_row)" = 'missing -' ]
  printf '%s\n' 'udp4       0      0  *.5900                 *.*' >"$FW_STATE/netstat"
  [ "$(status_row)" = 'missing exposed-beyond-tailnet' ]

  install_present
  # A restricted listener still binds every address; pf, not netstat, filters it.
  [ "$(status_row)" = 'present kernel-rules-unverified' ]
  rm "$FW_STATE/netstat"
  [ "$(status_row)" = 'present kernel-rules-unverified' ]
  printf '(never exited)\n' >"$FW_STATE/last-exit"
  [ "$(status_row)" = 'present kernel-rules-unverified' ]

  printf '# edited\n' >>"$ANCHOR"
  [ "$(status_row)" = 'drifted anchor-changed' ]
  install_present
  printf '<!-- edited -->\n' >>"$DAEMON"
  [ "$(status_row)" = 'drifted daemon-changed' ]
  install_present
  rm "$FW_STATE/loaded"
  [ "$(status_row)" = 'drifted daemon-not-loaded' ]
  install_present
  printf '1\n' >"$FW_STATE/last-exit"
  [ "$(status_row)" = 'drifted daemon-last-exit:1' ]
  printf '%s\n' 'tcp6       0      0  *.5900                 *.*                    LISTEN' >"$FW_STATE/netstat"
  [ "$(status_row)" = 'drifted daemon-last-exit:1,exposed-beyond-tailnet' ]

  install_present
  FW_PRINT=fail
  export FW_PRINT
  [ "$(status_row)" = 'unknown launchctl-exit:5' ]
  unset FW_PRINT
  FW_NETSTAT=fail
  export FW_NETSTAT
  [ "$(status_row)" = 'unavailable netstat-failed' ]
  unset FW_NETSTAT
  rm "$ANCHOR"
  ln -s "$DAEMON" "$ANCHOR"
  [ "$(status_row)" = 'unavailable unsafe-anchor' ]

  run env RIG_PLATFORM=linux "$RIG" status
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not support platform 'linux'"* ]] || false
  ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
}

@test "granted apply runs the exact ordered native argv once and then converges" {
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- pfctl -n -f RENDERED-anchor
sudo -n -- /usr/bin/install -o root -g wheel -m 0644 RENDERED-anchor ROOT/etc/pf.anchors/org.rig.test.screen-sharing
sudo -n -- /usr/bin/install -o root -g wheel -m 0644 RENDERED-daemon ROOT/Library/LaunchDaemons/org.rig.test.screen-sharing.plist
sudo -n -- launchctl bootstrap system ROOT/Library/LaunchDaemons/org.rig.test.screen-sharing.plist
sudo -n -- pfctl -E -a com.apple/org.rig.test.screen-sharing -f ROOT/etc/pf.anchors/org.rig.test.screen-sharing
sudo -n -- pfctl -a com.apple/org.rig.test.screen-sharing -s rules
LOG
)" ]
  [ "$(cat "$ANCHOR")" = "$(golden_anchor)" ]
  [ "$(cat "$DAEMON")" = "$(golden_daemon)" ]
  [ "$(/usr/bin/stat -c %a "$ANCHOR" 2>/dev/null || /usr/bin/stat -f %Lp "$ANCHOR")" = 644 ]
  /usr/bin/grep -F $'macos-pf\tfirewall\tscreen-sharing\torg.rig.test.screen-sharing' "$RECEIPT"
  /usr/bin/grep -qE '^firewall:screen-sharing'$'\t''macos-pf'$'\t''.*'$'\t''0$' "$HOME/.local/state/rig/apply-history/macos.tsv"
  [ -z "$(/bin/ls -A "$TMPDIR")" ]
  assert_no_global_firewall

  : >"$NATIVE_LOG"
  printf '0\n' >"$FW_STATE/last-exit"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || false
  [[ "$(cat "$STDOUT")" == *'no prompt needed'* ]] || false
  ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
  run "$RIG" apply
  [ "$status" -eq 0 ]
  ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
}

@test "granted apply repairs a changed daemon by unloading it first" {
  install_present
  printf '<!-- edited -->\n' >>"$DAEMON"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- pfctl -n -f RENDERED-anchor
sudo -n -- launchctl bootout system/org.rig.test.screen-sharing
sudo -n -- /usr/bin/install -o root -g wheel -m 0644 RENDERED-daemon ROOT/Library/LaunchDaemons/org.rig.test.screen-sharing.plist
sudo -n -- launchctl bootstrap system ROOT/Library/LaunchDaemons/org.rig.test.screen-sharing.plist
sudo -n -- pfctl -E -a com.apple/org.rig.test.screen-sharing -f ROOT/etc/pf.anchors/org.rig.test.screen-sharing
sudo -n -- pfctl -a com.apple/org.rig.test.screen-sharing -s rules
LOG
)" ]
  [ "$(cat "$DAEMON")" = "$(golden_daemon)" ]
}

@test "a rejected anchor installs nothing and a reread mismatch fails" {
  FW_PARSE=fail
  export FW_PARSE
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [[ "$(cat "$STDERR")" == *'pfctl rejected the rendered anchor; nothing installed'* ]] || false
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = 'sudo -n -- pfctl -n -f RENDERED-anchor' ]
  [ -z "$(/usr/bin/find "$RIG_SYSTEM_ROOT" -type f)" ]
  [ -z "$(/bin/ls -A "$TMPDIR")" ]
  ! /usr/bin/grep -F $'macos-pf\tfirewall' "$RECEIPT" 2>/dev/null || false

  unset FW_PARSE
  FW_RULES=mismatch
  export FW_RULES
  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [[ "$(cat "$STDERR")" == *'loaded rules do not match the rendered anchor'* ]] || false
  [ "$(native | /usr/bin/grep -c '^sudo -n -- pfctl -a com.apple/org.rig.test.screen-sharing -s rules')" -eq 1 ]
  assert_no_global_firewall
}

@test "apply without a grant or with a refused grant dispatches no native mutation" {
  run env RIG_OUTCOME=always "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'skipped'*'administrator-grant-required'* ]] || false
  [[ "$output" == *'incomplete'* ]] || false
  ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false

  FW_SUDO=refuse
  export FW_SUDO
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [ "$(native | /usr/bin/grep '^sudo')" = 'sudo -v' ]
  ! /usr/bin/grep -E '^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
  [ -z "$(/usr/bin/find "$RIG_SYSTEM_ROOT" -type f)" ]
}

@test "deleting the declaration retires only the receipted locator and leaves pf enabled" {
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || false
  printf '0\n' >"$FW_STATE/last-exit"

  # Deselection keeps the declaration, so nothing is retired.
  FW_MEMBERS=
  write_config
  : >"$NATIVE_LOG"
  run "$RIG" apply
  [ "$status" -eq 0 ]
  ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
  /usr/bin/grep -F $'macos-pf\tfirewall\tscreen-sharing' "$RECEIPT"
  [ -f "$ANCHOR" ]

  printf '%s\n' '[rig]' 'default-profile = "default"' '[profile.default]' 'name = "Default"' \
    >"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'skipped'*'administrator-grant-required'* ]] || false
  /usr/bin/grep -F $'macos-pf\tfirewall\tscreen-sharing' "$RECEIPT"

  FW_FLUSH=fail
  export FW_FLUSH
  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  /usr/bin/grep -F $'macos-pf\tfirewall\tscreen-sharing' "$RECEIPT"
  [ -f "$ANCHOR" ]

  # The failed attempt unloaded the daemon; reload it to prove the full order.
  unset FW_FLUSH
  : >"$FW_STATE/loaded"
  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- launchctl bootout system/org.rig.test.screen-sharing
sudo -n -- pfctl -a com.apple/org.rig.test.screen-sharing -F all
sudo -n -- /bin/rm -f -- ROOT/Library/LaunchDaemons/org.rig.test.screen-sharing.plist ROOT/etc/pf.anchors/org.rig.test.screen-sharing
LOG
)" ]
  [ ! -e "$ANCHOR" ]
  [ ! -e "$DAEMON" ]
  ! /usr/bin/grep -F $'macos-pf\tfirewall' "$RECEIPT" || false
  assert_no_global_firewall
}

@test "discovery takes only the interface carrying Tailscale's ULA and refuses anything else" {
  local case_name
  # Two addresses of one family on the tailnet interface, a second tailnet
  # interface, a missing family and no tailnet at all are each undiscoverable.
  for case_name in none second-interface no-ipv4 no-ipv6 two-ipv4 unreadable; do
    case "$case_name" in
      none) write_interfaces "$(en0_interface)" ;;
      second-interface) write_interfaces "$(en0_interface)" \
        "$(tailnet_interface utun3 100.101.1.2 fd7a:115c:a1e0::1:2)" \
        "$(tailnet_interface utun7 100.101.1.3 fd7a:115c:a1e0::1:3)" ;;
      no-ipv4) write_interfaces "$(en0_interface)" "$(tailnet_interface utun3 '' fd7a:115c:a1e0::1:2)" ;;
      no-ipv6) write_interfaces "$(en0_interface)" "$(tailnet_interface utun3 100.101.1.2 '')" ;;
      two-ipv4) write_interfaces "$(tailnet_interface utun3 100.101.1.2 fd7a:115c:a1e0::1:2)" \
        $'\tinet 100.101.1.4 --> 100.101.1.4 netmask 0xffffffff' ;;
      unreadable) rm "$FW_STATE/ifconfig" ;;
    esac
    [ "$(status_row)" = 'unknown tailnet-address-undiscoverable' ] ||
      { printf '%s: %s\n' "$case_name" "$(status_row)" >&3; false; }
    run "$RIG" apply --dry-run
    [[ "$output" == *'destinations=unknown (tailnet-address-undiscoverable); apply installs nothing'* ]] ||
      { printf '%s: %s\n' "$case_name" "$output" >&3; false; }
    ! printf '%s\n' "$output" | /usr/bin/grep -E '^  (rule|command)=' || false
    run "$RIG" show firewall:screen-sharing
    [[ "$output" == *'Allowed destinations: unknown (tailnet-address-undiscoverable)'* ]] || false
  done

  # A CGNAT address outside the tailnet interface is never chosen, whichever
  # order the interfaces appear in.
  write_interfaces "$(tailnet_interface utun3 100.101.1.2 fd7a:115c:a1e0::1:2)" "$(en0_interface)"
  run "$RIG" apply --dry-run
  [[ "$output" == *'  destinations=100.101.1.2 fd7a:115c:a1e0::1:2'* ]] || false
  ! printf '%s\n' "$output" | /usr/bin/grep -F 100.72.5.9 || false
  ! /usr/bin/grep -E '^sudo|^pfctl|^launchctl (bootstrap|bootout)' "$NATIVE_LOG" || false
}

@test "an undiscoverable tailnet address installs and rewrites nothing" {
  write_interfaces "$(en0_interface)"
  run env RIG_OUTCOME=always "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'skipped'*'tailnet-address-undiscoverable'* ]] || false
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [[ "$(cat "$STDOUT" "$STDERR")" == *'tailnet-address-undiscoverable'* ]] || false
  ! native | /usr/bin/grep -E '^sudo -n -- |^pfctl|^launchctl (bootstrap|bootout)' || false
  [ -z "$(/usr/bin/find "$RIG_SYSTEM_ROOT" -type f)" ]

  # An installed anchor stays as it is while Tailscale is down.
  install_present
  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$(cat "$STDOUT" "$STDERR")" == *'tailnet-address-undiscoverable'* ]] || false
  ! native | /usr/bin/grep -E '^sudo -n -- |^pfctl|^launchctl (bootstrap|bootout)' || false
  [ "$(cat "$ANCHOR")" = "$(golden_anchor)" ]
  [ "$(cat "$DAEMON")" = "$(golden_daemon)" ]
}

@test "a changed tailnet address reports stale and apply rewrites the destinations" {
  install_present
  [ "$(status_row)" = 'present kernel-rules-unverified' ]
  write_interfaces "$(en0_interface)" "$(tailnet_interface utun5 100.101.9.8 fd7a:115c:a1e0::9:8)"
  [ "$(status_row)" = 'drifted tailnet-address-stale' ]
  # Any other edit is still an ordinary change.
  printf '# edited\n' >>"$ANCHOR"
  [ "$(status_row)" = 'drifted anchor-changed' ]
  install_present

  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- pfctl -n -f RENDERED-anchor
sudo -n -- /usr/bin/install -o root -g wheel -m 0644 RENDERED-anchor ROOT/etc/pf.anchors/org.rig.test.screen-sharing
sudo -n -- pfctl -E -a com.apple/org.rig.test.screen-sharing -f ROOT/etc/pf.anchors/org.rig.test.screen-sharing
sudo -n -- pfctl -a com.apple/org.rig.test.screen-sharing -s rules
LOG
)" ]
  [ "$(cat "$ANCHOR")" = "$(golden_anchor | /usr/bin/sed -e 's/100\.101\.1\.2 /100.101.9.8 /' -e 's/fd7a:115c:a1e0::1:2 /fd7a:115c:a1e0::9:8 /')" ]
  [ "$(/usr/bin/grep -c ' to 100.101.9.8 port' "$ANCHOR")" -eq 2 ]
  [ "$(cat "$DAEMON")" = "$(golden_daemon)" ]
  [ "$(status_row)" = 'present kernel-rules-unverified' ]
  assert_no_global_firewall
}
