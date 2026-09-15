---
id: RIG-MIG-002
area: MIG
title: Extract machine audit
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-MIG-004]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-MIG-002: Extract machine audit

## Goal

Rig can expose the current read-only machine-profile audit as an optional extension while portable expected-versus-observed state is handled by the core provider contract.

## Context

The current audit is Bun-based and reads private software, macOS, Brewfile, guide, housekeeping, and `ki-self` sources directly. Those workstation-governance checks are broader than Rig's portable presence and drift model.

## Boundary

This item does not expose the destructive `machine apply` operation, rewrite the audit in Bash, or move personal application and macOS choices into the Rig executable.

## Discussion

### Extension boundary

Machine audit remains a configured executable provider or compatibility command. This keeps Rig dependency-free while allowing a private profile to invoke richer optional tooling when present.
