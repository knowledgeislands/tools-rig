---
id: RIG-MIG-001
area: MIG
title: Extract bootstrap behavior
theme: migration
horizon: triage
status: draft
blocks: [RIG-MIG-005]
blocked_by: [RIG-MIG-004]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T11:06:43Z
---

# RIG-MIG-001: Extract bootstrap behavior

## Goal

Rig provides a small top-level bootstrap command that preserves the useful outcomes of the current dotfiles dispatcher through the private profile and provider model.

## Context

The existing implementation dispatches Homebrew, permissions, Node, Ruby, Zsh, Bun, SSH, uv, and completion components in a fixed order. It supports install, update, cleanup, and backup actions. Portable selection, ordering, failure, and reporting behaviour belongs in Rig; selected programs, native manifests, action policy, and scripts belong to private workstation configuration.

Feature parity concerns outcomes and safety rather than copying every private subsystem or nested command into the permanent public CLI. Portable machine checks move to `doctor` and `status`; macOS audit and launchd service operations remain optional private executable integrations.

## Boundary

This item migrates bootstrap behaviour, compatibility, and cutover only. It does not implement the catalogue resolver or provider engine, expose host-specific machine and service internals as permanent top-level commands, or design personal declarations.

## Discussion

### V1 command

`rig bootstrap [--profile NAME] [--dry-run]` is the small permanent top-level command for first materialisation of a resolved rig. It uses provider capabilities and the same dependency plan as apply rather than maintaining a second orchestration engine.

Install, update, cleanup, and backup outcomes remain available only where selected providers declare those capabilities. Any action-shaped compatibility accepted during cutover is documented as transitional rather than expanding every provider into a permanent command hierarchy.

### Compatibility

The existing `rig bootstrap` command remains live through cutover. The standalone command needs equivalent Bats coverage for dispatch order, selected components, stale-manifest protection, unsupported capabilities, dry-run non-mutation, and failure boundaries before the dotfiles source stops owning duplicate behaviour.

The same delivery updates top-level and command-specific help, completion, README command inventory, `rig(1)`, and the curated v1 changelog.
