---
id: KI-TOOL-RIG-CORE-067
area: CORE
title: Managers as catalogue tools
purpose: capability
theme: rig
kind: deliver
status: ready
horizon: next
priority: medium
size: l
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-20T22:21:02Z
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

Grounded at `973073e` on 20 October 2026 from source only.

- **Deferral is a fixed matrix.** `rig_apply_provider_prerequisite` ([`21-provider-state.bash`](../../src/rig/21-provider-state.bash)) lets apply defer a missing built-in manager only for four `adapter:provider:kind:locator` shapes (mise and mas from a Homebrew formula, npm from mise `node`, uv from mise `uv`), and only when the consumer reaches the prerequisite through hand-written `requires` (`rig_tool_requires_tool`, [`30-commands.bash`](../../src/rig/30-commands.bash)) earlier in the selected plan. Homebrew is never deferrable, as [RIG-ORCH-018](../specs/orchestration.md) requires.
- **Missing managers repeat per tool.** With a loaded configuration, `rig_observe_plan` ([`22-observation.bash`](../../src/rig/22-observation.bash)) reports each tool whose manager executable is absent as `unavailable (executable-unavailable)`, `action=install-or-configure-provider`, once per dependant. A tool whose prerequisite failed already reports `unknown (blocked-by:<tool>)` with `action=resolve-<tool>`, so the blocked-by path exists to reuse.
- **The fixed doctor list.** `rig_doctor_native_availability` prints `brew uv mise npm chezmoi` availability only when the configuration failed to load; it never covers mas or custom providers.
- **Catalogue-only tools are neutral.** A `[tool.*]` with no installation binding observes as `unavailable (catalogue-only)` and counts as neutral, which is what a `[tool.homebrew]` declared today would be.
- **Relationships.** [RIG-CAT-004](../specs/catalogue.md) types `requires`, `related` and `alternatives`; [RIG-CAT-008](../specs/catalogue.md) lets a tool's installation differ by platform variant while its identity and relationships stay single. A manager edge is therefore a property of the consumer's bound provider on the resolved platform, not of its catalogue identity.

## Queries

- **PLAN067-EDGES.** Should derived manager edges sit beside hand-written `requires`, with a duplicate accepted silently? Recommended a), confidence high: every existing configuration stays valid, the plan order is the union, and `rig explain` can label each edge `derived` or `declared`. b) replace manager `requires`, warning on duplicates, which forces about 25 hand edits in the personal configuration on upgrade (14 mas, 9 npm and 2 uv edges, per the design note).
- **PLAN067-OPTIN.** Should the missing-provider check (G4) run only once the catalogue declares at least one `provides`? Recommended a), confidence high: a configuration without `provides` behaves exactly as today, and the check can then name the one manager a tool's binding needs. b) always warn, which reports Homebrew as undeclared on every current configuration.
- **PLAN067-MATRIX.** Keep the fixed deferral matrix as the fallback for a manager no catalogue tool provides? Recommended a), confidence medium: it avoids a behaviour change for configurations that never adopt `provides`, at the cost of two routes until a later removal. b) remove it now and require `provides` for any deferral.
- **PLAN067-ADR.** Record the move of manager knowledge into the catalogue as a new Decision Record, ADR-KI-TOOL-RIG-011? Recommended a), confidence high: it amends RIG-ORCH-018's "Homebrew itself MUST already be available" into "observed, never installed", and changes where manager knowledge lives, which is durable rationale. b) specification changes only.
- **PLAN067-READY.** Approve this plan to Ready once the four answers are in? Recommended a), confidence medium: each step is fixture-testable and touches no live manager, but the record is large and changes apply ordering.

## Steps

- [x] **Gate.** The five queries answered and this plan adjusted to the answers. Without that, stop.
- [x] **1. Decision Record.** Per PLAN067-ADR, write [ADR-KI-TOOL-RIG-011](../decisions/ADR-KI-TOOL-RIG-011-package-managers-as-catalogue-tools.md) (proposed): managers are catalogue tools that declare `provides`; Rig derives manager edges from the consumer's bound provider; Homebrew is observed and never installed. Written and indexed with the Ready sign-off, as the owner directed; delivery marks it current once the code lands.
- [ ] **2. `provides` field.** Accept optional `provides` on `[tool.*]`, naming one of the built-in manager adapters (`homebrew`, `mas`, `mise`, `npm`, `uv`, `chezmoi`). Reject an unknown manager, two tools providing the same manager, and `provides` on a variant. A tool with `provides = "homebrew"` needs no installation binding.
- [ ] **3. Derived edges.** During plan resolution, for each selected tool bound to a built-in manager that a selected tool provides, add an ordering edge to the providing tool, using the binding for the resolved platform. Edges sit beside hand-written `requires` (PLAN067-EDGES): the plan order is their union, a duplicate is accepted silently, both enter cycle detection, and `rig explain` labels each edge `derived` or `declared`. They are never written into the public projection.
- [ ] **4. Data-driven deferral.** `rig_apply_provider_prerequisite` defers a missing manager when the providing tool is earlier in the selected plan, whether by derived or declared edge. The fixed matrix stays as the fallback for a manager no selected tool provides (PLAN067-MATRIX). Homebrew is never deferred: a tool providing it is observation-only.
- [ ] **5. One manager-level finding.** A missing provided manager reports once, on the providing tool (`homebrew: unavailable (manager-missing); action=install-homebrew`, other managers `action=run-rig-apply`), and each dependant reports `unknown (blocked-by:<manager tool>)`. Without `provides`, today's per-tool finding stays.
- [ ] **6. Doctor manager report (G2).** On the loaded-configuration path, doctor adds one `managers` block listing each manager the selected plan binds, built-in and custom, with `available` or `unavailable`, the owning tool or `provider:<id>`, and an action. A custom provider's availability is its executable's. The broken-configuration path keeps its fixed list, extended with `mas`.
- [ ] **7. Missing-provider check (G4).** Only once the catalogue declares at least one `provides` (PLAN067-OPTIN), `rig doctor` warns `manager-not-declared:<manager>` for a selected tool bound to a built-in manager that no selected tool provides.
- [ ] **8. Fixtures.** Extend `tests/rig-provider-fixtures.bats` (or a new `tests/rig-managers.bats`) with `rig_test_provider` stubs: derived order without `requires`, a duplicate hand-written edge accepted and labelled `declared`, the fixed-matrix fallback with no `provides`, Homebrew observed and never installed, one manager finding with blocked dependants, deferral through a derived edge, duplicate and unknown `provides` rejected, variant platforms choosing different managers, the doctor block including a custom provider, and an unchanged configuration without `provides`.
- [ ] **9. Documents and assembly.** Amend the specifications and guides under [Documentation impact](#documentation-impact), add a CHANGELOG entry, run `scripts/assemble-rig`, then the gate under [Verify](#verify).

## Files touched

- `src/rig/10-configuration.bash` — `provides` field and validation.
- `src/rig/20-orchestration.bash`, `src/rig/21-provider-state.bash` — derived edges and deferral.
- `src/rig/22-observation.bash`, `src/rig/30-commands.bash` — manager finding, doctor block, warning.
- `bin/rig` — regenerated, never edited.
- `tests/` — the fixture cases in step 8.
- `docs/decisions/ADR-KI-TOOL-RIG-011-package-managers-as-catalogue-tools.md` and `docs/decisions/README.md` (written at Ready; delivery sets it current), `docs/specs/catalogue.md`, `docs/specs/orchestration.md`, `docs/specs/state.md`, `docs/guides/user/getting-started.md`, `docs/guides/user/commands.md`, `man/rig.1`, `CHANGELOG.md`.
- This record.

## Verify

- The new fixture cases pass, and the existing provider, Homebrew-authority and uv suites pass unchanged, which shows a configuration without `provides` is unaffected.
- The complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes, including `scripts/smoke-native-providers`, `scripts/assemble-rig --check` and `mandoc -T lint man/rig.1`.
- No step installs a manager on the workstation. Adding `provides` to the personal configuration and checking `rig doctor` on `sol` is a later chezmoi step.

## Dependencies / blocks

Not blocked. It supersedes the hard-coded uv-from-mise deferral that [KI-TOOL-RIG-CORE-066](https://github.com/knowledgeislands/tools-rig/blob/028aaae74b69b24e70fe5b5f2307d8b53a16653f/docs/roadmap/KI-TOOL-RIG-CORE-066-plan-managers-and-uv-prerequisite.md) added, which stays as the fallback for a manager no catalogue tool provides (PLAN067-MATRIX), and owns that record's G2.

## Documentation impact

### Decision Records

[ADR-KI-TOOL-RIG-011](../decisions/ADR-KI-TOOL-RIG-011-package-managers-as-catalogue-tools.md), written and indexed at Ready as `proposed`; delivery sets it `current`. [ADR-KI-TOOL-RIG-005](../decisions/ADR-KI-TOOL-RIG-005-provider-execution-contract.md)'s native-tool boundary is unchanged: Rig still never installs Homebrew or orchestrates Brewfiles.

### Specifications

RIG-CAT-004 gains derived manager edges and a new catalogue requirement for `provides` (next free `RIG-CAT-010`); RIG-ORCH-018 changes from a fixed deferral list to provider-derived deferral; a new state requirement covers the manager finding and doctor block (next free `RIG-STATE-049`, since [KI-TOOL-RIG-CORE-053](KI-TOOL-RIG-CORE-053-macos-menu-bar-declarations.md) took `RIG-STATE-048`).

### Guides

The getting-started guide's fresh-Mac stage says to declare `[tool.homebrew]` with `provides`; the commands guide describes the doctor `managers` block.

### Roadmap

This record only.

## Discussion

A no-code interim exists: declare `[tool.homebrew]` as a catalogue-only public tool in chezmoi and add `requires = ["homebrew"]` where wanted, at the cost of 128 hand edits this record would then police. Planning questions: whether derived edges sit beside or replace hand-written manager `requires`, and whether a hand-written edge that duplicates a derived one warns; how `provides` interacts with platform variants, since a tool's manager differs by platform; whether the mise-hosted runtimes (node for npm, uv) are modelled as providers of their managers or as ordinary prerequisites; and whether this warrants a Decision Record, since it moves manager knowledge from code into the catalogue. Capture only; adoption, priority and plan belong to this repository.

G2 fold: KI-TOOL-RIG-CORE-066's G2 asked doctor to derive its manager list from the selected plan, covering mas and custom providers, with an action when one is missing. Its fixed `brew uv mise npm chezmoi` line runs only on doctor's configuration-failure path, where no plan exists; with a loaded configuration a missing manager surfaces per dependent tool as `unavailable` with `action=install-or-configure-provider`. Planning decides where the plan-derived manager report sits on the loaded-configuration path, how custom providers report availability, and whether the broken-configuration line keeps its fixed list.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: RIG-MANAGERS a), confidence high, folds G2 here, and RIG-TRIAGE's Next adoption, confidence high, follows because catalogue-derived manager prerequisites and one manager-level finding sit inside Rig's manager-of-managers boundary while platform variants and edge semantics need design before Ready.

Gate: Kris's sign-off of 20 October 2026 at 23:16 BST in the [ways-of-working decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/decisions.md), "query sign-offs, first batch", took PLAN067-READY as a) with the four recommended answers: PLAN067-EDGES a), derived manager edges sit beside hand-written `requires` and a duplicate is accepted silently; PLAN067-OPTIN a), the missing-provider check runs only once the catalogue declares a `provides`; PLAN067-MATRIX a), the fixed deferral matrix stays as the fallback for a manager no catalogue tool provides; PLAN067-ADR a), ADR-KI-TOOL-RIG-011 records the move. The plan above is adjusted to those answers and the record is Ready.
