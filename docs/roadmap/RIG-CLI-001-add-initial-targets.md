---
id: RIG-CLI-001
area: CLI
title: Add initial targets
theme: cli
horizon: triage
status: draft
blocks: [RIG-DIST-001, RIG-MIG-001]
blocked_by: [RIG-CORE-002]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-CLI-001: Add initial targets

## Goal

Rig ships initial target integrations for Homebrew, uv, chezmoi, and an explicitly configured executable target.

## Context

These targets establish the manager-of-managers boundary across package managers, language-tool management, configuration management, and user-defined behaviour.

## Boundary

The integrations invoke supported native operations but do not reimplement package resolution, lock files, or target-specific state.

## Discussion

### Lifecycle vocabulary

Not every target supports every action. The configuration and help surface should expose capabilities rather than pretending install, update, cleanup, backup, audit, diff, and apply are universal synonyms.

### Chezmoi safety

Chezmoi mutation must preserve its review boundary: Rig may expose diff and apply as distinct actions and must not turn an inspection request into an implicit apply.
