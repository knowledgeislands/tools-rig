---
id: RIG-MIG-001
area: MIG
title: Extract bootstrap behavior
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-MIG-004]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-MIG-001: Extract bootstrap behavior

## Goal

The current dotfiles bootstrap dispatcher becomes a compatibility surface over the private Rig profile and its provider bindings.

## Context

The existing implementation dispatches Homebrew, permissions, Node, Ruby, Zsh, Bun, SSH, uv, and completion components in a fixed order. Portable dispatch behaviour belongs in Rig; selected programs, native manifests, and scripts belong to private workstation configuration.

## Boundary

This item migrates bootstrap compatibility and cutover only. Machine auditing, managed service operations, and personal declaration design remain separate work.

## Discussion

### Compatibility

The existing `rig bootstrap` command remains live through cutover. The standalone command needs equivalent Bats coverage for dispatch order, selected components, stale-manifest protection, and failure boundaries before the dotfiles source stops owning duplicate behaviour.
