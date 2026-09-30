---
id: RIG-CORE-036
area: CORE
title: Resolve mutators absolutely
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 89132f4f00722a891ddf0f8e40544ebe839b2749
created_at: 2026-09-30T09:10:00Z
updated_at: 2026-09-30T20:11:30Z
---

## Goal

Decide whether `defaults`, `dockutil`, and `killall` should resolve by absolute path as `launchctl` does, so that the explicit override variable is the only way to substitute them, or whether resolving them through `PATH` is a property worth keeping.

## Context

`RIG_LAUNCHCTL` defaults to `/bin/launchctl` at `src/rig/20-orchestration.bash:245`, and the reason is recorded in `RIG-CORE-033`'s Discussion: an absolute path cannot be shadowed by a fixture directory prepended to `PATH`, so the only substitution route is the variable Rig itself names. The three macOS mutators resolve as bare names at `:775`, `:779`, and `:783`, so a `PATH` entry can capture any of them without Rig knowing.

`RIG-CORE-034` pinned all three in the test harness through their variables and left this question open in its Discussion, because the harness needed fixing that day and this did not. Its review packet names it as the one outstanding concern on the runtime side.

The two resolutions pull in different directions. `dockutil` is a Homebrew formula and genuinely lives wherever `PATH` finds it, so an absolute default is wrong for it unless Rig consults `brew --prefix`. `defaults` and `killall` are system binaries at `/usr/bin/defaults` and `/usr/bin/killall` on every supported macOS, so an absolute default costs nothing and removes a substitution route that nothing legitimate uses.

## Boundary

This is a runtime default, not a harness change; `RIG-CORE-034` owns the harness and is done. Rig does not become test-aware and no command gains a mock mode. The override variables keep their names and semantics either way.

If `PATH` resolution is kept for any of the three, the reason is written into the Discussion so the next reader does not reopen it.

## Current state

`rig_macos_defaults_command`, `rig_macos_dockutil_command`, and `rig_macos_killall_command` return `${RIG_DEFAULTS:-defaults}`, `${RIG_DOCKUTIL:-dockutil}`, and `${RIG_KILLALL:-killall}`. The harness exports all three to stubs, so the suite cannot reach the live commands by omission, but a fixture that prepends to `PATH` still can by construction.

## Steps

- [x] Default `defaults` and `killall` to their macOS system paths, retaining their explicit overrides.
- [x] Keep `dockutil` resolved through `PATH` because its Homebrew installation prefix is not fixed; document that deliberate distinction beside the helper.
- [x] Cover the default values and explicit overrides in isolated tests without invoking any live mutator.
- [x] Reassemble `bin/rig` and update the developer safety note if its description of bare-name resolution has changed.

## Files touched

`src/rig/20-orchestration.bash`, generated `bin/rig`, focused tests, and the safety note in `AGENTS.md` if needed.

## Verify

Assert helper resolution for default and override paths in an isolated Bats fixture; run ShellCheck, Bash syntax, assembly check, and the Bats suite with stdin closed.

## Dependencies / blocks

No build-order dependency. This shares the test-containment boundary with [RIG-CORE-025](RIG-CORE-025-isolate-state-in-tests.md), but each change can be verified independently.

## Documentation impact

### Decision Records

None expected; the choice is limited to executable lookup defaults.

### Specifications

None expected; the command contract is unchanged.

### Guides

The developer safety note must describe the final resolution rules.

### Roadmap

Record any distinct lookup hazard found during implementation separately.

## Review

### Delivered

From baseline `89132f4f00722a891ddf0f8e40544ebe839b2749`, `defaults` and `killall` select their macOS system paths by default, while `dockutil` still selects from `PATH`. All three retain explicit override variables.

### Change Summary

Updated the three command helpers in `src/rig/20-orchestration.bash`, regenerated `bin/rig`, corrected the test-helper explanation, and added a direct lookup test in `tests/rig-macos.bats`. No live mutator was invoked for verification.

### Verification

The focused default-and-override Bats test passed. The full repository gate and byte-identical assembly check are recorded with the delivery commit.

### Outstanding concerns

`dockutil` intentionally remains discoverable through `PATH`; its installation prefix varies. The explicit override remains the containment route in tests.

### Post-change review

Lookup now follows the fixed versus variable executable locations without changing any resource operation or runtime dependency. The test inspects resolved command values only.

### Mini recap

The runtime lookup decision is delivered for acceptance review. Provider fixtures remain owned by RIG-CORE-033.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Why this is not part of RIG-CORE-033

`RIG-CORE-033` relies on `PATH` shadowing as the mechanism for provider fixtures, and reasons that it works precisely because package managers resolve by name. If `defaults` and `killall` become absolute, they leave that mechanism and join `launchctl` in needing a variable, which is the split `RIG-CORE-033` already describes for the launchd adapter. That record can absorb this one if its reviewer prefers a single determinism boundary; it is captured apart because the answer may differ per command and `dockutil` is the case that keeps it from being obvious.
