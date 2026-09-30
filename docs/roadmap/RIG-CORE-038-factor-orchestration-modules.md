---
id: RIG-CORE-038
area: CORE
title: Factor orchestration modules
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T10:03:46Z
updated_at: 2026-09-30T10:03:46Z
---

## Goal

The authored orchestration source is divided by responsibility so a maintainer can locate provider, observation, and application logic quickly while Rig remains one Bash-only executable.

## Context

The [command-surface audit](../guides/developer/command-surface.md) found that `src/rig/20-orchestration.bash` holds 143 functions across 4,892 lines: native resource adapters, provider operations, state observation and reports, and both `apply` and `bootstrap`. The source is assembled in a fixed order by `scripts/assemble-rig`; moving contiguous function groups into additional authored modules changes no runtime loading model. Several planned changes will otherwise keep editing the same large file.

## Boundary

This is a source-only split. Do not change command flags, output, provider protocol, function behaviour, state vocabulary, or the generated executable's Bash 3.2 and zero-runtime-dependency contract. Do not introduce a runtime module loader. A shared helper moves with its existing domain unless doing so would alter assembly order; unrelated refactoring stays outside this item.

## Current state

The existing file has natural contiguous boundaries near resource-plan observation, state/status reporting, and application helpers. `scripts/assemble-rig` lists the authored modules explicitly, so each added source path requires an assembly-list update. Existing tests exercise the assembled payload.

## Steps

- [ ] Split the current file at complete function boundaries into ordered authored modules for core resources, provider operations, state observation and reports, and application/bootstrap.
- [ ] Update `scripts/assemble-rig` with the exact new order, preserving function definitions and their relative order.
- [ ] Update developer module guidance and source-path references in still-open roadmap plans that this split makes stale.
- [ ] Reassemble `bin/rig` and inspect the generated diff for moved code only.
- [ ] Verify the full local gate, with the benchmark given an isolated state home until RIG-CORE-033 fixes its default.

## Files touched

`src/rig/20-orchestration.bash`, new ordered `src/rig/*.bash` modules, `scripts/assemble-rig`, generated `bin/rig`, developer guide, and affected active roadmap path references.

## Verify

Run ShellCheck and Bash syntax on every authored and assembled file, `scripts/assemble-rig --check`, the benchmark, native-provider smoke, and Bats with stdin closed. Compare the assembled pre- and post-split code after excluding module banners to confirm every function body remains in the same order; inspect the Git diff for behaviour changes.

## Dependencies / blocks

No build-order dependency. Land the split before the larger observation and output changes so subsequent edits have narrower source owners.

## Documentation impact

### Decision Records

None; the single-executable architecture remains in force.

### Specifications

No accepted behaviour changes.

### Guides

Update the developer command-surface map and its module paths.

### Roadmap

Update source locations in active plans after the split without changing their outcome or authority.

## Discussion

### Why split authored modules

The existing file size is not itself a defect. The reason to split is that distinct maintenance concerns currently share one edit surface. An ordered source split keeps the installed file and manager-of-managers model intact while reducing the search area for each subsequent change.
