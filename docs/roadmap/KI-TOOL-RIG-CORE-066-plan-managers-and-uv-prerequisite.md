---
id: KI-TOOL-RIG-CORE-066
area: CORE
title: Plan managers, uv prerequisite
purpose: corrective
theme: rig
kind: deliver
horizon: now
status: ready
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T22:55:30Z
---

# Doctor Reports the Selected Plan's Managers, and uv Installs Before Its Tools

## Goal

`rig doctor` reports the availability of exactly the package managers the selected plan uses, including mas and custom providers, with an action when one is missing; and a first `rig apply` on a fresh Mac installs uv through mise before preflighting the uv tools that need it.

## Context

The [rig site configuration design note](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/design/rig-site-config.md), section 3, found two small gaps:

- G2: `rig_doctor_native_availability` (`src/rig/22-observation.bash`) checks a fixed `brew uv mise npm chezmoi` list. It omits mas and custom providers, ignores what the profile selects, and always reports `action=none`.
- G3: `rig_apply_provider_prerequisite` (`src/rig/21-provider-state.bash`) hard-codes three deferral cases: mise from Homebrew, mas from Homebrew, npm from mise node. Kris's uv comes from mise, so by code reading a first apply on a fresh Mac fails full-plan preflight on `claude-swap` and `headroom` ("provider 'uv' executable is unavailable") before any mutation. This is inferred, not reproduced.

Kris chose on 19 October 2026 (MANAGERS-AS-TOOLS a), [Tools burndown decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/decisions.md)) to capture these as one small record, separate from the model change in [KI-TOOL-RIG-CORE-067](KI-TOOL-RIG-CORE-067-package-managers-as-catalogue-tools.md).

## Boundary

- In: doctor deriving its manager list from the providers the selected plan binds, covering built-in and custom providers; a missing manager the plan needs reporting a non-`none` action; a uv-from-mise deferral case; a test-first reproduction of the G3 preflight failure under `tests/` with fixture providers; specification alignment in RIG-STATE and RIG-ORCH.
- Out: the `provides` field and data-derived prerequisites (KI-TOOL-RIG-CORE-067); bringing Homebrew into the catalogue; reproducing G3 against the live workstation, which `AGENTS.md` forbids.

## Current state

Re-read on 19 October 2026 at baseline `cc4e993545d3f1ba792653d88988446e6558ae16`.

- **G3 holds.** `rig_apply_provider_prerequisite` defers a missing manager only for `mise:homebrew:formula:mise`, `mas:homebrew:formula:mas` and `npm:mise:tool:node`. Kris's configuration binds `[tool.uv]` to mise with locator `uv`, and `claude-swap` and `headroom` bind to uv with `requires = ["uv"]`, so on a Mac without uv the full-plan preflight stops at `provider 'uv' executable is unavailable` before any mutation. `tests/rig-bootstrap-staging.bats` already proves the same deferral shape for npm through mise node.
- **G2 does not match the code.** `rig_doctor_native_availability` runs only on doctor's configuration-failure path, where no configuration and therefore no plan exists to derive a manager list from. With a loaded configuration doctor prints no manager list at all; a missing manager surfaces on each dependent tool as `unavailable` with `action=install-or-configure-provider`, which is already a non-`none` action. The fixed `brew uv mise npm chezmoi` line is the information block of a broken configuration (`tests/rig-doctor-config.bats`). Deriving that line "from the selected plan" is therefore not possible, and the useful part of G2, one manager-level finding instead of one per dependant, is exactly KI-TOOL-RIG-CORE-067's attribution item. G2 is left out of this delivery and put to Kris under the RIG-TRIAGE query.

## Steps

- [ ] Add a failing fixture test to `tests/rig-bootstrap-staging.bats`: a mise-hosted `uv` tool and a uv-bound consumer that `requires = ["uv"]`, with uv absent until `mise install uv` runs. Confirm it fails with `provider 'uv' executable is unavailable` before any change.
- [ ] Add `uv:mise:tool:uv|uv:mise:tool:uv@*` to the deferral cases in `rig_apply_provider_prerequisite` (`src/rig/21-provider-state.bash`), and reassemble `bin/rig`.
- [ ] Add a companion test proving a uv consumer without `requires = ["uv"]` is still refused, so the deferral stays explicit.
- [ ] Align RIG-ORCH-018 in `docs/specs/orchestration.md` to name the mise uv prerequisite and its evidence.
- [ ] Run the complete local gate.

## Files touched

- `src/rig/21-provider-state.bash` and the assembled `bin/rig`.
- `tests/rig-bootstrap-staging.bats`.
- `docs/specs/orchestration.md`.
- This record.

## Verify

- The new staging test fails before the code change with the uv preflight error and passes after it; the call log shows `mise install uv` before `uv tool install`, and no `brew bundle`.
- The refusal companion and the existing staging tests still pass, including the two that use uv as an unrelated missing provider.
- [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository) passes, `bats tests/ </dev/null` included. No live apply.

## Dependencies / blocks

Not blocked. KI-TOOL-RIG-CORE-067 would later replace the hard-coded deferral matrix this record extends; this record does not wait for it.

## Documentation impact

### Decision Records

None.

### Specifications

RIG-ORCH-018 names the mise uv prerequisite beside the mise node one.

### Guides

None; no guide enumerates the deferral cases.

### Roadmap

This record moves to Awaiting review at delivery.

## Discussion

### Approval

Kris, 19 October 2026 (TRIAGE-ALL, relayed by the mac-studio-setup State of play): every high-confidence Now recommendation is adopted and delivered to Awaiting review, tools burn-down work first. The rig-triage run of 19 October 2026 recommended this record for Now with high confidence, as the tools burn-down's smallest corrective item, and planned it to Ready with G2 narrowed out as recorded under Current state.

### Origin

Planning should confirm G3 with a fixture test before changing code, and decide whether doctor's line keeps listing chezmoi when no tool binds the `chezmoi` provider. If KI-TOOL-RIG-CORE-067 is adopted first, its derived matrix may absorb G3 and leave only G2 here. Capture only; adoption, priority and plan belong to this repository.
