---
id: RIG-CLI-009
title: Improve operation progress
area: CLI
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:41:42Z
updated_at: 2026-09-21T23:43:26Z
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

- [ ] Define a stable progress vocabulary and interactive versus redirected rendering contract with truthful started, succeeded, skipped, failed, and interrupted outcomes.
- [ ] Emit phase changes for configuration discovery, parsing, synthesis, validation, resolution, planning, preflight, tool and resource observation, provider execution, publication staging, resource reconciliation, and completion where those phases are material.
- [ ] Include current and total counts for enumerable work only after completion advances the count, identify the current safe-to-display item or provider, and disclose single-item, manifest-wide, or provider-wide scope before consequential work.
- [ ] Preserve concise output for fast commands and redact private values, command payloads, credentials, and sensitive observed details.
- [ ] Add deterministic tests for slow observation, provider execution, resource reconciliation, failures, skipped work, redirected output, and non-interactive runs.
- [ ] Align help, manual, guides, completion-adjacent command documentation, and changelog with the resulting behaviour.

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

## Discussion

### Semantic progress

Progress should describe useful state transitions rather than print activity for its own sake. Counts are useful only when Rig knows the complete work set, and the named current item must be a public identifier or other deliberately safe label.

### Output channels

Human progress belongs on stderr so command data on stdout remains composable. Redirected output should use stable line-oriented events rather than terminal rewriting; interactive rendering may remain simple enough for Bash 3.2 and ordinary terminals.
