---
id: RIG-MIG-002
area: MIG
title: Extract machine audit
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CORE-002]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-MIG-002: Extract machine audit

## Goal

Rig can host the current read-only machine-profile audit without embedding the dotfiles repository's application catalogue or macOS declarations.

## Context

The current audit is Bun-based and reads several chezmoi source files directly. The standalone shell-only core needs a portable extension boundary or a shell implementation while retaining read-only semantics.

## Boundary

This item does not expose the destructive `machine apply` operation or move personal application choices into the Rig executable.

## Discussion

### Extension boundary

Machine audit may be a configured target command rather than a built-in adapter. That keeps Rig dependency-free while allowing a profile to invoke richer optional tooling when present.
