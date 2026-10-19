---
id: KI-TOOL-RIG-CORE-067
area: CORE
title: Managers as catalogue tools
purpose: capability
theme: rig
status: triage
priority: medium
size: l
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T20:49:28Z
---

# Package Managers as Catalogue Tools

## Goal

A catalogue tool can declare `provides = "MANAGER"` for a built-in manager, Homebrew included, so Rig derives each bound tool's manager edge, the apply-time prerequisite order and doctor's missing-manager finding from data instead of hand-written `requires` and hard-coded lists.

## Context

The [rig site configuration design note](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/design/rig-site-config.md), section 3, found package managers half-modelled. mas, mise, node, npm and uv are ordinary catalogue tools with hand-written `requires` links, but Homebrew, the manager behind 128 of Kris's 170 installation-bearing tools, sits outside the catalogue: it must pre-exist (RIG-ORCH-018), has no rationale or public card, and a missing Homebrew surfaces as one `unavailable` finding per dependent tool (G1). Nothing checks that a tool installed by mas, mise, npm or uv declares the matching `requires`, so a new App Store tool without `requires = ["mas"]` would fail a fresh-Mac apply with no warning (G4).

Kris chose on 19 October 2026 (MANAGERS-AS-TOOLS a), [Tools burndown decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/decisions.md)) to capture this model change as its own record, separate from the small fixes in [KI-TOOL-RIG-CORE-066](KI-TOOL-RIG-CORE-066-plan-managers-and-uv-prerequisite.md).

## Boundary

- In: an optional `provides` field on `[tool.*]` naming a built-in manager; Homebrew declarable as an observation-only tool because it must pre-exist; deriving the manager edge for every tool bound to a provided manager; replacing the hard-coded deferral matrix in `rig_apply_provider_prerequisite` with that data; attributing a missing manager to one finding on the manager tool rather than to every dependant; deriving doctor's manager list from the selected plan; validation for a tool whose manager no selected tool provides; specification, guide and test alignment.
- Out: installing Homebrew itself; Rig orchestrating Brewfiles or Homebrew Bundle; custom providers, which ship as executables; any change to public-export content, including derived manager edges entering public relationships, which needs its own decision; authoring `provides` in Kris's configuration, a later chezmoi step.

## Dependencies / blocks

Not blocked. It would supersede the hard-coded deferral case KI-TOOL-RIG-CORE-066 adds.

## Discussion

A no-code interim exists: declare `[tool.homebrew]` as a catalogue-only public tool in chezmoi and add `requires = ["homebrew"]` where wanted, at the cost of 128 hand edits this record would then police. Planning questions: whether derived edges sit beside or replace hand-written manager `requires`, and whether a hand-written edge that duplicates a derived one warns; how `provides` interacts with platform variants, since a tool's manager differs by platform; whether the mise-hosted runtimes (node for npm, uv) are modelled as providers of their managers or as ordinary prerequisites; and whether this warrants a Decision Record, since it moves manager knowledge from code into the catalogue. Capture only; adoption, priority and plan belong to this repository.
