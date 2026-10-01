---
id: RIG-CLI-023
area: CLI
title: Design live operational display
theme: cli
horizon: next
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T07:40:30Z
updated_at: 2026-10-01T04:07:40Z
---

## Goal

While Rig performs a long operation in an interactive terminal, the display gives a stable, immediately legible view of the current phase, active work, completed results, and failures, in the spirit of a tmux-style status layout.

## Context

Rig currently has an in-place progress bar on terminal stderr and automatic line events when stderr is redirected. The command-surface and structural work is delivered. [The report contract](../specs/state.md) now covers completed tables and machine-readable projections, while [the progress contract](../specs/orchestration.md) covers non-terminal stderr. This item owns the interactive live experience and must preserve both contracts.

## Boundary

"Tmux-like" is a design direction, not a requirement to run tmux, create panes, or add a runtime dependency. Preserve Rig's Bash 3.2 single-executable contract and stdout report versus stderr progress boundary. Do not make a read-only query appear operational, hide provider diagnostics, or let an interactive display alter JSON output or exit status.

## Current state

The compact progress renderer already protects native output by avoiding cursor redraw during passthrough phases. The user selected this as the final implementation batch after reliability and asked to review command output as well as live operation. Preserve that terminal-ownership boundary instead of introducing competing writers.

## Steps

- [ ] Present representative isolated output for every public command, separating informational queries, mutation previews, operation results and machine-readable output; agree the display interaction before implementation.
- [ ] Prototype the agreed layout; the recommended bounded option is a compact two-line terminal panel containing phase, completed/total work, current qualified target and truthful outcome counts.
- [ ] Explicitly choose whether the first display may yield while native output streams. Recommended scope is to clear the panel before native output, leave a durable task header and redraw afterwards; a permanently anchored pane is a different, larger mediation design.
- [ ] Integrate the agreed panel through shared progress helpers with narrow/dumb-terminal fallback and existing lines/never controls; add no tmux dependency, alternate screen or background animation.
- [ ] Preserve final stdout report bytes, JSON, provider diagnostics, exit status, interruption behavior and the privacy boundary for identifiers versus arbitrary native/authored values.
- [ ] Extend PTY fixtures for widths, resizing, no-final-newline output, failure, interruption, redirection and fallback; run the full gate and provide an acceptance capture.

## Files touched

Shared runtime progress helpers, only the command call sites necessary for terminal ownership, generated executable, PTY/output fixtures, orchestration specification, manual and relevant user guides. Do not rewrite individual command renderers independently.

## Verify

Use isolated terminal fixtures and fake providers. Compare final stdout byte-for-byte with the noninteractive run, test JSON independently, preserve native diagnostic sentinels and signal exit status, and prove narrow/fallback modes leave no cursor artifacts. No workstation mutation is needed to capture examples. Run the full AGENTS.md gate.

## Dependencies / blocks

Sequence after reliability and unattended-contract work so their evidence and result semantics are settled. This is user-selected delivery order, not a missing shared build prerequisite. The display interaction remains a review checkpoint before Ready.

## Delegation

A renderer worker owns the shared terminal helpers and PTY tests. A separate reviewer checks output channels, privacy, fallback and interruption behavior. The coordinator owns the user-facing preview, agreed scope, call-site integration and final gate.

## Documentation impact

### Decision Records

Record any durable terminal-ownership decision if it changes the existing passthrough boundary; do not infer permission for a terminal multiplexer.

### Specifications

Specify supported layout/fallback behavior and maintain the separation between live progress, durable diagnostics and final report data.

### Guides

Show the agreed interactive layout and how to select line-oriented or suppressed progress. Keep read-only command examples quiet.

### Roadmap

This is the last feature batch before the new 0.x release. Broader terminal mediation is not silently admitted if the compact panel proves insufficient.

## Readiness gate

The record remains draft until the user selects yielding versus always-visible native-output behavior. The bounded yielding proposal below is fully specified; it is not silently approved by preparation. If an always-visible region is selected, return to terminal-mediation design before Ready rather than implementing the smaller contract under the same promise.

## Discussion

### Bounded yielding proposal

Use two lines: operation, selected configuration, phase and completed/total count; then the active qualified target and outcome counts. Update only on real events. Clear owned panel lines before native output, emit a durable task header and redraw after the provider returns. Do not capture, buffer or reinterpret native diagnostics. Clear the owned panel before final stdout reports and during interruption; retain signal exit status.

Use line output for redirected stderr, TERM=dumb and widths too small to render safely. Preserve explicit lines and never progress controls. No alternate screen, background animation, permanent scroll region or tmux dependency. PTY fixtures cover shrinking/resizing, output without a final newline, diagnostic sentinels, interruption and separately captured byte-identical stdout text/JSON. Present isolated examples of all ten commands for acceptance, but do not turn informational queries into operations.

### Layout and fallback

Explore a small stable terminal layout with visible phase, task, count, and error regions. Decide how it behaves with narrow terminals, interrupted runs, provider stderr, no terminal, and terminals without reliable cursor control. An explicit simple mode should remain available if richer rendering is introduced.

### Sequencing

Agree the interaction model in chat before implementation. The proposed first version yields terminal ownership during native diagnostics; a persistent pane throughout those calls needs explicit agreement on a larger design. Keep each resulting change independently testable so a live display failure cannot obscure the final outcome report.
