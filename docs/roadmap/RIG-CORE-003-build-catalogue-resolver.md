---
id: RIG-CORE-003
area: CORE
title: Build catalogue resolver
theme: orchestration
horizon: triage
status: draft
blocks: [RIG-CORE-002, RIG-CLI-002, RIG-CLI-003]
blocked_by: [RIG-CORE-001]
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-CORE-003: Build catalogue resolver

## Goal

Rig can parse inert configuration and resolve categories, tools, relationships, profiles, platforms, and provider bindings deterministically in Bash 3.2.

## Context

Catalogue resolution is the shared read model for local queries, provider orchestration, and public export. It must exist before those consumers implement separate interpretations of the configuration contract.

## Boundary

This item builds parsing, validation, and resolution. It does not invoke providers, observe machine state, mutate the machine, render a public site, or migrate personal declarations.

## Discussion

### Parser boundary

The parser accepts only the documented versioned grammar, recognised sections and keys, repeated list fields, and literal values. It rejects ambiguity, unknown references, cycles, and executable syntax without sourcing configuration.

### Resolution boundary

Profile composition and required-tool expansion produce a deterministic selected tool set. Binding selection respects platforms and fails when more than one compatible provider remains.
