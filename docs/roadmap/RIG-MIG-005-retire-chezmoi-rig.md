---
id: RIG-MIG-005
area: MIG
title: Retire chezmoi Rig
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-MIG-001, RIG-MIG-002, RIG-MIG-003, RIG-CLI-004]
baseline_ref: null
created_at: 2026-09-16T11:06:43Z
updated_at: 2026-09-16T11:06:43Z
---

# RIG-MIG-005: Retire chezmoi Rig

## Goal

The standalone Rig becomes the only managed `rig` command after equivalent behaviour, tests, private declarations, and callers have moved safely out of the legacy chezmoi implementation.

## Context

`~/.local/bin/rig` currently resolves to the standalone working installation, while `~/bin/rig` remains managed by chezmoi as a fallback. The dotfiles repository still contains the legacy dispatcher, helper scripts, tests, guides, data, and command references. Removing only the wrapper now would leave live workflows without proven replacements.

## Boundary

This item removes the legacy Rig ownership only after its parity gates pass. It does not delete provider helpers that remain selected by private Rig configuration, discard unrelated dotfiles changes, run `chezmoi apply` without explicit approval, change live GitHub settings, push, or publish a release.

## Discussion

### Cutover gate

Retirement requires standalone tests equivalent to the old bootstrap, machine-audit, and service-operation coverage; migrated command callers and documentation; a side-by-side command inventory; and a reviewed `chezmoi diff` showing the exact source transition.

### Source transition

Changes happen in chezmoi source state. Host-specific declarations remain private, native provider manifests remain authoritative, and helpers are retained whenever the new configuration still references them.

### Rollback

The legacy implementation remains recoverable from dotfiles Git history. Applying the reviewed chezmoi transition is a separately approved action so the user can retain the old executable until the standalone replacement is proven on the target machine.
