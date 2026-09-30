---
id: RIG-CLI-022
area: CLI
title: Name relationship endpoints
theme: cli
horizon: soon
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T09:10:00Z
updated_at: 2026-09-30T09:39:54Z
---

## Goal

Somebody reading `rig explain` sees what a tool requires, relates to, or replaces by the name they know it by, not only by the catalogue identifier that names it.

## Context

`rig explain processspy` reports `Alternatives: builtin-activity-monitor`, and `rig explain path-finder` reports `Alternatives: builtin-finder`. `Requires: npm` and `Related: codex` read the same way. The identifier is correct and stable, but it is the wrong register for a line whose other fields are `Name: ProcessSpy` and `Category: system (System)` — the category line already resolves an identifier to its display name in exactly the shape a relationship line could use.

The case surfaced under `DOTFILES-UE-061`, which typed two displacements as `alternatives` edges so that they would be visible to consumers rather than buried in a `rationale` sentence. The edges are visible now, as identifiers.

## Boundary

`rig export` keeps identifiers. The version-2 shape at `src/rig/40-publication-lifecycle.bash:134` carries relationships as structured values whose consumers resolve names themselves, and changing that is a schema change with a compatibility cost this record does not take on. Whether a rendered public projection built from that export should resolve names is that projection's concern.

`rig explain` gains no new flag. The line changes shape for everyone or for nobody.

## Current state

`rig_command_explain` in `src/rig/30-commands.bash` joins the collected identifiers for all three relationship kinds with `rig_join_query_items` and prints them as-is at `:1467`. The category line at `:1466` prints `identifier (Display Name)`, which is the precedent.

## Shaping

Use `identifier (Display Name)` for relationship endpoints, matching the existing Category line. Promote this after the command-surface audit confirms that `rig explain` remains a distinct query and before the shared report-rendering change, so the text representation has one reviewed owner. No export schema change is needed.

## Discussion

### Which register to lead with

`Category: system (System)` leads with the identifier and parenthesises the name. A relationship line could do the same, `builtin-finder (Finder)`, or invert it, `Finder (builtin-finder)`. The category precedent argues for the former; the fact that a person reads `explain` to learn about a tool rather than to look up identifiers argues for the latter. Either is better than the identifier alone, and consistency with the category line is probably the deciding factor.
