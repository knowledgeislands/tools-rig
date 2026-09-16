---
id: RIG-CORE-004
area: CORE
title: Optimise catalogue queries
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-16T12:57:39Z
updated_at: 2026-09-16T12:57:39Z
---

# RIG-CORE-004: Optimise catalogue queries

## Goal

Catalogue diagnostics and queries remain responsive for a realistic personal catalogue while preserving Bash 3.2, deterministic results, and the no-runtime-dependency contract.

## Context

An isolated render of the current 89-tool private catalogue is valid, but observed execution is approximately five seconds for `diag`, six seconds for `list`, and seven seconds for `show` on the target Mac. The current indexed-array model repeatedly scans sections and fields during validation and resolution.

## Boundary

This item profiles and optimises the existing Bash implementation without changing schema meaning, query output, provider boundaries, or requiring a runtime dependency. It does not reduce the private catalogue to conceal the cost or combine performance work with migration.

## Discussion

### Evidence first

Planning should add a deterministic large-catalogue fixture, establish repeatable before-and-after measurements, identify repeated scans, and set a proportionate target before selecting an indexing or caching strategy.

### Portability

Any optimisation must work in macOS Bash 3.2 and retain the current sourceable test seam. Associative arrays and external parsers are not available solutions.
