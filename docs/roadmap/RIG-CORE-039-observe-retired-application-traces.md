---
id: RIG-CORE-039
area: CORE
title: Observe retired app traces
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-01T04:22:44Z
updated_at: 2026-10-01T04:22:44Z
---

# RIG-CORE-039: Observe retired app traces

## Goal

Rig can report read-only evidence of data and usage traces left by a retired macOS application, so a person can review its retirement without inferring that retained data should be deleted.

## Context

The personal dotfiles roadmap identified a gap while reviewing Actual and Unsloth Studio retirements: Rig reconciles application bundles but does not report retained support files, caches, preferences, or partial last-used evidence. That request was submitted as work trade `TRD-62dc768f` from `krisb/dotfiles` on 2026-09-30. This receiver-owned intake record preserves the requested outcome and safety constraints without requiring an ongoing route to the personal repository.

The first investigation should establish whether Rig's current catalogue, provider observations, and state model can express a retired application identity and its non-package data locations without adding a personal-machine assumption to portable behaviour.

## Boundary

This is unadopted Triage, not approval to implement an adapter or change Rig's schema. Do not delete data, infer ownership from name substrings, treat weak last-used signals as proof of disuse, or take over dotfiles' personal application declarations and retirement decisions. Package-managed stores remain visibly distinct from candidate user-data remnants.

## Discussion

### Observation contract

The proposed macOS observation should match exact retired identities, report conventional remnant locations and partial last-used evidence, and mark uncertainty and package ownership. The initial deliverable is an owner-reviewed design for the portable Rig observation and command language, with a testable safety boundary before implementation is selected.

### Open questions

Determine which identities and locations Rig can observe reliably, how to represent evidence that is unavailable or ambiguous, and whether the existing provider contract can carry this without a new adapter or schema field. Personal follow-on guidance belongs to dotfiles only after Rig has an actual interface to evaluate.
