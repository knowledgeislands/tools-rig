---
id: RIG-CORE-035
area: CORE
title: Surface permanent apply failures
theme: orchestration
horizon: next
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T00:00:00Z
updated_at: 2026-09-30T22:28:16Z
---

## Goal

Make a failed application visible to read-only health checks even when the native manager still reports the tool installed. Keep historical failure evidence distinct from what is observed on the machine now.

## Context

Repeated failed applications previously disappeared into terminal scrollback while status showed tools present and doctor had no findings. Installation receipts do not prove that the last attempted change succeeded. The command cutover preserves this gap: apply has resource reconciliation receipts but no durable per-target outcome history.

The user approved the reliability work and the recommendation to show the last failed attempt immediately, without labelling one failure permanent. This item records failure evidence; [unattended-contract hardening](RIG-CORE-024-widen-needs-person-detection.md) preserves known preflight exclusions. Neither substitutes for the other.

## Boundary

Do not probe mutating provider paths from status or doctor, add a provider capability, introduce an event database, infer a credential problem from an error, or repair personal declarations. Preserve the live observation and existing outcome vocabulary. Display styling follows in the separate live-display item.

## Current state

Apply prints per-target outcomes and an aggregate result, but those rows are not retained. Last-upgrade is a separate unattended lifecycle report, not apply evidence. Targeted apply already requires preservation of unrelated resource receipts; a new failure ledger must likewise avoid losing evidence about targets absent from a narrow run.

## Steps

- [ ] Specify one bounded versioned failure ledger per platform under Rig state, keyed by qualified target and provider, carrying the last actual failed attempt's UTC time and native exit status without native output, arguments or credentials.
- [ ] Record actual dispatch failures and clear a target only after its later successful dispatch. Leave unrelated, skipped, unselected, preflight-rejected and dry-run targets untouched.
- [ ] Add safe atomic merge/replacement with a short state-write lock so concurrent tool-only applies cannot overwrite unrelated outcomes; define same-target attempt ordering so an older failed attempt cannot replace a later successful result. Refuse unsafe paths and preserve previous valid evidence on failure.
- [ ] Show selected unresolved failures as explicitly historical findings in doctor and a separate status section, including problems-only and JSON projections. Preserve current native state and expose recorded time/age; historical health findings contribute to the documented finding exit status.
- [ ] Treat missing history as neutral and corrupt or unreadable history as unavailable evidence. Make persistence failures visible separately without rewriting the provider's actual result.
- [ ] Cover failure, repeated failure, later success, targeted preservation, provider/platform separation, changed declarations, interrupted runs, unsafe state, concurrent writers and read-only follow-up.
- [ ] Align state specifications and guides, run the full gate and prepare the review packet.

## Files touched

The apply and observation modules, a focused authored history helper if factoring warrants it, deterministic assembly, generated executable, isolated state tests, state specification and inspection guides. Do not implement this as duplicated persistence logic in status and doctor.

## Verify

Use recording provider stubs and isolated state homes. Prove live observation remains present while historical failure is visible; a later successful attempt clears only the matching target. Dry runs and read-only checks must not change ledger bytes or invoke mutation. Exercise malformed files, symlinks, failed writes and parallel disjoint-target merges. Run the complete AGENTS.md gate with Bats stdin redirected from /dev/null.

## Dependencies / blocks

No build-order dependency. Sequence this before [live display](RIG-CLI-023-design-live-operational-display.md) so presentation consumes settled evidence. The Dock observation fix is independently executable and may share an aggregate verification pass after each item has its own tests and review packet.

## Delegation

One implementation lane owns the shared history contract and apply/observation integration to avoid competing writes to the same state model. A separate reviewer checks data safety, targeted preservation and read-only guarantees. The coordinator owns roadmap state, integration and final verification; no worker live-machine mutations or Git writes.

## Documentation impact

### Decision Records

Explain the distinction between remembered execution evidence and provider-owned current state if a durable authority clarification is needed.

### Specifications

Specify ledger keys, merge/clear rules, privacy, age, interrupted-run behavior and finding exit semantics before implementation. The first unresolved failure is visible; there is no new permanent-failure state.

### Guides

Explain how to inspect a past failed attempt, why an installed tool can also have a historical finding, and why unrelated targeted applications do not clear it.

### Roadmap

No provider materialisability capability or repair framework is included. Retain those as separate concerns only if later evidence justifies them.

## Discussion

### Last attempted result, not permanence

Use the latest actual failure and its timestamp, not a consecutive-failure threshold or an event log. Repeated failure updates that evidence; a matching success clears it. The stable title is historical, not a claim that Rig can prove permanence. This keeps the chosen reliability benefit small and understandable.

### Scope and stale evidence

Select historical findings using the current target/provider/platform identity and label them as past execution evidence. A configuration change is not proof of recovery, but neither should an old provider's failure be attributed to its replacement. Deleted or no-longer-selected targets must not contaminate an unrelated status result. Decide retention and changed-binding presentation explicitly in the specification.

### Interrupted writes and concurrency

Persist completed attempts safely without turning a failed ledger write into a fictional provider failure. Leave previous valid evidence intact when publication cannot complete. Interrupted operations must not be presented as successful; document whether only completed attempt evidence survives. A whole-run report that overwrites unrelated targeted results is not an acceptable shortcut.
