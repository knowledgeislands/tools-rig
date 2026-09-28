---
id: RIG-CORE-034
area: CORE
title: Pin destructive macOS writers
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-28T09:28:51Z
updated_at: 2026-09-28T09:28:51Z
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

## Discussion

### Why a stub rather than an unset

Unsetting achieves nothing: each variable falls back to a real command name, so absence is the dangerous state. The harness must point each one at an inert stub in the test's own tree, as it already does for `launchctl` — reporting a benign observation and accepting every mutation, so that a forgotten override fails the assertion it belongs to rather than the runner's machine.

### Whether the defaults for these should be absolute

`RIG_LAUNCHCTL` defaults to `/bin/launchctl` precisely because an absolute path cannot be shadowed through `PATH`. These three resolve as bare names, so a fixture directory prepended to `PATH` can capture them, which is what makes RIG-CORE-033's mechanism relevant. Whether that is a feature worth keeping, or whether `defaults` and `killall` should also become absolute so the only way to substitute them is the explicit variable, is a genuine question for planning rather than a settled part of this record.

### Why the observed damage is the wrong kind of evidence to lose

The two drifted settings are currently the only externally visible proof this defect exists. Repairing the machine before a regression test exists would leave the defect real and the evidence gone, which is the reasoning recorded in `DOTFILES-UE-060` as well. The values are written down in both records for that reason.
