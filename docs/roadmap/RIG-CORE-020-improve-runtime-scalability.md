---
id: RIG-CORE-020
title: Improve runtime scalability
area: CORE
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:35:16Z
---

## Goal

Rig should load and query a realistic personal catalogue quickly, observe provider state without avoidable repetition, and remain reviewable as its Bash-only capability grows.

## Context

On the 1,893-line personal configuration, `rig diag` took about 16.8 seconds and `rig show` about 15.7 seconds. A bounded doctor run displayed progress but had only begun the first of 99 tool observations after 30 seconds. The single executable now contains more than 7,000 lines and about 229 functions, while functional large-catalogue tests impose no performance budget.

## Boundary

This work does not change the installed Bash 3.2 and zero-required-runtime contract merely to gain speed. It does not weaken validation, remove progress reporting, cache observed provider state as competing authority, or make completion invoke an expensive model resolution.

## Discussion

### Performance evidence

Introduce representative query and observation budgets, profile parser and repeated lookup cost, and batch provider observations where native systems support it. Declaration-only commands should normally complete quickly enough that progress is unnecessary; slow observation should retain explicit progress.

### Authored structure

One installed executable does not require one authored source file. Consider deterministic assembly from domain-focused Bash modules with a drift check so parser, model, providers, resources, publication, cache, and presentation can be reviewed independently without introducing a runtime dependency.

### Native confidence

Retain exact fake-based contract tests and add a small disposable-machine smoke matrix for real manager commands and platform effects. Performance evidence and native smoke evidence should complement rather than replace deterministic unit coverage.
