---
id: KI-TOOL-RIG-CORE-062
area: CORE
title: Own-address firewall destination
purpose: capability
theme: rig
kind: deliver
horizon: now
status: in-progress
size: m
blocks: []
blocked_by: []
baseline_ref: 9dce7120fcaa8aefb6856876c614f5e40ae537b3
created_at: 2026-10-18T09:45:00Z
updated_at: 2026-10-20T05:33:29Z
---

# Own-Address Firewall Destination

## Goal

A `macos-pf` firewall passes a declared port only when the destination is one of the Mac's own tailnet addresses, refreshed at each `rig apply --sudo`, so a neighbour on a carrier-grade NAT or hotspot network that gives the Mac a `100.64.0.0/10` address can no longer reach the port.

## Context

[KI-TOOL-RIG-CORE-047](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) delivered an anchor that passes a declared port `from 100.64.0.0/10 to 100.64.0.0/10`, plus the IPv6 equivalent, on any interface. Its Range correction, RIG-ORCH-023 and [ADR-KI-TOOL-RIG-009](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) now state the residual risk: when the Mac's own local-network address falls in `100.64.0.0/10`, a neighbour on the same network passes the rule. Kris agreed on 18 October 2026 (RIG-FIREWALL-RANGE a), ways-of-working decisions log) to capture one follow-up narrowing the rule to the Macs' own tailnet addresses, refreshed at apply.

## Boundary

- In: discovering the Mac's own Tailscale IPv4 and IPv6 addresses read-only at apply; rendering them, for example as a pf table, as the only permitted destination for each declared port; refreshing them on every `apply --sudo` and on reread; observation reporting a stale or undiscoverable address set; specification, ADR, guide and test alignment.
- Out: the `linux-nftables` provider, which shares the range rule but can match `tailscale0`; arbitrary CIDR allow-lists; installing or configuring Tailscale; any live apply, which needs Kris's separate approval.

## Current state

Read on 19 October 2026 at `7665767`, after [KI-TOOL-RIG-CORE-063](https://github.com/knowledgeislands/tools-rig/blob/766576763a799929f386d2b50df5797312285dc7/docs/roadmap/KI-TOOL-RIG-CORE-063-fatal-bats-assertions.md) landed.

- `rig_firewall_render_anchor` in `src/rig/29-firewall.bash` renders, per declared port, a `lo0` pass, `from 100.64.0.0/10 to 100.64.0.0/10`, `from fd7a:115c:a1e0::/48 to fd7a:115c:a1e0::/48`, then a block. The ranges are the constants `RIG_FIREWALL_TAILNET_IPV4` and `RIG_FIREWALL_TAILNET_IPV6`. Observation compares the rendered anchor byte for byte with the installed one, so any input to the renderer is also an input to drift.
- The LaunchDaemon only reruns `pfctl -E -a com.apple/LOCATOR -f /etc/pf.anchors/LOCATOR`; it reloads the installed file and cannot rediscover anything.
- `tests/rig-firewall.bats` asserts the range rules literally (the expected anchor near line 151, the dry-run counts near line 276, the `explain` line near line 300) and stubs `netstat` through `RIG_NETSTAT_COMMAND`. Since KI-TOOL-RIG-CORE-063, every bare `[[ ]]` or `!` assertion ends `|| false`, `SHELL-FATAL` is clean, and `assert_no_global_firewall` matches only `pfctl`'s own `-d` or `-X`. New assertions must keep both properties.
- `tests/helpers/isolate.bash` stubs `plutil`, `launchctl`, `defaults`, `dockutil`, `killall` and `sudo`; nothing reads interface addresses yet.
- Discovery evidence, read without privilege on `sol` (Tailscale.app): `/sbin/ifconfig` shows one interface, `utun4`, holding both `100.90.130.74` and `fd7a:115c:a1e0::b636:824c`. `terra` (Homebrew `tailscaled`) is not yet read; Homebrew `tailscaled` also uses a `utun` device, so the same shape is expected but unconfirmed.

## Planning answers

- **Discovery.** Read `ifconfig` without privilege or a Tailscale CLI. The tailnet interface is the single interface carrying an `inet6` address inside `fd7a:115c:a1e0::/48`; take that interface's one `inet` address inside `100.64.0.0/10` and its one `inet6` inside the ULA prefix. A local-network `100.64.0.0/10` address never sits on an interface with a Tailscale ULA, so the pairing separates the two. No such interface, more than one, or a missing family is undiscoverable. This works for Tailscale.app and Homebrew `tailscaled` alike.
- **Address stability.** Tailscale assigns a node's addresses for its lifetime; they change on re-registration or an admin edit, not on restart or roaming. The LaunchDaemon therefore keeps reloading the static file and needs no refresh logic; a changed address shows as drift and is repaired by the next `apply --sudo`.
- **Rendering.** Inline the two addresses in the pass rules, `from 100.64.0.0/10 to 100.90.130.74` and `from fd7a:115c:a1e0::/48 to fd7a:115c:a1e0::b636:824c`, rather than a pf table, so the existing `-s rules` reread still verifies the whole anchor; a table would need a second `-t ... -T show` read.
- **No address at apply (Q-062-ABSENT, answered a)).** Refuse: observation reports `unknown` with `tailnet-address-undiscoverable`, and apply neither installs nor rewrites the anchor. Because addresses are stable, an installed anchor stays correct while Tailscale is down; keeping the range rule would reopen the risk this record removes, and a loopback-only anchor would lock out tailnet access until an attended reapply.
- **Interface match (Q-062-SCOPE, answered a)).** Not added. A rendered `utunN` goes stale after any `tailscaled` restart with no reload trigger, which silently blocks tailnet access. This leaves one narrowed residual, stated in the specification, the ADR and the guide: macOS accepts a packet for a local address on any interface, so an on-link neighbour holding its own `100.64.0.0/10` address who targets the Mac's tailnet address through the local network still passes the rule, and because the neighbour's subnet is a more specific connected route than Tailscale's, the reply leaves by the local network and a TCP handshake can complete. A neighbour scanning the local network, the common case, no longer reaches the port. This is a material limit on the record's Goal, so it is raised as a query rather than assumed.

## Queries

- **Q-062-SCOPE — answered a).** Kris, 20 October 2026 at 00:16 BST: "Q-062-SCOPE/ABSENT proceed with recommendation". Deliver the own-address destination with no interface match. The specification, ADR-KI-TOOL-RIG-009 and the firewall guide state the remaining targeted case, which covers TCP as well as UDP: an on-link neighbour holding its own `100.64.0.0/10` address who sends to the Mac's tailnet address through the local network still passes. "Tailnet-only" is worded so it does not promise authenticated Tailscale ingress, and the guide keeps the advice to turn Screen Sharing off on untrusted shared networks.
- **Q-062-ABSENT — answered a).** Same decision. When apply cannot find the Mac's own tailnet address, observation reports `unknown` with `tailnet-address-undiscoverable`, and apply installs or rewrites nothing.

## Steps

- [x] Add `rig_firewall_tailnet_addresses` to `src/rig/29-firewall.bash`: run `${RIG_IFCONFIG_COMMAND:-/sbin/ifconfig}` read-only, apply the discovery rule above, and set `RIG_FIREWALL_SELF_IPV4` and `RIG_FIREWALL_SELF_IPV6` or return non-zero with `tailnet-address-undiscoverable`. Bash 3.2 only; no new runtime dependency.
- [x] Render each port's two tailnet pass rules with the discovered destinations; keep the source ranges, the `lo0` pass and the block unchanged. Update the anchor's header comment to name own-address destinations.
- [x] In `rig_firewall_observe`, discover before rendering; on failure report `unknown`, `tailnet-address-undiscoverable`, without rendering. When the installed anchor differs from the rendered one only in its pass rules' destinations, report `tailnet-address-stale` instead of `anchor-changed`.
- [x] In `rig_firewall_apply` and `rig_firewall_apply_ready`, stop on `unknown`, so an undiscoverable address installs and rewrites nothing and apply reports it as skipped with `tailnet-address-undiscoverable`, with or without the grant; `apply --sudo` repairs a stale address through the existing install, reload and reread path. `rig_firewall_print_projection` and `rig_explain_firewall` show the discovered destinations, or the undiscoverable reason.
- [x] Point `tests/helpers/isolate.bash` at an inert `ifconfig` stub through `RIG_IFCONFIG_COMMAND` so no test reads the runner's interfaces, and give `tests/rig-firewall.bats` a fixture `ifconfig` with a local-network `en0` in `100.64.0.0/10` beside a `utun` tailnet interface.
- [x] Update the literal expectations in `tests/rig-firewall.bats`, and add cases for: own addresses rendered, the `en0` CGNAT address never chosen, no tailnet interface, two tailnet interfaces, a missing family, `tailnet-address-stale` after an address change, and apply installing nothing when undiscoverable. Every new bare assertion ends `|| false`.
- [x] Align RIG-ORCH-023, RIG-STATE-045, RIG-CONF-030 if its wording names the ranges as the match, [ADR-KI-TOOL-RIG-009](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md)'s residual-risk paragraph, the operational-resources guide's `tailnet` section, help, manual and changelog. Reassemble `bin/rig`.
- [x] Run the complete local gate.

## Files touched

- `src/rig/29-firewall.bash`; generated `bin/rig`.
- `tests/rig-firewall.bats`, `tests/helpers/isolate.bash`.
- `docs/specs/orchestration.md`, `docs/specs/state.md`, `docs/specs/configuration.md`; `docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md`; `docs/guides/user/operational-resources.md`; help text, manual page and `CHANGELOG.md` where they describe the firewall match.
- This record.

No `linux-nftables` change.

## Verify

- `bats tests/rig-firewall.bats </dev/null` covers every case in the Steps, with fixture-only `ifconfig`, `pfctl`, `launchctl` and `sudo`; read-only commands still log no `sudo`, `pfctl` or load.
- `ki repo audit --skill ki-repo-tools --repo .` reports no `SHELL-FATAL` finding.
- [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository) passes, `bats tests/ </dev/null` included, and once under a hostile inherited `XDG_STATE_HOME`, since the isolation helper changes.
- `rig show firewall:ID` on `sol`, read-only and without `--sudo`, names `100.90.130.74` and `fd7a:115c:a1e0::b636:824c`. A read-only `ifconfig` on `terra` confirms the same discovery shape before any live apply.
- No live apply. Applying on `sol` or `terra` is a connection-critical change for Kris's separate approval, and any live rollout is attended at the screen. It carries KI-TOOL-RIG-CORE-047's tested SSH rollback and restore path: the no-Rig rollback in the operational-resources guide (`sudo launchctl bootout system/LOCATOR`, then `sudo pfctl -a com.apple/LOCATOR -F all`) and the restore by `sudo launchctl bootstrap system /Library/LaunchDaemons/LOCATOR.plist`, both rehearsed on `terra` on 19 October 2026 with SSH, never restricted, as the recovery route.

## Dependencies / blocks

Follows [KI-TOOL-RIG-CORE-047](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md), still awaiting review; Kris's RIG-ORDER decision of 19 October 2026 authorises planning on it. [KI-TOOL-RIG-CORE-068](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-068-replaced-pf-root-ruleset-bypass.md) is independent but edits the same module, tests and RIG-STATE-045, so deliver the two one after the other, not in parallel. Blocks nothing.

## Documentation impact

### Decision Records

[ADR-KI-TOOL-RIG-009](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md): replace the "proposed remedy" sentence with the delivered own-address destination and the narrowed on-link residual.

### Specifications

RIG-ORCH-023 (rendered rules and residual risk), RIG-STATE-045 (`tailnet-address-undiscoverable`, `tailnet-address-stale` and the `ifconfig` source), and RIG-CONF-030 if it describes the match.

### Guides

`docs/guides/user/operational-resources.md`, the `tailnet` meaning and its residual-risk text.

### Roadmap

This record moves to Awaiting review at delivery; [KI-TOOL-RIG-CORE-047](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md)'s Range correction gains a pointer to the delivered narrowing.

## Review

### Delivered

The approved boundary: a `macos-pf` anchor now passes each declared port from Tailscale's ranges only to the Mac's own tailnet IPv4 and IPv6 addresses, discovered read-only from `ifconfig` at every observation and apply. Discovery refuses an ambiguous or incomplete shape, observation reports `tailnet-address-undiscoverable` and `tailnet-address-stale`, and apply installs and rewrites nothing without an address. Excluded as planned: `linux-nftables`, interface matching, arbitrary CIDRs, Tailscale configuration and any live apply. Immutable baseline `9dce7120fcaa8aefb6856876c614f5e40ae537b3` (the Ready commit); the delivery commit follows it on `main`.

### Change Summary

- `src/rig/29-firewall.bash`: `rig_firewall_tailnet_addresses` (paired discovery from the one interface carrying a `fd7a:115c:a1e0::/48` address, honouring `RIG_IFCONFIG_COMMAND`); the renderer names the discovered destinations and refuses to render without them; `rig_firewall_mask_destinations` lets observation report `tailnet-address-stale` when only the pass rules' destinations differ; observation reports `unknown (tailnet-address-undiscoverable)` before rendering; `rig_firewall_apply_ready` skips an undiscoverable firewall with that reason, with or without the grant; the dry-run projection and `show firewall:ID` print the destinations or the reason. `bin/rig` reassembled.
- `tests/helpers/isolate.bash` refuses `ifconfig` through an inert logging stub; `tests/rig.bats`'s isolation guard asserts it. `tests/rig-firewall.bats` adds a fixture `ifconfig` with a CGNAT `en0` beside a `utun` tailnet interface, updates the golden anchor, and adds three tests: discovery shapes (none, second tailnet interface, missing IPv4, missing IPv6, repeated IPv4, unreadable, interface order), undiscoverable apply installing and rewriting nothing with and without an installed anchor, and a changed address reported stale then repaired by the existing install, reload and reread path.
- Docs: RIG-ORCH-023 and RIG-STATE-045; ADR-KI-TOOL-RIG-009's residual-risk paragraph; the operational-resources guide's `tailnet` section; `man/rig.1`; `CHANGELOG.md`; a pointer in KI-TOOL-RIG-CORE-047's Range correction. RIG-CONF-030 and the help text do not describe the match, so they are unchanged.
- Decisions applied: Q-062-SCOPE a) and Q-062-ABSENT a), Kris, 20 October 2026 at 00:16 BST. No approved deviation.

### Verification

- `bats tests/ </dev/null`: 593 of 593 pass; run again with `XDG_STATE_HOME` pointed at a planted directory, 593 of 593 pass and the directory stays empty.
- `bats tests/rig-firewall.bats </dev/null`: 13 of 13, covering every case in the Steps with fixture-only `ifconfig`, `pfctl`, `launchctl` and `sudo`; read-only commands still log no `sudo`, `pfctl` or load.
- Shell gate: `shellcheck` clean, `bash -n` clean on every script, `scripts/assemble-rig --check` current, `scripts/benchmark-rig` and `scripts/smoke-native-providers` pass, `mandoc -T lint man/rig.1` clean, `git diff --check` clean.
- `ki repo audit --skill ki-repo-tools --repo .`: no `SHELL-FATAL` finding. `ki repo audit --repo .`: no failure; its warnings (`.rumdl.toml` template drift, Claude Desktop binding, untracked `.githooks/pre-commit`, roadmap `size` migration notes on other records) predate this change and touch no file it changed.
- Read-only discovery on `sol`: `rig show firewall:probe` with a throwaway catalogue, the real `/sbin/ifconfig` and stubbed `launchctl`, `netstat`, `sudo` and `pfctl` names `100.90.130.74` and `fd7a:115c:a1e0::b636:824c`, logs no escalation and writes nothing.
- Not run: the read-only `ifconfig` on `terra` (no remote call in this run) and any live apply, which stays for Kris's separate, attended approval.

### Outstanding concerns

- `sol` and `terra` carry anchors rendered by KI-TOOL-RIG-CORE-047's range rule. Under the new renderer both report `drifted (anchor-changed)`, not `tailnet-address-stale`, because the header comment changed too; an attended `rig apply --sudo` rewrites them. That rollout is connection-critical, needs Kris's separate approval, is attended at the screen, and carries KI-TOOL-RIG-CORE-047's tested SSH rollback and restore path.
- `terra`'s `ifconfig` shape under Homebrew `tailscaled` is unconfirmed; the record's Verify asks for a read-only check there before any live apply. Not done in this run (no remote calls).
- `rig apply --sudo` still asks for the administrator grant when the only firewall is undiscoverable, then skips it; harmless, and outside the planned files.
- The targeted on-link case stays by decision: a host on the same local network sending to the Mac's tailnet address through that network passes, over TCP and UDP.

### Post-change review

The Goal holds for the common case: a neighbour scanning a CGNAT or hotspot network no longer reaches the port, and the remaining targeted case is stated in the specification, ADR and guide without promising authenticated Tailscale ingress. Scope held to the planned files. Regression risk is confined to the `macos-pf` adapter: every rendered anchor now depends on discovery, which refuses rather than guesses, and the full suite passes under the isolation helper, which now refuses `ifconfig`. Ready for Kris's review; live rollout stays separate.

### Mini recap

Own-address destinations, paired IPv4 and IPv6 discovery, stale and undiscoverable reporting, fixture tests and documentation are delivered and verified locally; no live machine was touched. Proposed learning route: none beyond the specification and guide already updated.

## Discussion

Origin: the ways-of-working rig-fixes run of 18 October 2026, from the rig-review finding on KI-TOOL-RIG-CORE-047. Planning questions: how to discover the address without privilege or a Tailscale CLI dependency (both Macs differ: Homebrew `tailscaled` on `terra`, Tailscale.app on `sol`); what the anchor does when no tailnet address is present (block, or keep the range rule); whether the address can change between applies without a Tailscale restart, which would need the LaunchDaemon to refresh it too; and whether the one-way forged-source exposure warrants an interface match despite unstable `utun` names. Kris's RIG-ORDER decision a) of 19 October 2026 at 23:27 BST ("All three are high confidence to do them") adopted this record for planning at horizon Now. Kris answered Q-062-SCOPE and Q-062-ABSENT a) on 20 October 2026 at 00:16 BST ("proceed with recommendation"), which approves the plan as written; the record moved to Ready.

### Independent acceptance review, 20 October 2026

The six-heading Review packet, completed Steps and immutable baseline are present, and the code and fixture cases implement paired own-address discovery, conservative refusal and stale-address reconciliation. Independent acceptance is refused: `ki repo audit --repo .` fails `ki-repo-tools`'s `SHELL-HOOK` criterion because the committed `.githooks/pre-commit` still runs Bats. The record's Verify requires both that governing audit and the complete gate; `ki-accept` permits no waiver. Returned to `in-progress` under the independent acceptance brief. HOOK-GUARD remains in force: no conform, hook or runtime change was made.

Verify's read-only `ifconfig` confirmation on `terra` is still explicitly missing from the packet; the overnight brief permits no such remote machine probe. An attended rewrite of the installed range anchors also remains separately approved work. The remaining targeted on-link exposure is an approved limitation, not a new finding. After the gate is repaired, refresh verification and obtain the missing machine evidence before resubmitting.

Independent local verification: 602 of 602 Bats tests pass normally and again with hostile inherited XDG configuration and state directories; their planted sentinels remain unchanged. ShellCheck, Bash syntax, assembly drift, the benchmark, bounded native-provider version probes, mandoc and diff checks pass. The roadmap and authoring audits have warnings only; the complete audit still fails the hook criterion above. Source reviewed at `590872732dde2a77bc118c2938d68b35d16068eb`; neither the runtime nor the hooks changed during this review.
