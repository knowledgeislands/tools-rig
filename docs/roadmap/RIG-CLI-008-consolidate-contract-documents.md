---
id: RIG-CLI-008
title: Consolidate contract documents
area: CLI
theme: cli
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:35:16Z
---

## Goal

Rig's Decision Records, Specifications, manual, changelog, and cross-surface contract should each explain their own concern once, agree with shipped behaviour, and describe the current and future product without obsolete implementation history.

## Context

The user-guide information architecture has its own `RIG-CLI-007` record. The broader assessment also found a stale lifecycle statement in the security decision, detailed command and ABI behaviour duplicated across architecture decisions and Specifications, exact schema material placed under the manual's `FILES` section, contradictory bootstrap wording, and current normative evidence that still describes superseded binding behaviour.

## Boundary

This work does not absorb the reader journey owned by `RIG-CLI-007`, alter behaviour merely to simplify prose, or erase genuine release history from the changelog. It does not create another documentation system.

## Discussion

### Decision authority

Retain the existing nine records but tighten ownership: the product record owns the model, the security record owns trust transitions, the configuration record owns inert representation, the execution record owns orchestration rationale, and detailed fields, command mechanics, state tokens, and verification remain in Specifications.

### Reference structure

Move the manual's schema reference under `CONFIGURATION`, keep `FILES` about filesystem locations, correct bootstrap language, add the declaration-kind lifecycle table and provider-operation scope, and remove historical wording from current normative material where it no longer helps interpret the present contract.

### Human review gate

Add a judgemental definition-of-done criterion that affected guidance reaches a recognisable outcome, introduces concepts when needed, uses copyable examples, and remains readable against realistic configuration. Keep the existing mechanical alignment tests as a complementary gate.
