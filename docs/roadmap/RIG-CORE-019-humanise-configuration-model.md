---
id: RIG-CORE-019
title: Humanise configuration model
area: CORE
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:35:16Z
---

## Goal

Rig configuration should remain inert and Bash-readable while being pleasant for a person to understand, edit, review, and extend across realistic catalogues and more than one machine context.

## Context

Schema 1 rejects multiline arrays, producing a 1,305-character default tool-membership line in the current personal rig. Profiles have membership but no display name or purpose. Repeated platform and installation fields add noise, and one logical tool cannot yet express provider variants for different platforms. Managed resources can depend on tools but cannot express ordering between resources.

The proposed item-centric membership model can remove the largest profile arrays, but other arrays, schedules, programs, and ordered layouts still need a humane representation. Configuration usability is part of the product contract, not only guide formatting.

## Boundary

This work does not adopt YAML, a complete general-purpose TOML evaluator, arbitrary environment expansion, last-wins overrides, or executable configuration. Personal values and rationale remain private data rather than defaults embedded in Rig.

## Discussion

### Schema 1 evolution

A bounded multiline array of basic strings can remain valid TOML and inert Bash-parsed data. Profile name, purpose, safe item-centric membership, and concise defaults should be considered as compatible schema 1 evolution while the format is still personal and pre-v1.

### Cross-machine variants

Preserve one logical tool identity while deciding whether a bounded installation and artifact variant can select a native owner by platform or machine context. Do not reintroduce separate binding declarations or duplicate tools merely to choose Homebrew on macOS and another manager elsewhere.

### Resource dependencies

Determine whether explicit resource-to-resource ordering is needed for settings before services or daemons before jobs. Any addition should remain a dependency graph, not a generic task runner.

### Human validation

Examples and diagnostics should help an owner distinguish purpose from rationale, understand fragment composition, and locate conflicting or duplicated intent without requiring knowledge of Rig's internal parser representation.
