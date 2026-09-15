---
id: RIG-CLI-001
area: CLI
title: Add provider adapters
theme: cli
horizon: triage
status: draft
blocks: [RIG-DIST-001, RIG-MIG-004]
blocked_by: [RIG-CORE-002]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-CLI-001: Add provider adapters

## Goal

Rig ships provider adapters for Homebrew, uv, chezmoi, direct downloads, and explicitly configured executables, with read-only observation and explicit supported mutations.

## Context

Providers are the manager-of-managers mechanism beneath the catalogue product. They connect selected tools to native systems without making Rig another package resolver or configuration database.

## Boundary

Adapters invoke supported native operations but do not reimplement native resolution, lock files, manifests, configuration, or state. This item does not choose a person's catalogue or publish their rig.

## Discussion

### Capability vocabulary

Not every provider supports every action. Configuration and help surfaces should expose real capabilities instead of pretending install, update, cleanup, backup, audit, diff, and apply are universal synonyms.

### Optional dependencies

A provider executable is required only when a selected binding uses it. Missing optional providers report `unavailable` rather than becoming Rig core dependencies.

### Chezmoi safety

Chezmoi inspection and mutation remain distinct. Neither catalogue queries nor state inspection may trigger `chezmoi apply`; mutation requires an explicit apply action.

### Download integrity

Direct-download bindings require declared integrity evidence and perform network or filesystem mutation only through explicit application.
