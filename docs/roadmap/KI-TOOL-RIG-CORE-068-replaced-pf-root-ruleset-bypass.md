---
id: KI-TOOL-RIG-CORE-068
area: CORE
title: pf root ruleset bypass
purpose: corrective
theme: rig
status: triage
priority: high
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T22:14:04Z
updated_at: 2026-10-19T22:14:04Z
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

The attended N/P check in the [terra-nordvpn report](/Users/krisbrown/.local/state/ki/agents/chezmoi/terra-nordvpn.report.md) is this record's acceptance evidence. Kris has not yet run it. Before it runs, it takes these corrections from the review:

- **A tested restore path comes first.** Connecting and disconnecting NordVPN changes connection-critical routing and pf state. If NordVPN keeps its rules after a disconnect, no restore has been tested. Prepare and rehearse one before the trial, under the connection-critical rule. Being at the console gives access, but it does not restore anything.
- **N's verdict needs more evidence.** Before it reports the rules as evaluated, N must also show that pf is enabled, that the rule contents match and not only their count, that no `set skip` covers the tested interfaces, and that no earlier rule ends evaluation first. Any read that fails reports unknown. A missing `com.apple/*` call alone does not prove that nothing else reaches Rig's anchor.
- **P's negative results don't prove blocking.** A failed SSH connection or a missing RFB greeting does not prove a firewall block. Confirm `terra`'s current LAN address, and confirm that the SSH alias resolves to the tailnet address. P tests IPv4 TCP only, so it says nothing about UDP 5900 or IPv6. Only a greeting gives positive evidence.
- **Repeat after disconnect.** Run the endpoint checks again after the disconnect, as well as the root inspection.

The check's results set the scope: whether detection alone suffices, whether the kill switch keeps the bypass after a disconnect, and whether re-assertion is wanted. Implementation waits for them, but capturing and planning do not.

## Dependencies / blocks

Not blocked. It follows [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md), whose resource it extends. [KI-TOOL-RIG-CORE-062](KI-TOOL-RIG-CORE-062-own-address-firewall-destination.md) narrows the same anchor's destination, and the two are independent.

## Discussion

- **Avoid simultaneous use, outside Rig.** The review proposed this until protection is verified: keep Screen Sharing off whenever NordVPN is connected, and keep it off after a disconnect until the protection is checked again. The alternative is to keep NordVPN disconnected while Screen Sharing is needed. That operational advice belongs in the chezmoi guide, not here. NordVPN's local-network setting could later add protection, but it is not yet verified for every protocol and address family.
- **Other residual risks.** These stay outside this record's fix, but planning should keep them in view. Meshnet NATs and filters `100.64.0.0/10`, which overlaps Tailscale's range. Tailnet SSH may depend on what NordVPN's block-all passes. The anchor's range and interface limits are covered in KI-TOOL-RIG-CORE-047's [Range correction](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md#range-correction).
- **One wildcard is a start.** Checking for root's `com.apple/*` call is an initial invariant, not a complete test of protection. Planning decides how far to go towards effective reachability before the evidence runs out.

Capture only. Adoption, horizon and plan need Kris's approval.
