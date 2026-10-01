---
id: RIG-CLI-023
area: CLI
title: Design live operational display
theme: cli
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T07:40:30Z
updated_at: 2026-10-01T19:29:52Z
---

## Goal

While Rig performs a long operation in an interactive terminal, the display gives a stable, immediately legible view of the current phase, active work, completed results, and failures, in the spirit of a tmux-style status layout.

## Context

Rig currently has an in-place progress bar on terminal stderr and automatic line events when stderr is redirected. The command-surface and structural work is delivered. [The report contract](../specs/state.md) now covers completed tables and machine-readable projections, while [the progress contract](../specs/orchestration.md) covers non-terminal stderr. This item owns the interactive live experience and must preserve both contracts.

## Boundary

"Tmux-like" is a design direction, not a requirement to run tmux, create panes, or add a runtime dependency. Preserve Rig's Bash 3.2 single-executable contract and stdout report versus stderr progress boundary. Do not make a read-only query appear operational, hide provider diagnostics, or let an interactive display alter JSON output or exit status.

## Current state

The reliability work is accepted and pruned. The user approved proceeding after reviewing established terminal conventions, with an APT-style footer preferred and native prompts, diagnostics and Bash-only portability preserved. Feasibility review established that a bottom-anchored footer is possible without an extra runtime, but an always-visible footer alongside arbitrary native terminal writers is not safely enforceable. Implement an adaptive footer: anchored during Rig-owned work, fully removed during native-capable items, restored after return. This is not a terminal multiplexer or an APT-equivalent child PTY.

## Steps

- [ ] Record the terminal-feasibility assessment and implement the approved adaptive ownership boundary without a child PTY, native-output mediation or new runtime dependency.
- [ ] Replace the bar with a bottom-anchored two-line stderr footer showing validated command and resolved selection identifiers, phase, completed/total count, qualified target and phase-local outcome counts.
- [ ] Make native-capable items yield before their entire semantic operation, including observation and preflight; leave a durable task header, restore full margins and a safe cursor position, then resume at a safe boundary after return. Default unclassified phases to native-capable; explicitly opt proven Rig-owned phases into continuous rendering.
- [ ] Fall back to line events for redirected stderr, unsupported or dumb terminals, failed geometry discovery and terminals smaller than eight rows or sixty columns. Preserve lines/never and automatic declaration-query silence; handle resize only at safe boundaries without animation, cursor hiding or alternate screens.
- [ ] Preserve final stdout report bytes, JSON, provider diagnostics, exit status, interruption behavior and the privacy boundary for identifiers versus arbitrary native/authored values.
- [ ] Add isolated stdout-equivalence coverage for all ten public commands, including previews, text/JSON results and discovery/export artifacts where supported. Extend PTY fixtures for widths, resizing, native ANSI/no-final-newline output, failure, interruption, redirection, fallback and idempotent cleanup; run the full gate and provide acceptance captures.

## Files touched

`src/rig/00-runtime.bash`, ownership annotations in configuration/orchestration call sites, command metadata and buffered-report cleanup in main/commands, generated `bin/rig`, existing progress assertions, new `tests/rig-progress.bats` and its PTY helper, new `tests/rig-output-contract.bats`, orchestration specification, manual, command guide and changelog. Do not rewrite individual report renderers, add flags or alter provider execution semantics.

## Verify

Use isolated terminal fixtures and fake providers. Compare final stdout byte-for-byte with the noninteractive run, test JSON independently, preserve native diagnostic sentinels and signal exit status, and prove narrow/fallback modes leave no cursor artifacts. No workstation mutation is needed to capture examples. Run the full AGENTS.md gate.

## Dependencies / blocks

Reliability and unattended-contract work is delivered and accepted. This is the selected final feature batch before release; release execution and cross-repository migration remain outside this item. User instruction on 2026-10-01 authorises proceeding with the researched bounded design; uninterrupted visibility during native execution is explicitly not promised.

## Delegation

The renderer worker owns `src/rig/00-runtime.bash`, `tests/rig-progress.bats` and `tests/helpers/tty-progress.py`; the output-contract worker owns only `tests/rig-output-contract.bats`. Both read this plan, existing isolated fixtures and provider/output contracts. The independent reviewer owns no files and assesses channels, privacy, geometry, interruption, cleanup and all native execution boundaries. The coordinator owns other call sites, existing tests, documentation, assembly, lifecycle, Git and the final gate. Shared primary checkout, disjoint file ownership, no worker Git writes or live providers. Workers stop for runtime dependencies, a new provider contract, an always-visible native pane or changed stdin/signals. Return touched paths, exact focused checks, limitations and review findings; integration waits for both lanes and independent review. Fixtures must call `rig_test_isolate` first and use only fake providers.

## Documentation impact

### Decision Records

The existing native provider execution boundary remains authoritative: rendering yields instead of intercepting native execution. No new authority decision or terminal multiplexer is introduced; explain this constraint in the existing guide and accepted progress contract.

### Specifications

Specify supported layout/fallback behavior and maintain the separation between live progress, durable diagnostics and final report data.

### Guides

Show the agreed interactive layout and how to select line-oriented or suppressed progress. Keep read-only command examples quiet.

### Roadmap

This is the last feature batch before the new 0.x release. Broader terminal mediation is not silently admitted if the compact panel proves insufficient.

## Readiness gate

The user requested implementation after the standards/examples review. The selected design is an adaptive bottom footer, not uninterrupted native-output isolation. Feasibility review and the explicit safe fallback were reported before implementation. Ready covers that bounded design only; if tests show it cannot preserve prompts, diagnostics, reports or terminal restoration, stop rather than add mediation or weaken the contract.

## Discussion

### Implementation preparation

The reliability work is accepted and pruned. Read-only implementation review confirmed that public mutation wrappers already buffer Rig's final stdout reports, while native provider stdout and stderr stream immediately to stderr. The yielding design needs no additional provider-output buffering or per-report-row redraw hooks.

Yielding means the panel steps aside for the entire native call, even when that call is quiet. A durable task header stays visible; the panel returns after the call. An always-visible pane cannot be promised by these helpers alone. This constraint survives the user-approved move from the earlier inline-panel proposal to the adaptive bottom-anchored design.

The renderer lane owns shared progress helpers and isolated PTY fixtures. The coordinator owns fresh command and resolved selection metadata, existing progress assertions, documentation and assembly. Labels may contain validated command, profile, platform and qualified target identifiers, never configuration paths, arguments or native output. Before selection resolution, show pending selection rather than stale metadata.

Acceptance coverage spans all ten commands: configuration-free help and completion; init preview/creation; show tables and item/JSON views; status observations, unmanaged inventory and history; doctor findings and diagnostics; apply and upgrade previews/results; capture inventory/proposals; and export confirmation with its separate publication tree. Compare stdout and stderr separately, freeze fixture time for byte comparisons, and retain the final outcome ordering. Informational queries must stay quiet under automatic progress.

### Adaptive footer contract

Use two bottom-anchored lines: operation, validated selected profile/platform identifiers (or selection pending), phase and completed/total count; then the active qualified target and outcome counts. Update only on real events. Reserve the bottom rows while Rig owns the terminal. Clear only owned rows and restore full margins plus a safe cursor position before a native-capable item, emit a durable task header and redraw after return. Yielding spans the entire call even when quiet. Do not capture, buffer or reinterpret native diagnostics. A separating newline after native execution may add a blank line when output already ended with LF; it prevents appending a footer to a partial diagnostic without inspecting that output. Clear before final stdout reports and during handled interruption; retain signal status and reconciliation-lock cleanup, including inside the buffered-report subshell.

Use line output for redirected stderr, unsupported TERM, unavailable geometry and small terminals. Use optional existing system geometry discovery, never consume terminal replies or change shared terminal dimensions/modes. Re-measure at rendering boundaries; WINCH may invalidate geometry but must not redraw during native execution. Nested suspension must never resume early. No alternate screen, cursor hiding, background animation, native output filtering or tmux dependency. Restore margins on normal completion, failure and handled HUP/INT/TERM; SIGKILL cannot promise cleanup. Present isolated examples of all ten commands for acceptance, but do not turn declaration-only queries into operations.

### Layout and fallback

Explore a small stable terminal layout with visible phase, task, count, and error regions. Decide how it behaves with narrow terminals, interrupted runs, provider stderr, no terminal, and terminals without reliable cursor control. An explicit simple mode should remain available if richer rendering is introduced.

### Sequencing

The user approved proceeding from the standards review. APT supplies the anchoring model, not an implied PTY runtime; BuildKit supplies the interactive/plain distinction, not a new machine-output protocol. Keep each change independently testable so a live display failure cannot obscure the final outcome report. Broader native-terminal mediation requires a separate design decision.
