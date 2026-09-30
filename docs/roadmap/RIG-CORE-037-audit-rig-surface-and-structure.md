---
id: RIG-CORE-037
area: CORE
title: Audit surface and structure
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T07:38:05Z
updated_at: 2026-09-30T07:38:05Z
---

## Goal

Rig's commands and internal structure have a reviewed, coherent purpose: overlapping ways to achieve the same result are identified, and the Bash runtime remains easy to navigate and change without adding a runtime dependency.

## Context

Rig exposes fourteen commands. Its six authored Bash modules assemble into the single `bin/rig` payload. The largest modules are `src/rig/20-orchestration.bash` at 4,892 lines and `src/rig/10-configuration.bash` at 2,799 lines. Size alone does not show poor factorization, but it makes command and helper ownership worth reviewing across the full runtime.

The roadmap already owns specific overlaps: [RIG-CLI-019](RIG-CLI-019-describe-every-option.md) addresses repeated option descriptions and completion lists, and [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md) addresses duplicate table rendering. The wider review should identify other command, flag, provider, observation, and helper overlaps without duplicating those items. The user wants this structural review before the final output-design wave.

## Boundary

This is an inventory and decision pass. It does not remove a public command, rename a flag, split the runtime into loaded files, change the Bash 3.2 or zero-runtime-dependency contract, or refactor code on the strength of line counts. Any material behaviour change or large rewrite needs its own scoped work and verification.

## Discussion

### Review surfaces

Compare each public command's purpose, inputs, outputs, and side effects against adjacent commands. Trace repeated resolution, provider dispatch, observation, rendering, and outcome paths to their authored modules. Distinguish useful shared helpers from accidental duplication, and preserve the provider-owned semantics beneath Rig's manager-of-managers boundary.

### Result of the review

Record a small surface map, concrete duplication findings with source locations, and a recommendation for each: retain with a clear reason, consolidate within an existing item, or capture a separate bounded change. Identify safe batch groupings only where changes remain independently verifiable. Keep output presentation and the proposed tmux-like running display for the final wave after the surface and structure decisions are settled.
