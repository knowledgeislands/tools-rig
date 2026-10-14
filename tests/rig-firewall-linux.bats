#!/usr/bin/env bats

# Every native boundary is a stateful fixture in the test's own tree. sudo
# executes only the fixture nft and systemctl or emulates install and rm
# beneath RIG_SYSTEM_ROOT, so nothing reaches /etc, systemd or live nftables.

setup() {
  source "$BATS_TEST_DIRNAME/helpers/isolate.bash"
  rig_test_isolate
  RIG=$BATS_TEST_DIRNAME/../bin/rig
  export RIG_PLATFORM=linux
  export RIG_CONFIG_HOME=$BATS_TEST_TMPDIR/config
  export TMPDIR=$BATS_TEST_TMPDIR/tmp
  export FW_STATE=$BATS_TEST_TMPDIR/firewall-state
  export NATIVE_LOG=$BATS_TEST_TMPDIR/native-log
  export RIG_SUDO_REFRESH_SECONDS=60
  export TERM=xterm-256color
  FW_BIN=$BATS_TEST_TMPDIR/firewall-bin
  RULES=$RIG_SYSTEM_ROOT/etc/rig/firewall/org.rig.test.dev-server.nft
  UNIT=$RIG_SYSTEM_ROOT/etc/systemd/system/org.rig.test.dev-server.service
  export RULES UNIT
  RECEIPT=$HOME/.local/state/rig/resources/linux.tsv
  STDOUT=$BATS_TEST_TMPDIR/stdout
  STDERR=$BATS_TEST_TMPDIR/stderr
  mkdir -p "$RIG_CONFIG_HOME" "$TMPDIR" "$FW_STATE" "$FW_BIN"
  : >"$NATIVE_LOG"

  # nft lists a table without comments or the replace preamble.
  cat >"$FW_BIN/nft" <<'SH'
#!/usr/bin/env bash
printf 'nft %s\n' "$*" >>"$NATIVE_LOG"
case "$*" in
  '-c -f '*) [ "${FW_PARSE:-ok}" = ok ]; exit $? ;;
  '-f '*) /bin/cp "$2" "$FW_STATE/nft-loaded"; exit $? ;;
  'list table inet rig_org_rig_test_dev_server')
    [ -f "$FW_STATE/nft-loaded" ] || exit 1
    [ "${FW_RULES:-ok}" = ok ] || { printf 'table inet rig_org_rig_test_dev_server {\n}\n'; exit 0; }
    /usr/bin/grep -v -e '^#' -e '^table inet [a-z_]*$' -e '^delete table' "$FW_STATE/nft-loaded"
    exit 0 ;;
  'delete table inet rig_org_rig_test_dev_server') /bin/rm -f "$FW_STATE/nft-loaded"; exit $? ;;
esac
exit 99
SH

  # systemctl emulates the unit's ExecStart and ExecStop through the fixture nft.
  cat >"$FW_BIN/systemctl" <<'SH'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$NATIVE_LOG"
case "$*" in
  'show org.rig.test.dev-server.service --property=LoadState,ActiveState,UnitFileState,Result')
    [ "${FW_SHOW:-ok}" = ok ] || exit 4
    if [ -f "$UNIT" ]; then printf 'LoadState=loaded\n'; else printf 'LoadState=not-found\n'; fi
    if [ -f "$FW_STATE/active" ]; then printf 'ActiveState=active\n'
    elif [ -f "$FW_STATE/result" ]; then printf 'ActiveState=failed\n'
    else printf 'ActiveState=inactive\n'; fi
    if [ -f "$FW_STATE/enabled" ]; then printf 'UnitFileState=enabled\n'
    elif [ -f "$UNIT" ]; then printf 'UnitFileState=disabled\n'
    else printf 'UnitFileState=\n'; fi
    printf 'Result=%s\n' "$(cat "$FW_STATE/result" 2>/dev/null || printf success)"
    exit 0 ;;
  daemon-reload) exit 0 ;;
  'enable org.rig.test.dev-server.service') : >"$FW_STATE/enabled"; exit 0 ;;
  'restart org.rig.test.dev-server.service')
    "$RIG_NFT" -f "$RULES" || exit 1
    : >"$FW_STATE/active"; exit 0 ;;
  'disable --now org.rig.test.dev-server.service')
    [ "${FW_DISABLE:-ok}" = ok ] || exit 1
    [ "${FW_STOP:-ok}" = keep ] || /bin/rm -f "$FW_STATE/nft-loaded"
    /bin/rm -f "$FW_STATE/active" "$FW_STATE/enabled"; exit 0 ;;
esac
exit 99
SH

  cat >"$FW_BIN/ss" <<'SH'
#!/usr/bin/env bash
printf 'ss %s\n' "$*" >>"$NATIVE_LOG"
[ "${FW_SS:-ok}" = ok ] || exit 1
[ ! -f "$FW_STATE/ss" ] || cat "$FW_STATE/ss"
SH

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
    [ "$2 $3 $4 $5 $6 $7 $8" = '-D -o root -g root -m 0644' ] || exit 99
    case "${10}" in "$RIG_SYSTEM_ROOT"/*) ;; *) exit 98 ;; esac
    /bin/mkdir -p "${10%/*}" && /bin/cp "$9" "${10}" && /bin/chmod 0644 "${10}"
    exit $? ;;
  /bin/rm)
    [ "$2 $3" = '-f --' ] || exit 99
    shift 3
    for path in "$@"; do case "$path" in "$RIG_SYSTEM_ROOT"/*) ;; *) exit 98 ;; esac; done
    /bin/rm -f -- "$@"
    exit $? ;;
  "$RIG_NFT"|"$RIG_SYSTEMCTL") exec "$@" ;;
esac
exit 97
SH
  chmod +x "$FW_BIN/nft" "$FW_BIN/systemctl" "$FW_BIN/ss" "$RIG_SUDO"
  export RIG_NFT=$FW_BIN/nft
  export RIG_SYSTEMCTL=$FW_BIN/systemctl
  export RIG_SS_COMMAND=$FW_BIN/ss
  write_config
}

# Optional overrides replace one field of the fixture declaration.
write_config() {
  local members ports allow platforms
  members='"dev-server"'; ports='"tcp:3000", "udp:3000"'; allow='"tailnet"'; platforms='"linux"'
  members=${FW_MEMBERS-$members}; ports=${FW_PORTS:-$ports}
  allow=${FW_ALLOW-$allow}; platforms=${FW_PLATFORMS:-$platforms}
  cat >"$RIG_CONFIG_HOME/rig.toml" <<TOML
[rig]
default-profile = "default"
[profile.default]
name = "Default"
firewalls = [$members]
[tool.server]
name = "Server"
category = "core"
purpose = "Fixture"
rationale = "Fixture"
platforms = ["linux"]
[category.core]
name = "Core"
purpose = "Fixture"
[firewall.dev-server]
name = "Development server"
purpose = "Keep the development server on the tailnet"
rationale = "Fixture"
provider = "${FW_PROVIDER:-linux-nftables}"
locator = "${FW_LOCATOR:-org.rig.test.dev-server}"
ports = [$ports]
allow = [$allow]
platforms = [$platforms]
${FW_EXTRA:-}
TOML
}

native() {
  /usr/bin/sed -E 's#[^ ]*/rig-firewall-(rules|unit)\.[A-Za-z0-9]+#RENDERED-\1#g' "$NATIVE_LOG" |
    /usr/bin/sed -e "s#$RIG_SYSTEM_ROOT#ROOT#g" -e "s#$FW_BIN/##g"
}

terminal() {
  run /usr/bin/python3 "$BATS_TEST_DIRNAME/helpers/tty-progress.py" \
    --stdout "$STDOUT" --stderr "$STDERR" --reply unused -- "$RIG" "$@"
  [[ "$output" == *'"restored": true'* ]] || { printf '%s\n' "$output" >&3; false; }
}

# The golden fixtures are the exact files apply installs.
golden_rules() {
  cat <<'NFT'
# Managed by rig from firewall.dev-server. Generated file; rig apply replaces edits.
# Declared ports accept loopback and tailnet-to-tailnet traffic only.
table inet rig_org_rig_test_dev_server
delete table inet rig_org_rig_test_dev_server
table inet rig_org_rig_test_dev_server {
	chain input {
		type filter hook input priority filter; policy accept;
		iif "lo" tcp dport 3000 accept
		ip saddr 100.64.0.0/10 ip daddr 100.64.0.0/10 tcp dport 3000 accept
		ip6 saddr fd7a:115c:a1e0::/48 ip6 daddr fd7a:115c:a1e0::/48 tcp dport 3000 accept
		tcp dport 3000 drop
		iif "lo" udp dport 3000 accept
		ip saddr 100.64.0.0/10 ip daddr 100.64.0.0/10 udp dport 3000 accept
		ip6 saddr fd7a:115c:a1e0::/48 ip6 daddr fd7a:115c:a1e0::/48 udp dport 3000 accept
		udp dport 3000 drop
	}
}
NFT
}

golden_unit() {
  cat <<'UNIT'
# Managed by rig from firewall.dev-server. Generated file; rig apply replaces edits.
[Unit]
Description=Rig tailnet-only firewall org.rig.test.dev-server
DefaultDependencies=no
Wants=network-pre.target
After=nftables.service ufw.service
Before=network-pre.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/rig/firewall/org.rig.test.dev-server.nft
ExecStop=-/usr/sbin/nft delete table inet rig_org_rig_test_dev_server

[Install]
WantedBy=multi-user.target
UNIT
}

install_present() {
  mkdir -p "${RULES%/*}" "${UNIT%/*}"
  golden_rules >"$RULES"
  golden_unit >"$UNIT"
  /bin/cp "$RULES" "$FW_STATE/nft-loaded"
  : >"$FW_STATE/active"
  : >"$FW_STATE/enabled"
  /bin/rm -f "$FW_STATE/result"
}

status_row() {
  run "$RIG" status
  printf '%s\n' "$output" | /usr/bin/grep '^dev-server ' | /usr/bin/awk '{ print $4, $5 }'
}

# Rig never touches another firewall or the distribution's ruleset.
assert_no_global_firewall() {
  ! /usr/bin/grep -E 'ufw|iptables|nftables\.conf|flush|nft (-f|list|delete) .*(ruleset|table inet [^r])' \
    "$NATIVE_LOG" || false
}

@test "validation rejects unsafe linux declarations before any native invocation" {
  local case_name
  for case_name in provider locator platform both-platforms ssh-tcp ssh-udp allow-any duplicate; do
    unset FW_PROVIDER FW_LOCATOR FW_PLATFORMS FW_PORTS FW_ALLOW FW_EXTRA
    case "$case_name" in
      provider) FW_PROVIDER=ufw ;;
      locator) FW_LOCATOR=dev-server ;;
      platform) FW_PLATFORMS='"macos"' ;;
      both-platforms) FW_PLATFORMS='"linux", "macos"' ;;
      ssh-tcp) FW_PORTS='"tcp:3000", "tcp:22"' ;;
      ssh-udp) FW_PORTS='"udp:22"' ;;
      allow-any) FW_ALLOW='"any"' ;;
      duplicate) FW_PORTS='"tcp:3000", "tcp:3000"' ;;
    esac
    write_config
    run "$RIG" show
    [ "$status" -eq 2 ] || { printf '%s: %s\n' "$case_name" "$output" >&3; false; }
    [[ "$output" == *'firewall.dev-server'* ]] || { printf '%s: %s\n' "$case_name" "$output" >&3; false; }
  done
  unset FW_PROVIDER FW_LOCATOR FW_PLATFORMS FW_PORTS FW_ALLOW FW_EXTRA
  write_config
  # Locators differing only in '.' and '-' would share one nftables table.
  printf '%s\n' '[firewall.other]' 'name = "Other"' 'purpose = "Fixture"' 'rationale = "Fixture"' \
    'provider = "linux-nftables"' 'locator = "org.rig.test-dev.server"' 'ports = ["tcp:3001"]' \
    'allow = ["tailnet"]' 'platforms = ["linux"]' >>"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *"shares nftables table 'rig_org_rig_test_dev_server' with [firewall.dev-server]"* ]] || false
  [ ! -s "$NATIVE_LOG" ]
}

@test "one composed profile may not restrict a port twice on linux" {
  FW_EXTRA='[firewall.again]
name = "Again"
purpose = "Fixture"
rationale = "Fixture"
provider = "linux-nftables"
locator = "org.rig.test.again"
ports = ["tcp:3000"]
allow = ["tailnet"]
platforms = ["linux"]'
  FW_MEMBERS='"dev-server", "again"'
  write_config
  run "$RIG" show
  [ "$status" -eq 2 ]
  [[ "$output" == *"conflicts with"*"native target 'linux-nftables:port:tcp:3000'"* ]] || false
  [ ! -s "$NATIVE_LOG" ]
}

@test "dry run projects only declared ports from the tailnet ranges" {
  local rules
  run "$RIG" apply --dry-run
  [ "$status" -eq 0 ]
  rules=$(printf '%s\n' "$output" | /usr/bin/sed -n 's/^  rule=//p')
  [ "$rules" = "$(golden_rules | /usr/bin/grep -v '^#' | /usr/bin/sed -E 's/^[[:space:]]+//')" ]
  ! printf '%s\n' "$rules" | /usr/bin/grep -w 22 || false
  [ "$(printf '%s\n' "$rules" | /usr/bin/grep -c 'ip saddr 100.64.0.0/10 ip daddr 100.64.0.0/10')" -eq 2 ]
  [ "$(printf '%s\n' "$rules" | /usr/bin/grep -c 'ip6 saddr fd7a:115c:a1e0::/48 ip6 daddr fd7a:115c:a1e0::/48')" -eq 2 ]
  [[ "$output" == *'policy accept'* ]] || false
  [[ "$output" == *"command=sudo -n systemctl restart org.rig.test.dev-server.service"* ]] || false
  [[ "$output" == *"command=sudo -n nft list table inet rig_org_rig_test_dev_server"* ]] || false
}

@test "read-only commands never escalate write or load with or without a grant" {
  local command
  for state in fresh present; do
    [ "$state" = fresh ] || install_present
    for command in status doctor show 'show firewall:dev-server' 'show --format json' 'apply --dry-run' \
      'apply --dry-run --sudo'; do
      # shellcheck disable=SC2086
      run "$RIG" $command
      [ "$status" -le 1 ] || { printf '%s: %s\n' "$command" "$output" >&3; false; }
    done
    ! /usr/bin/grep -E '^sudo|^nft|^systemctl (daemon-reload|enable|restart|disable)' "$NATIVE_LOG" || false
  done
  [ "$(cat "$RULES")" = "$(golden_rules)" ]
  [ "$(cat "$UNIT")" = "$(golden_unit)" ]
  run "$RIG" show firewall:dev-server
  [[ "$output" == *'Allowed sources: lo, 100.64.0.0/10, fd7a:115c:a1e0::/48'* ]] || false
  [[ "$output" == *'nftables table: inet rig_org_rig_test_dev_server'* ]] || false
  [[ "$output" == *'Observed state: present (kernel-rules-unverified)'* ]] || false
  run "$RIG" show --format json
  [[ "$output" == *'"provider":"linux-nftables"'* ]] || false
  [[ "$output" == *'"locator":"org.rig.test.dev-server"'* ]] || false
  [[ "$output" == *'"allow":["tailnet"]'* ]] || false
}

@test "observation distinguishes present missing drifted exposed and unavailable" {
  [ "$(status_row)" = 'missing -' ]
  printf '%s\n' 'tcp LISTEN 0 511 0.0.0.0:3000 0.0.0.0:*' >"$FW_STATE/ss"
  [ "$(status_row)" = 'missing exposed-beyond-tailnet' ]
  printf '%s\n' 'tcp LISTEN 0 511 [::]:3000 [::]:*' >"$FW_STATE/ss"
  [ "$(status_row)" = 'missing exposed-beyond-tailnet' ]
  printf '%s\n' 'udp UNCONN 0 0 *%eth0:3000 *:*' >"$FW_STATE/ss"
  [ "$(status_row)" = 'missing exposed-beyond-tailnet' ]
  printf '%s\n' 'tcp LISTEN 0 511 100.101.1.2:3000 0.0.0.0:*' 'tcp LISTEN 0 511 127.0.0.1:3000 0.0.0.0:*' \
    'tcp LISTEN 0 511 *%lo:3000 *:*' 'tcp LISTEN 0 511 0.0.0.0:30000 0.0.0.0:*' 'udp UNCONN 0 0 0.0.0.0:5353 *:*' \
    >"$FW_STATE/ss"
  [ "$(status_row)" = 'missing -' ]

  install_present
  # A restricted listener still binds every address; nftables, not ss, filters it.
  printf '%s\n' 'tcp LISTEN 0 511 0.0.0.0:3000 0.0.0.0:*' >"$FW_STATE/ss"
  [ "$(status_row)" = 'present kernel-rules-unverified' ]

  printf '# edited\n' >>"$RULES"
  [ "$(status_row)" = 'drifted rules-changed,exposed-beyond-tailnet' ]
  rm "$FW_STATE/ss"
  [ "$(status_row)" = 'drifted rules-changed' ]
  install_present
  printf '# edited\n' >>"$UNIT"
  [ "$(status_row)" = 'drifted unit-changed' ]
  install_present
  rm "$RULES"
  [ "$(status_row)" = 'drifted rules-missing' ]
  install_present
  rm "$FW_STATE/enabled"
  [ "$(status_row)" = 'drifted unit-not-enabled' ]
  install_present
  rm "$FW_STATE/active"
  [ "$(status_row)" = 'drifted unit-not-active' ]
  printf 'exit-code\n' >"$FW_STATE/result"
  [ "$(status_row)" = 'drifted unit-result:exit-code' ]
  install_present
  rm "$UNIT"
  [ "$(status_row)" = 'drifted unit-missing' ]

  install_present
  FW_SHOW=fail
  export FW_SHOW
  [ "$(status_row)" = 'unknown systemctl-exit:4' ]
  unset FW_SHOW
  FW_SS=fail
  export FW_SS
  [ "$(status_row)" = 'unavailable ss-failed' ]
  unset FW_SS
  rm "$RULES"
  ln -s "$UNIT" "$RULES"
  [ "$(status_row)" = 'unavailable unsafe-rules' ]

  run env RIG_PLATFORM=macos "$RIG" status
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not support platform 'macos'"* ]] || false
  ! /usr/bin/grep -E '^sudo|^nft|^systemctl (daemon-reload|enable|restart|disable)' "$NATIVE_LOG" || false
}

@test "granted apply runs the exact ordered native argv once and then converges" {
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- nft -c -f RENDERED-rules
sudo -n -- /usr/bin/install -D -o root -g root -m 0644 RENDERED-rules ROOT/etc/rig/firewall/org.rig.test.dev-server.nft
sudo -n -- /usr/bin/install -D -o root -g root -m 0644 RENDERED-unit ROOT/etc/systemd/system/org.rig.test.dev-server.service
sudo -n -- systemctl daemon-reload
sudo -n -- systemctl enable org.rig.test.dev-server.service
sudo -n -- systemctl restart org.rig.test.dev-server.service
sudo -n -- nft list table inet rig_org_rig_test_dev_server
LOG
)" ]
  [ "$(cat "$RULES")" = "$(golden_rules)" ]
  [ "$(cat "$UNIT")" = "$(golden_unit)" ]
  [ "$(/usr/bin/stat -f %Lp "$RULES" 2>/dev/null || /usr/bin/stat -c %a "$RULES")" = 644 ]
  /usr/bin/grep -F $'linux-nftables\tfirewall\tdev-server\torg.rig.test.dev-server' "$RECEIPT"
  [ -z "$(/bin/ls -A "$TMPDIR")" ]
  assert_no_global_firewall

  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || false
  [[ "$(cat "$STDOUT")" == *'no prompt needed'* ]] || false
  ! /usr/bin/grep -E '^sudo|^nft|^systemctl (daemon-reload|enable|restart|disable)' "$NATIVE_LOG" || false
  run "$RIG" apply
  [ "$status" -eq 0 ]
  ! /usr/bin/grep -E '^sudo|^nft|^systemctl (daemon-reload|enable|restart|disable)' "$NATIVE_LOG" || false
}

@test "granted apply repairs a changed unit without reinstalling current rules" {
  install_present
  printf '# edited\n' >>"$UNIT"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- nft -c -f RENDERED-rules
sudo -n -- /usr/bin/install -D -o root -g root -m 0644 RENDERED-unit ROOT/etc/systemd/system/org.rig.test.dev-server.service
sudo -n -- systemctl daemon-reload
sudo -n -- systemctl enable org.rig.test.dev-server.service
sudo -n -- systemctl restart org.rig.test.dev-server.service
sudo -n -- nft list table inet rig_org_rig_test_dev_server
LOG
)" ]
  [ "$(cat "$UNIT")" = "$(golden_unit)" ]
}

@test "a rejected table installs nothing and a reread mismatch fails" {
  FW_PARSE=fail
  export FW_PARSE
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [[ "$(cat "$STDERR")" == *'nft rejected the rendered table; nothing installed'* ]] || false
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = 'sudo -n -- nft -c -f RENDERED-rules' ]
  [ -z "$(/usr/bin/find "$RIG_SYSTEM_ROOT" -type f)" ]
  [ -z "$(/bin/ls -A "$TMPDIR")" ]
  ! /usr/bin/grep -F $'linux-nftables\tfirewall' "$RECEIPT" 2>/dev/null || false

  unset FW_PARSE
  FW_RULES=mismatch
  export FW_RULES
  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [[ "$(cat "$STDERR")" == *'loaded rules do not match the rendered table'* ]] || false
  [ "$(native | /usr/bin/grep -c '^sudo -n -- nft list table inet rig_org_rig_test_dev_server')" -eq 1 ]
  assert_no_global_firewall
}

@test "apply without a grant or with a refused grant dispatches no native mutation" {
  run env RIG_OUTCOME=always "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'skipped'*'administrator-grant-required'* ]] || false
  ! /usr/bin/grep -E '^sudo|^nft|^systemctl (daemon-reload|enable|restart|disable)' "$NATIVE_LOG" || false

  FW_SUDO=refuse
  export FW_SUDO
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  [ "$(native | /usr/bin/grep '^sudo')" = 'sudo -v' ]
  ! /usr/bin/grep -E '^nft|^systemctl (daemon-reload|enable|restart|disable)' "$NATIVE_LOG" || false
  [ -z "$(/usr/bin/find "$RIG_SYSTEM_ROOT" -type f)" ]
}

@test "deleting the declaration retires only the receipted table and unit" {
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || false

  # Deselection keeps the declaration, so nothing is retired.
  FW_MEMBERS=
  write_config
  : >"$NATIVE_LOG"
  run "$RIG" apply
  [ "$status" -eq 0 ]
  /usr/bin/grep -F $'linux-nftables\tfirewall\tdev-server' "$RECEIPT"
  [ -f "$RULES" ]

  printf '%s\n' '[rig]' 'default-profile = "default"' '[profile.default]' 'name = "Default"' \
    >"$RIG_CONFIG_HOME/rig.toml"
  run "$RIG" apply
  [ "$status" -eq 1 ]
  [[ "$output" == *'skipped'*'administrator-grant-required'* ]] || false
  /usr/bin/grep -F $'linux-nftables\tfirewall\tdev-server' "$RECEIPT"

  # A failed retirement keeps its receipt row and every file.
  FW_DISABLE=fail
  export FW_DISABLE
  terminal apply --sudo
  [[ "$output" == *'"status": 1'* ]] || false
  /usr/bin/grep -F $'linux-nftables\tfirewall\tdev-server' "$RECEIPT"
  [ -f "$RULES" ]
  [ -f "$UNIT" ]
  unset FW_DISABLE

  # A table the stopped unit left behind is deleted by name.
  FW_STOP=keep
  export FW_STOP
  : >"$NATIVE_LOG"
  terminal apply --sudo
  [[ "$output" == *'"status": 0'* ]] || { cat "$STDOUT" "$STDERR" >&3; false; }
  [ "$(native | /usr/bin/grep '^sudo -n -- ')" = "$(cat <<'LOG'
sudo -n -- systemctl disable --now org.rig.test.dev-server.service
sudo -n -- nft list table inet rig_org_rig_test_dev_server
sudo -n -- nft delete table inet rig_org_rig_test_dev_server
sudo -n -- /bin/rm -f -- ROOT/etc/systemd/system/org.rig.test.dev-server.service ROOT/etc/rig/firewall/org.rig.test.dev-server.nft
sudo -n -- systemctl daemon-reload
LOG
)" ]
  [ ! -e "$RULES" ]
  [ ! -e "$UNIT" ]
  [ ! -e "$FW_STATE/nft-loaded" ]
  ! /usr/bin/grep -F $'linux-nftables\tfirewall' "$RECEIPT" || false
  assert_no_global_firewall
}
