---
id: KI-TOOL-RIG-CORE-078
area: CORE
title: Record interrupted launchd applies
priority: medium
size: m
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-18T05:30:00Z
updated_at: 2026-11-18T05:30:00Z
---

# KI-TOOL-RIG-CORE-078: Record interrupted launchd applies

## Goal

A launchd apply that is killed or interrupted before it finishes leaves a row in apply history, so `rig doctor` can report the resource as interrupted rather than showing nothing.

## Context

On 12 November 2026 a `rig apply --scope resources` on `sol` was killed while booting out `com.stablyai.orca.serve`. `rig_history_begin` in `src/rig/25-apply-history.bash` only reserves an attempt and `rig_history_complete` writes the row once the native apply returns, so the interrupted apply left no row: the last `service:orca-serve` row was from 8 November, and nothing in Rig showed that the agent had been unloaded. The evidence is in the dotfiles repository's record PERSONAL-DOTFILES-UE-141, which proposed this as the third of three fixes. KI-TOOL-RIG-CORE-077 delivers the first two. Source revision at capture: `c552d7f2fcb83194a5c92776a24898e37902fcda`.

## Boundary

- **In:** writing a started row, or an equivalent durable marker, before a launchd apply acts; reconciling it on completion; a doctor finding for an attempt that never completed; specification and tests.
- **Out:** the no-op reconcile and the hosting-caller refusal, which KI-TOOL-RIG-CORE-077 owns; providers other than launchd unless the same transaction serves them without extra cost; any live apply.

## Discussion

- 18 November 2026, Kitteth (the Cairn summit's guardian), under CASCADE-DOWN: split from KI-TOOL-RIG-CORE-077. Untriaged: the open design question is whether the reserved attempt itself becomes the started row, or a separate marker is written, and whether every provider gains it rather than only launchd.
