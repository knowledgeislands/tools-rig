---
id: RIG-CORE-025
area: CORE
title: Isolate state in tests
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-25T15:00:00Z
---

## Goal

No test can read or write the machine's real Rig state, whichever test file it lives in.

## Context

Rig now writes a run report beneath `RIG_STATE_HOME`, so the state directory is no longer read-only territory for the suite. `tests/rig-lifecycle.bats` pins `RIG_STATE_HOME` into a per-test directory. Seven of the thirteen bats files never pin it at all — `rig-artifacts`, `rig-bootstrap-staging`, `rig-human-config`, `rig-model-boundaries`, `rig-performance`, `rig-projection`, and `rig-uv-extras` — so an ambient `XDG_STATE_HOME` reaches them, and in the files that do pin it the isolation is per invocation rather than per file.

Nothing fails today because no test in those files writes state. The gap is worth closing before one does, since the first symptom would be a suite that mutates the developer's own machine.

## Boundary

This covers state isolation only. It does not restructure the suite, unify the existing per-invocation `env` calls into a shared helper as a matter of style, or extend to the config, data, and cache homes beyond what the same mechanism gives for free.

## Discussion

### Where the pin belongs

A per-file `setup` that exports all four XDG overrides into `BATS_TEST_TMPDIR` would close it uniformly, but the suite currently prefers explicit `env` prefixes on each `run`, which makes each test readable in isolation. Either is defensible; mixing them silently is what leaves the gap.
