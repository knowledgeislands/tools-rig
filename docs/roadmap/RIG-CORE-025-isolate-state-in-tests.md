---
id: RIG-CORE-025
area: CORE
title: Isolate state in tests
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-30T09:39:54Z
---

## Goal

The suite proves that its default test environment cannot reach the runner's real Rig state or destructive macOS adapters.

## Context

The original plan predated `rig_test_isolate`. That helper now runs first in every Bats `setup`, removes inherited XDG and Rig homes, moves `HOME` into each test's temporary tree, and stubs launchctl and the destructive macOS writers. The initial directory and writer isolation is implemented, but the suite lacks a direct guard that proves the helper remains in force, and it has not been run against a hostile ambient state home.

## Boundary

This closes the remaining verification gap in the existing helper. It does not rework every test invocation, replace the helper with per-file XDG exports, or stub native package managers; [RIG-CORE-033](RIG-CORE-033-make-tests-machine-independent.md) owns provider fixtures and the benchmark.

## Current state

All thirteen Bats files call `rig_test_isolate` first in `setup`. The helper creates an isolated home and inert mutator stubs. Existing per-invocation overrides still take precedence, which is intentional for tests of specific paths.

## Steps

- [ ] Add a focused test proving the helper's unqualified state path is beneath `BATS_TEST_TMPDIR` and its default destructive command overrides point to the test stubs.
- [ ] Run the suite with an inherited hostile XDG state home and assert the helper still chooses only its temporary state path.
- [ ] Keep the existing explicit per-invocation overrides and document that the helper, rather than repeated XDG exports, owns default containment.

## Files touched

`tests/helpers/isolate.bash`, one focused Bats file, and the test-isolation note in `AGENTS.md`.

## Verify

Run the focused helper assertion and `bats tests/ </dev/null` with a temporary hostile `XDG_STATE_HOME`; verify the path and stub argv assertions, not only a green suite. The temporary hostile directory is created outside the repository and removed only after its exact path is checked.

## Dependencies / blocks

Nothing blocks this. It shares the test-containment surface with [RIG-CORE-036](RIG-CORE-036-resolve-mutators-absolutely.md), while [RIG-CORE-033](RIG-CORE-033-make-tests-machine-independent.md) owns the broader provider matrix.

## Documentation impact

### Decision Records

None. Test isolation decides nothing about Rig's behaviour or contracts.

### Specifications

None. No behaviour-level contract changes.

### Guides

Update the existing note to name the helper as the containment owner and the focused guard as its proof.

### Roadmap

Remove the duplicate isolation guard from [RIG-CORE-033](RIG-CORE-033-make-tests-machine-independent.md).

## Discussion

### Existing containment

The helper landed after this record was planned, so repeating its old per-file XDG export plan would add a second isolation mechanism. A direct guard tests the actual current contract and leaves each test free to override its own paths deliberately.
