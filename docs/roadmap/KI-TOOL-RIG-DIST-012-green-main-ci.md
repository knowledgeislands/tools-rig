---
id: KI-TOOL-RIG-DIST-012
area: DIST
title: Green main CI
theme: rig
kind: deliver
purpose: corrective
status: done
blocks: []
blocked_by: []
baseline_ref: f6160db38ea29b5d29617c297b94368cb6dca0fb
created_at: 2026-10-18T18:07:57Z
updated_at: 2026-10-18T19:43:44Z
---

# KI-TOOL-RIG-DIST-012: Green Main CI

## Goal

Every CI job on `main` passes again, so the release guide's first gate is met and v0.7.0 can be tagged on the candidate.

## Context

The last green `main` run was `efd4eae` on 15 October 2026; every `main` run since failed in two jobs that pass locally:

- **Shell lint:** the runner's ShellCheck reports SC2015 (`A && B || C` is not if-then-else) on three `|| continue` lines in `src/rig/10-configuration.bash` and their assembled copies in `bin/rig`. Local ShellCheck 0.11.0 does not report them.
- **KI governance:** CI pinned `KI_VERSION: v0.8.4`, whose harness retired the record field `theme` and fails `ITEM-2` on all 14 roadmap records. The current harness reinstates `theme` as the territory theme from the Project registry, `rig` is one, and local `ki` 0.11.2 passes the same records.

Kris agreed on 18 October 2026 (RIG-CI-RED a), ways-of-working decisions log, 19:05 BST owner answers) to fix both under one record before tagging v0.7.0.

## Boundary

- In: rewriting the three lines so no ShellCheck version reads them as SC2015; moving the CI `KI_VERSION` pin to the current ki release; confirming green `main` CI.
- Out: reclassifying the 14 records, which the current harness accepts; other repositories' `KI_VERSION` pins, which also sit at v0.8.4; the release itself; any live apply.

## Current state

Delivered in `8d2d253`; main CI run 39153236499 for `b8f3813` passed every job.

## Steps

- [x] Rewrite the two `homebrew`/`mas` guards in the `mas` normalisation loop as `if ! ... || ...; then continue; fi`.
- [x] Rewrite the dependency guard in the ordering loop as `case "$dependencies" in +|-) continue ;; esac`.
- [x] Regenerate `bin/rig` with `scripts/assemble-rig --write`.
- [x] Move `KI_VERSION` in `.github/workflows/ci.yml` from v0.8.4 to v0.11.2.
- [x] Run the complete local gate, push, and confirm `main` CI.

## Files touched

- `src/rig/10-configuration.bash`
- `bin/rig`
- `.github/workflows/ci.yml`
- `docs/roadmap/KI-TOOL-RIG-DIST-012-green-main-ci.md`

## Verify

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes, and the CI run for the pushed commit on `main` passes every job.

## Dependencies / blocks

Blocks the v0.7.0 release; blocked by nothing.

## Documentation impact

### Decision Records

None: no durable rationale changes.

### Specifications

None: Rig's behaviour is unchanged; the guards are logically equivalent.

### Guides

None: the developer guide names no `KI_VERSION` pin.

### Roadmap

Unblocks the v0.7.0 release; the estate-wide v0.8.4 pin is noted under Discussion.

## Review

### Delivered

Both failing jobs addressed within the boundary, from baseline `f6160db`; no record reclassified and no other repository changed.

### Change Summary

- `src/rig/10-configuration.bash` and assembled `bin/rig`: three `A && B || continue` guards rewritten as an `if` and a `case`, with identical control flow.
- `.github/workflows/ci.yml`: `KI_VERSION` v0.8.4 to v0.11.2, matching the local ki that already passes the audit.

### Verification

Local gate passed: `ki repo audit` (FAIL=0, warnings only), ShellCheck, `bash -n`, `scripts/assemble-rig --check`, benchmark, native-provider smoke, Bats (582 of 582), mandoc lint and `git diff --check`. Main CI run 39153236499 for `b8f3813` passed KI governance, Shell lint, Bats on Ubuntu and macOS, and mandoc, the first green `main` run since `efd4eae`.

### Outstanding concerns

Local ShellCheck 0.11.0 cannot reproduce the runner's SC2015 finding, so only CI proves the lint fix; it did. RIG-CI-RED a) proposed reclassifying the 14 records' `theme: rig`; moving the pin made that unnecessary, so they are unchanged.

### Post-change review

The guards keep their meaning: each skips the iteration unless the lookup succeeds and matches, or unless dependencies are neither `+` nor `-`.

### Mini recap

CI was red on a newer ShellCheck rule and a stale ki pin; three lines and one pin fix it.

## Done

Kris accepted the record as it stands on 18 October 2026 (RIG-DIST-012-ACCEPT a), ways-of-working decisions log, 20:33 BST owner answers: "do all the recommended items, we just need to move forwards"). The six-part review packet stands: both failing jobs fixed within the boundary, main CI run 39153236499 green, and the 14 records' `theme` left unchanged, as the current harness accepts it.

In the same answers Kris accepted the annotated, unsigned `v0.7.0` tag (RIG-TAG-SIGN a)) as matching the `v0.6.3` practice: both tags are annotated and neither carries a signature.

## Discussion

### Estate pin

At least nine other KI repositories pin `KI_VERSION: v0.8.4`; any of them whose records carry `theme` will fail `ITEM-2` the same way. They are outside this record.
