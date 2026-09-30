---
id: RIG-CORE-034
area: CORE
title: Pin destructive macOS writers
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: c773a5396af4a8c31f844730d04567d6bcafb496
created_at: 2026-09-28T09:28:51Z
updated_at: 2026-09-30T09:00:00Z
---

## Goal

No test can write the runner's real macOS preferences, rearrange its Dock, or signal its running processes, whether or not the test remembers to say so.

## Context

RIG-CORE-032 severed the base directories and the launchd domain, and `tests/helpers/isolate.bash` now pins `XDG_*`, `RIG_*_HOME`, `HOME`, `RIG_LAUNCHCTL`, and `RIG_LAUNCHD_DOMAIN`. Three macOS mutators were left out of that pass and remain unpinned by the harness:

- `RIG_DEFAULTS` — `src/rig/20-orchestration.bash:775`, defaulting to `defaults`
- `RIG_DOCKUTIL` — `src/rig/20-orchestration.bash:779`, defaulting to `dockutil`
- `RIG_KILLALL` — `src/rig/20-orchestration.bash:783`, defaulting to `killall`

Only two invocations in the suite override any of them: `tests/rig-macos.bats:54` and `tests/rig-macos.bats:138` pass `RIG_DEFAULTS="$DEFAULTS_FAKE"` themselves. That is the per-invocation opt-in pattern RIG-CORE-032 already diagnosed for launchd — an override a test must remember, rather than a guarantee the harness holds.

The consequence is observed, not hypothetical. This workstation's `com.apple.finder NewWindowTargetPath` and `com.apple.screencapture location` currently hold `/tmp/rig-case-postfix-default/home/…`, a directory that no longer exists, so screenshots have no valid destination. `DOTFILES-UE-060` in the chezmoi repository owns repairing that machine state.

Moving `HOME` does not protect against this, which is why the RIG-CORE-032 mechanism does not already cover it. `defaults` reaches the user domain through `cfprefsd` rather than through `$HOME`, so a run under a sandboxed `HOME` writes the _real_ preference domain using the _sandboxed_ path as the value. That is exactly the shape of the observed damage, and it means a passing sandbox check is not evidence of containment here.

`killall` is the sharpest of the three. Unpinned, a test that exercises the restart path signals processes belonging to the person running the suite.

## Boundary

This record covers harness-level pinning of the macOS mutators only, by the mechanism RIG-CORE-032 established. It is deliberately small and deliberately urgent.

RIG-CORE-033 owns provider determinism: fixture stubs for `PATH`-resolved package managers, explicit `RIG_PLATFORM`, and the observation variation matrix. Its Discussion reasons about why `RIG_LAUNCHCTL` needs a variable while `PATH` tools do not, and does not reach these three commands. Its hermeticity guard would plausibly detect the leak once delivered, so a reviewer may prefer to merge this record into RIG-CORE-033 rather than deliver it separately — but RIG-CORE-033 is a broad determinism and coverage item at `next`, and this is a live destructive defect, so they are captured apart and the disposition is the reviewer's.

Rig's runtime must not become test-aware. The variables already exist; nothing in `bin/rig` gains a branch, a mock mode, or a capability bypass.

Per `AGENTS.md`, this defect is not to be reproduced by applying against the live workstation even with every sandbox variable set. Reproduction belongs in a test under `tests/`, or in a throwaway catalogue naming nothing the machine owns.

## Current state

`tests/helpers/isolate.bash` pins five names and none of these three, confirmed at `5726716`. The two `tests/rig-macos.bats` overrides are the only protection in the suite. `rig doctor` on the development workstation reports the two drifted settings described above.

## Steps

- [x] Point `RIG_DEFAULTS`, `RIG_DOCKUTIL`, and `RIG_KILLALL` at inert stubs in the test's own tree from `rig_test_isolate`, beside the existing `launchctl` stub.
- [x] Add a regression test asserting the harness contains all three when a test names no override, and that an invocation without overrides cannot read the runner's real preference domain.
- [x] Record the mutator pinning in the `AGENTS.md` isolation note, which currently names only the base directories and the launchd adapter.

## Files touched

- `tests/helpers/isolate.bash`
- `tests/rig-macos.bats`
- `AGENTS.md`

## Verify

The complete gate in `AGENTS.md`. The assertion that matters is the new regression test: with the harness pinning removed it must fail, and it must never write a preference domain to prove it. `bin/rig` stays byte-identical, since no runtime source changes and the runtime gains no test awareness.

## Dependencies / blocks

Nothing blocks this. RIG-CORE-032 delivered the directory and launchd half of the same boundary and is accepted. `DOTFILES-UE-060` in the chezmoi repository repairs the machine state this defect caused and should follow rather than precede the regression test.

## Documentation impact

### Decision Records

None. RIG-CORE-032 established the harness-isolation approach; this extends it to three more commands without changing the contract.

### Specifications

None. No specified behaviour changes.

### Guides

`AGENTS.md` only, extending the existing isolation paragraph.

### Roadmap

RIG-CORE-033 keeps its own boundary. If its reviewer later merges this record into it, that is a disposition decision recorded there.

## Review

### Delivered

The approved boundary in full: `rig_test_isolate` now pins `RIG_DEFAULTS`, `RIG_DOCKUTIL`, and `RIG_KILLALL` alongside the base directories and the launchd adapter, a regression test asserts the harness holds when a test names no override, and the `AGENTS.md` isolation note records all three. Nothing in `bin/rig` changed, so the runtime gained no test awareness.

Immutable baseline `c773a5396af4a8c31f844730d04567d6bcafb496`.

### Change Summary

Each of the three variables is exported to a generated stub inside `$BATS_TEST_TMPDIR`. The `defaults` stub exits non-zero for `read` and `read-type`, so a key reads as absent; the `dockutil` stub returns an empty `--list`, so the Dock reads as having no items; all three accept every mutation and discard it. Each stub appends its own argv to `$0.log`, which is self-relative, so a test can prove the stub received a call without any env plumbing.

One decision worth naming: the assertion is on the stub's log, not on an observed preference value. The first attempt asserted `"state":"missing"` in `rig status --format json` and passed with the pinning removed, because the declared key `AppleInterfaceStyleSwitchesAutomatically` has never been set on this machine, so the real `defaults` reports it absent exactly as the stub does. An observation-based assertion cannot distinguish a contained read from a real one in that case.

The new test exercises only `rig status`, a read path, so it cannot write the domain it protects even if the harness regresses.

No approved deviations.

### Verification

The complete `AGENTS.md` gate: `ki repo audit --repo .` PASS, `shellcheck` and `bash -n` clean over the runtime, installer, scripts and the helper, `scripts/assemble-rig --check` clean so `bin/rig` is byte-identical, `scripts/benchmark-rig` within budget on all three commands, `scripts/smoke-native-providers` PASS for mise, npm, chezmoi and mas, `bats tests/ < /dev/null` 251 of 251 passing, `mandoc -T lint man/rig.1` clean.

The assertion that matters was checked in both directions. With the three `export` lines replaced by `: unpinned`, test 8 reports `not ok`, failing on `[ -f "$RIG_DEFAULTS.log" ]`. No preference domain was written to establish that, per the `AGENTS.md` prohibition on reproducing a destructive defect against the live workstation.

### Outstanding concerns

The three variables still default to bare command names, so a fixture directory prepended to `PATH` can shadow them. Whether `defaults` and `killall` should become absolute paths as `RIG_LAUNCHCTL` is, leaving the explicit variable as the only substitution route, is left open in the Discussion below and belongs to RIG-CORE-033 or to its reviewer's merge decision.

`DOTFILES-UE-060` in the chezmoi repository still holds the machine-state repair. It was deliberately not performed before this test existed.

### Post-change review

The goal is met structurally rather than by convention: a test cannot reach the runner's preferences, Dock, or processes by omission, only by naming a real command deliberately. Scope held at three exports, one test, and one paragraph.

Regression risk is in the forced stubs, since they change what a test sees when it names no override. The two `tests/rig-macos.bats` invocations that pass their own fakes are unaffected, because `run env VAR=…` wins for that invocation, and the full suite passes.

Ready for acceptance.

### Mini recap

`defaults`, `dockutil`, and `killall` resolved as bare names and the harness never pinned them, so a test that forgot an override rewrote the runner's real machine — which is how this workstation's screenshot location came to point at a deleted temporary directory. `rig_test_isolate` now stubs all three, and the regression test asserts on the stub's own argv log, because the obvious assertion on an observed value passes even when the pinning is gone.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Why a stub rather than an unset

Unsetting achieves nothing: each variable falls back to a real command name, so absence is the dangerous state. The harness must point each one at an inert stub in the test's own tree, as it already does for `launchctl` — reporting a benign observation and accepting every mutation, so that a forgotten override fails the assertion it belongs to rather than the runner's machine.

### Whether the defaults for these should be absolute

`RIG_LAUNCHCTL` defaults to `/bin/launchctl` precisely because an absolute path cannot be shadowed through `PATH`. These three resolve as bare names, so a fixture directory prepended to `PATH` can capture them, which is what makes RIG-CORE-033's mechanism relevant. Whether that is a feature worth keeping, or whether `defaults` and `killall` should also become absolute so the only way to substitute them is the explicit variable, is a genuine question for planning rather than a settled part of this record.

### Why the observed damage is the wrong kind of evidence to lose

The two drifted settings are currently the only externally visible proof this defect exists. Repairing the machine before a regression test exists would leave the defect real and the evidence gone, which is the reasoning recorded in `DOTFILES-UE-060` as well. The values are written down in both records for that reason.
