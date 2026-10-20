---
id: KI-TOOL-RIG-CORE-066
area: CORE
title: uv prerequisite from mise
purpose: corrective
theme: rig
kind: deliver
horizon: now
status: awaiting-review
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: d0ea7430d4dd016596459b25c6612a30d70e4666
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T23:58:00Z
---

# uv Installs Through mise Before Its Tools

## Goal

A first `rig apply` on a fresh Mac installs uv through mise before preflighting the uv tools that need it. The doctor manager-availability outcome first captured here as G2 now belongs to [KI-TOOL-RIG-CORE-067](KI-TOOL-RIG-CORE-067-package-managers-as-catalogue-tools.md).

## Context

The [rig site configuration design note](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/design/rig-site-config.md), section 3, found two small gaps:

- G2: `rig_doctor_native_availability` (`src/rig/22-observation.bash`) checks a fixed `brew uv mise npm chezmoi` list. It omits mas and custom providers, ignores what the profile selects, and always reports `action=none`.
- G3: `rig_apply_provider_prerequisite` (`src/rig/21-provider-state.bash`) hard-codes three deferral cases: mise from Homebrew, mas from Homebrew, npm from mise node. Kris's uv comes from mise, so by code reading a first apply on a fresh Mac fails full-plan preflight on `claude-swap` and `headroom` ("provider 'uv' executable is unavailable") before any mutation. This is inferred, not reproduced.

Kris chose on 19 October 2026 (MANAGERS-AS-TOOLS a), [Tools burndown decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/decisions.md)) to capture these as one small record, separate from the model change in [KI-TOOL-RIG-CORE-067](KI-TOOL-RIG-CORE-067-package-managers-as-catalogue-tools.md).

## Boundary

- In: a uv-from-mise deferral case; a test-first reproduction of the G3 preflight failure under `tests/` with fixture providers; specification alignment in RIG-ORCH.
- Out: G2, doctor's manager availability and its manager-level finding, folded into KI-TOOL-RIG-CORE-067; the `provides` field and data-derived prerequisites (KI-TOOL-RIG-CORE-067); bringing Homebrew into the catalogue; reproducing G3 against the live workstation, which `AGENTS.md` forbids.

## Current state

Re-read on 19 October 2026 at baseline `cc4e993545d3f1ba792653d88988446e6558ae16`.

- **G3 holds.** `rig_apply_provider_prerequisite` defers a missing manager only for `mise:homebrew:formula:mise`, `mas:homebrew:formula:mas` and `npm:mise:tool:node`. Kris's configuration binds `[tool.uv]` to mise with locator `uv`, and `claude-swap` and `headroom` bind to uv with `requires = ["uv"]`, so on a Mac without uv the full-plan preflight stops at `provider 'uv' executable is unavailable` before any mutation. `tests/rig-bootstrap-staging.bats` already proves the same deferral shape for npm through mise node.
- **G2 does not match the code.** `rig_doctor_native_availability` runs only on doctor's configuration-failure path, where no configuration and therefore no plan exists to derive a manager list from. With a loaded configuration doctor prints no manager list at all; a missing manager surfaces on each dependent tool as `unavailable` with `action=install-or-configure-provider`, which is already a non-`none` action. The fixed `brew uv mise npm chezmoi` line is the information block of a broken configuration (`tests/rig-doctor-config.bats`). Deriving that line "from the selected plan" is therefore not possible, and the useful part of G2, one manager-level finding instead of one per dependant, is exactly KI-TOOL-RIG-CORE-067's attribution item. G2 is left out of this delivery and put to Kris under the RIG-TRIAGE query.

## Steps

- [x] Add a failing fixture test to `tests/rig-bootstrap-staging.bats`: a mise-hosted `uv` tool and a uv-bound consumer that `requires = ["uv"]`, with uv absent until `mise install uv` runs. Confirm it fails with `provider 'uv' executable is unavailable` before any change.
- [x] Add `uv:mise:tool:uv|uv:mise:tool:uv@*` to the deferral cases in `rig_apply_provider_prerequisite` (`src/rig/21-provider-state.bash`), and reassemble `bin/rig`.
- [x] Add a companion test proving a uv consumer without `requires = ["uv"]` is still refused, so the deferral stays explicit.
- [x] Align RIG-ORCH-018 in `docs/specs/orchestration.md` to name the mise uv prerequisite and its evidence.
- [x] Run the complete local gate.

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

## Review

### Delivered

Within the narrowed boundary recorded under Current state: a first `rig apply` now installs uv through a declared, selected mise prerequisite before preflighting the uv tools that require it, and still refuses a uv consumer that does not declare `requires = ["uv"]`. G2, the doctor manager list, was not delivered; it waits on the RIG-TRIAGE query. Baseline `d0ea7430d4dd016596459b25c6612a30d70e4666`; the delivery commit follows it. Nothing was applied live.

### Change Summary

- `src/rig/21-provider-state.bash`: `rig_apply_provider_prerequisite` gains the `uv:mise:tool:uv` and `uv:mise:tool:uv@*` deferral cases; `bin/rig` reassembled.
- `tests/rig-bootstrap-staging.bats`: a `write_uv_fixture` helper and two tests, the mise uv staging order and the refusal without an explicit `requires`.
- `docs/specs/orchestration.md`: RIG-ORCH-018 names the mise uv prerequisite and its evidence.
- Deviation: G2 is out of this delivery because its premise does not match the code (Current state); no other deviation.

### Verification

- New staging test failed before the code change with `provider 'uv' executable is unavailable`, confirming G3 by fixture, and passes after it, with `mise install uv` logged before `uv tool install ruff`.
- Refusal companion and the eight existing staging tests pass, including the two using uv as an unrelated missing provider.
- `bats tests/ </dev/null`: 584 of 584 pass.
- `ki repo audit --repo .`: no failures; warnings are the pre-existing `size` migration-window notes and judgement items.
- shellcheck, `bash -n` on every script, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1` and `git diff --check`: pass.

### Outstanding concerns

None for G2, which was folded into [KI-TOOL-RIG-CORE-067](KI-TOOL-RIG-CORE-067-package-managers-as-catalogue-tools.md) under RIG-MANAGERS a) (Discussion). The fix is proven by fixture only; the first real proof is the next attended fresh-Mac apply.

### Post-change review

The G3 goal holds: the deferral matrix now covers the one manager Kris's configuration hosts on mise but Rig did not defer. The change adds two case patterns and stays inside RIG-ORCH-018's explicit-prerequisite rule, so regression risk is low; every other preflight refusal is unchanged. Ready for acceptance review against the narrowed G3 goal.

### Mini recap

Added uv-from-mise to apply's manager deferral, proved test-first, full gate green. G2 turned out to describe the configuration-failure path, so it went to Kris rather than into code. Learning route, not promoted: `bats --jobs` needs GNU parallel, absent on this Mac, so the developer guide's serial `bats tests/` stays the gate.

## Discussion

### Approval

Kris, 19 October 2026 (TRIAGE-ALL, relayed by the mac-studio-setup State of play): every high-confidence Now recommendation is adopted and delivered to Awaiting review, tools burn-down work first. The rig-triage run of 19 October 2026 recommended this record for Now with high confidence, as the tools burn-down's smallest corrective item, and planned it to Ready with G2 narrowed out as recorded under Current state.

### G2 disposition

Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations, among them RIG-MANAGERS a), confidence high: G2's useful outcome, built-in and custom-provider availability with one actionable manager-level finding, is folded into [KI-TOOL-RIG-CORE-067](KI-TOOL-RIG-CORE-067-package-managers-as-catalogue-tools.md), and this record's goal and boundary are narrowed to the delivered G3. The record stays at Awaiting review; acceptance remains Kris's. The review did not rerun the recorded verification.

### Origin

Planning should confirm G3 with a fixture test before changing code, and decide whether doctor's line keeps listing chezmoi when no tool binds the `chezmoi` provider. If KI-TOOL-RIG-CORE-067 is adopted first, its derived matrix may absorb G3 and leave only G2 here. Capture only; adoption, priority and plan belong to this repository.
