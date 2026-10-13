---
id: KI-TOOL-RIG-CORE-047
area: CORE
title: Tailnet-only listener firewall
initiative: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 39499cd6566b2fa02f9c66476eda53f052ccb351
created_at: 2026-10-13T22:48:41Z
updated_at: 2026-10-13T23:35:15Z
---

# KI-TOOL-RIG-CORE-047: Tailnet-Only Listener Firewall

## Goal

A profile declares that named remote-access listeners, Screen Sharing first, accept connections only from the tailnet and loopback. On macOS, `rig apply --sudo` installs a packet-filter (`pf`) restriction that survives restarts and macOS updates without editing `/etc/pf.conf`; `rig doctor` reports a machine whose restriction is missing or damaged, or whose declared listener is open beyond the tailnet with no restriction in place. Every other port, SSH in particular, is never touched, and the application firewall is never enabled.

## Context

Kris asked for remote access to be managed by Rig on 2026-10-13 (mac-studio-bootstrap Decision 45), and chose to build the tailnet-only Screen Sharing firewall properly in Rig now rather than hand-fix `sol` (Decision 48, after Decision 47 deferred the hand fix to Rig). This record is the firewall slice split out of [KI-TOOL-RIG-CORE-046](KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md), which keeps Screen Sharing on or off, allowed users, Handoff, Universal Clipboard and Universal Control.

macOS Screen Sharing has no per-interface setting: launchd holds its socket on every address, IPv4 and IPv6, whenever the service is enabled. With the application firewall off, anyone on a shared network can reach port 5900 and try the account password. The person's two Macs are `terra` (MacBook, `laptop` profile, Tailscale through the Homebrew `tailscaled` daemon) and `sol` (Mac Studio, `studio` profile, Tailscale.app). The manual steps and the current advice to turn Screen Sharing off on shared networks are in the chezmoi source's macOS workstation guide, "Remote access" section.

## Boundary

- **In:** a new `firewall` resource kind with a built-in `macos-pf` provider; declaration validation; read-only observation in `rig status` and `rig doctor`; `rig apply --sudo` install and repair; catalogue-scoped retirement under [ADR-KI-TOOL-RIG-008](../decisions/ADR-KI-TOOL-RIG-008-catalogue-scoped-resource-retirement.md); `rig show` and `rig explain` presentation; specification, guide, help, manual, changelog and test alignment.
- **Out:** turning Screen Sharing on or off and choosing its users ([KI-TOOL-RIG-CORE-046](KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md)); SSH server settings, keys and port 22, which this record never filters; the macOS application firewall (`socketfilterfw`), which Rig neither enables nor reads as part of this resource; installing or configuring Tailscale; arbitrary CIDR allow-lists, outbound rules, NAT or general firewall management; editing `/etc/pf.conf` or Apple's `/etc/pf.anchors/com.apple`; any personal declaration, which belongs to the person's Rig configuration in the chezmoi source.
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

Planning changes this record, [KI-TOOL-RIG-CORE-046](KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md) and [the issue ledger](_ISSUES.md) only. Expected delivery scope:

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

`blocks: []` and `blocked_by: []`. Delivery needs no machine, profile or chezmoi change. The personal `[firewall.*]` declaration and the chezmoi guide's pointer move to this record belong to the chezmoi source after delivery. [KI-TOOL-RIG-CORE-046](KI-TOOL-RIG-CORE-046-remote-access-and-continuity.md) is independent: either can land first.

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

### Outstanding concerns

- The rule normalisation that compares `pfctl -a … -s rules` output with the rendered anchor is proven only against a fixture. Real `pfctl` display formatting must be confirmed in live acceptance; a mismatch would fail apply safely rather than leave rules unloaded.
- Live acceptance on `terra` and `sol` is withheld and unrun: tailnet SSH and `vnc://`, LAN refusal, survival across restart, and NordVPN on `sol`.
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

- **Match by address, not interface.** `tailnet` expands to Tailscale's fixed ranges, `100.64.0.0/10` and `fd7a:115c:a1e0::/48`, required on both source and destination. The `utunN` name differs per machine and per boot (evidence above). Requiring the destination to be the machine's own tailnet address as well as the source closes the gap where a device on the local network happens to hold a `100.64.0.0/10` address (some carrier-grade NAT and hotspot networks do). Loopback is always allowed. Arbitrary CIDRs are deliberately not accepted.
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
- **System-domain blast radius.** First Rig resource outside `$HOME`. Tests redirect every system path through `RIG_SYSTEM_ROOT` and stub every privileged command; [AGENTS.md](../../AGENTS.md) already forbids reproducing a destructive defect against the live machine.

### Decisions for Kris

- **FW-SHAPE.** Approve the `[firewall.ID]` kind, `macos-pf` provider, `protocol:port` list and `allow = ["tailnet"]` as the only source. Recommend yes: it is the smallest shape that solves Screen Sharing and leaves room for a Linux provider.
- **FW-MATCH.** Match tailnet addresses on source and destination, never an interface. Recommend yes, for the evidence above.
- **FW-PERSIST.** Use a Rig-owned LaunchDaemon loading a `com.apple/` child anchor at boot and on `/etc/pf.conf` change, never editing `/etc/pf.conf`. Recommend yes. Alternative: also re-assert every 15 minutes (`StartInterval`) to self-heal after a VPN client flushes pf, at the cost of a repeating root job; recommend adding it only if the NordVPN live check fails.
- **FW-DOCTOR.** Accept that unprivileged doctor reports files, daemon and listener exposure, and states kernel rules as unverified, instead of adding a privileged doctor. Recommend yes: doctor stays read-only and promptless.
- **FW-LINUX.** Linux is an explicit non-goal here, with the schema left open for a later provider once a Linux profile exists. Recommend yes.

### Approval boundary

Approving this plan moves the record to Ready and permits local, fixture-backed delivery through `ki-implement` only. It grants no personal declaration, no `rig apply` on any machine, no change on `sol` or `terra`, no live pf operation, and no acceptance, pruning or release. The live acceptance checks need their own approval.

### Adoption approval

Kris approved the split, adoption and planning to Ready in mac-studio-bootstrap Decision 48 (13 October 2026): "FIREWALL: B" - build the tailnet-only Screen Sharing firewall properly in Rig now, not by hand on `sol`. That adopted this record as Deliver / draft at Next under the Rig Initiative and authorised read-only evidence from `sol`. It grants no implementation.

### Plan approval

On 13 October 2026 Kris approved this plan as written (mac-studio-bootstrap Decision 49): "we can at least accept what has been suggested ... ironed out for getting on with it". The decisions are FW-PLAN approve; FW-SHAPE yes; FW-MATCH yes; FW-PERSIST yes, with no periodic re-load yet; FW-DOCTOR yes; FW-LINUX yes, for a later record. The record moves to `ready` at Next. The approval permits local, fixture-backed delivery through `ki-implement` to Awaiting review only; it grants no personal declaration, no `rig apply` on `terra` or `sol`, no live pf operation, and no acceptance, pruning or release.
