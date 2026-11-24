---
id: KI-TOOL-RIG-CORE-081
area: CORE
title: Export comment and kind
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

# KI-TOOL-RIG-CORE-081: Export comment and kind

## Goal

`rig export` carries an optional `comment` on each tool, its provider and install kind (never the locator) and a declared `kind` (application, command-line tool, runtime and so on), with `rationale` deprecated in stages through a versioned publication contract change.

## Context

Kris chose this on 20 October 2026 for the Rig site's tool table (RIG-COMMENT-KIND). The publishing specification still exports `rationale` and excludes provider and installation fields, and publication v1 forbids silently removing a field. The Rig site already renders `comment` and will read the new fields once shipped; its half is carried by personal.site-rig. Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (RIG-INTAKE), and the [rig-intake report](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/setup/rig-intake.report.md). Original line: [the Mac Studio setup messages](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/messages.md), 20 October.

## Boundary

- **In:** the optional `comment` field on tool declarations and in publishing's allowed fields; the declared `kind`; exporting provider and install kind; the staged, versioned deprecation of `rationale`; specification and tests.
- **Out:** the locator, which is never exported; the site's rendering; radar attributes, which KI-TOOL-RIG-CORE-084 owns.

## Discussion

This is a versioned publication contract change and planning must treat it as one. When it lands, personal.site-rig is told, under change 11's step 6. Captured as triage for Kris to adopt or cancel.
