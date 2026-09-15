---
id: RIG-MIG-003
area: MIG
title: Extract service operations
theme: migration
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CORE-002]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-MIG-003: Extract service operations

## Goal

Rig preserves declared service discovery, run, restart, status, and log operations without hard-coding one machine's launchd labels.

## Context

The current dotfiles command discovers scheduled jobs and managed services from chezmoi data and fails closed on unknown names. That declaration-led safety model is reusable even when the service manager differs by platform.

## Boundary

This item does not make launchd a mandatory Rig dependency or define service declarations before the core configuration contract is accepted.

## Discussion

### Platform boundary

Service operations may be expressed as configured executable targets with platform conditions. A dedicated service abstraction should be introduced only if more than one backend demonstrates a stable shared contract.
