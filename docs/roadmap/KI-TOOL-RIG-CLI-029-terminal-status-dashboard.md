---
id: KI-TOOL-RIG-CLI-029
area: CLI
title: Terminal status dashboard
priority: low
size: m
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-24T12:02:30Z
---

# KI-TOOL-RIG-CLI-029: Terminal status dashboard

## Goal

A terminal dashboard shows a Mac's Rig state at a glance by reading `rig status --json`, as a separate viewer rather than a mode of the Bash CLI.

## Context

Kris asked on 27 October 2026 for a tools-rig record (RIG-TUI): a terminal dashboard reading `rig status --json`, a separate viewer since Rig is Bash, perhaps Textual or a TypeScript terminal toolkit. The [rig-intake report](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/setup/rig-intake.report.md) proposed folding RIG-FULLSCREEN, a held idea for a full-screen view inside Rig, in as the alternative shape. Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (RIG-INTAKE). Original line: [the Mac Studio setup messages](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/messages.md), 28 October.

## Boundary

- **In:** choosing the viewer's home and toolkit, a read-only dashboard over `rig status --json`, and RIG-FULLSCREEN as the alternative in-Rig shape.
- **Out:** any change to what `rig status --json` reports, which KI-TOOL-RIG-CLI-028 owns; acting on the Mac from the dashboard.

## Discussion

KI-TOOL-RIG-CLI-028's item (5), sections missing from `--json`, is a known dependency. Planning settles whether the viewer lives in tools-rig or its own repository, and whether a separate runtime is acceptable beside a pure-Bash tool. Captured as triage for Kris to adopt or cancel.
