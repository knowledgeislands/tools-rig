---
id: RIG-CLI-023
area: CLI
title: Design live operational display
theme: cli
horizon: soon
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T07:40:30Z
updated_at: 2026-09-30T20:07:25Z
---

## Goal

While Rig performs a long operation in an interactive terminal, the display gives a stable, immediately legible view of the current phase, active work, completed results, and failures, in the spirit of a tmux-style status layout.

## Context

Rig currently has an in-place progress bar on terminal stderr and automatic line events when stderr is redirected. The command-surface and structural work is delivered. [The report contract](../specs/state.md) now covers completed tables and machine-readable projections, while [the progress contract](../specs/orchestration.md) covers non-terminal stderr. This item owns the interactive live experience and must preserve both contracts.

## Boundary

"Tmux-like" is a design direction, not a requirement to run tmux, create panes, or add a runtime dependency. Preserve Rig's Bash 3.2 single-executable contract and stdout report versus stderr progress boundary. Do not make a read-only query appear operational, hide provider diagnostics, or let an interactive display alter JSON output or exit status.

## Shaping

Settle a compact terminal layout and a testable fallback with a captured interactive fixture before promoting this item. The display must preserve final stdout, stderr progress, and the existing `RIG_PROGRESS` control. The preceding surface audit and output-contract work establish which information belongs in each region.

## Discussion

### Layout and fallback

Explore a small stable terminal layout with visible phase, task, count, and error regions. Decide how it behaves with narrow terminals, interrupted runs, provider stderr, no terminal, and terminals without reliable cursor control. An explicit simple mode should remain available if richer rendering is introduced.

### Sequencing

Agree the interaction model after the command-surface review, then revise the existing report and progress plans where their rendering assumptions change. Keep each resulting change independently testable so a live display failure cannot obscure the final outcome report.
