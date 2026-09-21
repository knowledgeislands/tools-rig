---
id: RIG-CORE-018
title: Define reconciliation authority
area: CORE
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:35:16Z
---

## Goal

Rig should give profiles, providers, and each declaration kind one predictable authority model so selecting, applying, switching, and deselecting a profile cannot cause surprising retention, retirement, disclosure, or provider-wide mutation.

## Context

Resource receipts are platform-wide, so applying another profile can retire services and scheduled jobs absent from the new selection. Tools and artifacts remain installed, settings and Dock state remain last-applied, and Homebrew lifecycle operations can affect a complete native manifest rather than only selected tools. Resolved profiles can also select settings or Dock layouts that target contradictory native state, while service locator conflicts are rejected even across mutually exclusive profiles.

The current profile model stores complete member arrays centrally. The real default profile therefore contains very long tool and resource lists. A proposed inversion would place profile membership on each item and make unqualified declarations implicit members. Literal membership in every profile would, however, make a new private item appear automatically in minimal, public, or view-only profiles.

## Boundary

This work does not add arbitrary lifecycle hooks or make Rig authoritative for provider-native state. It must preserve the distinction between declarative intent, native ownership, minimal reconciliation receipts, and public projection.

## Discussion

### Item-centric membership

The leading option is item-centric membership with a safe default: an item that omits membership belongs to the configured `default` profile, not literally every profile. Another machine or role profile may inherit `default` explicitly, while public, minimal, and view-only profiles remain explicit. An item can name additional or restricted profiles beside its own declaration, eliminating the giant central membership arrays without causing automatic disclosure.

Profile declarations would then own identity, purpose, composition, and whether they are appliable complete machine intent or non-appliable views. Dependencies still close transitively during resolution. The design needs a clear migration from existing profile arrays and must reject ambiguous mixed selection modes.

### Reconciliation semantics

The contract must state the effect of deselection for tools, artifacts, services, jobs, settings, layouts, ports, and skills. It must also decide whether retirement ownership is per platform, profile, or explicit machine target and protect publication-only views from application.

### Conflict and operation scope

Native target conflicts should be checked over the resolved profile so mutually exclusive alternatives remain declarable but contradictory selected intent fails before observation or mutation. Every lifecycle work item should disclose whether it affects one declaration, a native manifest, or a whole provider.

### Concurrent application

Atomic receipt replacement is not sufficient when two applies can reconcile different selections concurrently. The accepted authority model should define serialization or conflict behaviour before scheduled and interactive applications can safely coexist.
