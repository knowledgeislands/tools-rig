---
id: KI-TOOL-RIG-CORE-068
area: CORE
title: pf root ruleset bypass
purpose: corrective
theme: rig
kind: deliver
status: draft
horizon: now
priority: high
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T22:14:04Z
updated_at: 2026-10-20T00:51:09Z
---

# Doctor Reports a Firewall Bypassed by a Replaced pf Root Ruleset

## Goal

`rig doctor` reports a `macos-pf` firewall resource as bypassed when root's pf ruleset no longer calls `com.apple/*`, as when NordVPN replaces it with one that calls `main/*`. Doctor reports the resource as unknown, not healthy, when it lacks the privilege to tell. Whether Rig should also re-assert its protection is decided from the attended NordVPN check, not assumed.

## Context

[KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) loads Rig's rules as the child anchor `com.apple/LOCATOR`. pf evaluates that anchor only while root's main ruleset calls `anchor "com.apple/*"`. Its [read-only preflight on `sol`](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md#read-only-preflight-on-sol-19-october-2026) called for this follow-up.

The chezmoi work's [terra-nordvpn run](/Users/krisbrown/.local/state/ki/agents/chezmoi/terra-nordvpn.report.md) read `terra` without root on 19 October 2026. It read the root ruleset template from the strings of NordVPN's privileged helper, `com.nordvpn.macos.helper`. On connect, the helper replaces root's whole ruleset with one that calls only `scrub-anchor`, `nat-anchor`, `rdr-anchor`, `dummynet-anchor` and `anchor "main/*"`, sets `set skip on { … }`, and then loads `/etc/pf.conf` as the anchor `main`. Apple's relative `anchor "com.apple/*"` then resolves to `main/com.apple/*`. Rig's root-level `com.apple/LOCATOR` stays loaded, but nothing evaluates it. The template is fixed, and NordVPN's settings change only what it contains. With the kill switch on, the replaced ruleset probably outlasts the connection. The daemon's `WatchPaths` on `/etc/pf.conf` does not fire, because the helper never edits that file.

A [blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/nordvpn-review.report.md) found the anchor reasoning sound, conditionally. The installed `pf.conf(5)` confirms that a sub-anchor's relative calls resolve beneath it and that a wildcard visits only immediate children. That is strong evidence of a bypass while this template is active, but not proof of a connected Mac's call graph. The review also found that the strings do not prove the exclusion for every setting, the persistence after disconnect, or the actual exposure of the LAN or tailnet.

Kris approved this record on 19 October 2026 at 23:13 BST (TERRA-NORDVPN a), [chezmoi decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.chezmoi/decisions.md)): the fix lies in Rig.

Today Rig cannot see the bypass:

- **Unprivileged doctor.** It sees files, the daemon and whether the listener is exposed, and states kernel rules as unverified. It cannot read pf.
- **`apply --sudo`.** It rereads only `pfctl -a com.apple/LOCATOR -s rules` against the rendered rules (`src/rig/29-firewall.bash`, the loaded-rule check and apply path). An attended apply can therefore succeed while root never reaches the child. KI-TOOL-RIG-CORE-047's Risks and FW-PERSIST suggest that apply notices a lost anchor point. That holds for a missing child anchor, but not for a missing parent call.

## Boundary

- **In: an invariant on root's call.** Under privilege, check that root's main ruleset calls `com.apple/*` as well as that the child's rules match. If root does not call it, report the firewall `drifted` with a new reason, for example `anchor-not-reached`, in doctor, status and `apply --sudo`. Name the replacing anchor (`main/*`) when one is visible.
- **In: an honest unprivileged view.** Doctor without root keeps reporting kernel state as unknown. It must never report the protection as effective from file, daemon or rule-count evidence alone. Planning decides whether unprivileged evidence that a pf-using VPN is connected, such as a connected `scutil --nc` service, should raise the finding to a possible bypass.
- **In: keep loaded rules and reachability apart.** Child rules that match while root does not reach them are loaded, not protecting. The report says which one it has shown.
- **In: specification alignment.** Add the reason to RIG-STATE-045. Correct KI-TOOL-RIG-CORE-047's Risks text and ADR-KI-TOOL-RIG-009's residual risk wherever they imply that apply detects this bypass. Add fixture coverage in `tests/rig-firewall.bats` with stubbed `pfctl` output for a `main/*` root.
- **Decided later, from the attended check: re-assertion.** Whether Rig should restore its protection while a VPN owns root. Reloading an orphaned child cannot restore its missing parent call. Rewriting root's ruleset would compete with NordVPN as a root-rule writer, and could remove its kill-switch or leak-prevention rules. Re-assertion therefore needs its own design, a tested restore path under the connection-critical rule, and Kris's approval. A periodic `StartInterval` reload (FW-PERSIST's alternative) does not help, for the same reason.
- **Out:** NordVPN settings and any change on `sol` or `terra`; editing `/etc/pf.conf`; writing root's main ruleset; reproducing the bypass by connecting a VPN as an automated test. [AGENTS.md](../../AGENTS.md) forbids live reproduction of a destructive defect, and this one is connection-critical.

## Acceptance evidence

The attended NordVPN check below is this record's acceptance evidence, and it gates implementation. It replaces the N and P blocks in the [terra-nordvpn report](/Users/krisbrown/.local/state/ki/agents/chezmoi/terra-nordvpn.report.md) and takes the [blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/nordvpn-review.report.md)'s corrections:

- **A tested restore path comes first.** Step 4 rehearses the restore R on `terra` before NordVPN connects. If R does not pass, the trial stops there.
- **N reports evaluation only on fuller evidence.** It reports `RIG EVALUATED` only when pf is enabled, the loaded rules match the anchor file's content, root calls `com.apple/*`, no root rule comes before that call, no other `com.apple` child holds rules, and neither `en0` nor the tailnet interface is skipped. Any failed read reports `UNKNOWN`. A missing `com.apple/*` call reports `RIG NOT EVALUATED`, and N prints every other root anchor call so that the paste shows whether anything else reaches Rig's anchor.
- **P reports what it saw, not a block.** Only `GREETING` is positive evidence. Rig's block rule drops packets, so `TIMEOUT` is consistent with a block but does not prove one; `REFUSED` means nothing listened or something rejected. P uses `terra`'s current LAN address from N, prints where the `terra` SSH alias resolves, and probes LAN 22 as a control. It tests TCP only; it can probe IPv6 on the tailnet if N prints `terra`'s tailnet IPv6 address, and says nothing about UDP 5900.
- **Everything repeats after the disconnect,** the root inspection and the endpoint probes alike.

### Attended NordVPN check

Run it on the home network, at `terra`'s own console, with a plain shell on `sol` beside it. A connected NordVPN may block SSH over the tailnet, so no step depends on reaching `terra` remotely. Every block checks which machine it is on and writes every name literally. N and P only read. R writes pf: it reloads Apple's own `/etc/pf.conf` into root and reloads Rig's anchor with the command its LaunchDaemon already runs, and it refuses unless the NordVPN app is quit and no VPN other than Tailscale is connected. The only other change is NordVPN's own Connect and Disconnect, made by Kris. If a block prints `REFUSED`, it has run nothing. Stop at any result that differs from the expectation and paste everything; never improvise a reload.

1. **Record NordVPN's settings on `terra`.** Open NordVPN and note the kill switch, the local-network ("Invisibility on LAN" or LAN discovery) setting, Meshnet and auto-connect. Leave Screen Sharing as it is. This phase needs the kill switch off. If it is on, either turn it off and note that you did, or stop here; turning it back on afterwards is step 10. Quit NordVPN.
2. **Baseline N on `terra`.** Expect `NordVPN app: not running`, no `connected:` line other than Tailscale, `N RESULT: pf enabled: yes | rig rules 8, match file: yes | root calls com.apple/*: yes | other root anchors: none | root rules before call: 0 | rules in other com.apple children: 0 | skipped: no | unreadable: none` and `N VERDICT: RIG EVALUATED`. Note the `== addr en0` IPv4 address and the tailnet interface's `fd7a:` address. If the verdict differs, stop: the anchor is not protecting even without NordVPN.
3. **Baseline P on `sol`.** First set `LAN=` to step 2's `en0` address and `T6=` to its `fd7a:` address in the block. Expect the alias line to name `100.96.126.29` or a name for it, `P SSH terra: open`, `GREETING RFB` on tailnet 5900 (and on the IPv6 line), `TIMEOUT` on LAN 5900 and `CONNECTS, no greeting` on LAN 22. LAN 22 must connect; if it does not, the LAN lines say nothing.
4. **Rehearse the restore R on `terra`, with NordVPN still quit.** Expect `R START`, pfctl's usual warnings about `-f` flushing the main ruleset and about ALTQ, then `R RESULT: apple root reload rc=0 | rig anchor reload rc=0`. Run N again and expect step 2's `N RESULT` and `RIG EVALUATED`, with one more `pfctl` enable reference, which is harmless, as KI-TOOL-RIG-CORE-047's rehearsal found. Run P on `sol` and expect step 3's lines. Only when all three match is the restore path tested; otherwise stop, and do not connect NordVPN.
5. **Connect NordVPN on `terra`, then run N.** The expectation from the helper's template is `root calls com.apple/*: NO`, `other root anchors: anchor "main/*"` and `N VERDICT: RIG NOT EVALUATED`. Either result is evidence: `RIG EVALUATED` here would contradict the template and change this record's scope. Paste the whole output, including the `NordVPN` rules and `skip` lines.
6. **Run P on `sol` while connected.** Paste it. SSH over the tailnet may fail and either 5900 line may change; these results show what NordVPN's own rules pass.
7. **Disconnect NordVPN, quit it, then run N.** Expect step 2's result again, which means NordVPN restored root itself. If it reports `RIG NOT EVALUATED`, NordVPN kept its ruleset: run R, which step 4 rehearsed, then N, and expect step 2's result. Paste both.
8. **Run P on `sol` after the disconnect.** Expect step 3's lines.
9. **If R refused, failed, or N still did not report `RIG EVALUATED`:** open NordVPN, check that the kill switch is off, disconnect and quit it, and run N again. If that still fails, restart `terra` at the console. Apple's boot job reloads `/etc/pf.conf` and Rig's LaunchDaemon reloads the anchor at boot, which KI-TOOL-RIG-CORE-047's restart evidence proved for a machine without NordVPN connected. After logging in, run N and P and paste them. Until N reports `RIG EVALUATED` again, keep Screen Sharing off on `terra`.
10. **Return NordVPN to the settings step 1 recorded.** If the kill switch was on, turn it back on only with NordVPN disconnected, then run N once more and expect step 2's result. Whether the kill switch keeps the replaced ruleset after a disconnect is a second, optional phase: it repeats steps 5 to 9 with the kill switch on, and needs Kris's separate go after this phase's results are in.

The check succeeds when steps 2 to 4 match and steps 5 to 8 are pasted, whatever they show, and `terra` ends at step 2's result. The restore path is then R, rehearsed at step 4, with NordVPN's own disconnect and a restart as fallbacks.

**N, on `terra` (terminal at `terra`'s console; reads only):**

```sh
( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | grep -q 2C1DB95F-EC29-535D-A7CC-333EDF838C02 || { echo "REFUSED: not terra, nothing run"; exit 1; }
  [ -z "$SSH_CONNECTION" ] || { echo "REFUSED: this is an SSH session; use terra's own console"; exit 1; }
  [ -t 0 ] || { echo "REFUSED: no terminal, nothing run"; exit 1; }
  echo "== $(date +%T) NordVPN app: $(/usr/bin/pgrep -f '/NordVPN[.]app/Contents/MacOS/' >/dev/null && echo running || echo 'not running')"
  /sbin/ifconfig | awk '/^[a-z]/{n=$1} /inet6? /{print "== addr", n, $2}' | grep -v -E ' lo0: | fe80:'
  /usr/sbin/scutil --nc list 2>/dev/null | grep "(Connected)" | sed "s/^/== connected: /"
  tun=$(/sbin/ifconfig | awk '/^[a-z]/{n=$1} /inet6 fd7a:115c:a1e0:/{sub(":$","",n); print n; exit}')
  echo "== tailnet interface: ${tun:-NOT FOUND}"
  sudo /bin/zsh -fc '
/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | grep -q 2C1DB95F-EC29-535D-A7CC-333EDF838C02 || { print "REFUSED: not terra"; exit 1; }
L=uk.me.kris.rig.firewall.screen-sharing; tun=$1; u=
info=$(/sbin/pfctl -s info 2>/dev/null) || u="$u info"
root=$(/sbin/pfctl -s rules 2>/dev/null) || u="$u root-rules"
loaded=$(/sbin/pfctl -a com.apple/$L -s rules 2>/dev/null) || u="$u rig-rules"
want=$(/sbin/pfctl -nvf /etc/pf.anchors/$L 2>/dev/null) || u="$u anchor-file"
ifs=$(/sbin/pfctl -s Interfaces -v 2>/dev/null) || u="$u interfaces"
kids=$(/sbin/pfctl -a com.apple -s Anchors 2>/dev/null) || u="$u com.apple-anchors"
print "== pf: ${info%%$'\''\n'\''*}"; print "== enable references"; /sbin/pfctl -s References 2>/dev/null
print "== root rules"; print -r -- "$root"; print "== root nat"; /sbin/pfctl -s nat 2>/dev/null
print "== skip"; print -r -- "$ifs" | grep -i skip || print none
print "== root anchors"; /sbin/pfctl -s Anchors 2>/dev/null; print "== com.apple anchors"; print -r -- "$kids"
print "== main anchors"; /sbin/pfctl -a main -s Anchors -v 2>/dev/null
for a in NordVPN $(/sbin/pfctl -a NordVPN -s Anchors -v 2>/dev/null); do print "== $a rules"; /sbin/pfctl -a $a -s rules 2>/dev/null; print "== $a nat"; /sbin/pfctl -a $a -s nat 2>/dev/null; done
norm() { sed -e "s/[[:space:]][[:space:]]*/ /g" -e "s/ $//" -e "s/ keep state$//" -e "s/ flags S\/SA$//" | grep -v "^$"; }
n=$(print -r -- "$loaded" | grep -c .)
[ "$(print -r -- "$loaded" | norm)" = "$(print -r -- "$want" | norm)" ] && c=yes || c=NO
print -r -- "$info" | grep -q "^Status: Enabled" && on=yes || on=NO
print -r -- "$root" | grep -q "^anchor \"com.apple/\*\"" && e=yes || e=NO
m=$(print -r -- "$root" | grep -o "^anchor \"[^\"]*\"" | grep -v "\"com.apple/\*\"" | tr "\n" " ")
pre=$(print -r -- "$root" | sed "/^anchor \"com.apple\/\*\"/,\$d" | grep -v -c -E "^(scrub-|nat-|rdr-|dummynet-)?anchor ")
sib=0; for k in ${(f)kids}; do k=${k//[[:space:]]/}; [ "$k" = com.apple/$L ] && continue; s=$(/sbin/pfctl -a $k -s rules 2>/dev/null | grep -c .); sib=$((sib+s)); done
sk=no; for i in en0 $tun; do print -r -- "$ifs" | grep -i skip | grep -q -w $i && sk="$sk $i"; done
print "N RESULT: pf enabled: $on | rig rules $n, match file: $c | root calls com.apple/*: $e | other root anchors: ${m:-none} | root rules before call: $pre | rules in other com.apple children: $sib | skipped: $sk | unreadable:${u:- none}"
if [ -n "$u" ] || [ -z "$tun" ]; then print "N VERDICT: UNKNOWN - paste everything above"
elif [ $e = NO ] || [ $on = NO ] || [ $n = 0 ]; then print "N VERDICT: RIG NOT EVALUATED - paste everything above"
elif [ $c = yes ] && [ $pre = 0 ] && [ $sib = 0 ] && [ "$sk" = no ]; then print "N VERDICT: RIG EVALUATED"
else print "N VERDICT: UNKNOWN - paste everything above"; fi
' zsh "$tun" )
```

**P, on `sol` (plain shell; reads only).** Set `LAN` and `T6` from step 2's N output before running it.

```sh
( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | grep -q BFDD9EED-C084-5B5C-BECB-070FF0D05916 || { echo "REFUSED: not sol, nothing run"; exit 1; }
  LAN=192.168.1.22; T4=100.96.126.29; T6=
  echo "== $(date +%T) ssh alias terra -> $(ssh -G terra 2>/dev/null | awk '$1=="hostname"{print $2}') (tailnet is $T4)"
  e=$(ssh -o ControlMaster=no -o ControlPath=none -o ConnectTimeout=10 -o BatchMode=yes terra '/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | grep -q 2C1DB95F-EC29-535D-A7CC-333EDF838C02 && echo terra' 2>&1)
  [ "$e" = terra ] && echo "P SSH terra: open" || echo "P SSH terra: FAILED ($(print -r -- "$e" | tail -1))"
  probe() { local b z; b=$(nc -G 5 -w 5 $2 $3 </dev/null 2>/dev/null | head -c 12 | tr -d "\n")
    case "$b" in RFB*) echo "P $1 $3: GREETING $b"; return;; esac
    z=$(nc -v -z -G 5 -w 5 $2 $3 2>&1)
    case "$z" in *succeeded*) echo "P $1 $3: CONNECTS, no greeting";; *refused*) echo "P $1 $3: REFUSED";; *timed\ out*|*Timeout*|"") echo "P $1 $3: TIMEOUT";; *) echo "P $1 $3: OTHER ($z)";; esac; }
  probe "tailnet $T4" $T4 5900; probe "LAN $LAN" $LAN 5900; probe "LAN $LAN" $LAN 22
  [ -z "$T6" ] || probe "tailnet $T6" $T6 5900 )
```

**R, on `terra` (terminal at `terra`'s console; restores Apple's root ruleset and Rig's anchor).** Run it only at step 4, and at step 7 if N reports `RIG NOT EVALUATED` after the disconnect.

```sh
( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | grep -q 2C1DB95F-EC29-535D-A7CC-333EDF838C02 || { echo "REFUSED: not terra, nothing run"; exit 1; }
  [ -z "$SSH_CONNECTION" ] || { echo "REFUSED: this is an SSH session; use terra's own console"; exit 1; }
  [ -t 0 ] || { echo "REFUSED: no terminal, nothing run"; exit 1; }
  /usr/bin/pgrep -f '/NordVPN[.]app/Contents/MacOS/' >/dev/null && { echo "REFUSED: NordVPN app is running; disconnect and quit it first, nothing run"; exit 1; }
  /usr/sbin/scutil --nc list 2>/dev/null | grep "(Connected)" | grep -v -i tailscale | grep -q . && { echo "REFUSED: a VPN other than Tailscale is connected, nothing run"; exit 1; }
  echo "R START $(date +%T)"
  sudo /bin/zsh -fc '
/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | grep -q 2C1DB95F-EC29-535D-A7CC-333EDF838C02 || { print "REFUSED: not terra"; exit 1; }
[ -f /Library/LaunchDaemons/uk.me.kris.rig.firewall.screen-sharing.plist ] && [ -f /etc/pf.anchors/uk.me.kris.rig.firewall.screen-sharing ] || { print "REFUSED: Rig files missing, nothing run"; exit 1; }
/sbin/pfctl -n -f /etc/pf.conf 2>/dev/null || { print "REFUSED: /etc/pf.conf does not parse, nothing run"; exit 1; }
/sbin/pfctl -f /etc/pf.conf; a=$?
/sbin/pfctl -E -a com.apple/uk.me.kris.rig.firewall.screen-sharing -f /etc/pf.anchors/uk.me.kris.rig.firewall.screen-sharing; b=$?
print "R RESULT: apple root reload rc=$a | rig anchor reload rc=$b"
' )
```

The three blocks pass `zsh -n`, as do N's and R's root scripts. None has been run.

### What the results decide

- **Step 5 reports `RIG NOT EVALUATED` with `main/*`:** the bypass is confirmed, and Steps 1 to 6 below proceed as planned.
- **Step 5 reports `RIG EVALUATED`:** the template reading was wrong for this setting. Return this record to planning; the root invariant may still be worth keeping, but its premise needs restating.
- **Step 7 reports `RIG NOT EVALUATED` with the kill switch off:** the bypass outlasts a connection even without the kill switch. Detection is unchanged, but the operational advice in Discussion tightens, and re-assertion becomes a stronger candidate for its own record.
- **Re-assertion** stays out of this record whatever the results. If they show it is wanted, it goes under Queries for a new record, with its own design and its own tested restore path.

## Current state

Grounded at `6e060d0` on 20 October 2026, from source only. No pf state was read.

- **Unprivileged observation** (`rig_firewall_observe`, `src/rig/29-firewall.bash`) compares the two rendered files with those on disk, reads the daemon with `launchctl print system/LOCATOR`, scans listeners with `netstat -an` and reads the tailnet addresses from `ifconfig`. When everything matches it reports `present` with `kernel-rules-unverified`. It cannot see pf.
- **The privileged reread** (`rig_firewall_loaded_rules_match`) runs only `sudo -n pfctl -a com.apple/LOCATOR -s rules` and compares the normalised output with the anchor file. Nothing reads root's ruleset.
- **A present firewall is never reread.** `rig_sudo_guard` (`src/rig/28-sudo-session.bash`) counts a firewall as needing the grant only when its unprivileged observation is not `present`, and prints `no prompt needed` otherwise; `rig_firewall_apply` without the grant returns success for a present firewall. So on a Mac where both files and the daemon are correct, `rig apply --sudo` neither prompts nor rereads, even the child's rules. RIG-ORCH-043 and the user guide's "a correct firewall needs no grant and no prompt" specify that. ADR-KI-TOOL-RIG-009's "`apply --sudo` rereads the loaded rules on every run", the guide's "`apply --sudo` checks them on every run" and KI-TOOL-RIG-CORE-047's Risks contradict it. The reread runs only after a repair, as on `sol`'s attended apply, whose anchor was missing.
- **Fixtures.** The `pfctl` stub in `tests/rig-firewall.bats` answers `-n -f`, `-E -a … -f`, `-a … -s rules` and `-a … -F all`, and fails anything else with 99. The sudo stub passes `pfctl` and `launchctl` through. Every test asserts that no log names `/etc/pf.conf`, `socketfilterfw`, `pfctl -d` or `-X`.
- **Specifications.** RIG-ORCH-023 fixes the adapter's mutation order and its child-only reread; RIG-STATE-045 owns unprivileged evidence and its reasons; RIG-ORCH-043 owns when the grant is taken. `man/rig.1` and [Add resources](../guides/user/operational-resources.md) describe the same behaviour.

## Steps

- [ ] **Gate.** Kris has run the [attended NordVPN check](#attended-nordvpn-check), steps 2 to 4 matched, and the pasted results are recorded in this record's Review. [What the results decide](#what-the-results-decide) keeps this plan, and Kris has answered the planning queries. Without all of that, stop. Every later step is fixture-only and touches no live pf.
- [ ] **1. Root invariant.** Add `rig_firewall_root_reaches` to `src/rig/29-firewall.bash`. Under the grant it runs `sudo -n pfctl -s rules` once and succeeds only when root's rules include `anchor "com.apple/*"`. Otherwise it sets `anchor-not-reached`, with `:main/*` or whichever other wildcard anchor call root makes. A failed read sets `root-ruleset-unreadable`. It reads only; no new `pfctl` write exists.
- [ ] **2. Apply verifies reachability as well as rules.** In `rig_firewall_apply`, a present firewall checks both the child's rules and root's call. A root that does not reach the child fails the resource with `anchor-not-reached…`, explaining that reloading the child cannot restore its parent call, and installs, boots out and reloads nothing. A missing or drifted firewall is installed as today; after the reread, the root check runs, and a root that does not reach it fails the resource with the same reason, leaving the installed files in place for the next boot.
- [ ] **3. `apply --sudo` takes the grant to verify a present firewall,** subject to query PLAN068-VERIFY-GRANT. `rig_sudo_guard` counts a selected `macos-pf` firewall as needing the grant whenever `--sudo` is given, so the reread and root check run on every attended apply. Plain `rig apply` stays promptless and unchanged.
- [ ] **4. Unprivileged view,** subject to query PLAN068-UNPRIV. Doctor, status and `show` keep `present` with `kernel-rules-unverified`; `rig explain` and the documents say that this does not mean the rules are evaluated. No `scutil` hint: the kill switch can keep a replaced ruleset with no VPN connected, and Tailscale is itself a connected `scutil --nc` service, so the signal is neither necessary nor sufficient.
- [ ] **5. Fixtures.** Extend the `pfctl` stub in `tests/rig-firewall.bats` with a root `-s rules` answer chosen by `FW_ROOT`: `apple` (default), `nordvpn` (the helper's template, calling `main/*`) or `fail`. Cover: a present firewall under an Apple root completes; under a NordVPN root it fails with `anchor-not-reached:main/*` and logs no install, bootout, bootstrap or load; a missing firewall under a NordVPN root installs, rereads and then fails with the same reason; a failed root read fails with `root-ruleset-unreadable`; `apply --sudo` with a present firewall takes the grant, while plain `apply` and doctor log no `sudo` or `pfctl`. Update the matching case in `tests/rig-sudo-session.bats` if step 3 changes its expectation. Extend the existing log assertion so that no test runs `pfctl -f` or `-F` without `-a`.
- [ ] **6. Documents and assembly.** Align the specifications, ADR, guide, manual and KI-TOOL-RIG-CORE-047's Risks as [Documentation impact](#documentation-impact) lists, add a CHANGELOG entry, run `scripts/assemble-rig`, then run the gate under [Verify](#verify).

## Files touched

- `src/rig/29-firewall.bash` and `src/rig/28-sudo-session.bash`; `bin/rig`, regenerated by `scripts/assemble-rig`.
- `tests/rig-firewall.bats`, and `tests/rig-sudo-session.bats` if step 3 changes its case.
- `docs/specs/orchestration.md` (RIG-ORCH-023, RIG-ORCH-043) and `docs/specs/state.md` (RIG-STATE-045).
- `docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md`.
- `docs/guides/user/operational-resources.md`, `man/rig.1` and `CHANGELOG.md`.
- `docs/roadmap/KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md`, Risks only, and this record.

Nothing under `/etc`, `/Library` or any live Mac. `package.json`, `bun.lock`, `.husky/` and `.githooks/` are unchanged.

## Verify

- `bats tests/rig-firewall.bats tests/rig-sudo-session.bats </dev/null` passes, including every new case in step 5.
- The complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes, including `scripts/assemble-rig --check`, `bats tests/ </dev/null`, the shell gate, `mandoc -T lint man/rig.1`, `ki repo audit --repo .` and `git diff --check`.
- A hostile isolation run, with `XDG_STATE_HOME` and `XDG_CONFIG_HOME` pointed at outside directories, passes and leaves them empty.
- No test log names `/etc/pf.conf`, `socketfilterfw`, `pfctl -d`, `-X`, or a `pfctl -f` or `-F` without `-a`.
- Live acceptance is the attended check's evidence, already recorded at the gate. A later attended `rig apply --sudo` on `terra` while NordVPN is connected would show the new reason live, but it needs its own approval and is not required here.

## Dependencies / blocks

Gated on Kris's attended NordVPN check, which is not a roadmap record. It follows [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md), whose resource it extends and whose Risks it corrects. [KI-TOOL-RIG-CORE-062](KI-TOOL-RIG-CORE-062-own-address-firewall-destination.md) changed the same anchor's destinations; the two are independent, and this plan assumes 062's rendering as it is at `6e060d0`.

## Documentation impact

### Decision Records

ADR-KI-TOOL-RIG-009 is `proposed`, so it is corrected in place. Its Decision states that `apply --sudo` rereads the loaded rules "on every run" and that a present resource needs no grant; it will say instead that an attended apply verifies both the child's rules and root's call, subject to PLAN068-VERIFY-GRANT. Its Consequences gain the replaced-root case beside the dropped-anchor-point case, and say that the attended apply detects it but does not repair it.

### Specifications

- RIG-ORCH-023: the reread gains root's `com.apple/*` call and the reasons `anchor-not-reached` and `root-ruleset-unreadable`, and the adapter is forbidden from writing root's ruleset.
- RIG-ORCH-043: under PLAN068-VERIFY-GRANT a), a selected `macos-pf` firewall counts as work for an explicit `--sudo`.
- RIG-STATE-045: `kernel-rules-unverified` covers root reachability as well as the loaded rules, and a present observation does not mean the rules are evaluated.

### Guides

[Add resources](../guides/user/operational-resources.md)'s macOS firewall section: correct "A correct firewall needs no grant and no prompt" and "`apply --sudo` checks them on every run", explain `anchor-not-reached`, and say that a VPN client replacing pf's ruleset bypasses the firewall, which Rig reports but does not repair. The operational advice for NordVPN itself belongs in the chezmoi guide, not here.

### Roadmap

KI-TOOL-RIG-CORE-047's Risks ("Covered by the live NordVPN check; a periodic re-assertion is the fallback") and its Outstanding concerns' statement that only `apply --sudo` notices a dropped anchor point are corrected to point here and to say that no periodic reload restores a missing parent call.

## Queries

Planning raises these three. They are answered before the gate; none blocks the attended check.

- **PLAN068-VERIFY-GRANT.** Should an explicit `apply --sudo` take the grant to verify a present `macos-pf` firewall? Recommended a), confidence high: otherwise the attended apply never reaches the new root check on a correct-looking Mac, which is exactly where the bypass hides; plain `apply` stays promptless. b) keeps today's rule and adds the root check only after a repair.
- **PLAN068-UNPRIV.** The Goal says doctor reports unknown, not healthy, without privilege. Should that change the observation from `present` to `unknown`? Recommended a), confidence medium: keep `present` with `kernel-rules-unverified` and make its meaning explicit, because `unknown` would make every firewall a permanent doctor finding on every Mac and drown the signal. b) report `unknown` with `kernel-rules-unverified`, and accept that permanent finding.
- **PLAN068-READY.** Approve this plan to Ready, with implementation gated on the attended check? Recommended a), confidence medium: the detection plan stands whatever the check shows unless step 5 contradicts the template, which the gate catches. b) keep it in draft until the check has run.

## Discussion

- **Avoid simultaneous use, outside Rig.** The review proposed this until protection is verified: keep Screen Sharing off whenever NordVPN is connected, and keep it off after a disconnect until the protection is checked again. The alternative is to keep NordVPN disconnected while Screen Sharing is needed. That operational advice belongs in the chezmoi guide, not here. NordVPN's local-network setting could later add protection, but it is not yet verified for every protocol and address family.
- **Other residual risks.** These stay outside this record's fix, but planning should keep them in view. Meshnet NATs and filters `100.64.0.0/10`, which overlaps Tailscale's range. Tailnet SSH may depend on what NordVPN's block-all passes. The anchor's range and interface limits are covered in KI-TOOL-RIG-CORE-047's [Range correction](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md#range-correction).
- **One wildcard is a start.** Checking for root's `com.apple/*` call is an initial invariant, not a complete test of protection. Planning decides how far to go towards effective reachability before the evidence runs out.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: adopted into Now, confidence high, for planning and evidence preparation only, because the child-rule check cannot establish root reachability and misleading protection evidence deserves early attention. Implementation waits for Kris's attended NordVPN check and a tested restore path under the connection-critical rule; no root-ruleset re-assertion, `pfctl` change or other live machine change is authorised.
