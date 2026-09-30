---
id: RIG-CORE-037
area: CORE
title: Audit surface and structure
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: b0b716dd004a4b9a053cf4ec0b0ac487c200f124
created_at: 2026-09-30T07:38:05Z
updated_at: 2026-09-30T20:11:30Z
---

## Goal

Rig's commands and internal structure have a reviewed, coherent purpose: overlapping ways to achieve the same result are identified, and the Bash runtime remains easy to navigate and change without adding a runtime dependency.

## Context

Rig exposes fourteen commands. Its six authored Bash modules assemble into the single `bin/rig` payload. The largest modules are `src/rig/20-orchestration.bash` at 4,892 lines and `src/rig/10-configuration.bash` at 2,799 lines. Size alone does not show poor factorization, but it makes command and helper ownership worth reviewing across the full runtime.

The roadmap already owns specific overlaps: [RIG-CLI-019](RIG-CLI-019-describe-every-option.md) addresses repeated option descriptions and completion lists, and [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md) addresses duplicate table rendering. The wider review should identify other command, flag, provider, observation, and helper overlaps without duplicating those items. The user wants this structural review before the final output-design wave.

## Boundary

This is an inventory and decision pass. It does not remove a public command, rename a flag, split the runtime into loaded files, change the Bash 3.2 or zero-runtime-dependency contract, or refactor code on the strength of line counts. Any material behaviour change or large rewrite needs its own scoped work and verification.

## Current state

The six authored modules have distinct broad roles, but no current document maps every command to its resolution and reporting path. Help strings and table rendering have known duplicate owners; the full command and helper overlap has not been assessed.

## Steps

- [x] Inventory every public command's purpose, inputs, outputs, and side effects against CLI help and the Specifications.
- [x] Trace profile resolution, provider dispatch, observation, table rendering, progress, and outcomes to their authored modules.
- [x] Compare adjacent commands and repeated helpers; record each candidate overlap with source locations and a retain, consolidate, or separate-work decision.
- [x] Produce a concise developer-facing surface map, update its guide index, and capture only bounded follow-up work that existing roadmap records do not own.
- [x] Recheck the first three delivery waves against the findings before the final output wave begins.

## Files touched

Developer guide and its index, with roadmap records only when a distinct evidenced follow-up is found. Runtime source is read, not changed by this audit.

## Verify

Cross-check the map against every command dispatched by `src/rig/90-main.bash`, module function definitions, CLI help, and the existing Specification areas. Run the roadmap, authoring, and full repository audits.

## Dependencies / blocks

No build-order dependency. The audit leads the structure wave so later consolidation uses its findings.

## Documentation impact

### Decision Records

Record only a durable architectural decision that the audit actually changes.

### Specifications

No behaviour changes in the audit; any proposed change receives its own record.

### Guides

The developer guide records the durable surface map and its index links to it.

### Roadmap

Capture only distinct evidenced follow-ups without duplicating current items.

## Review

### Delivered

The fourteen-command surface and six authored module responsibilities are mapped in the developer guide from baseline `b0b716dd004a4b9a053cf4ec0b0ac487c200f124`. The output and option duplication already have owners; the distinct source factorization follow-up is [RIG-CORE-038](RIG-CORE-038-factor-orchestration-modules.md). No runtime behaviour was changed.

### Change Summary

Added `docs/guides/developer/command-surface.md`, linked it from the developer index, and captured one source-only follow-up. The planned structure, safety, core-behaviour, and final-output waves remain distinct; factorization joins the structure wave before later source edits.

### Verification

Cross-checked all command branches in `src/rig/90-main.bash`, the module function lists, CLI help, and the Specification areas. `ki repo audit --repo .`, focused Guides and authoring audits, `git diff --check`, ShellCheck, Bash syntax, assembly check, isolated-state benchmark, native-provider smoke, Bats, and manual lint passed during this delivery.

### Outstanding concerns

The default benchmark still inherits the runner's state and fails in its `status` case here; the isolated-state invocation passes. RIG-CORE-033 owns that defect. The factorization change is planned and has not yet been implemented.

### Post-change review

The guide gives maintainers a concrete route from command to source owner and distinguishes useful shared paths from duplicated presentation. It preserves the single-file runtime boundary and leaves each proposed code change to its own verification.

### Mini recap

The surface audit is delivered for acceptance review. Follow-up routes are the existing option and renderer records plus RIG-CORE-038 for source structure; no separate command-removal proposal is supported by the current evidence.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Review surfaces

Compare each public command's purpose, inputs, outputs, and side effects against adjacent commands. Trace repeated resolution, provider dispatch, observation, rendering, and outcome paths to their authored modules. Distinguish useful shared helpers from accidental duplication, and preserve the provider-owned semantics beneath Rig's manager-of-managers boundary.

### Result of the review

Record a small surface map, concrete duplication findings with source locations, and a recommendation for each: retain with a clear reason, consolidate within an existing item, or capture a separate bounded change. Identify safe batch groupings only where changes remain independently verifiable. Keep output presentation and the proposed tmux-like running display for the final wave after the surface and structure decisions are settled.
