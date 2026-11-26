---
id: KI-TOOL-RIG-CORE-084
area: CORE
title: Tool radar attributes
priority: medium
size: m
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-26T03:00:00Z
---

# KI-TOOL-RIG-CORE-084: Tool radar attributes

## Goal

Every Rig tool may carry optional, validated and exported attributes: a radar ring (Adopt, Trial, Assess, Caution), a radar sector, a purpose and an install method; a tool with no ring or sector simply does not appear on a radar.

## Context

Kris asked on 6 November 2026 for tools-rig to take this up (RIG-RADAR-ATTRIBUTES, MSG-8793d253). The settled rules are chezmoi's KDR-PERSONAL-DOTFILES-001 (tool radar rings): ThoughtWorks rings, assessment only and never selection, ring public and trial status private. The sector overlaps today's `category`. When it lands, chezmoi declares the values and the Rig site adds attribute filters and a radar view; personal-principal's PERSONAL-PRINCIPAL-052, sector radars, is on hold beside it. Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (RIG-RADAR-ATTRIBUTES). Original line: [the Mac Studio setup messages](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/messages.md), 6 November, with RADAR-SCHEMA on 3 November.

## Boundary

- **In:** the optional attributes' schema and validation, `rig show`, review findings, and a narrow public export that respects KDR-PERSONAL-DOTFILES-001's public and private split.
- **Out:** declaring the values, which chezmoi owns; the site's radar view; the comment and kind fields, which KI-TOOL-RIG-CORE-081 owns.

## Discussion

Planning settles how the sector relates to `category`, and treats the export as a versioned publication contract change. When it lands, personal.site-rig and chezmoi are told along the tree, as its rollout (ki.tools reset map, 26 November 2026). Captured as triage for Kris to adopt or cancel.
