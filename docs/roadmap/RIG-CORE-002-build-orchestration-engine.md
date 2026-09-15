---
id: RIG-CORE-002
area: CORE
title: Build orchestration engine
theme: orchestration
horizon: triage
status: draft
blocks: [RIG-CLI-001, RIG-MIG-002, RIG-MIG-003]
blocked_by: [RIG-CORE-001]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-CORE-002: Build orchestration engine

## Goal

Rig can resolve a selected profile into ordered targets and dispatch supported lifecycle actions with predictable failure and reporting behaviour.

## Context

The existing dotfiles Rig has an install-safe ordered dispatcher. The standalone project must generalise that behaviour without hard-coding one machine's subsystem names.

## Boundary

This item builds the target engine but does not implement package-manager-specific adapters or migrate dotfiles.

## Discussion

### Execution model

The engine should fail closed on unknown targets, unsupported actions, dependency cycles, and failed prerequisites. A target failure should stop dependent work while preserving the native command's exit result in Rig's report.

### Shell compatibility

Implementation must remain compatible with Bash 3.2, which excludes associative arrays and newer conveniences from the core design.
