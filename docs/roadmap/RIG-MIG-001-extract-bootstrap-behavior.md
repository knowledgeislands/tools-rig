---
id: RIG-MIG-001
area: MIG
title: Extract bootstrap behavior
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CLI-001]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-MIG-001: Extract bootstrap behavior

## Goal

The current dotfiles bootstrap dispatcher becomes a Rig profile whose target choices and ordering live in workstation configuration.

## Context

The existing implementation dispatches Homebrew, permissions, Node, Ruby, Zsh, Bun, SSH, uv, and completion components in a fixed order. That portable dispatch behaviour belongs in Rig; the selected programs and scripts belong with the workstation.

## Boundary

This item migrates bootstrap behaviour only. Machine auditing and managed service operations remain separate work.

## Discussion

### Compatibility

The existing `rig bootstrap` command should remain usable through the cutover until the standalone command has equivalent tests and the dotfiles source no longer owns duplicate behaviour.
