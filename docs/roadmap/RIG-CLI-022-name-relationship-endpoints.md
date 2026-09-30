---
id: RIG-CLI-022
area: CLI
title: Name relationship endpoints
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 8b35359326ba8d2a1e861ad3162b3dd56f667d9b
created_at: 2026-09-30T09:10:00Z
updated_at: 2026-09-30T20:11:30Z
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

## Steps

- [x] Resolve `requires`, `related`, and `alternatives` endpoints to `identifier (Display Name)` in `rig explain` while preserving declaration order.
- [x] Keep configuration validation and structured export unchanged.
- [x] Cover all three relationship fields, punctuation, ordered multiple endpoints, and an empty relationship in Bats.
- [x] Update the user command guide, manual, and query Specification.

## Files touched

`src/rig/30-commands.bash`, generated `bin/rig`, `tests/rig.bats`, and `man/rig.1` or `docs/guides/user/commands.md` where the old examples appear.

## Verify

The focused explain tests must show stable identifiers and exact display names for all three relationship kinds while `rig export` remains byte-identical. Run ShellCheck, assembly check, full Bats suite, and man lint.

## Dependencies / blocks

The command-surface audit [RIG-CORE-037](RIG-CORE-037-audit-rig-surface-and-structure.md) is awaiting review and confirms `rig explain` remains a distinct query. Implement before [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md) so the shared renderer receives the settled text shape.

## Documentation impact

### Decision Records

None; the existing category display convention supplies the choice.

### Specifications

Update the explain text contract if it enumerates relationship rendering; do not change export schema 2.

### Guides

Align the manual and user command guide with the displayed relationship examples.

### Roadmap

No follow-up expected; shared report rendering remains a separate item.

## Review

### Delivered

From baseline `8b35359326ba8d2a1e861ad3162b3dd56f667d9b`, `rig explain` names tool relationship endpoints while retaining their stable identifiers.

### Change Summary

An explain-only join helper resolves each relationship identifier to its declared name. The three text fields use it; no export code or schema changed. The query Specification, manual, guide, and fixture assertions now describe the display shape.

### Verification

Focused explain tests and the complete Bats suite passed. Repository audit, ShellCheck, Bash syntax, assembly check, native-provider smoke test, man lint, and diff check passed. The benchmark passed when rerun alone; one concurrent run exceeded its status budget under full-suite load.

### Outstanding concerns

The text remains a human display; consumers needing stable structured relationships should use export. This change does not alter non-tool explanation fields.

### Post-change review

The output preserves ID-first category-style formatting and declaration order, including two related endpoints; punctuation in a display name survives unchanged. Empty relationships remain `none`.

### Mini recap

Named relationship endpoints are delivered for acceptance review ahead of shared report rendering.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### Which register to lead with

`Category: system (System)` leads with the identifier and parenthesises the name. A relationship line could do the same, `builtin-finder (Finder)`, or invert it, `Finder (builtin-finder)`. The category precedent argues for the former; the fact that a person reads `explain` to learn about a tool rather than to look up identifiers argues for the latter. Either is better than the identifier alone, and consistency with the category line is probably the deciding factor.
