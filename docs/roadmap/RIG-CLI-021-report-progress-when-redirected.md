---
id: RIG-CLI-021
area: CLI
title: Report progress when redirected
theme: cli
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T00:00:00Z
updated_at: 2026-09-30T00:00:00Z
---

## Goal

A long operational command whose stderr is redirected reports as it goes, so a wrapper, a log, or a scheduled job sees phases and counts arrive rather than eighty seconds of silence followed by everything at once.

## Context

`rig_progress_select_renderer` in `src/rig/00-runtime.bash` maps `RIG_PROGRESS=auto` to `bar` when the context is operational and stderr is a terminal, and to `off` otherwise. `RIG_PROGRESS=always` already chooses `lines` for exactly that non-terminal case, so the fallback exists and `auto` simply declines to use it.

This was step 5 of RIG-CLI-017 and was held there rather than delivered. It is a live behaviour change for runs nobody is watching: this workstation's `workstation-health` scheduled job would begin receiving per-item progress on stderr, and every Bats test that merges stderr into `$output` without setting `RIG_PROGRESS=never` would see new lines. It is also orthogonal to what 017 set out to fix, so it is spun out so that record can close. It arrives already shaped by that planning, but is captured here unadopted so the roadmap session decides whether and when it lands.

## Boundary

This changes only which renderer `auto` selects when stderr is not a terminal. It does not change the `lines` event shape, the bar, the stdout report, exit statuses, or the outcome line. Declaration-only queries stay quiet under `auto` regardless.

## Discussion

### Who is affected

Progress goes to stderr, which is never part of the report, so a consumer parsing stdout cannot be broken. A consumer that wants nothing on stderr still has `RIG_PROGRESS=never`. The cost is stderr output in scripted runs that previously had none, which is why this is a specification change in `docs/specs/orchestration.md` rather than an implementation detail, and why the `workstation-health` wrapper in chezmoi should be checked before this lands.

### The suite

Planning should decide whether `tests/helpers/isolate.bash` sets `RIG_PROGRESS=never` for every test by default, with the progress tests opting back in, or whether each affected assertion is widened. The former is one change and keeps unrelated tests indifferent to progress; the latter preserves the accidental coverage some tests get today.
