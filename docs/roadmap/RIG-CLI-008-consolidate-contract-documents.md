---
id: RIG-CLI-008
title: Consolidate contract documents
area: CLI
theme: cli
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 8e47d336aa2ccec747bc8dd661e51661c87d3441
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-22T04:14:58Z
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

- [x] Tighten each Decision Record to its durable decision and route detailed accepted behaviour to the owning Specification.
- [x] Update the security and operational-resource decisions for current lifecycle mutations, resolved-profile ownership, and deselection semantics.
- [x] Remove superseded binding and historical implementation wording from current normative Specifications while retaining genuine changelog history.
- [x] Move schema reference material into a structured manual `CONFIGURATION` section and keep `FILES` limited to filesystem locations.
- [x] Align bootstrap wording, declaration lifecycle, provider operation scope, help, completion, README, manual, guides, and changelog.
- [x] Add the human-readability criterion to the definition of done and release checklist beside the mechanical cross-surface alignment check.

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

## Review

### Delivered

Delivered the approved contract-document consolidation from immutable baseline `8e47d336aa2ccec747bc8dd661e51661c87d3441`. The change retains all nine decision identities, every Specification requirement identifier, and genuine `0.x` changelog history. It changes documentation only; runtime behaviour, completion generation, release state, and the `RIG-CLI-007` reader-journey structure remain outside this delivery.

### Summary of changes

The product, configuration, publication, orchestration, operational-resource, security, and XDG decisions now state durable present-tense rationale while routing exact fields and command mechanics to Specifications. Current Specifications no longer describe superseded binding representation or expose that historical implementation term. The manual now keeps schema material in structured `CONFIGURATION` subsections, limits `FILES` to filesystem locations, and documents declaration-kind deselection plus declaration, manifest, and provider-wide operation scope. Bootstrap wording agrees on the fixed Homebrew → mise → npm prerequisite chain. Developer completion and release checklists now require both mechanical cross-surface alignment and a judgemental reader-outcome review. `CHANGELOG.md` records the consolidation without rewriting public preview history.

### Verification

- `ki repo audit --repo .` — PASS across all 16 declared skills.
- `ki repo audit --skill ki-decision-records --repo .` — PASS.
- `ki repo audit --skill ki-specs --repo .` — PASS.
- `ki repo audit --skill ki-guides --repo .` — PASS.
- `ki repo audit --skill ki-authoring --repo .` — PASS.
- `ki repo audit --skill ki-work-roadmap --repo .` — PASS.
- `rumdl check CHANGELOG.md docs/decisions docs/guides docs/specs README.md docs/roadmap/RIG-CLI-008-consolidate-contract-documents.md` — PASS.
- `shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers` and Bash syntax checks — PASS.
- `scripts/assemble-rig --check`, `scripts/benchmark-rig`, and `scripts/smoke-native-providers` — PASS; benchmark results were 2s diag, 2s show, 2s list, and 5s status.
- `bats tests/` — PASS, 221 tests including help, completion, public command inventory, bootstrap, lifecycle, and publication alignment.
- `mandoc -T lint man/rig.1` and rendered-manual inspection — PASS.
- `git diff --check` — PASS.

### Outstanding concerns

None. The changelog deliberately retains historical `0.x` release content, and internal source or test symbols may still use implementation-local terminology that is not part of the current public contract.

### Post-change review

Fresh review found the four-document split coherent: Decisions explain why, Specifications own testable behaviour, Guides explain how, and this roadmap record owns delivery history. The manual renders schema reference and file locations under separate headings, the lifecycle table reflects receipt-backed retirement semantics, and no runtime or command surface changed. The item is ready for human acceptance review.

### Mini recap

This delivery consolidated contract authority, corrected bootstrap and lifecycle wording, added the human readability gate, and passed the full repository verification suite. No automatic learning promotion is proposed because the durable guidance already lives in the repository's decisions, specifications, manual, and developer checklists.

## Discussion

### Decision authority

Retain the existing nine records but tighten ownership: the product record owns the model, the security record owns trust transitions, the configuration record owns inert representation, the execution record owns orchestration rationale, and detailed fields, command mechanics, state tokens, and verification remain in Specifications.

### Reference structure

Move the manual's schema reference under `CONFIGURATION`, keep `FILES` about filesystem locations, correct bootstrap language, add the declaration-kind lifecycle table and provider-operation scope, and remove historical wording from current normative material where it no longer helps interpret the present contract.

### Human review gate

Add a judgemental definition-of-done criterion that affected guidance reaches a recognisable outcome, introduces concepts when needed, uses copyable examples, and remains readable against realistic configuration. Keep the existing mechanical alignment tests as a complementary gate.
