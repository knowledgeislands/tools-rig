---
id: ADR-KI-TOOL-RIG-009
title: 'System-Domain Resources Under an Attended Grant'
date: 2026-10-14
status: proposed
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [ADR-KI-TOOL-RIG-006, ADR-KI-TOOL-RIG-008]
---

# ADR-KI-TOOL-RIG-009: System-Domain Resources Under an Attended Grant

## Context

Every resource Rig managed before this decision lived in the person's own domain: launchd user agents, user preferences, the Dock and Launch Services choices. None needed root, and an ordinary `rig apply` could reconcile all of them.

Some listeners on macOS, such as Screen Sharing, bind every address and offer no way to bind one interface. Restricting them to the tailnet needs packet-filter rules, which only root can load, and those rules must survive a restart. That is Rig's first resource outside the person's home.

macOS owns `/etc/pf.conf`, and updates can restore it. Its stock ruleset already evaluates every child anchor beneath `com.apple/*`. A VPN client or other component may also enable pf and hold its own references.

Status and doctor are read-only and promptless. Loaded pf rules cannot be read without root.

## Decision

Rig manages a system-domain resource only through its own files and its own native identity, and changes it only under the attended administrator grant of `rig apply --sudo`.

For a firewall restriction, Rig owns two root-owned files: an anchor at `/etc/pf.anchors/LOCATOR`, loaded as the child anchor `com.apple/LOCATOR`, and a system LaunchDaemon at `/Library/LaunchDaemons/LOCATOR.plist` that reloads it at boot and whenever `/etc/pf.conf` changes. Rig never edits `/etc/pf.conf`, never uses the application firewall, never disables pf and never flushes an anchor it does not own. Retirement removes only Rig's daemon, anchor rules and files.

Every privileged command runs through `sudo -n` within the attended grant. Without the grant, a resource that needs work is skipped with `administrator-grant-required` and nothing is touched. A resource whose unprivileged observation is present needs no grant and causes no prompt.

Read-only commands accept unprivileged evidence: file content, the daemon's load state and last exit code, and listener exposure. They report the kernel rules as unverified rather than claim them. `apply --sudo` rereads the loaded rules on every run and fails unless they match.

Every managed system path resolves beneath an optional `RIG_SYSTEM_ROOT`, so tests can run the complete adapter against a fixture tree without reaching the real system.

## Consequences

A macOS update that restores `/etc/pf.conf` removes nothing Rig owns, and the daemon reloads the anchor afterwards. If a future macOS dropped Apple's `com.apple/*` anchor point, the anchor would silently stop being evaluated; only `apply --sudo` and a live restart check would notice.

Status and doctor stay promptless, at the cost of a firewall reported present while its kernel rules are unverified. The reread under `apply --sudo` is the stronger check.

The restriction passes a tailnet source only when the destination is one of the machine's own tailnet addresses, which Rig reads from `ifconfig` at each observation and apply (KI-TOOL-RIG-CORE-062). When the address cannot be found, Rig installs and rewrites nothing, and an installed anchor keeps working because Tailscale keeps a node's addresses for its lifetime. A neighbour on a carrier-grade NAT or hotspot network that hands out `100.64.0.0/10` addresses therefore no longer reaches the port by scanning that network. The rule still names no interface, because Tailscale's interface name changes per machine and per boot and a rendered name would silently go stale. So it is tailnet-only by address, not authenticated Tailscale ingress. One targeted case remains: macOS accepts a packet for any local address on any interface, so a host on the same local network that sends to the machine's tailnet address through that network passes, for TCP and UDP alike. When the sender holds its own `100.64.0.0/10` address on the local subnet, the reply leaves through the local network and a TCP connection completes; with a forged tailnet source, one-way traffic arrives. On an untrusted shared network, turn the listener off.

Rig leaves pf enabled after retirement. With only Apple's anchors loaded this filters nothing, and it avoids releasing references another component holds.

The attended grant becomes a precondition for any system-domain change, so unattended runs cannot repair a drifted firewall. That is deliberate: a mistake in this domain can lock a person out of their machine.

## References

- [ADR-KI-TOOL-RIG-006](ADR-KI-TOOL-RIG-006-declarative-operational-resources.md) — establishes declaration as desired state and the receipt as managed identity.
- [ADR-KI-TOOL-RIG-008](ADR-KI-TOOL-RIG-008-catalogue-scoped-resource-retirement.md) — retirement follows the catalogue, which this decision keeps for system-domain resources.
