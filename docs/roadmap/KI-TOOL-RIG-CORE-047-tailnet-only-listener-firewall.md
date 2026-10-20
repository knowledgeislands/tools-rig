---
id: KI-TOOL-RIG-CORE-047
area: CORE
title: Tailnet-only listener firewall
theme: rig
kind: deliver
horizon: now
status: in-progress
blocks: []
blocked_by: []
baseline_ref: 39499cd6566b2fa02f9c66476eda53f052ccb351
created_at: 2026-10-13T22:48:41Z
updated_at: 2026-10-20T05:33:29Z
---

# KI-TOOL-RIG-CORE-047: Tailnet-Only Listener Firewall

## Goal

A profile declares that named remote-access listeners, Screen Sharing first, accept connections only from the tailnet and loopback. On macOS, `rig apply --sudo` installs a packet-filter (`pf`) restriction that survives restarts and macOS updates without editing `/etc/pf.conf`; `rig doctor` reports a machine whose restriction is missing or damaged, or whose declared listener is open beyond the tailnet with no restriction in place. Every other port, SSH in particular, is never touched, and the application firewall is never enabled.

## Context

Kris asked for remote access to be managed by Rig on 2026-10-13 (mac-studio-bootstrap Decision 45), and chose to build the tailnet-only Screen Sharing firewall properly in Rig now rather than hand-fix `sol` (Decision 48, after Decision 47 deferred the hand fix to Rig). This record is the firewall slice split out of [KI-TOOL-RIG-CORE-046](https://github.com/knowledgeislands/tools-rig/blob/5d7af1c5101d19438aff80973b483c227255a907/docs/roadmap/KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md), which keeps Screen Sharing on or off, allowed users, Handoff, Universal Clipboard and Universal Control.

macOS Screen Sharing has no per-interface setting: launchd holds its socket on every address, IPv4 and IPv6, whenever the service is enabled. With the application firewall off, anyone on a shared network can reach port 5900 and try the account password. The person's two Macs are `terra` (MacBook, `laptop` profile, Tailscale through the Homebrew `tailscaled` daemon) and `sol` (Mac Studio, `studio` profile, Tailscale.app). The manual steps and the current advice to turn Screen Sharing off on shared networks are in the chezmoi source's macOS workstation guide, "Remote access" section.

## Boundary

- **In:** a new `firewall` resource kind with a built-in `macos-pf` provider; declaration validation; read-only observation in `rig status` and `rig doctor`; `rig apply --sudo` install and repair; catalogue-scoped retirement under [ADR-KI-TOOL-RIG-008](../decisions/ADR-KI-TOOL-RIG-008-catalogue-scoped-resource-retirement.md); `rig show` and `rig explain` presentation; specification, guide, help, manual, changelog and test alignment.
- **Out:** turning Screen Sharing on or off and choosing its users ([KI-TOOL-RIG-CORE-046](https://github.com/knowledgeislands/tools-rig/blob/5d7af1c5101d19438aff80973b483c227255a907/docs/roadmap/KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md)); SSH server settings, keys and port 22, which this record never filters; the macOS application firewall (`socketfilterfw`), which Rig neither enables nor reads as part of this resource; installing or configuring Tailscale; arbitrary CIDR allow-lists, outbound rules, NAT or general firewall management; editing `/etc/pf.conf` or Apple's `/etc/pf.anchors/com.apple`; any personal declaration, which belongs to the person's Rig configuration in the chezmoi source.
- **Linux, explicit non-goal for this record.** No Linux profile exists yet. The declaration below is provider-neutral, so a later record can add a `linux-nftables` (or `ufw`) provider that filters on `tailscale0` without changing the schema. On Linux, a selected `macos-pf` declaration is refused by the existing resource-platform rule.

## Current state

Evidence gathered read-only on 2026-10-13 (`sol` was still on macOS 26.5.2, build 25F84, before its macOS 27 upgrade; `terra` is on macOS 27.0, build 26A428). Both machines agree on every point below.

- **`/etc/pf.conf` is Apple's default** on both, unchanged between 26 and 27: it declares `anchor "com.apple/*"` and loads `/etc/pf.anchors/com.apple`, which defines only `200.AirDrop/*` and `250.ApplicationFirewall/*`. `/etc/pf.anchors` holds only `com.apple`. Any child anchor loaded as `com.apple/<name>` is therefore evaluated without editing a system file.
- **pf loads but is not enabled at boot.** `com.apple.pfctl` runs `pfctl -f /etc/pf.conf` at load (last exit 0 on `terra`) and never `-E`; the file's own comment says each component must enable pf by reference with `-E`/`-X`.
- **pf state needs root.** `pfctl -s info` and `pfctl -sr` both fail with "/dev/pf: Permission denied" for the user, so an unprivileged `rig doctor` cannot see loaded rules.
- **Application firewall is off** on both ("Firewall is disabled. (State = 0)", stealth mode off).
- **Screen Sharing exposure.** `netstat` shows `*.5900` listening on tcp4 and tcp6 on both machines, owned by `launchd:1`, while `system/com.apple.screensharing` is "not running" (socket-activated). SSH `*.22` likewise listens on all addresses. No UDP 5900 or 3283 listener was present at observation time.
- **Rig's listener source cannot see it.** The [RIG-ORCH-031](../specs/orchestration.md) snapshot uses unprivileged `lsof -iTCP -sTCP:LISTEN`, which returns nothing for the launchd-owned 5900 socket; unprivileged `netstat -anv -p tcp` does report it with owner `launchd:1`.
- **Tailscale interface names are unstable.** `sol` carries its tailnet address `100.90.130.74` and `fd7a:115c:a1e0::b636:824c` on `utun8`; `terra` carries `100.96.126.29` on `utun2`. Each has ten or more other `utun` interfaces (iCloud Private Relay and, on `sol`, a NordVPN helper), so no interface name can be declared.
- **Other pf users.** `sol` has a NordVPN privileged helper (`com.nordvpn.macos.helper`). VPN clients may load their own pf rules for kill-switch or LAN features.
- **Rig has no system-domain resource yet.** Existing launchd resources live in `gui/<uid>`; the only administrator path is [RIG-ORCH-043](../specs/orchestration.md)'s attended `apply --sudo` grant, which the software-removal adapter consumes through `sudo -n`.

## Steps

- [x] After Kris approves this plan, re-read authority and source, establish the immutable implementation baseline through `ki-implement`, and keep the agreed boundary. Stop for review if source drift changes the resource, sudo or retirement assumptions below.
- [x] Register `firewall` as a setup declaration and add the `macos-pf` built-in provider. Validate the shape in [Proposed contract](#proposed-contract-for-owner-review): required text fields, `provider = "macos-pf"`, `platforms = ["macos"]`, a reverse-DNS `locator`, non-empty unique `ports` of the form `tcp:N` or `udp:N` with N in 1–65535, `allow = ["tailnet"]` as the only accepted value, and the shared `requires`, `depends-on` and `profiles` fields. Reject `tcp:22` and `udp:22`. Add locator uniqueness and a native-target conflict for two selected firewall declarations naming the same protocol and port (extend [RIG-ORCH-027](../specs/orchestration.md)).
- [x] Render deterministically from the declaration, never from a template the person supplies: the anchor rule file and a system LaunchDaemon property list, each opening with the existing "Managed by rig" ownership comment. The anchor passes the declared ports on `lo0` and between tailnet addresses (source and destination both in `100.64.0.0/10`, or both in `fd7a:115c:a1e0::/48`), then blocks the declared ports from anywhere else. Every rendered rule names a declared port; there is no rule without a port match and no outbound rule.
- [x] Observe without privilege: rendered and on-disk anchor file and daemon property list compared byte for byte; `launchctl print system/LOCATOR` for load state and last exit code; and a new fixed read-only `netstat -an` listener source (injectable as `RIG_NETSTAT_COMMAND`) for whether each declared port is listening on all addresses. Report `present`, `missing`, `drifted`, or `unavailable` per [RIG-STATE-021](../specs/state.md), with the drift reasons in [Proposed contract](#proposed-contract-for-owner-review). Read-only commands never call `sudo` or `pfctl`.
- [x] Apply only under `rig apply --sudo`, through the existing attended grant with `sudo -n`; without the grant, or in an unattended run, report the resource `incomplete` with `administrator-grant-required` and touch nothing. Order: validate the rendered anchor with `pfctl -n -f FILE`; install the anchor file and property list root-owned `0644`; `launchctl bootstrap system` (bootout first when replacing, using the existing release wait); load and enable with `pfctl -E -a com.apple/LOCATOR -f FILE`; re-read the loaded anchor with `pfctl -a com.apple/LOCATOR -s rules` and fail unless it matches the rendered rules. A correct, loaded resource is a no-op. Never write `/etc/pf.conf`, never call `socketfilterfw`, never flush any anchor but Rig's own.
- [x] Retire under ADR-KI-TOOL-RIG-008 when the catalogue no longer declares the locator: `launchctl bootout system/LOCATOR`, `pfctl -a com.apple/LOCATOR -F all`, then remove the property list and anchor file. Do not disable pf with `-X`: pf stays enabled with Apple's default anchors only until the next restart, which filters nothing. Profile deselection alone does not retire, as for every resource.
- [x] Extend `sudo` need detection in `rig_sudo_start` so a firewall that needs work counts, and a satisfied one does not prompt. Dry-run prints the rendered rules, files and commands with no `sudo`, `pfctl`, `launchctl` or file write.
- [x] Add `rig show firewall:ID` and `rig explain` text and JSON, listing ports, the allowed sources it expands to, locator, file paths and the observed state.
- [x] Add isolated public-command Bats coverage in `tests/rig-firewall.bats` with stubbed `sudo`, `pfctl`, `launchctl` and `netstat`, and the system paths redirected into the test tree by an override the isolation helper sets (`RIG_SYSTEM_ROOT`, defaulting to `/`), so no test can reach `/Library/LaunchDaemons` or `/etc`. Cover every case in [Verify](#verify).
- [x] Align specifications, guides, help, manual and the active changelog; assemble `bin/rig`; run the permitted offline gate and assemble an honest review packet. The live acceptance checks below remain outside the delivery grant and are reported as withheld.

## Files touched

Planning changes this record, [KI-TOOL-RIG-CORE-046](https://github.com/knowledgeislands/tools-rig/blob/5d7af1c5101d19438aff80973b483c227255a907/docs/roadmap/KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md) and [the issue ledger](_ISSUES.md) only. Expected delivery scope:

- [Declarations](../../src/rig/05-declarations.bash), [runtime help](../../src/rig/00-runtime.bash), [configuration](../../src/rig/10-configuration.bash), [orchestration](../../src/rig/20-orchestration.bash), [observation](../../src/rig/22-observation.bash), [application](../../src/rig/23-application.bash), [sudo session](../../src/rig/28-sudo-session.bash), [commands](../../src/rig/30-commands.bash), a new `src/rig/2N-firewall.bash` module, and the assembled [executable](../../bin/rig).
- New `tests/rig-firewall.bats`; [isolation helper](../../tests/helpers/isolate.bash) (system-root redirect and `sudo`/`pfctl`/`netstat` stubs); [sudo-session tests](../../tests/rig-sudo-session.bats), [profile-authority tests](../../tests/rig-profile-authority.bats) and [command-surface tests](../../tests/rig-cli-surface.bats) where shared behaviour changes.
- [Configuration](../specs/configuration.md), [orchestration](../specs/orchestration.md) and [state](../specs/state.md) specifications; [operational resources](../guides/user/operational-resources.md) and [commands](../guides/user/commands.md) guides; [README](../../README.md); [manual](../../man/rig.1); [changelog](../../CHANGELOG.md).

## Verify

Every test calls `rig_test_isolate` first and asserts on stub argument logs, never on the real machine.

- **Validation:** missing fields, wrong provider or platform, malformed or duplicate ports, `tcp:22`, `udp:22`, any `allow` other than `["tailnet"]`, and a duplicate locator each fail before any native invocation. Two profiles may hold conflicting declarations; one composed profile selecting both fails.
- **Rendering:** the anchor for `["tcp:5900", "udp:5900"]` matches a golden file exactly; every rule names port 5900; no rule names 22 or carries no port; IPv4 and IPv6 tailnet ranges appear on both source and destination; the property list runs `/sbin/pfctl` with literal argv, `RunAtLoad`, and `WatchPaths` on `/etc/pf.conf`.
- **Read-only boundary:** `status`, `doctor`, `show`, `explain` and `apply --dry-run` log no `sudo`, `pfctl`, `launchctl bootstrap|bootout` or file write under the redirected system root, with or without a cached grant.
- **Observation:** files and loaded daemon with last exit 0 are `present`; absent files `missing`; edited anchor or property list, unloaded daemon or non-zero last exit `drifted`; a declared port listening on all addresses while the restriction is missing or drifted adds `exposed-beyond-tailnet`; a present restriction with an all-addresses listener is healthy with the note that kernel rules are unverified without administrator rights; `netstat` failure or Linux reports `unavailable`.
- **Apply:** with a grant, the exact ordered argv (`pfctl -n`, install, bootstrap, `pfctl -E -a … -f`, `pfctl -a … -s rules`) runs once; a second apply is a no-op; a `pfctl -n` failure installs nothing; a reread mismatch is a failure; without `--sudo` the resource is `incomplete` with `administrator-grant-required` and no native call; a refused grant dispatches nothing ([RIG-ORCH-043](../specs/orchestration.md)). `/etc/pf.conf` and `socketfilterfw` never appear in any log.
- **Retirement:** deleting the declaration retires exactly the receipted locator in the order above and leaves pf enabled; deselecting the profile retires nothing; a failed retirement keeps the receipt row.

Run focused fixtures with stdin closed:

```sh
bats tests/rig-firewall.bats tests/rig-sudo-session.bats tests/rig-profile-authority.bats tests/rig-cli-surface.bats </dev/null
```

Then run [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository), including a hostile inherited `XDG_STATE_HOME` run because the isolation helper changes. Do not run native-provider smoke against live pf.

**Live acceptance, withheld from the delivery grant.** After review, and only with Kris's separate approval at the machine, Kris, or an attended session Kris directs, applies the personal declaration on `terra` first, then `sol` on macOS 27, and checks: SSH over the tailnet still connects; `vnc://` over the tailnet still connects; Screen Sharing on the LAN address from another device is refused; `sudo pfctl -a com.apple/LOCATOR -s rules` survives a restart; turning NordVPN on and off on `sol` leaves the anchor loaded. Record any failure as a follow-up rather than widening this record.

## Dependencies / blocks

`blocks: []` and `blocked_by: []`. Delivery needs no machine, profile or chezmoi change. The personal `[firewall.*]` declaration and the chezmoi guide's pointer move to this record belong to the chezmoi source after delivery. [KI-TOOL-RIG-CORE-046](https://github.com/knowledgeislands/tools-rig/blob/5d7af1c5101d19438aff80973b483c227255a907/docs/roadmap/KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md) is independent: either can land first.

## Documentation impact

### Decision Records

Propose one ADR at delivery, `ADR-KI-TOOL-RIG-009` (system-domain resources under an attended grant): Rig's first resource that writes outside the user's home and needs root, why it uses a `com.apple/` child anchor and a Rig-owned LaunchDaemon rather than editing `/etc/pf.conf`, and why read-only commands accept unprivileged evidence. [ADR-KI-TOOL-RIG-006](../decisions/ADR-KI-TOOL-RIG-006-declarative-operational-resources.md) and ADR-KI-TOOL-RIG-008 stay unchanged.

### Specifications

Add a configuration requirement for firewall declarations after RIG-CONF-029; extend RIG-ORCH-023 (built-in macOS adapters) with `macos-pf` and its never-touch list, RIG-ORCH-027 with the protocol-and-port conflict, and RIG-ORCH-043 so a firewall counts as grant-needing work; add a state requirement for firewall observation, drift reasons and the unprivileged-evidence limit, and extend RIG-STATE-043 with `administrator-grant-required`. Leave RIG-ORCH-031's `lsof` port snapshot unchanged; the `netstat` source is firewall-only. Record conformance truthfully until delivered.

### Guides

Add "Restrict a listener to the tailnet" to [operational resources](../guides/user/operational-resources.md): a synthetic declaration, what Rig installs and where, that it needs `apply --sudo`, what doctor can and cannot see, how persistence works, and an emergency rollback that needs no Rig (`sudo pfctl -a com.apple/LOCATOR -F all` and `sudo launchctl bootout system/LOCATOR`), stated before the apply step. Update [commands](../guides/user/commands.md), help, the manual and the changelog for the new kind. The chezmoi macOS workstation guide is owned elsewhere; its "Remote access" pointer is a follow-up for that thread.

### Roadmap

Kris approved adoption in Decision 48 and this plan in Decision 49, so this record is Deliver / ready at Next.

## Review

### Delivered

Delivered within the approved boundary from baseline `39499cd6566b2fa02f9c66476eda53f052ccb351`, using fixtures only. Rig now accepts a `[firewall.ID]` declaration with the built-in `macos-pf` provider. It renders a `com.apple/LOCATOR` child anchor and a system LaunchDaemon, observes them without privilege, applies and retires them only under `apply --sudo`, and leaves `/etc/pf.conf`, the application firewall and other anchors alone. Proposed [ADR-KI-TOOL-RIG-009](../decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) records the system-domain decision.

Excluded, as the approval requires: no personal declaration, no `rig apply` on `terra` or `sol`, no live pf, `sudo` or `launchctl` operation, and no acceptance, pruning or release. The live acceptance checks in [Verify](#verify) are withheld for Kris's separate approval.

### Change Summary

- **New module** `src/rig/29-firewall.bash`: validation, rendering, unprivileged observation, preflight, apply, retirement, dry-run projection and explanation. Assembled into `bin/rig` after `29-default-applications.bash`.
- **Registry and configuration** (`05-declarations.bash`, `10-configuration.bash`): the `firewall` setup kind, its fields, profile `firewalls`, membership and dependency references, the `macos-pf` built-in adapter, and a native-target conflict on a shared protocol and port.
- **Orchestration, receipts and apply** (`20-orchestration.bash`, `21-provider-state.bash`, `23-application.bash`): capability, preflight, observation, apply, projection and retirement dispatch; a firewall needing work without a grant is `skipped` with `administrator-grant-required` and keeps the run incomplete.
- **Sudo session** (`28-sudo-session.bash`): a firewall counts as grant-needing work only when its observation is not present; `RIG_SUDO_GRANTED` marks a live grant.
- **Commands** (`30-commands.bash`, `00-runtime.bash`): show tables with a ports column, item explanation, JSON, doctor counts and help text.
- **Tests**: new `tests/rig-firewall.bats` (10 tests); `tests/helpers/isolate.bash` now roots `RIG_SYSTEM_ROOT` in the test tree and refuses `pfctl` and `netstat` by default; a new isolation guard in `tests/rig.bats`.
- **Documentation**: specifications (new RIG-CONF-030 and RIG-STATE-045; RIG-CONF-008, RIG-ORCH-023, RIG-ORCH-027, RIG-ORCH-043 and RIG-STATE-043 extended), the operational-resources, commands and getting-started guides, README, manual, changelog, and the proposed ADR with its index entry.

Deviations and interpretations for review:

- **RIG-CONF-030, not 029.** The plan named RIG-CONF-029, which default applications already hold.
- **`com.apple.*` locators rejected.** Added so a declaration cannot collide with Apple's own labels or anchors.
- **`rig explain` is `rig show firewall:ID`.** Rig has no `explain` command; the item explanation in text and JSON carries the ports, allowed sources, anchor, files and observed state.
- **Linux.** Selection already refuses a macOS-only resource on Linux (status exits 2), as the Boundary requires; observation reports `unavailable` only defensively if reached.
- **Grant and reread.** When a grant exists for other work, a present firewall's loaded rules are reread and reloaded on mismatch. A fully satisfied selection still prompts for nothing.
- **Observation dispatch** lives in `20-orchestration.bash`, so `22-observation.bash` was not changed.

### Verification

All commands were run locally on 14 October 2026 with stdin closed. No live `sudo`, `pfctl`, `launchctl` load or unload, or Rig apply was run.

- Focused set, `bats tests/rig-firewall.bats tests/rig-sudo-session.bats tests/rig-profile-authority.bats tests/rig-cli-surface.bats </dev/null`: 33 of 33 passed.
- Complete gate from [Develop Rig](../guides/developer/README.md#verify-the-repository):
  - `ki repo audit --repo .`: no failures. One existing warning (HOOK-1, no committed pre-commit gate) is unrelated.
  - `shellcheck` and `bash -n` on every listed script: clean.
  - `scripts/assemble-rig --check`: current.
  - `scripts/benchmark-rig`: all within budget (status 6 s of 8 s).
  - `scripts/smoke-native-providers`: read-only version probes only, all passed. It never touches pf.
  - `bats tests/ </dev/null`: 528 of 528 passed.
  - `mandoc -T lint man/rig.1`: clean.
  - `git diff --check`: clean.
- Hostile isolation run, `XDG_STATE_HOME` and `XDG_CONFIG_HOME` pointed at outside directories: 528 of 528 passed, and the hostile state directory stayed empty.
- `tests/rig-firewall.bats` covers every Verify case except live acceptance. Its sudo fixture refuses any install or removal outside `RIG_SYSTEM_ROOT`, and every test asserts that no log names `/etc/pf.conf`, `socketfilterfw`, `pfctl -d` or `-X`.

#### Live read-only evidence, 19 October 2026

The ways-of-working rig-live run gathered this on `sol` and, over the tailnet by SSH, on `terra`, under RIG-UPGRADE-MACHINES a) and RIG-FIREWALL-RANGE a). Both Macs run `rig 0.7.0+dev`, the tools-rig checkout at `424727c` linked as `~/.local/bin/rig`, on macOS 27.0.1. Nothing ran but `rig show`, `rig status`, `rig doctor`, `rig apply --dry-run` and unprivileged system queries; no apply, `sudo`, `pfctl` or `launchctl` change.

- **No personal declaration.** Neither Mac's Rig configuration declares a `[firewall.*]`, and the chezmoi source has never held one.
- **`terra` already carries the restriction, outside Rig's records.** `/etc/pf.anchors/uk.me.kris.rig.firewall.screen-sharing` and its LaunchDaemon property list, root-owned `0644`, date from 14 October 2026 08:49, after the delivery commit `7544d3d`. Rig's state directory holds no receipt for them. `launchctl print system/uk.me.kris.rig.firewall.screen-sharing` shows `/sbin/pfctl -E`, `RunAtLoad`, `WatchPaths` on `/etc/pf.conf`, one run since the 15 October 10:25 restart, and last exit 0. With the [Proposed contract](#proposed-contract-for-owner-review) declaration added to a throwaway copy of the configuration, `rig status` and `rig show` report it `present (kernel-rules-unverified)`: the installed files match the current renderer byte for byte. The live anchor is the range rule the [Range correction](#range-correction) describes, `from 100.64.0.0/10 to 100.64.0.0/10` and the IPv6 equivalent, so the residual `100.64.0.0/10` exposure applies to `terra` today.
- **`sol` is open.** No Rig anchor or daemon; `*.5900` listens on tcp4 and tcp6 and the application firewall is off. The same throwaway declaration reports `missing (exposed-beyond-tailnet)` in status and doctor, as the contract requires.
- **Read-only boundary held.** The firewall dry-run on both Macs printed the eight rendered rules and the six `sudo -n` commands (`pfctl -n`, two installs, `launchctl bootstrap system`, `pfctl -E -a`, `pfctl -a … -s rules`) without running them. On `terra` it plans a reconcile although the resource is `present`, because only an attended grant can reread the loaded rules. `/etc/pf.conf` is still Apple's default on both, identical by checksum.
- **SSH over the tailnet works** from `sol` to `terra` (`100.90.130.74` to `100.96.126.29`) with the restriction installed on `terra`; port 22 is not in the anchor.

Not proved, because each needs a privileged read or a live change: the loaded kernel rules (`sudo pfctl -a com.apple/LOCATOR -s rules`) on `terra`, before or after a restart; `vnc://` over the tailnet; Screen Sharing refused on a LAN address from another device; NordVPN on and off on `sol`; and any `rig apply --sudo`. Live acceptance stays outstanding.

#### Attended rollback rehearsal on `terra`, 19 October 2026

Kris ran the rehearsal at the machine from 22:03 to 22:06 BST, under RIG-FIREWALL-REHEARSE a) and RIG-FIREWALL-RUN a) in the chezmoi work's decisions log. Terminal A was `ssh -t terra` from `sol`, and stayed open throughout. Terminal B was a plain shell on `sol` that opened a fresh SSH connection for each check. The sequence was reviewed blind before it ran. Every block wrote the locator out literally, used no shell variables, checked that it was on `terra` in an SSH session, and refused without changing anything if `terra` was not in the expected state. The removal step restored automatically after 300 seconds, or at once if the session dropped. Kris's output, verbatim:

```text
A0 (before): pf enabled: yes | daemon loaded: yes, last exit 0: yes
anchor rules: 8, match file: yes | parent calls anchor: yes
TOKENS: 546 pfctl 7339458489387109918 0 days 00:54:05
A0 RESULT: PROTECTED
B PASS 22:03:06: fresh SSH to terra, daemon loaded
A1: reload rc=0 | match file: yes | pf enabled: yes | parent calls anchor: yes | references 3 -> 3
A1 RESULT: RELOAD PROVEN
A2: REMOVED 22:04:26: anchor empty, daemon absent.
B PASS 22:04:59: fresh SSH to terra, daemon absent
RESTORING 22:05:17
bootstrap rc=0 | new run exit 0: yes | match file: yes | pf enabled: yes | parent calls anchor: yes | references 3 -> 4
A2 RESULT: RESTORED
B PASS 22:05:40: fresh SSH to terra, daemon loaded
A0 (after): pf enabled: yes | daemon loaded: yes, last exit 0: yes
anchor rules: 8, match file: yes | parent calls anchor: yes
TOKENS: 14331 pfctl 4286484510776417438 0 days 00:00:45; 546 pfctl 7339458489387109918 0 days 00:57:40
A0 RESULT: PROTECTED
```

Each step proves the following:

- **A0, before and after: the loaded kernel rules.** `sudo pfctl -a com.apple/uk.me.kris.rig.firewall.screen-sharing -s rules` printed eight rules, identical apart from whitespace to `pfctl -nvf` of the anchor file. pf was enabled, and Apple's `anchor "com.apple/*"` in the main ruleset calls the child anchor. The LaunchDaemon was loaded with last exit 0.
- **Survival across a restart.** In the A0 before, the only enable reference belonged to `pfctl` pid 546. It was 54 minutes old, so it dated from `terra`'s 21:07 BST boot. The daemon's `RunAtLoad` had reloaded and enabled the anchor at boot without anyone touching it.
- **A1: a reload changes nothing.** Reloading the same file without `-E` exited 0. The rules still matched and the reference count stayed the same.
- **A2: the emergency rollback leaves SSH working.** `launchctl bootout system/LOCATOR` followed by a flush of the anchor's rules left the anchor empty and the daemon absent, and a fresh SSH connection from `sol` succeeded at 22:04:59. The flush was `-F rules`. Rig's retirement path uses `-F all` on the same anchor.
- **A2: the restore works.** `launchctl bootstrap system /Library/LaunchDaemons/LOCATOR.plist` exited 0 and the daemon's new run exited 0. The eight rules matched the file again, pf stayed enabled and the parent anchor still called the child. The bootstrap's `pfctl -E` added an enable reference (3 → 4 lines; pid 14331 beside pid 546), and pf has no way to release the earlier one. That is harmless, and it is consistent with Rig never disabling pf. Fresh SSH succeeded again at 22:05:40.

**First attempt, 21:07 BST.** An earlier hand-run sequence set the locator in a shell variable `L`, which then expanded in a block pasted separately. In the shell that ran `sudo launchctl bootout system/$L`, `L` was empty. The command became `launchctl bootout system/`, which boots out the whole system domain, and `terra` shut down (launchd logged `bootout initiated by: launchctl … slaying domain … committing to system shutdown`). The flush never ran. pf, the anchor and the restore path played no part, and `terra` came back with the restriction loaded, as the restart evidence above shows. The hazard lay only in the hand-run sequence, which is why the rehearsal above writes the locator literally. Rig's own firewall path is not exposed to it: `rig_firewall_locator_valid` rejects an empty locator, both at validation and in retirement preflight, and Rig runs bootout only after `launchctl print system/LOCATOR` reports the service loaded.

Still not proved: Screen Sharing reachability over the tailnet, and refusal on a LAN address with fresh flows (existing pf states survive a flush, so these need new connections); NordVPN on and off on `sol`; the real `pfctl -s rules` text against Rig's own normalisation, which the rehearsal compared with `pfctl -nvf` and not through Rig; and any `rig apply --sudo`. `sol` has no restriction installed and needs its own attended rehearsal before its `rig apply --sudo`.

#### Read-only preflight on `sol`, 19 October 2026

The chezmoi work's sol-preflight runs read `sol` without root under SOL-FIREWALL a), and Kris ran one read-only root check at about 22:26 BST under SOL-PF-ROOT. `/etc/pf.conf`, `/etc/pf.anchors/com.apple` and the `com.apple.pfctl` boot job are Apple's stock files. No LaunchDaemon calls `pfctl`, and pf is disabled with no enable references. The one other pf user is NordVPN's privileged helper, `com.nordvpn.macos.helper`, which has run since boot. Its strings carry a complete root ruleset. That ruleset replaces Apple's main ruleset, reloads `/etc/pf.conf` as a sub-anchor, blocks by default and can NAT `100.64.0.0/10`.

The root check printed:

```text
== root rules: scrub-anchor "com.apple/*" all fragment reassemble | anchor "com.apple/*" all
== root nat/rdr: nat-anchor "com.apple/*" all | rdr-anchor "com.apple/*" all
== root dummynet: dummynet-anchor "com.apple/*" all
== root anchors: NordVPN, com.apple
== com.apple anchors: com.apple/200.AirDrop, com.apple/250.ApplicationFirewall
```

Root holds Apple's boot ruleset, which calls only `com.apple/*`. The helper has loaded a root-level `NordVPN` anchor since boot, but no root rule calls it, so pf does not evaluate it. Enabling pf now turns on only Apple's empty anchors and this record's anchor. `sol`'s attended sequence refuses unless that is still so, and unless NordVPN is neither running nor connected, immediately before `rig apply --sudo`. Afterwards it checks that root still calls `com.apple/*` and lists the Rig anchor beneath it.

**Follow-up, not delivered here: NordVPN bypasses the anchor.** When NordVPN connects, its helper replaces root's main ruleset with its own. That ruleset does not call `com.apple/*`, so the Rig anchor stays loaded but is never evaluated, and Screen Sharing is exposed beyond the tailnet for as long as the connection lasts. Under its block-by-default rules, tailnet SSH and Tailscale may also depend on what NordVPN passes. The daemon's `WatchPaths` on `/etc/pf.conf` does not fire, because the helper loads its ruleset without editing that file. `apply --sudo` and the attended post-apply check see the bypass only while it lasts; unprivileged doctor cannot see it at all. Deciding how Rig detects or survives a replaced root ruleset, whether by a periodic re-assertion (FW-PERSIST's alternative), a check of root's calls, or a NordVPN-side setting, needs its own record. That record should start from the live NordVPN on-and-off check above, which is still outstanding. [KI-TOOL-RIG-CORE-068](KI-TOOL-RIG-CORE-068-replaced-pf-root-ruleset-bypass.md) is that record, captured on 19 October 2026 under TERRA-NORDVPN a).

#### Attended apply on `sol`, 19 October 2026

Kris applied `[firewall.screen-sharing-tailnet]` to `sol` at its own console from 22:50 to 23:06 BST, running the chezmoi work's sol-apply sequence block by block. Terminal S was a plain shell on `sol`; terminal T was `ssh -A -t terra` from `sol`, and each T run opened a fresh SSH connection and fresh port probes. Kris pasted this evidence:

- **S1, declaration.** The rendered `55-ports.toml` matched the reviewed SHA-256 `7331ebae…67c2` and was applied alone, and `rig apply --dry-run` planned the firewall.
- **T before the apply.** SSH passed, daemon absent. Tailnet 5900 answered (`RFB 003.889`). LAN `192.168.1.37` 5900 answered and LAN 22 was open.
- **S2, pre-apply gate: READY.** pf was disabled, the root `NordVPN` anchor was empty and uncalled, Apple's `200.AirDrop` and `250.ApplicationFirewall` anchors held 0 rules, and no VPN was active.
- **S3, apply.** `rig apply --sudo --target firewall:screen-sharing-tailnet` reported completed=1, failed=0.
- **S4, post-apply check: PROTECTED.** Every field was yes. The anchor held 8 rules matching the file, and both enable references belonged to `pfctl`.
- **T after the apply.** SSH passed, daemon loaded. Tailnet 5900 answered; LAN 5900 was blocked and LAN 22 stayed open.
- **U, undo rehearsal: UNDONE.** The daemon was booted out, the anchor's rules went to 0, both files moved to `/var/root/rig-firewall-undo/20261019T225608/`, and pf was disabled. T afterwards matched T before the apply.
- **Re-apply.** The gate first refused with `the Rig anchor is already loaded`; see the first follow-up below. With the gate corrected, the re-apply completed=1, failed=0, S4 was PROTECTED again, and T matched T after the first apply.
- **R, Rig's view.** `rig doctor` reported findings=3, the same three as before the apply (utm through mas, the `default-application.toml` handler drift and the historical TOML-handler failure), with no firewall finding. The R block as written hung; see the second follow-up below. A plain `rig doctor` completed.
- **V, end to end.** From `terra`, Finder's Connect to Server opened `vnc://100.90.130.74`.

This proves on `sol` what the `terra` rehearsal left open: `rig apply --sudo` itself, twice; Rig's reread of the loaded rules against real `pfctl -s rules` output, since apply completes only when the reread matches the rendered anchor; Screen Sharing over the tailnet, both by its RFB greeting and by `vnc://`; refusal on the LAN address with fresh flows while LAN SSH stays open; and the full undo back to the state before the apply, including `pfctl -d` when only `pfctl` holds enable references. NordVPN was off throughout, so its bypass above is still unproved either way.

**Follow-up, not delivered here: a pre-apply gate must test the Rig anchor's contents.** After the undo flushed the anchor with `-F rules`, and even after `-F all` left it with 0 rules, nat, tables and sub-anchors, macOS kept the empty `com.apple/uk.me.kris.rig.firewall.screen-sharing` listed under `com.apple`, exactly as it keeps the empty AirDrop and ApplicationFirewall anchors. A name stays listed until a restart, so a gate that refuses on the name refuses every re-apply after an undo. The sequence's S2 and S3 gate was corrected at the console to refuse only if the Rig anchor holds rules, nat, tables or anchors. Rig's own apply path does not test anchor names, so only attended sequences are affected; any future gate or runbook should test contents.

**Follow-up, not delivered here: never hide stderr from an attended `rig doctor`.** The R block discarded stderr and filtered stdout, so a prompt Rig wrote was invisible and the block appeared to hang. An attended check runs `rig doctor` with stderr visible, and filters only a copy of stdout if it filters at all.

**Follow-up, not delivered here: NordVPN on `terra`.** `terra`'s interaction with NordVPN is still open. A separate read-only run checked it and found the same bypass from the helper's template, and [KI-TOOL-RIG-CORE-068](KI-TOOL-RIG-CORE-068-replaced-pf-root-ruleset-bypass.md) now owns detecting it.

### Outstanding concerns

- Live acceptance is run on `sol` apart from NordVPN. The `terra` rehearsal proved the loaded kernel rules, their survival across a restart and the no-Rig rollback and restore; the [attended apply on `sol`](#attended-apply-on-sol-19-october-2026) proved `rig apply --sudo`, Rig's reread against real `pfctl` output, `vnc://` over the tailnet, LAN refusal with fresh flows and the undo. Still outstanding are NordVPN on and off on either Mac, and `rig apply --sudo` on `terra`, whose restriction predates Rig's records.
- Two lessons from the `sol` apply for attended sequences, recorded in that section: a gate tests the Rig anchor's contents, not its listed name, and an attended `rig doctor` never hides stderr.
- A NordVPN connection on `sol` replaces root's pf ruleset and bypasses the anchor; see [Read-only preflight on `sol`](#read-only-preflight-on-sol-19-october-2026). [KI-TOOL-RIG-CORE-068](KI-TOOL-RIG-CORE-068-replaced-pf-root-ruleset-bypass.md) owns detecting it.
- The address match is range-based, so a neighbour on a carrier-grade NAT or hotspot network that gives the Mac a `100.64.0.0/10` address can reach the declared port; see [Range correction](#range-correction).
- If a future macOS drops Apple's `com.apple/*` anchor point, the anchor stops being evaluated and only `apply --sudo` notices. This residual risk is recorded in the ADR.
- `rig show ITEM --format json` uses the existing generic label converter, which splits raw `key=value` lines such as `port=tcp:5900` at the colon. This is pre-existing behaviour shared by every resource kind, and was left unchanged as outside this record.

### Post-change review

The goal is met in code: a declared listener port can be restricted to loopback and the tailnet with Rig-owned files only, and the adapter never names `/etc/pf.conf` or `socketfilterfw` in any test log. Scope held to the record's files, apart from the module numbering and the unchanged `22-observation.bash`. Regression risk is concentrated in two shared paths: the sudo-need rule and the apply loop's new grant branch. Both are covered by the full suite, including the existing sudo-session tests. Acceptance readiness: ready for code review now; ready for live acceptance only after Kris approves it and the personal declaration exists in the chezmoi source.

### Mini recap

Built the `macos-pf` firewall resource with fixture-only proof: validation, golden rendering, the read-only boundary, every observation state, the exact apply argv, no-op, parse and reread failures, grant refusal and retirement order. Proposed learning route: none automatically. If live acceptance shows `pfctl` displays rules differently from the fixture, adjust the normalisation in a follow-up record rather than widening this one.

## Discussion

### Proposed contract for owner review

```toml
[firewall.screen-sharing-tailnet]
name = "Screen Sharing on the tailnet only"
purpose = "Keep remote screen sessions off shared networks"
rationale = "Screen Sharing listens on every address and macOS cannot bind it to one interface"
provider = "macos-pf"
locator = "uk.me.kris.rig.firewall.screen-sharing"
platforms = ["macos"]
ports = ["tcp:5900", "udp:5900"]
allow = ["tailnet"]
profiles = ["studio"]
```

- **Match by address, not interface.** `tailnet` expands to Tailscale's fixed ranges, `100.64.0.0/10` and `fd7a:115c:a1e0::/48`, required on both source and destination. The `utunN` name differs per machine and per boot (evidence above). As planned, this sentence said that requiring the destination to be the machine's own tailnet address closes the gap where a device on the local network holds a `100.64.0.0/10` address. The delivered rule requires only that the destination is in the tailnet range, so it closes that gap only while the Mac's own local-network address is outside the range; see [Range correction](#range-correction). Loopback is always allowed. Arbitrary CIDRs are deliberately not accepted.
- **Persistence.** The anchor file lives at `/etc/pf.anchors/LOCATOR` and the daemon at `/Library/LaunchDaemons/LOCATOR.plist`; both are third-party files that macOS updates leave in place. The daemon runs `pfctl -E -a com.apple/LOCATOR -f /etc/pf.anchors/LOCATOR` at every boot and again whenever `/etc/pf.conf` changes, so an update that restores `/etc/pf.conf` re-triggers the load. Because Rig never edits `/etc/pf.conf`, an update resetting it removes nothing Rig owns.
- **Doctor's view.** Without root, doctor sees the files, the daemon and its last exit code, and whether the port listens on all addresses. It cannot see the kernel rules; it says so rather than claiming they are loaded. `apply --sudo` verifies the loaded rules every run.
- **Drift reasons.** `anchor-missing`, `anchor-changed`, `daemon-missing`, `daemon-changed`, `daemon-not-loaded`, `daemon-last-exit:N`, plus `exposed-beyond-tailnet` when a declared port listens on all addresses and the restriction is not `present`.
- **Why port 5900 UDP too.** Apple lists Screen Sharing on TCP and UDP 5900, and the high-performance mode uses UDP. Remote Management (3283) is not enabled on either Mac and is not declared.

### Risks

- **Locking Kris out.** SSH is the recovery path. The anchor only ever names declared ports, port 22 is rejected at validation, no default-block rule exists, and `pfctl -n` parses before load. Live acceptance runs on `terra` first with physical access, and the guide puts the no-Rig rollback before the apply step. A pf mistake can still block Screen Sharing over the tailnet; SSH remains open to undo it.
- **Tailscale interface naming.** Avoided by matching addresses; tested by the golden anchor containing no interface but `lo0`.
- **macOS updates resetting `/etc/pf.conf`.** Rig never depends on its content beyond Apple's own `anchor "com.apple/*"` line, which is present on 26.5.2 and 27.0. If a future macOS removed that line, the anchor would silently stop being evaluated; doctor cannot see this without root, so `apply --sudo` reread and the live restart check are the guard. Record as a residual risk.
- **Other pf users.** A VPN client (NordVPN on `sol`) may replace the main ruleset or flush anchors. The daemon's `WatchPaths` does not catch that. Covered by the live NordVPN check; a periodic re-assertion is the fallback if it fails (see FW-PERSIST).
- **pf left enabled.** Rig enables pf and does not disable it on retirement, so other components' references are never released by Rig. With only Apple's anchors loaded this filters nothing.
- **Range, not own address.** The rule matches Tailscale's whole ranges on source and destination, not the Mac's own tailnet address, and names no interface. See [Range correction](#range-correction) for the two residual exposures this leaves.
- **System-domain blast radius.** First Rig resource outside `$HOME`. Tests redirect every system path through `RIG_SYSTEM_ROOT` and stub every privileged command; [AGENTS.md](../../AGENTS.md) already forbids reproducing a destructive defect against the live machine.

### Decisions for Kris

- **FW-SHAPE.** Approve the `[firewall.ID]` kind, `macos-pf` provider, `protocol:port` list and `allow = ["tailnet"]` as the only source. Recommend yes: it is the smallest shape that solves Screen Sharing and leaves room for a Linux provider.
- **FW-MATCH.** Match tailnet addresses on source and destination, never an interface. Recommend yes, for the evidence above.
- **FW-PERSIST.** Use a Rig-owned LaunchDaemon loading a `com.apple/` child anchor at boot and on `/etc/pf.conf` change, never editing `/etc/pf.conf`. Recommend yes. Alternative: also re-assert every 15 minutes (`StartInterval`) to self-heal after a VPN client flushes pf, at the cost of a repeating root job; recommend adding it only if the NordVPN live check fails.
- **FW-DOCTOR.** Accept that unprivileged doctor reports files, daemon and listener exposure, and states kernel rules as unverified, instead of adding a privileged doctor. Recommend yes: doctor stays read-only and promptless.
- **FW-LINUX.** Linux is an explicit non-goal here, with the schema left open for a later provider once a Linux profile exists. Recommend yes. Kris later approved that provider as [KI-TOOL-RIG-CORE-051](https://github.com/knowledgeislands/tools-rig/blob/5d7af1c5101d19438aff80973b483c227255a907/docs/roadmap/KI-TOOL-RIG-CORE-051-linux-tailnet-only-firewall.md) (Decision 51).

### Approval boundary

Approving this plan moves the record to Ready and permits local, fixture-backed delivery through `ki-implement` only. It grants no personal declaration, no `rig apply` on any machine, no change on `sol` or `terra`, no live pf operation, and no acceptance, pruning or release. The live acceptance checks need their own approval.

### Adoption approval

Kris approved the split, adoption and planning to Ready in mac-studio-bootstrap Decision 48 (13 October 2026): "FIREWALL: B" - build the tailnet-only Screen Sharing firewall properly in Rig now, not by hand on `sol`. That adopted this record as Deliver / draft at Next under the Rig Initiative and authorised read-only evidence from `sol`. It grants no implementation.

### Plan approval

On 13 October 2026 Kris approved this plan as written (mac-studio-bootstrap Decision 49): "we can at least accept what has been suggested ... ironed out for getting on with it". The decisions are FW-PLAN approve; FW-SHAPE yes; FW-MATCH yes; FW-PERSIST yes, with no periodic re-load yet; FW-DOCTOR yes; FW-LINUX yes, for a later record. The record moves to `ready` at Next. The approval permits local, fixture-backed delivery through `ki-implement` to Awaiting review only; it grants no personal declaration, no `rig apply` on `terra` or `sol`, no live pf operation, and no acceptance, pruning or release.

### Independent review

The ways-of-working rig-review run reviewed this record on 18 October 2026, read-only and without having written it, at `92d2d27`, under TOOLS-BLOCKERS in the ways-of-working decisions log. The complete local gate passes there: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark and mandoc; all 572 Bats tests pass. `scripts/smoke-native-providers` was not run. The review does not accept the record; acceptance stays with Kris.

**Verdict: findings for Kris before acceptance.** One medium finding, three low. The rendered rules and the apply, observe and retire paths otherwise match the approved plan.

- **Medium: the destination rule is the tailnet range, not the machine's own tailnet address.** The anchor passes `from 100.64.0.0/10 to 100.64.0.0/10`. The Discussion says requiring "the destination to be the machine's own tailnet address" closes the gap where a local-network device holds a `100.64.0.0/10` address. It closes it only while the Mac's own LAN address is outside that range. On a carrier-grade NAT or hotspot network that gives the Mac itself a `100.64.0.0/10` address, a neighbour on the same network passes the rule and reaches port 5900. Either correct the Discussion, specification and ADR to state this residual risk, or capture a follow-up that narrows the destination, for example to a pf table of the machine's tailnet addresses refreshed at apply.
- **Low: no interface match, by approved design.** macOS accepts packets for any local address on any interface, so an on-link host can send a packet with a tailnet source to the Mac's tailnet address over the LAN and it passes. A TCP handshake cannot complete, because the reply routes into Tailscale, but one-way UDP to 5900 can arrive. Worth one sentence in the ADR's risks.
- **Low: the ADR is still proposed.** Accepting this record leaves [ADR-KI-TOOL-RIG-009](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) at `status: proposed`; Kris decides both together.
- **Low: real `pfctl -s rules` formatting is unproven.** As the record says, normalisation is tested only against a fixture; a mismatch fails apply safely after loading, so it costs a failed run, not an open port.

Confirmed sound: every rule is `quick`, names a declared port and is inbound only; loopback and both tailnet families pass before the block; port 22 and any `allow` other than `tailnet` are rejected; `com.apple.*` locators are refused; read-only commands call no `sudo` or `pfctl`; `pfctl -n` runs before anything is installed; retirement boots out, flushes only `com.apple/LOCATOR` and leaves pf enabled; a firewall counts as grant-needing work only when not present. Live acceptance on `terra` and `sol` stays withheld; the guide states the no-Rig rollback before the apply step, as the connection-critical rule needs.

### Range correction

Kris agreed RIG-FIREWALL-RANGE a) on 18 October 2026 (ways-of-working decisions log, "owner answers, Rig batch"): correct this record, its specification and [ADR-KI-TOOL-RIG-009](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) to state the residual risk honestly, and capture one follow-up to narrow the rule. The ways-of-working rig-fixes run made the correction; no code changed.

The anchor passes a declared port `from 100.64.0.0/10 to 100.64.0.0/10` (and the IPv6 equivalent) on any interface. That leaves two residual exposures:

- **A shared range.** Carrier-grade NAT and some hotspots assign local-network addresses from `100.64.0.0/10`. When the Mac's own local-network address falls in that range, a neighbour on the same network holding such an address passes the rule and reaches the declared port, Screen Sharing on TCP and UDP 5900 included. The account password is then the only barrier, as it is with no restriction at all.
- **No interface match.** macOS accepts a packet for any local address on any interface, so an on-link host can send a packet with a forged tailnet source to the Mac's tailnet address over the local network and it passes. A TCP handshake cannot complete, because the reply routes into Tailscale, but one-way UDP to 5900 can arrive.

Both are accepted residual risks of the delivered design, now stated in RIG-ORCH-023, the ADR and the operational-resources guide; the guide's earlier claim that such a device "cannot reach the port" was wrong. The same range rule applies to the `linux-nftables` provider. [KI-TOOL-RIG-CORE-062](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-062-own-address-firewall-destination.md) captures narrowing the destination to each Mac's own tailnet addresses, refreshed at apply. This correction does not change the record's status or accept it.

KI-TOOL-RIG-CORE-062 delivered that narrowing on 20 October 2026 for `macos-pf` and is awaiting review; the on-link targeted case it leaves is stated in RIG-ORCH-023, the ADR and the guide. An anchor installed under this record's range rule reports `drifted (anchor-changed)` under the new renderer until an attended `rig apply --sudo` rewrites it.

### Independent acceptance review, 20 October 2026

The six-heading Review packet, completed Steps and immutable baseline are present. Independent acceptance against the current code is refused: `ki repo audit --repo .` fails `ki-repo-tools`'s `SHELL-HOOK` criterion because the committed `.githooks/pre-commit` still runs Bats. This is a repository gate failure, not a newly reproduced firewall defect; `ki-accept` permits no waiver for a failing governing audit. Returned to `in-progress` under the independent acceptance brief. HOOK-GUARD remains in force: no conform, hook or runtime change was made.

The review packet also still withholds the attended NordVPN on/off checks and Rig apply on `terra`; ADR-KI-TOOL-RIG-009 remains proposed. Those checks and decisions are not supplied by the overnight grant. No live apply or remote machine probe was attempted. After the gate is repaired, restore the review packet with fresh verification and retain the attended acceptance boundary.

Independent local verification: 602 of 602 Bats tests pass normally and again with hostile inherited XDG configuration and state directories; their planted sentinels remain unchanged. ShellCheck, Bash syntax, assembly drift, the benchmark, bounded native-provider version probes, mandoc and diff checks pass. The roadmap and authoring audits have warnings only; the complete audit still fails the hook criterion above. Source reviewed at `590872732dde2a77bc118c2938d68b35d16068eb`; neither the runtime nor the hooks changed during this review.
