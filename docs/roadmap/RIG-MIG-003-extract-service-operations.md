---
id: RIG-MIG-003
area: MIG
title: Extract service operations
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-MIG-004]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-MIG-003: Extract service operations

## Goal

Rig preserves declared service discovery, run, restart, status, and log operations through a private executable provider without hard-coding one machine's launchd labels into tools-rig.

## Context

The current dotfiles command discovers scheduled jobs and managed services from chezmoi data, depends on `jq` and `launchctl`, and fails closed on unknown names. Its declaration-led safety model is reusable, but its data and platform operations remain private.

## Boundary

This item does not make launchd or `jq` a mandatory Rig dependency, move service declarations into the public repository, or introduce a generic service abstraction.

## Discussion

### Platform boundary

Service operations are expressed as a configured executable provider with platform conditions. A dedicated service abstraction should be introduced only if more than one backend demonstrates a stable shared contract.
