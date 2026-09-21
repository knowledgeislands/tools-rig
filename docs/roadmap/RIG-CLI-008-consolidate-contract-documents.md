---
id: RIG-CLI-008
title: Consolidate contract documents
area: CLI
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:43:26Z
---

## Goal

Rig's Decision Records, Specifications, manual, changelog, and cross-surface contract should each explain their own concern once, agree with shipped behaviour, and describe the current and future product without obsolete implementation history.

## Context

The user-guide information architecture has its own `RIG-CLI-007` record. The broader assessment also found a stale lifecycle statement in the security decision, detailed command and ABI behaviour duplicated across architecture decisions and Specifications, exact schema material placed under the manual's `FILES` section, contradictory bootstrap wording, and current normative evidence that still describes superseded binding behaviour.

## Boundary

This work does not absorb the reader journey owned by `RIG-CLI-007`, alter behaviour merely to simplify prose, or erase genuine release history from the changelog. It does not create another documentation system.

## Current state

Nine Decision Records, six Specifications, the manual, changelog, README, and guides describe a conforming product, but several repeat command-level details or retain obsolete wording. `XDR-RIG-001` understates mutating lifecycle operations, `ADR-RIG-005` duplicates Specifications, the manual places schema reference material under `FILES`, and bootstrap descriptions disagree about supported prerequisite installation.

## Steps

- [ ] Tighten each Decision Record to its durable decision and route detailed accepted behaviour to the owning Specification.
- [ ] Update the security and operational-resource decisions for current lifecycle mutations, resolved-profile ownership, and deselection semantics.
- [ ] Remove superseded binding and historical implementation wording from current normative Specifications while retaining genuine changelog history.
- [ ] Move schema reference material into a structured manual `CONFIGURATION` section and keep `FILES` limited to filesystem locations.
- [ ] Align bootstrap wording, declaration lifecycle, provider operation scope, help, completion, README, manual, guides, and changelog.
- [ ] Add the human-readability criterion to the definition of done and release checklist beside the mechanical cross-surface alignment check.

## Files touched

Expected scope includes `docs/decisions/`, `docs/specs/`, `docs/guides/developer/definition-of-done.md`, `docs/guides/developer/releasing.md`, `man/rig.1`, `README.md`, and `CHANGELOG.md`.

## Verify

Run the complete repository gate, check every retained Decision Record has one clear authority, compare all public command and configuration surfaces, and verify the manual renders with schema material under `CONFIGURATION` and filesystem material under `FILES`.

## Dependencies / blocks

Use the accepted semantics delivered by `RIG-CORE-018`, `RIG-CORE-019`, and `RIG-CLI-009` when those records alter contract wording. Document consolidation can begin independently, but its final alignment pass follows the core and progress batches.

## Delegation

Decision Record and Specification consolidation, manual restructuring, and developer-checklist alignment are separable review lanes. The coordinator owns terminology reconciliation and the final complete gate.

## Documentation impact

### Decision Records

This item directly consolidates all Decision Records without changing their historical identifiers or creating a parallel decision series.

### Specifications

Specifications become the sole home for detailed accepted fields, command mechanics, state vocabulary, and verification evidence.

### Guides

Developer completion and release guides gain one shared human-and-mechanical cross-surface alignment criterion; user-guide restructuring remains in `RIG-CLI-007`.

### Roadmap

No follow-on documentation-consolidation item is expected; behavioural gaps discovered during review must be captured separately rather than hidden in prose edits.

## Discussion

### Decision authority

Retain the existing nine records but tighten ownership: the product record owns the model, the security record owns trust transitions, the configuration record owns inert representation, the execution record owns orchestration rationale, and detailed fields, command mechanics, state tokens, and verification remain in Specifications.

### Reference structure

Move the manual's schema reference under `CONFIGURATION`, keep `FILES` about filesystem locations, correct bootstrap language, add the declaration-kind lifecycle table and provider-operation scope, and remove historical wording from current normative material where it no longer helps interpret the present contract.

### Human review gate

Add a judgemental definition-of-done criterion that affected guidance reaches a recognisable outcome, introduces concepts when needed, uses copyable examples, and remains readable against realistic configuration. Keep the existing mechanical alignment tests as a complementary gate.
