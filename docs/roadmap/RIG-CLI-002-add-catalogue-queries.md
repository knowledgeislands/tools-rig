---
id: RIG-CLI-002
area: CLI
title: Add catalogue queries
theme: cli
horizon: triage
status: draft
blocks: [RIG-DIST-001, RIG-MIG-004]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-16T08:28:40Z
---

# RIG-CLI-002: Add catalogue queries

## Goal

People can inspect their declared rig through `show`, `list`, and `explain` commands without executing provider code.

## Context

The catalogue becomes useful before any machine mutation when it can answer what the rig contains, which tools serve a category or profile, and why a tool belongs.

## Boundary

This item covers deterministic human-facing read queries. It does not observe machine state, apply provider changes, export a public site, or define private catalogue contents.

## Discussion

### Query language

The initial surface is `rig show [--profile NAME]`, `rig list [--category NAME] [--profile NAME]`, and `rig explain TOOL`. Output should distinguish explicit profile membership, inherited membership, required relationships, and selected provider binding where relevant.

### Execution safety

These queries read and resolve inert declarations only. They never invoke a built-in or custom provider.
