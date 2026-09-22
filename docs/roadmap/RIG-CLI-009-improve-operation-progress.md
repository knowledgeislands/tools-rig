---
id: RIG-CLI-009
title: Improve operation progress
area: CLI
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 8c16b27afc059c93430b3d9283260545cab66ec2
created_at: 2026-09-21T23:41:42Z
updated_at: 2026-09-22T05:08:23Z
---

## Goal

Rig should keep a person meaningfully informed while a command performs slow observation or materialisation, without making fast commands noisy.

## Context

Current progress output is too light to show whether Rig is loading configuration, resolving a profile, waiting on a provider, observing one of many declarations, or applying consequential provider-wide work. A long command can therefore appear idle even when it is healthy. Existing performance work should shorten avoidable delays, but it does not remove the need for useful feedback while genuinely slow work continues.

## Boundary

This work does not add a graphical progress interface, promise duration estimates, expose secrets or private observed values, or compensate for avoidable slowness that belongs in `RIG-CORE-020`. Fast declaration-only commands should remain concise.

## Current state

Rig reports a small number of progress messages on interactive stderr. It does not consistently name the active phase, current declaration or provider, enumerable totals, provider mutation scope, or the distinction between active, waiting, skipped, successful, and failed work.

## Steps

- [x] Define a stable progress vocabulary and interactive versus redirected rendering contract with truthful started, succeeded, skipped, failed, and interrupted outcomes.
- [x] Emit phase changes for configuration discovery, parsing, synthesis, validation, resolution, planning, preflight, tool and resource observation, provider execution, publication staging, resource reconciliation, and completion where those phases are material.
- [x] Include current and total counts for enumerable work only after completion advances the count, identify the current safe-to-display item or provider, and disclose single-item, manifest-wide, or provider-wide scope before consequential work.
- [x] Preserve concise output for fast commands and redact private values, command payloads, credentials, and sensitive observed details.
- [x] Add deterministic tests for slow observation, provider execution, resource reconciliation, failures, skipped work, redirected output, and non-interactive runs.
- [x] Align help, manual, guides, completion-adjacent command documentation, and changelog with the resulting behaviour.

## Files touched

Expected scope includes `bin/rig`, `tests/rig.bats`, `docs/specs/`, `docs/guides/user/`, `man/rig.1`, `README.md`, and `CHANGELOG.md`.

## Verify

Run the complete repository gate and focused fake-provider scenarios proving ordered phase updates, completed-not-started counts, resource coverage, scope disclosure before mutation, readable redirected output, redaction, truthful failure and interruption termination, unchanged stdout, and silence for fast operations that complete below the progress threshold.

## Dependencies / blocks

Coordinate terminology and observation batching with `RIG-CORE-020`; neither record is a build prerequisite for the other. Use the authority and provider-scope decisions from `RIG-CORE-018` when describing consequential work.

## Documentation impact

### Decision Records

No new decision record is expected; progress is presentation of accepted orchestration and trust-boundary behaviour.

### Specifications

Add testable progress-channel, phase, scope, privacy, interactivity, and failure-reporting requirements.

### Guides

Show representative interactive and redirected progress and explain what a person can infer when Rig appears to wait on a provider.

### Roadmap

Coordinate the performance budget with `RIG-CORE-020`; no further progress-specific item is expected.

## Review

### Delivered

Delivered the approved progress contract from immutable baseline `8c16b27afc059c93430b3d9283260545cab66ec2` without changing command flags, provider protocols, publication data, completion definitions, release state, or the batch record. Authored modules remain the source and deterministically assemble the installed `bin/rig` payload.

### Summary of changes

- Replaced started-work counters with explicit phase start, item running, terminal succeeded/skipped/failed, phase finish/failure, and interruption events whose denominator remains the declared work total.
- Added operational-only automatic progress across configuration, resolution, planning, preflight, tool/resource/port/skill/inventory observation, apply and reconciliation, bootstrap, actions, lifecycle and capture, export and publication, and cleanup.
- Added declaration, manifest, and provider-wide scope before consequential invocation; generic and domain-specific signal handlers now terminate active progress while preserving lock, publication, export, and cleanup recovery.
- Kept query commands quiet in automatic mode, stdout byte-stable, and labels bounded to fixed terms plus validated identities rather than paths, locators, arguments, environment values, titles, observations, credentials, or native output.
- Aligned help, README, the command guide, `rig(1)`, `RIG-ORCH-019`, and the in-progress changelog; completions remain unchanged because no public flag or command changed.

### Verification

- `ki repo audit --repo .` — PASS.
- `scripts/assemble-rig --check` — PASS; authored modules and `bin/rig` have no drift.
- `shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers` — PASS.
- `bash -n bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers` — PASS.
- `bats tests/` — PASS, including terminal-count, failure, skipped, interruption, privacy, scope-order, stdout/stderr, and forced/automatic/suppressed progress coverage.
- `mandoc -T lint man/rig.1` — PASS.
- `rumdl check README.md CHANGELOG.md docs/specs/orchestration.md docs/guides/user/commands.md docs/roadmap/RIG-CLI-009-improve-operation-progress.md` — PASS.
- `scripts/benchmark-rig` — PASS: `diag`, `show`, and `list` 2s against 5s budgets; `status` 5s against the 8s budget.
- `RIG_BENCHMARK_BUDGET_SECONDS=2 scripts/benchmark-rig` — PASS: `diag`, `show`, and `list` 2s against strict 2s budgets; `status` 5s against the 8s budget.
- `scripts/smoke-native-providers` — PASS for Homebrew, uv, mise, npm, chezmoi, and mas bounded version probes.

### Outstanding concerns

None within the approved boundary. Native provider diagnostics intentionally continue to share stderr and remain provider-owned; Rig does not claim it can redact output emitted by those executables.

### Post-change review

The implementation preserves `RIG-CORE-020`'s indexed parser, command-local observation cache, Bash 3.2 runtime contract, authored-module assembly, and performance budgets. Progress adds no subprocess, timer, persistent cache, or competing observed state. Review confirmed every old `rig_progress_step` call is removed, no public command option changed, the unrelated batch ledger is untouched, and generated `bin/rig` exactly matches the authored modules.

### Mini recap

Rig now treats progress as a terminal event stream rather than an activity counter: `running` never advances completion, each enumerated item advances once on a terminal outcome, consequential work declares scope before invocation, and failure or interruption closes the active phase truthfully. The durable behaviour lives in `RIG-ORCH-019`; the user procedure and example live in the command guide.

## Done

Accepted 2026-09-22.

## Discussion

### Semantic progress

Progress should describe useful state transitions rather than print activity for its own sake. Counts are useful only when Rig knows the complete work set, and the named current item must be a public identifier or other deliberately safe label.

### Output channels

Human progress belongs on stderr so command data on stdout remains composable. Redirected output should use stable line-oriented events rather than terminal rewriting; interactive rendering may remain simple enough for Bash 3.2 and ordinary terminals.
