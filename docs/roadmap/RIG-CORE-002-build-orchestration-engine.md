---
id: RIG-CORE-002
area: CORE
title: Build orchestration engine
theme: orchestration
horizon: triage
status: draft
blocks: [RIG-CLI-001]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T08:28:40Z
---

# RIG-CORE-002: Build orchestration engine

## Goal

Rig can ask providers for observed state, compare it with a resolved profile, and dispatch supported materialisation actions in dependency order with predictable failure reporting.

## Context

The existing dotfiles Rig has install-safe ordered dispatch and several provider-specific safety checks. The standalone engine must generalise those behaviours without hard-coding one machine's subsystem names, package choices, or host paths.

## Boundary

This item builds the provider and state engine after catalogue resolution exists. It does not implement package-manager-specific adapters, public query presentation, private workstation declarations, or site publication.

## Discussion

### State model

For each tool expected by a resolved profile, the engine should report `present`, `missing`, `drifted`, `unavailable`, or `unknown` with its responsible provider. Observation is capability-gated and read-only.

### Execution model

The engine fails closed on unknown providers, unsupported capabilities, ambiguous bindings, dependency cycles, and failed prerequisites. A provider failure stops dependent work while preserving the native command's result in Rig's report.

### Shell compatibility

Implementation remains compatible with Bash 3.2 and avoids associative arrays and newer shell conveniences.
