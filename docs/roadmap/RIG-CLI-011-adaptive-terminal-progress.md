---
id: RIG-CLI-011
title: Render adaptive terminal progress
area: CLI
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 38887870c4099679f92d317b9b7133439df25002
created_at: 2026-09-22T06:08:41Z
updated_at: 2026-09-22T06:35:44Z
---

## Goal

Rig should show operational progress as one compact, continuously updated terminal line while retaining durable line-oriented events for logs and automation.

## Context

`RIG-CLI-009` established truthful phase, count, outcome, scope, privacy, and interruption semantics. Its deliberately line-oriented renderer is useful when stderr is captured, but creates too many terminal lines during normal interactive use. The event model is sound; this item changes presentation according to the output context.

## Boundary

This work changes only Rig-authored progress rendering. It must not change command stdout, provider protocols, provider-owned diagnostics, operation ordering, outcome accounting, public data, or introduce a runtime dependency. It does not add timing estimates, background refresh, colour, Unicode requirements, or a graphical interface.

## Current state

Rig already emits truthful operational progress on stderr and keeps stdout deterministic. Interactive and forced redirected progress currently share the same line-per-event renderer. The approved replacement preserves the event semantics while rendering them differently:

- In operational `auto` mode with terminal stderr, render an ASCII progress bar on one in-place line, including phase, completed and total counts, and current safe identifier.
- On successful completion, failure, or interruption, terminate the active line with one truthful summary and a newline.
- Keep provider diagnostics unbuffered and provider-owned; when they interrupt the transient line, redraw the bar on the next Rig event.
- Preserve line-oriented progress when stderr is redirected and `RIG_PROGRESS=always` is set.
- Add `RIG_PROGRESS=lines` to request line-oriented progress even on a terminal.
- Preserve `RIG_PROGRESS=never`; invalid values continue to follow safe automatic behaviour.
- Keep stdout byte-stable and keep declaration-only query commands quiet.
- Use Bash 3.2-compatible built-ins only; do not require `tput`, terminal-size commands, timers, or helper processes.

## Steps

- [x] Separate progress enablement from terminal versus line rendering mode.
- [x] Add fixed-width ASCII bar rendering, safe label compaction, in-place clearing, and final-line termination.
- [x] Preserve the existing line event grammar for redirected and explicitly line-oriented output.
- [x] Keep provider diagnostics unbuffered and redraw the bar on the next Rig event.
- [x] Add pseudo-terminal and redirected-channel Bats coverage for progress shape, counts, privacy, failures, interruption, modes, and unchanged stdout.
- [x] Align the orchestration Specification, user command guide, manual, changelog, release surfaces, and assembled executable.
- [x] Run the complete repository verification gate and revalidate the pending v0.3.0 candidate.

## Files touched

- `src/rig/00-runtime.bash` and assembled `bin/rig` for rendering state and terminal output.
- `tests/` for terminal and redirected-channel behaviour.
- `docs/specs/orchestration.md`, `docs/guides/user/commands.md`, `man/rig.1`, and `CHANGELOG.md` for the public contract.
- This roadmap record and issue ledger for delivery evidence.

## Verify

- Run focused Bats coverage for adaptive and line-oriented progress during implementation.
- Run assembly drift, Bash 3.2 syntax, ShellCheck, full Bats, manual lint, benchmark, native-provider smoke, and complete KI repository audit before review.

## Dependencies / blocks

No delivery dependency. Preserve the pending v0.3.0 release candidate and the independently captured `RIG-CLI-010` machine-readable status work.

## Documentation impact

### Decision Records

No new Decision Record expected. This is a presentation refinement within the accepted progress-channel boundary.

### Specifications

Update `RIG-ORCH-019` to distinguish transient terminal rendering from durable redirected event rendering.

### Guides

Explain automatic bar mode, forced line mode, redirected behaviour, provider diagnostics, and the unchanged stdout contract.

### Roadmap

Record implementation and verification evidence here; do not create a second progress item.

## Review

### Delivered

Delivered adaptive progress without changing stdout, provider protocols, operation ordering, native diagnostic ownership, or the Bash 3.2 runtime boundary.

Accepted by the repository owner on 2026-09-22.

### Summary of changes

- Interactive operational phases now rewrite a 16-cell ASCII bar with truthful counts, safe current identity, scope, and outcome.
- Redirected `RIG_PROGRESS=always` output preserves the existing event grammar; `RIG_PROGRESS=lines` explicitly selects it on any stderr.
- Automatic and invalid modes remain quiet outside an operational terminal, while `never` still suppresses Rig-authored progress.

### Verification

Evidence:

- Focused progress, help, command-inventory, and release-surface Bats cases pass.
- Full Bats suite passes with 223 cases, including the cross-platform pseudo-terminal bar case.
- ShellCheck and Bash syntax pass for the assembled executable, authored modules, installer, and scripts; assembly is byte-identical.
- `mandoc`, Rumdl, the performance benchmark, native-provider smoke, and the complete 16-skill KI repository audit pass.

### Outstanding concerns

Provider-owned diagnostics remain unbuffered and can interrupt the transient bar. The next Rig event clears and redraws it; Rig does not hide or rewrite native output.

### Post-change review

The implementation retains the completed-not-started event semantics from `RIG-CLI-009`, uses Bash built-ins only, and leaves deterministic stdout and public data unchanged. The bar represents completed items, not elapsed time.

### Mini recap

Interactive operations now present compact progress while redirected logs remain durable and machine-friendly.

## Done

Accepted by the repository owner on 2026-09-22. The implementation remains part of the pending v0.3.0 candidate.

## Discussion

The renderer should prefer honest, stable information over animation. A progress bar advances only when an item reaches a terminal outcome; it does not imply elapsed-time percentage or estimated completion time.

Implementation keeps native diagnostics streaming directly rather than buffering or wrapping provider stderr. A diagnostic may interrupt the transient display; the next Rig event clears and redraws the bar. This preserves provider timing, native exit semantics, and the manager-of-managers boundary.
