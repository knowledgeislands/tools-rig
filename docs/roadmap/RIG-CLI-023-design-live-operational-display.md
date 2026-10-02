---
id: RIG-CLI-023
area: CLI
title: Design live operational display
theme: cli
horizon: next
status: done
blocks: []
blocked_by: []
baseline_ref: 617d4343ae679c8e74158cff9a0f5f053ab74837
created_at: 2026-09-30T07:40:30Z
updated_at: 2026-10-02T01:37:43Z
---

## Goal

While Rig performs a long operation in an interactive terminal, the display gives a stable, immediately legible view of the current phase, active work, completed results, and failures, in the spirit of a tmux-style status layout.

## Context

At the implementation baseline, Rig had an in-place progress bar on terminal stderr and automatic line events when stderr was redirected. The command-surface and structural work is delivered. [The report contract](../specs/state.md) covers completed tables and machine-readable projections, while [the progress contract](../specs/orchestration.md) covers stderr progress. This item owns the interactive live experience and must preserve both contracts.

## Boundary

"Tmux-like" is a design direction, not a requirement to run tmux, create panes, or add a runtime dependency. Preserve Rig's Bash 3.2 single-executable contract and stdout report versus stderr progress boundary. Do not make a read-only query appear operational, hide provider diagnostics, or let an interactive display alter JSON output or exit status.

## Current state

The reliability work is accepted and pruned. The user approved proceeding after reviewing established terminal conventions, with an APT-style footer preferred and native prompts, diagnostics and Bash-only portability preserved. Feasibility review established that a bottom-anchored footer is possible without an extra runtime, but an always-visible footer alongside arbitrary native terminal writers is not safely enforceable. The adaptive footer is delivered and awaits human acceptance: anchored during Rig-owned work, fully removed during native-capable items, restored after return. This is not a terminal multiplexer or an APT-equivalent child PTY.

## Steps

- [x] Record the terminal-feasibility assessment and implement the approved adaptive ownership boundary without a child PTY, native-output mediation or new runtime dependency.
- [x] Replace the bar with a bottom-anchored two-line stderr footer showing validated command and resolved selection identifiers, phase, completed/total count, qualified target and phase-local outcome counts.
- [x] Make native-capable items yield before their entire semantic operation, including observation and preflight; leave a durable task header, restore full margins and a safe cursor position, then resume at a safe boundary after return. Default unclassified phases to native-capable; explicitly opt proven Rig-owned phases into continuous rendering.
- [x] Fall back to line events for redirected stderr, unsupported or dumb terminals, failed geometry discovery and terminals smaller than eight rows or sixty columns. Preserve lines/never and automatic declaration-query silence; handle resize only at safe boundaries without animation, cursor hiding or alternate screens.
- [x] Preserve final stdout report bytes, JSON, provider diagnostics, exit status, interruption behavior and the privacy boundary for identifiers versus arbitrary native/authored values.
- [x] Add isolated stdout-equivalence coverage for all ten public commands, including previews, text/JSON results and discovery/export artifacts where supported. Extend PTY fixtures for widths, resizing, native ANSI/no-final-newline output, failure, interruption, redirection, fallback and idempotent cleanup; run the full gate and provide acceptance captures.

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

## Review

### Delivered

Implemented the approved adaptive terminal footer from baseline `617d4343ae679c8e74158cff9a0f5f053ab74837` in delivery commit `7f7be58fd028de60e1daec0cf5dd098ed85a9e8c`. The footer is present during Rig-owned work and yields for complete native-capable items. No new runtime dependency, child PTY, native-output mediation, provider semantics, command or flag was introduced. Release, cross-repository changes, human acceptance and pruning remain outside this delivery.

### Change Summary

`src/rig/00-runtime.bash` replaces the inline bar with bounded two-line rendering, validated metadata, optional geometry discovery, conservative resize cleanup and nested suspension. Configuration and planning explicitly opt into owned rendering; other phases yield by default. Main, buffered mutation reports, resource locks and export cleanup compose terminal restoration with their existing lifecycle. The generated `bin/rig` is current.

The command guide, RIG-ORCH-019 specification, man page, help and Unreleased changelog describe the same behavior and limitations. Completion and README command syntax need no changes because the public surface is unchanged. New terminal and all-command output-contract fixtures accompany updated existing progress assertions. On uncertain resize/reflow, old footer text may remain in scrollback; no uncertain diagnostic coordinates are erased. This implements the disclosed bounded design without expanding it.

### Verification

The complete AGENTS.md gate passed on 2026-10-01 against the integrated delivery: `ki repo audit --repo .`; ShellCheck and Bash syntax checks for the assembled executable, installer, authored modules and named scripts; `scripts/assemble-rig --check`; `scripts/benchmark-rig`; `scripts/smoke-native-providers`; `RIG_TEST_PYTHON=/opt/homebrew/opt/python@3.14/bin/python3.14 bats tests/ </dev/null`; and `mandoc -T lint man/rig.1`. All 375 Bats tests passed. The final gate log is local, disposable evidence at `/tmp/rig-cli023.nbILVQ/final.log`; the 354-test baseline gate also passed before implementation. Formatting, a fresh repository audit and `git diff --check` passed after documentation finalisation.

Fourteen focused PTY tests passed independently on the final renderer. Seven output-contract groups exercise all ten commands with 33 paired cases plus a real controlling-terminal prompt: stdout bytes, JSON, exported artifacts, provider diagnostics, terminal geometry/modes and native failure outcomes remain separate and unchanged. The independent source reviewer found no blocking issue in native boundaries, shared return-value use, resizing, subprocess cleanup, locks or export traps; that review does not claim another independent test run.

Acceptance captures are local temporary evidence: terminal fixtures at `/var/folders/l7/8bd9jm7j66xgt1vx3bppyh740000gn/T/bats-run-ERzTAR`, and paired all-command captures at `/var/folders/l7/8bd9jm7j66xgt1vx3bppyh740000gn/T/bats-run-v3xloj`. The latter retain baseline/TTY stdout, stderr, status and geometry, with the prompt case in `test/7`. They can be regenerated using the two committed suites with `bats --no-tempdir-cleanup` and the test-only Python override above. These are isolated fake-provider captures, not workstation mutations or permanent product artifacts.

### Outstanding concerns

No unresolved implementation blocker or failing check. Human visual acceptance in the user's usual terminal remains outstanding. The fixture-only VT/reflow model is bounded evidence, not exhaustive terminal emulation. Native work intentionally owns the whole terminal while running, so the footer is not continuously visible. A separating newline may add a blank line; resized footer text may remain in scrollback; uncatchable termination cannot guarantee cleanup. These are documented design limits, not hidden follow-on requirements.

### Post-change review

The delivered behavior meets the approved live-display goal within the Bash-only and native-execution boundaries. The highest regression risks—terminal ownership, prompt interaction, resize cleanup, signals and stdout contamination—have targeted fixtures and full-suite coverage. The item is ready for human acceptance, not self-accepted. If uninterrupted native-time visibility is wanted later, it requires a separately approved mediation design rather than a renderer tweak.

### Mini recap

Adaptive footer delivered, all ten command contracts covered, wraparound documentation aligned, full gate clean and independent review complete. Await human acceptance before done/prune. The ownership and resize lessons are recorded in the existing guide and specification; no additional policy or Decision Record is needed. The release item remains separate, and no push or release was performed.

## Done

Accepted 2026-10-02 by Kris Brown on the review packet above.

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
