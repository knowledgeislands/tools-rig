---
id: RIG-CORE-015
area: CORE
title: Isolate resource preflight failures
theme: orchestration
horizon: next
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 25f1cc6f79fd06cb35a905a9449a5e0d3b517395
transferred_from: TRD-3a1ab790
created_at: 2026-09-21T12:06:12Z
updated_at: 2026-09-21T12:50:22Z
---

# RIG-CORE-015: Isolate resource preflight failures

## Goal

Report an invalid or unavailable managed resource without unnecessarily preventing independent valid resources from reconciling.

## Context

Trade `TRD-3a1ab790` shows one missing Dock folder causing `rig apply --dry-run` to exit before it can plan two drifted services, two drifted scheduled jobs, and one missing scheduled job. Full-plan preflight protects against partial mutation, but treating every resource-local validation failure as a global syntax failure can make unrelated recovery work unreachable.

## Boundary

Do not weaken configuration parsing, provider trust checks, dependency ordering, or the guarantee that unsafe shared prerequisites fail before mutation. Do not silently skip failed resources or report overall success when selected state remains unreconciled.

## Current state

`rig apply` preflights every resource through one fail-fast boundary. A missing local Dock item is therefore treated like a shared provider or receipt failure and prevents independent settings, services, and scheduled jobs from running. Runtime failures already produce resource rows and allow independent work to continue, but equivalent local preflight findings cannot enter that outcome model.

## Steps

- [x] Classify built-in resource checks as shared-fatal or resource-local without changing configuration and trust validation.
- [x] Record local preflight failures against their resource plan rows, continue preflighting the complete plan, and skip only failed resources during execution.
- [x] Preserve fail-before-mutation behaviour for provider capability, executable, receipt, and other shared safety failures.
- [x] Keep dry-run non-mutating and deterministic, return 1 for local failed rows, and prevent retirement or receipt replacement after any selected resource failure.
- [x] Add Bats coverage proving an invalid Dock item does not block independent resources while global preflight failures still block every mutation.
- [x] Align the living execution decision, specifications, operational-resources guide, manual, and changelog.

## Files touched

- `bin/rig`
- `tests/rig-macos.bats`
- `tests/rig.bats`
- `docs/decisions/ADR-RIG-005-provider-execution-contract.md`
- `docs/specs/orchestration.md`
- `docs/specs/state.md`
- `docs/guides/user/operational-resources.md`
- `man/rig.1`
- `CHANGELOG.md`
- this roadmap record

## Verify

- `bats tests/rig-macos.bats`
- `bats tests/rig.bats`
- `shellcheck bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`

## Dependencies / blocks

None. RIG-CORE-014 removes the reported `$HOME` false positive, while this record independently governs genuinely unavailable local resources.

## Documentation impact

### Decision Records

Amend ADR-RIG-005 to distinguish shared fail-before-mutation checks from resource-local preflight outcomes.

### Specifications

Amend state and orchestration requirements with the classification, report, exit-status, retirement, and receipt rules.

### Guides

Explain to operators which preflight failures stop the plan and which fail one resource while independent work continues.

### Roadmap

Keep this record as the delivery and review authority; no follow-on item is expected unless verification exposes a separate concern.

## Review

### Delivered

From immutable baseline `25f1cc6f79fd06cb35a905a9449a5e0d3b517395`, delivered the approved resource-local preflight isolation while preserving shared fail-before-mutation safety boundaries.

### Summary of changes

- Classified missing Dock item paths as resource-local preflight findings while retaining shared provider, executable, platform, and receipt checks.
- Added deterministic failed-row handling for dry-run and apply without invoking the failed resource.
- Kept independent resources available, returned overall status 1, withheld stale retirement, and prevented receipt replacement after failure.
- Updated the living decision, Specifications, user guides, README, manual, and changelog.

### Verification

- `ki repo audit --repo .` — passed.
- `shellcheck bin/rig install.sh` — passed.
- `bats tests/` — passed, including local Dock-path isolation and existing shared-preflight fail-before-mutation cases.
- `mandoc -T lint man/rig.1` — passed.

### Outstanding concerns

None within the approved boundary.

### Post-change review

A fresh safety review confirms the complete plan is still preflighted before mutation, locally failed resources are never invoked, shared failures retain status 2, and receipt atomicity remains intact. The item is ready for human acceptance.

### Mini recap

One unavailable resource can no longer make unrelated recovery work unreachable, while shared safety failures still close the whole plan.

## Discussion

### Failure classification

The work must distinguish model-wide invalidity and shared precondition failures from a resource-local unavailable path or native preflight finding. Only genuinely independent work may continue, with deterministic failed, skipped, and completed outcomes.

### Safety model

Rig should retain complete preflight before mutation where a later failure could make earlier changes unsafe. Any isolation design therefore needs an explicit dependency and rollback boundary rather than a blanket continue-on-error rule.

### Trade disposition

This record is unadopted intake captured from `TRD-3a1ab790`. It preserves the trade's secondary reliability concern separately from home-path expansion; adoption and the receiver-local trade linkage require explicit review.
