---
id: RIG-CORE-025
area: CORE
title: Isolate state in tests
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 2fe4ca00b43b4e74a68e32046ae52765bc4bfc97
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-30T20:11:30Z
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

- [x] Add a focused test proving the helper's unqualified state path is beneath `BATS_TEST_TMPDIR` and its default destructive command overrides point to the test stubs.
- [x] Run the suite with an inherited hostile XDG state home and assert the helper still chooses only its temporary state path.
- [x] Keep the existing explicit per-invocation overrides and document that the helper, rather than repeated XDG exports, owns default containment.

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

## Review

### Delivered

From baseline `2fe4ca00b43b4e74a68e32046ae52765bc4bfc97`, the suite has a focused guard for the default state path and destructive adapter overrides. Existing per-invocation test overrides remain intact.

### Change Summary

Added the guard to `tests/rig.bats` and recorded its role in `tests/helpers/isolate.bash` and `AGENTS.md`. The old per-file XDG export plan remains superseded by the already delivered shared helper.

### Verification

The focused Bats guard passed. The full Bats suite passed with an inherited `XDG_STATE_HOME` set to a temporary read-only directory; the exact temporary directory was restored and removed after the run. Repository and source gates are recorded with the delivery commit.

### Outstanding concerns

Provider executables and platform selection are not yet machine independent; [RIG-CORE-033](RIG-CORE-033-make-tests-machine-independent.md) owns those separate gaps.

### Post-change review

The test now fails if the helper stops isolating default state or any of the four destructive adapter overrides. It exercises the current containment design without reproducing a destructive defect on the workstation.

### Mini recap

The missing isolation proof is delivered for acceptance review. The provider fixture conversion remains the next test-harness item; no additional state-isolation mechanism is needed.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Existing containment

The helper landed after this record was planned, so repeating its old per-file XDG export plan would add a second isolation mechanism. A direct guard tests the actual current contract and leaves each test free to override its own paths deliberately.
