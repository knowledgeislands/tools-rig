---
id: KI-TOOL-RIG-CORE-083
area: CORE
title: Retire one stale service
priority: medium
size: m
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-24T12:02:30Z
---

# KI-TOOL-RIG-CORE-083: Retire one stale service

## Goal

A person can retire one stale service or scheduled job on a Mac, including one that has left the Mac's profile, without reconciling every live service at once.

## Context

Two asks describe the same fault. RIG-RETIRE-ONE (31 October 2026, at Kris's request): retiring one switched-off service, Paperclip's leftover launch file on terra, meant reconciling all eight live services at once; the ask is a way to retire one stale resource on its own. RIG-RETIRE (7 November 2026, from household-sol): Rig cannot retire a job that leaves a Mac's profile, so each job moved to another Mac is unloaded by hand. Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (RIG-RETIRE-ONE). Original ask: [the Mac Studio setup discussions](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/discussions.md), RIG-ASKS.

## Boundary

- **In:** selecting one service or scheduled job for retirement, including one no longer declared for this host; unloading it and removing its rendered launch file; specification and tests in disposable state.
- **Out:** reloading unchanged agents, which KI-TOOL-RIG-CORE-077 owns; removing applications or their data; host-specific software retirement, held as the KI-TOOL-RIG-CORE-074 idea.

## Discussion

Planning settles whether this is a targeted `rig remove` or a removal tracked from apply history when a job leaves the profile. Captured as triage for Kris to adopt or cancel.
