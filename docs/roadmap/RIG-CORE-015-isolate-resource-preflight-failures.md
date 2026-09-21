---
id: RIG-CORE-015
area: CORE
title: Isolate resource preflight failures
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
transferred_from: TRD-3a1ab790
created_at: 2026-09-21T12:06:12Z
updated_at: 2026-09-21T12:06:12Z
---

# RIG-CORE-015: Isolate resource preflight failures

## Goal

Report an invalid or unavailable managed resource without unnecessarily preventing independent valid resources from reconciling.

## Context

Trade `TRD-3a1ab790` shows one missing Dock folder causing `rig apply --dry-run` to exit before it can plan two drifted services, two drifted scheduled jobs, and one missing scheduled job. Full-plan preflight protects against partial mutation, but treating every resource-local validation failure as a global syntax failure can make unrelated recovery work unreachable.

## Boundary

Do not weaken configuration parsing, provider trust checks, dependency ordering, or the guarantee that unsafe shared prerequisites fail before mutation. Do not silently skip failed resources or report overall success when selected state remains unreconciled.

## Discussion

### Failure classification

The work must distinguish model-wide invalidity and shared precondition failures from a resource-local unavailable path or native preflight finding. Only genuinely independent work may continue, with deterministic failed, skipped, and completed outcomes.

### Safety model

Rig should retain complete preflight before mutation where a later failure could make earlier changes unsafe. Any isolation design therefore needs an explicit dependency and rollback boundary rather than a blanket continue-on-error rule.

### Trade disposition

This record is unadopted intake captured from `TRD-3a1ab790`. It preserves the trade's secondary reliability concern separately from home-path expansion; adoption and the receiver-local trade linkage require explicit review.
