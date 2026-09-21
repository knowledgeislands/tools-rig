---
id: RIG-CORE-014
area: CORE
title: Expand declared home paths
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

# RIG-CORE-014: Expand declared home paths

## Goal

Let portable personal declarations use documented home-relative values without producing false drift or making valid local paths impossible to apply.

## Context

Trade `TRD-3a1ab790` reports that macOS settings and Dock resources preserve `$HOME` literally during comparison and preflight. A screen-capture location declared as `$HOME/Downloads` is compared with `/Users/krisbrown/Downloads`, a Finder URL declared as `file://$HOME/` is compared with `file:///Users/krisbrown/`, and a Dock folder declared as `$HOME/Downloads` fails existence checks even though the directory exists. The result is phantom drift and an apply plan that stops before unrelated resources can reconcile.

## Boundary

Keep configuration inert and Bash 3.2-compatible. Do not add general shell interpolation, expand arbitrary environment variables, mutate the stored declaration, or require a personal absolute home path. Preserve native values and URL syntax outside the explicitly supported home forms.

## Discussion

### Expansion contract

Rig already recognises leading `~/` and `$HOME/` for selected comparison identities. The work must decide which typed setting, Dock, service, and job fields are genuinely path-valued, and whether a bounded `file://$HOME/` form belongs to the same contract without becoming substring-based variable expansion.

### State consistency

Observation, drift reporting, dry-run preflight, and application must use one normalised semantic value. A declaration must not compare one way and validate or apply another way.

### Trade disposition

This record is unadopted intake captured from `TRD-3a1ab790`. Receiving the trade does not select or prioritise the work; adoption and the receiver-local trade linkage require explicit review.
