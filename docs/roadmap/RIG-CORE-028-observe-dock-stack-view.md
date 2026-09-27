---
id: RIG-CORE-028
area: CORE
title: Observe Dock stack view
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-27T08:13:24Z
updated_at: 2026-09-27T08:13:24Z
---

## Goal

A Dock folder whose view or display no longer matches its declaration reports as drifted, so a person learns about the difference before the next apply silently overwrites their change.

## Context

`rig_dock_observe` in `src/rig/20-orchestration.bash:850` builds its expected value from `rig_dock_expected_paths` and compares it against the paths `dockutil --list` returns. It reports `drifted` only with `RIG_OBSERVATION_DETAIL=order`, and `present` otherwise. No declared field beyond `path` participates in the comparison.

A `dock-item` may also declare `view` and `display`, and `rig_dock_apply` at `src/rig/20-orchestration.bash:881` does pass both to `dockutil` as `--view` and `--display`. So the two halves of the contract disagree: apply asserts three fields, observe checks one.

The observed consequence on this workstation was a Dock folder set to List by hand against a declaration of `grid`. `rig status` reported the resource `present` throughout, because the path set matched. The next `rig apply` then ran `dockutil --remove all` and re-added the folder as a grid, discarding the change with no prior warning and no drift row. The declaration was corrected instead, but the reporting gap is independent of which value is right: the same silence would hide a declaration that had itself gone stale.

This is the general shape of an unchecked field rather than a Dock quirk. An observation that cannot see a field it applies will report agreement it has not established, and `present` then means "the part I looked at matched" while reading as "the machine matches the declaration".

## Boundary

This is about what the Dock observation compares and what it reports. It does not change how `rig_dock_apply` materialises a Dock, the full-teardown strategy that apply uses, the state vocabulary, or exit statuses. It does not add Dock fields beyond those already declarable, and it does not decide whether any particular workstation should prefer list or grid — that is configuration, not portable behaviour.

Whether other resource adapters share the same partial-comparison shape is worth knowing but is not scoped here.

## Discussion

### Where the comparison should live

`rig_dock_expected_paths` returns paths because that is what its name promises and what the order check needs. Widening it in place would make the order comparison harder to read. A separate expected-triple builder, or an extra comparison pass keyed by path, both keep the order finding intact. The detail token matters as much as the state: `order` and a new value such as `view` are different findings, and collapsing both into bare `drifted` would lose the distinction that makes the row actionable.

### Reading dockutil's own output

`dockutil --list` emits label, path, and container columns, not the view or display setting, so the current observation could not have compared those fields from the output it already reads. The values do live in `com.apple.dock` under `persistent-others[].tile-data`, as `showas` and `displayas` integers — observed on this machine as `showas: 3` for list and `displayas: 1` for folder. Reading them means either parsing that plist directly, which couples Rig to an Apple-internal encoding, or finding a `dockutil` query that exposes them. That choice is the substance of the work and is genuinely open; the plist route is more capable and less portable, and the integer mapping is undocumented.

### Relationship to the catalogue-only work

`RIG-CORE-027` is also about a status token that says something other than what a reader takes from it, but its subject is a neutral row counted as a fault. This is the inverse: a fault counted as agreement. They are separate records and neither depends on the other.
