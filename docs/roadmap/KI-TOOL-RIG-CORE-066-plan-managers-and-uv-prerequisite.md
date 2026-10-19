---
id: KI-TOOL-RIG-CORE-066
area: CORE
title: Plan managers, uv prerequisite
purpose: corrective
theme: rig
status: triage
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-19T20:49:28Z
updated_at: 2026-10-19T20:49:28Z
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

## Dependencies / blocks

Not blocked. KI-TOOL-RIG-CORE-067 would later replace the hard-coded deferral matrix this record extends; this record does not wait for it.

## Discussion

Planning should confirm G3 with a fixture test before changing code, and decide whether doctor's line keeps listing chezmoi when no tool binds the `chezmoi` provider. If KI-TOOL-RIG-CORE-067 is adopted first, its derived matrix may absorb G3 and leave only G2 here. Capture only; adoption, priority and plan belong to this repository.
