---
id: KI-TOOL-RIG-CORE-076
area: CORE
title: Host defaults and power
priority: medium
size: m
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-30T11:00:00Z
updated_at: 2026-10-30T11:00:00Z
---

# KI-TOOL-RIG-CORE-076: Host defaults and power

## Goal

A profile can declare a Mac's display-sleep and screen-saver timeouts, so that a rebuilt or second Mac gets them from Rig rather than from commands someone remembers.

## Context

On 30 October 2026 Amphetamine crashed on `sol` and the displays went off overnight, stopping the tower app. Kris set the fallback by hand: `sudo pmset -c displaysleep 0` and `defaults -currentHost write com.apple.screensaver idleTime -int 600`. Rig can declare neither.

- **Per-host defaults.** The screen saver's idle time lives in the per-host (ByHost) preferences that `defaults -currentHost` writes. [RIG-CONF-017](../specs/configuration.md) `macos-defaults` settings take a `domain` and `key` but have no host scope, so they write the ordinary user domain, which macOS ignores for this key.
- **Power settings.** `pmset` needs root and distinguishes power sources (`-c` charger, `-b` battery, `-a` all). Rig has no power resource. [RIG-ORCH-043](../specs/orchestration.md) already gives an attended `apply --sudo` session to firewall declarations, which is the pattern a power resource would follow.

The consumer is PERSONAL-DOTFILES-UE-115 in the dotfiles repository.

## Boundary

- **In:** an optional host scope on `macos-defaults` settings, observed and applied through `defaults -currentHost`; a built-in power-settings resource for named `pmset` keys and a power source, observed without root through `pmset -g custom` and applied only under the attended sudo session; doctor findings for drift in both; specifications, tests and the user guide.
- **Out:** sleep scheduling (`pmset repeat`), battery-only policy beyond the declared source, Lock Screen password settings that macOS does not expose to `defaults`, and any live apply on `sol` or `terra` during delivery.

## Dependencies / blocks

None in this repository. PERSONAL-DOTFILES-UE-115 waits on this to declare sol's settings.

## Discussion

Untriaged: adopt under `ki-next` and plan under `ki-plan`. Planning settles which `pmset` keys to allow (at least `displaysleep`, `sleep` and `disksleep`), how a power source is named in the declaration, and whether the host scope is a field on the existing setting table or a separate provider. Source revision at capture: `9297c9caeb23e77c1d6a02eafc38361104de8d5f`.
