---
id: RIG-CORE-018
title: Define reconciliation authority
area: CORE
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: f84233051bc7301fa84b78e03c4055ba6e33c1bf
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-22T00:31:39Z
---

## Goal

Rig should give profiles, providers, and each declaration kind one predictable authority model so selecting, applying, switching, and deselecting a profile cannot cause surprising retention, retirement, disclosure, or provider-wide mutation.

## Context

Resource receipts are platform-wide, so applying another profile can retire services and scheduled jobs absent from the new selection. Tools and artifacts remain installed, settings and Dock state remain last-applied, and Homebrew lifecycle operations can affect a complete native manifest rather than only selected tools. Resolved profiles can also select settings or Dock layouts that target contradictory native state, while service locator conflicts are rejected even across mutually exclusive profiles.

The current profile model stores complete member arrays centrally. The real default profile therefore contains very long tool and resource lists. A proposed inversion would place profile membership on each item and make unqualified declarations implicit members. Literal membership in every profile would, however, make a new private item appear automatically in minimal, public, or view-only profiles.

## Boundary

This work does not add arbitrary lifecycle hooks or make Rig authoritative for provider-native state. It must preserve the distinction between declarative intent, native ownership, minimal reconciliation receipts, and public projection.

## Current state

Profile arrays centrally enumerate declarations, receipts are platform-wide, declaration kinds have different deselection behaviour, conflicts are sometimes checked across the whole catalogue, and concurrent applies can replace the same receipt without serialization. The implementation does not yet distinguish appliable complete profiles from non-appliable views or consistently disclose provider mutation scope.

## Steps

- [x] Amend the product, configuration, orchestration, state, and publication contracts with the locked authority model below.
- [x] Add item-centric `profiles` membership with omission meaning `default`, explicit profile inheritance, and rejection of ambiguous mixed central and item-centric selection.
- [x] Add profile identity, purpose, and appliable-versus-view semantics; reject `apply` and `bootstrap` for non-appliable profiles.
- [x] Resolve dependencies transitively, then validate native-target conflicts only across the resolved selection while retaining globally unique declaration identities.
- [x] Make lifecycle plans disclose declaration, manifest, or provider-wide mutation scope before execution.
- [x] Serialize receipt-backed reconciliation per target and fail safely when another apply owns the target lock.
- [x] Cover selection, inheritance, publication safety, deselection, conflicts, provider scope, and concurrent apply with deterministic tests.

## Files touched

Expected scope includes `bin/rig`, `tests/rig.bats`, `docs/decisions/`, `docs/specs/`, `docs/guides/user/`, `man/rig.1`, `README.md`, and `CHANGELOG.md`.

## Verify

Run the complete repository gate and focused fixtures proving implicit default membership, explicit inheritance, non-appliable view rejection, resolved-only conflict checks, the declaration-kind deselection table, provider-scope disclosure, and exclusive receipt reconciliation.

## Dependencies / blocks

Nothing blocks the portable authority model. `RIG-CORE-019` consumes its item-centric membership and profile metadata; `RIG-MIG-007` migrates personal configuration only after this behaviour lands.

## Delegation

Contract changes, profile-resolution implementation, and concurrent-reconciliation tests are bounded lanes. The coordinator owns the locked semantic model, integration, and final gate.

## Documentation impact

### Decision Records

Update the catalogue-led product, inert configuration, execution, publication, and operational-resource decisions with authority rather than command-level detail.

### Specifications

Specify profile kinds, item membership, inheritance, deselection by declaration kind, conflict scope, provider operation scope, and reconciliation locking.

### Guides

Explain complete appliable profiles, safe views, switching effects, and how to read provider-wide work before applying it.

### Roadmap

This settles the semantic foundation for configuration, documentation, publication, and personal migration records; no separate authority item is expected.

## Review

### Delivered

The locked authority model is implemented across Rig's parser, selection engine, lifecycle commands, publication boundary, reconciliation state, and user-facing contracts.

### Summary of changes

- Selectable declarations can own profile membership, with omission resolving to the configured default profile and an explicit empty list selecting nowhere.
- Profiles have explicit inheritance and complete-versus-view semantics; mixed central and item-owned membership is rejected.
- Resolved selections close dependencies before checking native-target conflicts, while publication views require dependencies to opt in explicitly.
- Mutating lifecycle commands reject views, bootstrap requires a complete profile, and plans disclose declaration, manifest, or provider-wide scope.
- Receipt-backed reconciliation is serialized per target from receipt read through atomic replacement, with conservative stale-lock diagnostics and cleanup of locks acquired by the current process.
- Decisions, specifications, user guides, README, manual, changelog, and focused acceptance tests now describe and verify the same model.

### Verification

- `ki repo audit --repo .`
- `shellcheck bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- `git diff --check`

All checks passed on the delivery tree.

### Outstanding concerns

The legacy central profile-array form remains available as a compatibility mode, but cannot be mixed with item-owned membership. Existing personal configuration migration remains separately owned. Existing reconciliation locks are intentionally never removed automatically because Rig cannot prove that an unknown or stale-looking owner is safe to evict.

### Post-change review

The implementation satisfies the locked model without adding runtime dependencies or weakening Bash 3.2 compatibility. The principal operational risk is filesystem lock recovery after abnormal termination; explicit diagnosis is safer than automatic eviction, and the contract documents that boundary.

### Mini recap

Rig now has one unambiguous profile authority per configuration, safe non-mutating views, deterministic resolved-target validation, visible mutation scope, and serialized receipt-backed application.

## Discussion

### Locked authority model

Item-centric membership is authoritative. A declaration without `profiles` belongs to `default`; other complete machine or role profiles inherit `default` explicitly; minimal, public, and view profiles opt in explicitly. Profile declarations own identity, purpose, inheritance, and whether they are appliable. Central member arrays and item-centric membership cannot be mixed.

An appliable profile is complete desired Rig intent for one target. Previously receipted services and scheduled jobs omitted from the next appliable profile are retired. Packages, artifacts, settings, layouts, ports, and skills are non-destructive on deselection unless a separately explicit cleanup contract says otherwise. A non-appliable view never owns receipts or influences retirement.

Native-target conflicts are checked across the resolved selection, provider work discloses declaration, manifest, or provider-wide scope before execution, and receipt-backed reconciliation is serialized per target. A concurrent second apply fails before mutation with a clear active-owner diagnostic.

The exploratory observations below are retained as rationale; the locked model above resolves their open choices for implementation.

### Item-centric membership

The leading option is item-centric membership with a safe default: an item that omits membership belongs to the configured `default` profile, not literally every profile. Another machine or role profile may inherit `default` explicitly, while public, minimal, and view-only profiles remain explicit. An item can name additional or restricted profiles beside its own declaration, eliminating the giant central membership arrays without causing automatic disclosure.

Profile declarations would then own identity, purpose, composition, and whether they are appliable complete machine intent or non-appliable views. Dependencies still close transitively during resolution. The design needs a clear migration from existing profile arrays and must reject ambiguous mixed selection modes.

### Reconciliation semantics

The contract must state the effect of deselection for tools, artifacts, services, jobs, settings, layouts, ports, and skills. It must also decide whether retirement ownership is per platform, profile, or explicit machine target and protect publication-only views from application.

### Conflict and operation scope

Native target conflicts should be checked over the resolved profile so mutually exclusive alternatives remain declarable but contradictory selected intent fails before observation or mutation. Every lifecycle work item should disclose whether it affects one declaration, a native manifest, or a whole provider.

### Concurrent application

Atomic receipt replacement is not sufficient when two applies can reconcile different selections concurrently. The accepted authority model should define serialization or conflict behaviour before scheduled and interactive applications can safely coexist.
