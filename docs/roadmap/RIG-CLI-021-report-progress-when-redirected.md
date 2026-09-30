---
id: RIG-CLI-021
area: CLI
title: Report progress when redirected
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 1dfaec09165709b4a394b267403035c45b7593b9
created_at: 2026-09-30T00:00:00Z
updated_at: 2026-09-30T20:11:30Z
---

## Goal

A long operational command whose stderr is redirected reports as it goes, so a wrapper, a log, or a scheduled job sees phases and counts arrive rather than eighty seconds of silence followed by everything at once.

## Context

`rig_progress_select_renderer` in `src/rig/00-runtime.bash` maps `RIG_PROGRESS=auto` to `bar` when the context is operational and stderr is a terminal, and to `off` otherwise. `RIG_PROGRESS=always` already chooses `lines` for exactly that non-terminal case, so the fallback exists and `auto` simply declines to use it.

This was step 5 of RIG-CLI-017 and was held there rather than delivered. It is a live behaviour change for runs nobody is watching: this workstation's `workstation-health` scheduled job would begin receiving per-item progress on stderr, and every Bats test that merges stderr into `$output` without setting `RIG_PROGRESS=never` would see new lines. It is also orthogonal to what 017 set out to fix, so it is spun out so that record can close. It arrives already shaped by that planning, but is captured here unadopted so the roadmap session decides whether and when it lands.

## Boundary

This changes only which renderer `auto` selects when stderr is not a terminal. It does not change the `lines` event shape, the bar, the stdout report, exit statuses, or the outcome line. Declaration-only queries stay quiet under `auto` regardless.

## Current state

The non-terminal `lines` renderer already exists and is selected by `RIG_PROGRESS=always`. `RIG_PROGRESS=auto` currently suppresses it, even for operational work. The scheduled `workstation-health` wrapper captures `rig doctor` stdout and stderr into a detail file and chooses its notification from the doctor exit status, not from parsing report lines. Extra progress is visible in its final detail but does not change its health decision. Its source remains outside this repository and is not edited here.

## Steps

- [x] Select `lines` for `RIG_PROGRESS=auto` in operational context when stderr is redirected; keep terminal `bar`, declaration-query silence, and explicit `always`, `lines`, and `never` behavior.
- [x] Set `RIG_PROGRESS=never` in the isolated test default so unrelated merged-stream assertions remain about reports; explicitly select `auto`, `always`, or `lines` in progress tests.
- [x] Add Bats checks for redirected automatic phase/item/count events, their arrival during work, quiet queries, explicit suppression, unchanged stdout and exit status, and the provider passthrough boundary.
- [x] Update the progress Specification, guide, and manual for the automatic redirected fallback; regenerate the assembled executable.

## Files touched

- `src/rig/00-runtime.bash` and generated `bin/rig` — automatic renderer selection.
- `tests/helpers/isolate.bash` and `tests/rig.bats` — default isolation and explicit behavior checks.
- `docs/specs/orchestration.md`, `docs/guides/user/commands.md`, and `man/rig.1` — accepted and user-facing progress contract.

## Verify

Run the complete repository gate from the project `AGENTS.md`. Focused Bats checks must show lines on redirected operational stderr before the final report while an automatic query remains silent. `workstation-health` must still select its result from `rig doctor` status alone.

## Dependencies / blocks

No implementation dependency remains. RIG-CLI-023 owns only the interactive display and must preserve this line-oriented non-terminal fallback. This item can be delivered independently while that design remains draft.

## Documentation impact

### Decision Records

None. The stdout/stderr split and progress event vocabulary do not change.

### Specifications

`docs/specs/orchestration.md` states the automatic non-terminal operational fallback.

### Guides

`docs/guides/user/commands.md` and `man/rig.1` describe automatic line events in redirected operational runs.

### Roadmap

RIG-CLI-023 remains a separate interactive display item. No new work record is needed for the read-only `workstation-health` consumer.

## Review

### Delivered

From immutable baseline `1dfaec09165709b4a394b267403035c45b7593b9`, automatic progress now emits line-oriented events during redirected operational work. Interactive operational work keeps its bar, and declaration-only queries remain quiet under `auto`. Explicit modes, stdout reports, exit statuses, and outcome lines are unchanged.

### Change Summary

`src/rig/00-runtime.bash` selects the existing `lines` renderer for non-terminal operational `auto`; `bin/rig` is regenerated. The isolated Bats default disables progress for unrelated merged-stream assertions, while focused tests select modes explicitly. The progress Specification, user guide, and manual describe the fallback. The scheduled `workstation-health` consumer was inspected read-only and remains outside this change.

### Verification

Focused progress Bats tests passed, including an event observed before provider output, counts and phase completion, a quiet query, and explicit suppression. The complete 288-test Bats suite, repository audit, ShellCheck, Bash syntax, assembly check, benchmark, native-provider smoke test, man lint, and diff check passed. The scheduled consumer chooses its notification from `rig doctor` exit status, not parsed report lines.

### Outstanding concerns

Scheduled and scripted operational runs will now receive additional stderr lines by default; callers requiring silence can set `RIG_PROGRESS=never`. The interactive tmux-like display remains a separate design item, RIG-CLI-023. No release, push, or human acceptance is implied.

### Post-change review

The implementation reuses the established line-event vocabulary and keeps it separate from stdout report data. Provider diagnostics can interleave with complete progress lines without a cursor collision. The command's exit status and final report remain independent of the progress setting. The item is ready for acceptance review.

### Mini recap

Redirected operational progress is delivered and verified. The interactive display design and any acceptance follow-ups remain separate.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Who is affected

Progress goes to stderr, which is never part of the report, so a consumer parsing stdout cannot be broken. A consumer that wants nothing on stderr still has `RIG_PROGRESS=never`. The cost is stderr output in scripted runs that previously had none, which is why this is a specification change in `docs/specs/orchestration.md` rather than an implementation detail, and why the `workstation-health` wrapper in chezmoi should be checked before this lands.

### The suite

Planning should decide whether `tests/helpers/isolate.bash` sets `RIG_PROGRESS=never` for every test by default, with the progress tests opting back in, or whether each affected assertion is widened. The former is one change and keeps unrelated tests indifferent to progress; the latter preserves the accidental coverage some tests get today.
