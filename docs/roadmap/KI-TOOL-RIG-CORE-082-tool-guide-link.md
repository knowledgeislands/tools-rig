---
id: KI-TOOL-RIG-CORE-082
area: CORE
title: Tool guide link
priority: low
size: s
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-24T12:02:30Z
---

# KI-TOOL-RIG-CORE-082: Tool guide link

## Goal

A tool may declare an optional `guide` link, shown in Rig's tool description, so that each tool's guide is managed in Rig as well.

## Context

Kris asked on 31 October 2026 for each tool's guide to be "managed in Rig as well" (GUIDE-FIELD). Rig has no guide field and rejects unknown fields. The proposal is an optional `guide` link on a tool, shown in Rig's tool description and kept off the public site unless separately agreed, first used for the chezmoi modern-tools guide (eza, fd, bat). Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (GUIDE-FIELD). Original ask: [the Mac Studio setup discussions](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/discussions.md), RIG-ASKS.

## Boundary

- **In:** the optional field, its validation, `rig show`'s display, specification and tests.
- **Out:** exporting the link to the public site, unless separately agreed; writing the guides themselves.

## Discussion

Captured as triage for Kris to adopt or cancel.
