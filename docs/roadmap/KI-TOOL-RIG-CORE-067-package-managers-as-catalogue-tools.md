---
id: KI-TOOL-RIG-CORE-067
area: CORE
title: Managers as catalogue tools
purpose: capability
theme: rig
kind: deliver
status: draft
horizon: next
priority: medium
size: l
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T23:58:00Z
---

# Package Managers as Catalogue Tools

## Goal

A catalogue tool can declare `provides = "MANAGER"` for a built-in manager, Homebrew included, so Rig derives each bound tool's manager edge, the apply-time prerequisite order and doctor's missing-manager finding from data instead of hand-written `requires` and hard-coded lists. `rig doctor` reports the availability of the managers the selected plan uses, built-in and custom providers alike, with one actionable manager-level finding when one is missing.

## Context

The [rig site configuration design note](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/design/rig-site-config.md), section 3, found package managers half-modelled. mas, mise, node, npm and uv are ordinary catalogue tools with hand-written `requires` links, but Homebrew, the manager behind 128 of Kris's 170 installation-bearing tools, sits outside the catalogue: it must pre-exist (RIG-ORCH-018), has no rationale or public card, and a missing Homebrew surfaces as one `unavailable` finding per dependent tool (G1). Nothing checks that a tool installed by mas, mise, npm or uv declares the matching `requires`, so a new App Store tool without `requires = ["mas"]` would fail a fresh-Mac apply with no warning (G4).

Kris chose on 19 October 2026 (MANAGERS-AS-TOOLS a), [Tools burndown decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/decisions.md)) to capture this model change as its own record, separate from the small fixes in [KI-TOOL-RIG-CORE-066](https://github.com/knowledgeislands/tools-rig/blob/4ca939fa230b3e9eb02d9a170491a544a51b3651/docs/roadmap/KI-TOOL-RIG-CORE-066-plan-managers-and-uv-prerequisite.mdCORE-066).

## Boundary

- In: an optional `provides` field on `[tool.*]` naming a built-in manager; Homebrew declarable as an observation-only tool because it must pre-exist; deriving the manager edge for every tool bound to a provided manager; replacing the hard-coded deferral matrix in `rig_apply_provider_prerequisite` with that data; attributing a missing manager to one actionable finding on the manager tool rather than to every dependant; doctor reporting the availability of the built-in and custom providers the selected plan binds, folded from KI-TOOL-RIG-CORE-066's G2; validation for a tool whose manager no selected tool provides; specification, guide and test alignment.
- Out: installing Homebrew itself; Rig orchestrating Brewfiles or Homebrew Bundle; declaring `provides` for custom providers, which ship as executables, though their availability is in; any change to public-export content, including derived manager edges entering public relationships, which needs its own decision; authoring `provides` in Kris's configuration, a later chezmoi step.

## Current state

Not yet grounded. `ki-plan` records the current source facts before Ready.

## Steps

- [ ] Plan this record under `ki-plan` before Ready, including the G2 fold, replacing these placeholder sections.

## Files touched

Not yet planned.

## Verify

Not yet planned.

## Dependencies / blocks

Not blocked. It would supersede the hard-coded deferral case KI-TOOL-RIG-CORE-066 adds, and owns that record's undelivered G2.

## Documentation impact

### Decision Records

Not yet assessed.

### Specifications

Not yet assessed.

### Guides

Not yet assessed.

### Roadmap

Not yet assessed.

## Discussion

A no-code interim exists: declare `[tool.homebrew]` as a catalogue-only public tool in chezmoi and add `requires = ["homebrew"]` where wanted, at the cost of 128 hand edits this record would then police. Planning questions: whether derived edges sit beside or replace hand-written manager `requires`, and whether a hand-written edge that duplicates a derived one warns; how `provides` interacts with platform variants, since a tool's manager differs by platform; whether the mise-hosted runtimes (node for npm, uv) are modelled as providers of their managers or as ordinary prerequisites; and whether this warrants a Decision Record, since it moves manager knowledge from code into the catalogue. Capture only; adoption, priority and plan belong to this repository.

G2 fold: KI-TOOL-RIG-CORE-066's G2 asked doctor to derive its manager list from the selected plan, covering mas and custom providers, with an action when one is missing. Its fixed `brew uv mise npm chezmoi` line runs only on doctor's configuration-failure path, where no plan exists; with a loaded configuration a missing manager surfaces per dependent tool as `unavailable` with `action=install-or-configure-provider`. Planning decides where the plan-derived manager report sits on the loaded-configuration path, how custom providers report availability, and whether the broken-configuration line keeps its fixed list.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: RIG-MANAGERS a), confidence high, folds G2 here, and RIG-TRIAGE's Next adoption, confidence high, follows because catalogue-derived manager prerequisites and one manager-level finding sit inside Rig's manager-of-managers boundary while platform variants and edge semantics need design before Ready.
