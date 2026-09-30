---
id: RIG-CORE-033
area: CORE
title: Make tests machine independent
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-28T07:05:00Z
updated_at: 2026-09-30T09:50:25Z
---

## Goal

Make the suite's result depend only on the repository. A test's outcome must not vary with which package managers are installed on the runner, what they report, or which platform the runner is, and the suite must be able to present every observation state a provider can produce rather than only the one the machine happens to be in.

## Context

RIG-CORE-032 severed the base directories and the launchd domain, which is what stopped the suite unloading the runner's services. It did not sever the provider executables. `brew`, `uv`, `mise`, and `chezmoi` are resolved through `PATH`, and only seventeen of roughly two hundred and fifty invocations override `PATH` at all, so a test that reaches a provider generally reaches the real one.

That is both a determinism problem and a coverage ceiling. The machine presents one state per declaration — usually installed and current — so the interesting states are unreachable at any price: a tool absent, a tool present at the wrong version, a provider failing, a provider whose capability is unavailable, a locator that moved. The same applies to platform: `RIG_PLATFORM` is already an override, but a test that omits it exercises only the runner's own platform, so the macOS and Linux paths are never both covered in one run.

[RIG-CORE-025](RIG-CORE-025-isolate-state-in-tests.md) now owns the remaining direct containment guard and hostile ambient run. This item owns the separate manager-executable and platform fixture boundary. The benchmark still lacks its own state home; the required local gate currently stops when the benchmark's `status` command exits 1 after its three query cases.

## Boundary

The harness owns the provider boundary in tests, as it now owns the directory and launchd boundary. A test declares the observations it wants and asserts against them; it never depends on the runner's installed software.

`scripts/smoke-native-providers` keeps its current purpose unchanged and is explicitly not converted. Something must still prove that the real argv works against the real managers, and that script is the already-sandboxed place for it. Fixtures prove Rig's logic; the smoke script proves the integration.

Rig's runtime is not changed to be test-aware. No provider gains a mock mode, no capability check gains a test bypass, and `bin/rig` gains no branch that behaves differently under test. The mechanism is `PATH` and the existing override variables, which is why it works at all.

Excluded: containers or a separate user account; rewriting assertions that are already deterministic; and unifying the existing per-invocation `env` prefixes as a matter of style, which RIG-CORE-025's Boundary already excluded.

## Current state

The shared helper isolates directories and destructive macOS writers, but it does not isolate package-manager executables or default `RIG_PLATFORM`. Some tests use explicit manager stubs, while others inherit whichever manager is installed. `scripts/benchmark-rig` constructs a fake uv executable for observation but names no `RIG_STATE_HOME` and its status case currently fails in the local gate.

## Steps

- [ ] Add a fixture provider directory the harness prepends to `PATH`, with a stub per manager that replays a declared observation table and records its argv for assertion.
- [ ] Have `rig_test_isolate` set `RIG_PLATFORM` explicitly so a run covers a chosen platform rather than the runner's.
- [ ] Convert the existing tests that reach a real provider, file by file, to declare their observations.
- [ ] Add the variation matrix: provider by kind by observation state by platform, covering absent, present, drifted, failed, and capability-unavailable.
- [ ] Sandbox `scripts/benchmark-rig` so it names its own state home rather than inheriting the runner's.
- [ ] Record the fixture convention in the authoring notes so a new test file inherits it.

## Files touched

`tests/helpers/` for provider fixtures, the affected Bats files as they convert, `scripts/benchmark-rig`, and `AGENTS.md`. No runtime source change is planned.

## Verify

```sh
shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers
scripts/assemble-rig --check
bats tests/ < /dev/null
scripts/benchmark-rig
scripts/smoke-native-providers
```

Pass means the suite is green under a fixture-only manager path and on both selected platform values. The benchmark must pass with its own isolated state home. `bin/rig` byte-identical before and after is evidence that no test-only path entered the runtime; the hostile ambient directory check belongs to RIG-CORE-025.

## Dependencies / blocks

Nothing blocks this by build order. RIG-CORE-032 delivered initial directory and launchd isolation; RIG-CORE-025 owns its missing proof. This fixture conversion benefits from landing that guard first.

## Documentation impact

### Decision Records

Likely one, if the fixture boundary is a contract worth fixing: that tests prove Rig's logic against declared observations while one named script proves the real integration. Decide during planning rather than assuming it.

### Specifications

None expected. No specified behaviour changes; the `_Verify_` clauses continue to name the same tests, which assert the same contracts against declared observations rather than the runner's software.

### Guides

`AGENTS.md` gains the fixture convention beside the existing isolation note. No user-facing guide, `man/rig.1`, or README text changes, because nothing a person runs behaves differently.

### Roadmap

This record absorbs the `scripts/benchmark-rig` concern recorded under RIG-CORE-032. It no longer duplicates RIG-CORE-025's remaining verification work.

## Discussion

### Why fixtures rather than a runtime mock mode

A mock mode inside `bin/rig` would put test awareness in the product and would still not cover the case that matters, which is the argv Rig actually sends. Stubbing the executable on `PATH` tests the real dispatch path and lets a test assert the exact command line, which a mock would hide.

### Why the launchd adapter needed a variable but these do not

`RIG_LAUNCHCTL` exists because `/bin/launchctl` is absolute and never resolves through `PATH`, so nothing a harness does to the environment can contain it. The package managers are the opposite case: they resolve through `PATH`, so a prepended directory is sufficient and no new override variable is warranted.
