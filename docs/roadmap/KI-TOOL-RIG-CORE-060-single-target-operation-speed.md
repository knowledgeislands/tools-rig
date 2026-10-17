---
id: KI-TOOL-RIG-CORE-060
area: CORE
title: Single-target operation speed
purpose: corrective
initiative: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 4112c6cd19325b2db7a5f13ae91035839ddbaa88
created_at: 2026-10-17T21:44:09Z
updated_at: 2026-10-17T21:45:58Z
---

# KI-TOOL-RIG-CORE-060: Single-Target Operation Speed

## Goal

A targeted operation such as `rig apply --dry-run --profile laptop --target scheduled-job:ID`, or `rig show ID`, finishes in a few seconds on a real catalogue. Its output does not change, and it still observes only the target and its dependency closure.

## Context

A single scheduled-job preview against the `laptop` profile took about 24 seconds on Mac Studio `sol`. That catalogue has 191 tools and 496 model sections once the derived bindings are counted. Most of the time went on work whose cost grows faster than the catalogue, not on native probes. In `rig_build_plan`, the scan restarts after every planned tool and each membership check is linear, so the planner is cubic. A 500-tool disposable fixture spent 150 of its 171 seconds there. Binding selection, resource ordering, native-target conflict checks, cycle validation and sorted section insertion each scan the whole model once per item.

## Boundary

- **In:** these algorithms in `src/rig/10-configuration.bash` and `src/rig/20-orchestration.bash`, with unchanged ordering, messages and validation; fixture-backed regression coverage that counts native invocations for a targeted apply and pins the planner's order; the changelog; the assembled `bin/rig`.
- **Out:**
  - Skipping configuration validation, profile resolution or platform rules for a target. Full validation is the guarantee that a targeted run sees the same configuration errors as a full one.
  - Caching the parsed model between invocations.
  - Native-provider behaviour.
  - Any change to a person's configuration.

## Current state

Before this record, `rig_build_plan` restarted its scan after each planned tool and searched planned members linearly. `rig_select_bindings` scanned every section for each tool, and resource ordering and native-target checks rescanned the whole selection for each item. Cycle validation searched a visit array, and section indexing shifted the sorted lookup one element at a time. Native probes were already limited to the target's closure.

## Steps

- [x] Measure phase timings on disposable fixtures of 50, 200 and 500 tools, and on a read-only preview of the real `laptop` profile.
- [x] Replace the planner's restart scan with one pass over a waiting list and a newline-framed membership string.
- [x] Walk only the contiguous `binding.TOOL.` names in the sorted lookup when selecting a tool's bindings.
- [x] Order selected resources with precomputed dependency lists, and leave repeated selections together.
- [x] Cache native targets once in the conflict check, keep cycle-visit states as framed strings, and insert sorted lookup names by binary search and slicing.
- [x] Add Bats coverage, update the changelog, assemble `bin/rig` and run the complete local gate.

## Files touched

- [Configuration](../../src/rig/10-configuration.bash), [orchestration](../../src/rig/20-orchestration.bash), [runtime](../../src/rig/00-runtime.bash) and assembled [executable](../../bin/rig).
- [Performance tests](../../tests/rig-performance.bats).
- [Changelog](../../CHANGELOG.md).

## Verify

- Run the complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository).
- `bats tests/rig-performance.bats </dev/null` covers targeted native invocations and planner order.
- Against disposable fixtures, compare the output of a targeted dry run with the baseline binary's output.

## Dependencies / blocks

Not blocked; blocks nothing.

## Documentation impact

### Decision Records

None. The change is internal, and every boundary in an existing decision record still holds.

### Specifications

None. Ordering, selection, validation and messages are unchanged, so no requirement changes.

### Guides

None. The changelog notes the speed-up.

### Roadmap

Captured Now and delivered by the tools-burndown rig-target-speed run.

## Review

### Delivered

Delivered locally against fixtures and read-only previews only. No live `rig apply` ran, and nothing was accepted, pushed or released.

### Change Summary

- **Planner** (`20-orchestration.bash`): `rig_build_plan` keeps a waiting list, so each step plans the lowest-indexed ready tool without rescanning the selection. `RIG_PLAN_MEMBERS` makes the planned-membership check one pattern match.
- **Configuration** (`10-configuration.bash`):
  - `rig_select_bindings` walks only the contiguous `binding.TOOL.` names from a lower-bound search.
  - `rig_index_section_name` inserts by binary search and array slicing.
  - `rig_sort_selected_resources` precomputes dependency lists and orders repeated selections together.
  - `rig_validate_selected_native_targets` collects each item's native targets once.
  - Cycle checks keep visit states as newline-framed strings.
- **Tests:** two `tests/rig-performance.bats` cases.
  - A targeted apply's native invocations are exactly its dependency closure. Any other call is an undeclared stub call, which fails.
  - The dependency-ordered plan keeps an early tool that waits on a later one in its original position.
- **Changelog:** one entry under Changed and removed.

### Verification

Output was byte-identical to the baseline binary for every measured run. Wall-clock seconds, `apply --dry-run --profile laptop`:

| Run | Before | After |
|---|---|---|
| 50-tool fixture, one scheduled job | 1.3 | 1.1 |
| 200-tool fixture, one scheduled job | 14.3 | 3.2 |
| 500-tool fixture, one scheduled job | 171.3 | 10.1 |
| 500-tool fixture, whole profile | 183.1 | 20.4 |
| `sol` `laptop` preview, one scheduled job | 23.6 | 5.4 |
| `sol` `show scheduled-job:ID` | 5.2 | 3.4 |

Fixture timings ran under a function-timing wrapper; the `sol` timings did not.

The remaining cost of a targeted run is loading the configuration: parsing, binding synthesis and full-model validation take about 3.6 seconds on `sol`. Profile resolution adds about 0.9 seconds and planning about 0.7. Loading stays whole-model by design (see Boundary).

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes. The audit's only warning is the existing HOOK-1 note that no pre-commit gate is committed. All 552 Bats tests pass.

### Outstanding concerns

Most of the remaining time in a targeted run is configuration loading. Loading stays whole-model to keep the guarantee that every run validates the full configuration. A later record could cache the parsed model or shorten parsing and validation.

### Post-change review

The planner gives the same lowest-indexed-ready order: the new test pins an early tool that waits on a later one. Repeated targets still appear once. The cycle and conflict messages are unchanged, and the existing Bats cases cover them.

### Mini recap

A targeted `laptop` preview on `sol` now takes about 5 seconds instead of 24, with the same output and the same native probes.

## Discussion

The tools-burndown thread's rig-target-speed run delegated this record, using the HNR mail-triage job on the `laptop` profile as its example. That job is not declared on `sol`, so `scheduled-job:workstation-health` stands in for it in the real-catalogue measurements. The delegation allows local, fixture-backed delivery up to Awaiting review. It does not allow a live `rig apply`, acceptance, a push or a release.
