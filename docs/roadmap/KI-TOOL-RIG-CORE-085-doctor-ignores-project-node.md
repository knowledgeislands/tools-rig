---
id: KI-TOOL-RIG-CORE-085
area: CORE
title: Doctor ignores project Node
priority: medium
size: s
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-24T12:02:30Z
---

# KI-TOOL-RIG-CORE-085: Doctor ignores project Node

## Goal

`rig doctor` reports the same npm globals wherever it is run, so running it inside a repository whose `mise.toml` pins its own Node no longer reports them as missing.

## Context

Seen in household-terra's package sweep on 3 November 2026 (DOCTOR-NODE-PIN): `rig doctor`, run from inside a repository whose `mise.toml` pins its own Node, reports the npm globals as missing. Not yet diagnosed; the likely cause is that observation resolves `npm` through the working directory's mise pin rather than the global Node. Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (DOCTOR-NODE-PIN). Original line: [the Mac Studio setup messages](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/messages.md), 3 November.

## Boundary

- **In:** diagnosing the cause, making npm-global observation independent of the working directory, and a test in a disposable directory with its own pin.
- **Out:** mise's own configuration; which Node versions a profile declares.

## Discussion

Planning reproduces it on the current Rig before changing anything. Captured as triage for Kris to adopt or cancel.
