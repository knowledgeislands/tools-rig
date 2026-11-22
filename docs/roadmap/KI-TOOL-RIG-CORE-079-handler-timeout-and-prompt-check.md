---
id: KI-TOOL-RIG-CORE-079
area: CORE
title: Handler wait follow-up
purpose: corrective
theme: rig
component: orchestration
kind: deliver
status: ready
horizon: next
priority: medium
size: s
assignee: repo/tools-rig
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-22T11:30:00Z
updated_at: 2026-11-22T11:30:00Z
---

# KI-TOOL-RIG-CORE-079: Handler Wait Follow-up

## Goal

A mistyped handler-confirmation setting can no longer make an attended `rig apply` wait for ever, and the confirmation wait that KI-TOOL-RIG-CORE-070 added is seen working once against a real macOS prompt.

## Context

Kris accepted KI-TOOL-RIG-CORE-070 under ACCEPT-THREE a on Orca item 153, 22 November 2026: "Accept, with the follow-up". The decision is recorded in the Cairn store's ki.summit change document `work/ki/ki.summit/20-ki-sop-main-legacy.change.md`, section 4.2. This record is that follow-up.

The blind review of 18 November found, and the 070 review brief of 22 November reproduced, that `rig_default_application_confirmed` in `src/rig/29-default-applications.bash` never checks that `RIG_HANDLER_CONFIRMATION_TIMEOUT` is a whole number. A value such as `2m` or `1.5` makes the `[ ... -le 0 ]` and `[ ... -ge ... ]` tests error out quietly, neither branch returns, and an attended apply polls until it is interrupted. `RIG_HANDLER_CONFIRMATION_INTERVAL` is read the same way. Neither variable is set in the dotfiles, the shell or Rig's configuration today, so the defect cannot trigger now.

070's own record left the attended prompt untested: its Verification says "Not run: an attended `rig apply` raising the real macOS prompt", and the prompt has only been characterised on terra.

## Boundary

- In: validating both variables, falling back to the default with one warning when a value is not a whole number of zero or more (or, for the interval, of one or more); Bats cases for the fallback; the guide, specification, manual page and changelog lines on the variables; one attended check of the wait against a real prompt, recorded here.
- Out: telling a declined prompt from an unanswered one; KI-TOOL-RIG-CORE-069's dynamic-type setter error; any change to which application handles a file; a release, which is Kris's.

## Current state

070 is on `main` and shipped in v0.8.0. Both variables are used unchecked. No attended apply has yet raised the real prompt with 070's wait in place.

## Steps

- [ ] Validate `RIG_HANDLER_CONFIRMATION_TIMEOUT` and `RIG_HANDLER_CONFIRMATION_INTERVAL` in `rig_default_application_confirmed`: a value that is not a whole number in range falls back to the default (120 at a terminal or 0 unattended for the timeout, 2 for the interval) with one `rig:` warning naming the variable.
- [ ] Add Bats cases in `tests/rig-default-applications.bats` for `2m`, `1.5`, an empty string and a negative timeout, and for a zero or non-numeric interval, each finishing within the budget.
- [ ] Say in the guide, specification, manual page and changelog that a value outside the range falls back to the default.
- [ ] At the next attended handler change on either Mac, with Kris at the terminal, run `rig apply --target default-application:ID` and record here whether an accepted prompt was recorded as applied on that run. This is Kris's act; the record waits for it before review.

## Files touched

- `src/rig/29-default-applications.bash`, then `bin/rig` reassembled.
- `tests/rig-default-applications.bats`.
- `docs/guides/user/default-applications.md`, `docs/specs/orchestration.md`, `man/rig.1`, `CHANGELOG.md`.

## Verify

- `bats tests/rig-default-applications.bats </dev/null` passes, including the new fallback cases, none of which waits longer than its budget.
- `scripts/assemble-rig --check`, `shellcheck` and `bash -n` over the changed module and `bin/rig` pass.
- The attended check is recorded in this record's Review with the date, the Mac and the outcome.

## Dependencies / blocks

None for the validation. The attended check needs Kris at a Mac with a handler to change; it must not be forced by changing a live handler just to raise the prompt.

## Documentation impact

### Decision Records

None: this enforces the range 070 already documented.

### Specifications

`docs/specs/orchestration.md`: the default-applications paragraph gains the fallback for an out-of-range value.

### Guides

`docs/guides/user/default-applications.md`: one sentence on the fallback.

### Roadmap

None.

## Discussion

### Why fall back rather than refuse

Refusing the run for a mistyped tuning variable would block every other resource in the apply. Falling back to the documented default with a warning keeps the apply bounded and tells the person what was ignored, which is the fix the blind review proposed.
