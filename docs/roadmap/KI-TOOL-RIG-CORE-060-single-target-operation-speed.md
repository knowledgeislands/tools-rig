---
id: KI-TOOL-RIG-CORE-060
area: CORE
title: Single-target operation speed
purpose: corrective
initiative: rig
kind: deliver
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: 4112c6cd19325b2db7a5f13ae91035839ddbaa88
created_at: 2026-10-17T21:44:09Z
updated_at: 2026-10-17T21:44:09Z
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

## Steps

- [ ] Measure phase timings on disposable fixtures of 50, 200 and 500 tools, and on a read-only preview of the real `laptop` profile.
- [ ] Replace the planner's restart scan with one pass over a waiting list and a newline-framed membership string.
- [ ] Walk only the contiguous `binding.TOOL.` names in the sorted lookup when selecting a tool's bindings.
- [ ] Order selected resources with precomputed dependency lists, and leave repeated selections together.
- [ ] Cache native targets once in the conflict check, keep cycle-visit states as framed strings, and insert sorted lookup names by binary search and slicing.
- [ ] Add Bats coverage, update the changelog, assemble `bin/rig` and run the complete local gate.

## Files touched

- [Configuration](../../src/rig/10-configuration.bash), [orchestration](../../src/rig/20-orchestration.bash), [runtime](../../src/rig/00-runtime.bash) and assembled [executable](../../bin/rig).
- [Performance tests](../../tests/rig-performance.bats).
- [Changelog](../../CHANGELOG.md).

## Discussion

The tools-burndown thread's rig-target-speed run delegated this record, using the HNR mail-triage job on the `laptop` profile as its example. That job is not declared on `sol`, so `scheduled-job:workstation-health` stands in for it in the real-catalogue measurements. The delegation allows local, fixture-backed delivery up to Awaiting review. It does not allow a live `rig apply`, acceptance, a push or a release.
