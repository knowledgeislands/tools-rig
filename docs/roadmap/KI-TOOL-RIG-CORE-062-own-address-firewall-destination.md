---
id: KI-TOOL-RIG-CORE-062
area: CORE
title: Own-address firewall destination
purpose: capability
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T09:45:00Z
updated_at: 2026-10-18T09:45:00Z
---

# Own-Address Firewall Destination

## Goal

A `macos-pf` firewall passes a declared port only when the destination is one of the Mac's own tailnet addresses, refreshed at each `rig apply --sudo`, so a neighbour on a carrier-grade NAT or hotspot network that gives the Mac a `100.64.0.0/10` address can no longer reach the port.

## Context

[KI-TOOL-RIG-CORE-047](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) delivered an anchor that passes a declared port `from 100.64.0.0/10 to 100.64.0.0/10`, plus the IPv6 equivalent, on any interface. Its Range correction, RIG-ORCH-023 and [ADR-KI-TOOL-RIG-009](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) now state the residual risk: when the Mac's own local-network address falls in `100.64.0.0/10`, a neighbour on the same network passes the rule. Kris agreed on 18 October 2026 (RIG-FIREWALL-RANGE a), ways-of-working decisions log) to capture one follow-up narrowing the rule to the Macs' own tailnet addresses, refreshed at apply.

## Boundary

- In: discovering the Mac's own Tailscale IPv4 and IPv6 addresses read-only at apply; rendering them, for example as a pf table, as the only permitted destination for each declared port; refreshing them on every `apply --sudo` and on reread; observation reporting a stale or undiscoverable address set; specification, ADR, guide and test alignment.
- Out: the `linux-nftables` provider, which shares the range rule but can match `tailscale0`; arbitrary CIDR allow-lists; installing or configuring Tailscale; any live apply, which needs Kris's separate approval.

## Dependencies / blocks

Follows KI-TOOL-RIG-CORE-047's acceptance or a decision to build on it while it awaits review. Blocks nothing.

## Discussion

Origin: the ways-of-working rig-fixes run of 18 October 2026, from the rig-review finding on KI-TOOL-RIG-CORE-047. Planning questions: how to discover the address without privilege or a Tailscale CLI dependency (both Macs differ: Homebrew `tailscaled` on `terra`, Tailscale.app on `sol`); what the anchor does when no tailnet address is present (block, or keep the range rule); whether the address can change between applies without a Tailscale restart, which would need the LaunchDaemon to refresh it too; and whether the one-way forged-source exposure warrants an interface match despite unstable `utun` names. Capture only; adoption, priority and plan belong to this repository.
