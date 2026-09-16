---
id: RIG-CLI-005
area: CLI
title: Add declared operations
theme: cli
horizon: triage
status: draft
blocks: [RIG-MIG-002, RIG-MIG-003]
blocked_by: [RIG-CLI-001]
baseline_ref: null
created_at: 2026-09-16T11:06:43Z
updated_at: 2026-09-16T11:06:43Z
---

# RIG-CLI-005: Add declared operations

## Goal

Rig can invoke a named, configuration-defined tool operation through `rig run TOOL OPERATION` without acquiring permanent machine-audit or service command families.

## Context

The live chezmoi Rig exposes machine auditing and launchd service operations through dedicated commands. Much of that behaviour is already declaration-led, but the wrapper remains tied to chezmoi paths and macOS concepts. A generic operation contract lets private configuration retain those useful actions while the public tool stays catalogue-led.

## Boundary

This item adds the operation schema, resolution, validation, generic command, help, completion, manual, changelog, and tests. It does not hard-code service labels, host paths, workstation data, or arbitrary shell strings; implement provider adapters; migrate private declarations; or permit unrestricted argument pass-through.

## Discussion

### Operation identity

`[operation.TOOL.NAME]` names one declared tool and binds it to a declared provider capability. Required fields are `provider`, `capability`, `mode`, and `description`; repeated `platform`, `argument`, and `allow-argument` fields carry literal values.

### Trust modes

The `observe` and `mutate` modes make the trust transition visible. `status` and `doctor` remain observation-only. A mutate operation runs only after the user explicitly names it with `rig run`.

### Caller arguments

The optional `-- ARGUMENT...` tail accepts only exact values declared by repeated `allow-argument` fields. Rig passes configured and accepted caller arguments as literal boundaries without `eval`, shell parsing, or implicit expansion.

### Public surface

Delivery keeps top-level and command help, Bash and Zsh completion, README command inventory, `rig(1)`, the curated `1.0.0 — in progress` changelog, and Bats coverage aligned.
