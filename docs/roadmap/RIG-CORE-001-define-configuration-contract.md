---
id: RIG-CORE-001
area: CORE
title: Define configuration contract
theme: orchestration
horizon: triage
status: draft
blocks: [RIG-CORE-002]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-CORE-001: Define configuration contract

## Goal

Rig has a documented, versioned configuration contract for profiles, targets, native manifests, action support, ordering, and platform conditions.

## Context

Rig must remain fully customisable while its core depends only on Bash. The format must be practical to parse without an external runtime and must distinguish trusted executable extensions from declarative data.

## Boundary

This item defines the configuration contract but does not implement orchestration or choose a workstation's package list.

## Discussion

### Trust boundary

A sourced shell configuration maximises flexibility but executes arbitrary code. A line-oriented declarative grammar is safer but needs explicit rules for argument boundaries, repeated values, and evolution. The contract should make that choice visible rather than hiding execution behind a data-looking file.

### Native authority

Targets should be able to consume their own manifests, such as a Brewfile, without Rig becoming another package resolver. Inline native package identifiers may remain an optional convenience if their ownership is explicit.
