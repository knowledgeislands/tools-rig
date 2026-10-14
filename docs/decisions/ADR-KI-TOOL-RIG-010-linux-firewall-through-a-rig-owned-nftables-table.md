---
id: ADR-KI-TOOL-RIG-010
title: 'Linux Firewall Through a Rig-Owned nftables Table'
date: 2026-10-14
status: proposed
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [ADR-KI-TOOL-RIG-009]
---

# ADR-KI-TOOL-RIG-010: Linux Firewall Through a Rig-Owned nftables Table

## Context

A firewall declaration keeps named listener ports reachable only from loopback and the tailnet. On Linux the same restriction needs packet-filter rules loaded by root that survive a restart, and it often runs on a remote host reached only over the tailnet, where a mistake can end the only session.

Ubuntu offers two native routes. `ufw` manages the whole host's inbound policy and, once enabled, denies every port it does not allow. nftables lets independent components each own a table; every base chain on a hook sees each packet, and a drop in any of them is final. Ubuntu's `ufw` and `iptables` already use the nftables kernel back end.

Ubuntu's own `nftables.service` loads `/etc/nftables.conf`, which opens with `flush ruleset`. Distribution packages own that file and that unit. Listing loaded nftables rules needs root.

## Decision

On Linux, Rig restricts declared listeners with the built-in `linux-nftables` provider, under the attended grant ADR-KI-TOOL-RIG-009 defines.

Rig owns one nftables table, `inet rig_NAME`, derived from the declaration's locator, with one `input` chain whose policy is accept. For each declared port the chain accepts loopback and tailnet-to-tailnet traffic and drops everything else. The chain never drops an undeclared port, so Rig cannot loosen or replace another firewall and cannot cut off SSH, which validation also refuses to declare.

Rig owns two root-owned files: the rules at `/etc/rig/firewall/LOCATOR.nft` and a systemd unit at `/etc/systemd/system/LOCATOR.service`. The unit loads the table at every boot, after `nftables.service` and `ufw.service` and before the network comes up, and deletes only its own table when stopped. Rig never runs `ufw` or `iptables`, never edits `/etc/nftables.conf`, never flushes the ruleset and never touches another table. Retirement removes only Rig's unit, table and files.

Read-only commands compare the files, read the unit's state through `systemctl show` and check listener exposure with `ss`, reporting the kernel rules as unverified. `apply --sudo` checks the rendering with `nft -c` before installing anything and rereads the loaded table on every run.

## Consequences

Where `ufw` is active, both apply: `ufw` still governs every other port, Rig narrows the declared ones, and a `ufw` deny still wins. Doctor cannot see `ufw` rules without root and does not try.

A manual restart of `nftables.service`, or any `nft flush ruleset`, removes Rig's table until the next boot or `apply --sudo`. Doctor cannot see that without root; only the reread under `apply --sudo` notices.

The table filters the `input` hook only. Container ports published through a bridge reach the host on the `forward` hook and are not restricted.

A host without the `nftables` package cannot apply the restriction; Rig reports it unavailable and installs no system package.

## References

- [ADR-KI-TOOL-RIG-009](ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) — the attended grant, Rig-owned files and unprivileged evidence this provider keeps.
- [nftables wiki: Configuring chains](https://wiki.nftables.org/wiki-nftables/index.php/Configuring_chains) — base chains, hooks, priorities and policies.
