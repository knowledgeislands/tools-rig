---
id: RIG-CORE-003
area: CORE
title: Build catalogue resolver
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: c8d905571d7d4ba7f28ebe654a6406fd41b00726
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-16T08:30:15Z
---

# RIG-CORE-003: Build catalogue resolver

## Goal

Rig can parse inert configuration and resolve categories, tools, relationships, profiles, platforms, and provider bindings deterministically in Bash 3.2.

## Context

Catalogue resolution is the shared read model for local queries, provider orchestration, and public export. It must exist before those consumers implement separate interpretations of the configuration contract.

## Boundary

This item builds parsing, validation, and resolution. It does not invoke providers, observe machine state, mutate the machine, render a public site, or migrate personal declarations.

## Current state

The executable resolves XDG paths and provides help and completion, but it does not read `rig.conf`. The accepted schema and resolver semantics exist only in Decision Records and Specifications, so every later consumer would otherwise need to invent its own interpretation.

## Steps

- [x] Add a sourceable, internal catalogue data model and inert loader to `bin/rig` without changing the public command list.
- [x] Validate schema version, section identities, allowed fields, scalar and repeatable cardinality, required fields, references, and the decided custom-executable trust boundary before resolution succeeds.
- [x] Resolve composed profiles, transitive tool requirements, platform support, and exactly one compatible materialisation binding deterministically with cycle detection.
- [x] Add isolated Bats coverage for literal parsing, fragment order, validation failures, profile and tool graphs, platform binding selection, and stable output.
- [x] Update the implemented configuration, catalogue, and orchestration requirements with test evidence.

## Files touched

`bin/rig`, `tests/rig.bats`, the implemented requirements in `docs/specs/configuration.md`, `docs/specs/catalogue.md`, and `docs/specs/orchestration.md`, and this canonical work record.

## Verify

Run `shellcheck bin/rig`, `bats tests/rig.bats`, the complete repository gate from `AGENTS.md`, and `git diff --check`. Assert the existing public help, version, path, completion, and installer tests remain unchanged in outcome.

## Dependencies / blocks

`RIG-CORE-001` established the accepted grammar and trust boundary and is complete, so no build dependency remains. This resolver unblocks orchestration, catalogue queries, and public export; those consumers remain separate roadmap items.

## Delegation

One bounded worker may change `bin/rig` and `tests/rig.bats` only. The coordinator owns Specification conformance updates, roadmap lifecycle, integration review, full verification, and commits. The worker must preserve Bash 3.2, the existing public command surface, XDG behavior, and the no-runtime-dependency boundary.

## Documentation impact

### Decision Records

No Decision Record change is needed; the accepted grammar and trust decisions are implementation inputs.

### Specifications

Update only requirements demonstrably implemented by the parser and resolver, recording exact Bats evidence without claiming later query or provider execution work.

### Guides

No guide change is needed because this item adds no public command or user procedure.

### Roadmap

Clear the discharged dependency on `RIG-CORE-001`; successful delivery unblocks `RIG-CORE-002`, `RIG-CLI-002`, and `RIG-CLI-003` without selecting them.

## Review

### Delivered

Against immutable baseline `c8d905571d7d4ba7f28ebe654a6406fd41b00726`, Rig now has a Bash 3.2-compatible inert schema 1 loader, validator, profile resolver, and optional binding selector inside the standalone executable. No provider is invoked, no machine state is observed or mutated, no public command was added, and publication and personal declaration migration remain out of scope.

### Summary of changes

`bin/rig` now loads the XDG root and bytewise-ordered fragments without sourcing them, stores declarations in indexed arrays, validates schema structure and references, detects profile and required-tool cycles, resolves platform-aware transitive selections deterministically, and chooses bindings only for materialisable tools. `tests/rig.bats` grew from 7 to 25 cases, including review-found regressions for catalogue-only tools, incompatible required tools, and stale resolver state. The configuration, catalogue, and orchestration Specifications now state the clarified platform, path, publication, and materialisability contracts and carry evidence only for implemented requirements.

### Verification

`shellcheck bin/rig install.sh`, `/bin/bash -n bin/rig install.sh` under Bash 3.2.57, all 25 `bats tests/` cases, `mandoc -T lint man/rig.1`, `ki repo audit --skill ki-specs --repo .`, `ki repo audit --skill ki-authoring --repo .`, `ki repo audit --skill ki-work-roadmap --repo .`, `ki repo audit --skill ki-repo-tools --repo .`, and `git diff --check` pass. The complete `ki repo audit --repo .` also ran: fourteen of fifteen declared skills pass, with only the pre-existing live GitHub settings findings below.

### Outstanding concerns

The resolver is intentionally internal until the catalogue-query item exposes supported presentation commands. Adapter-specific field matrices, direct-download integrity, provider execution, observed state, and mutation remain pending in their owning roadmap items and are not claimed as conforming here. The full repository audit still reports ten out-of-scope live GitHub settings differences: license and description metadata, merge and branch cleanup policy, Wiki and Projects toggles, two Dependabot settings, and two secret-scanning settings. Changing those remote settings remains explicitly unauthorised.

### Post-change review

Independent review found and the implementation now covers mixed catalogue-only/materialisable profiles, platform-incompatible required tools, and failed-resolution state reuse. The existing CLI, completion, installer, XDG, manual, Bash 3.2, and no-runtime-dependency behavior remains intact. The approved boundary held and the item is ready for acceptance review.

### Mini recap

Rig now has one tested catalogue interpretation for later queries, orchestration, and public export. The three consumers are dependency-ready but remain unselected, and executable provider behavior remains separate.

## Discussion

### Parser boundary

The parser accepts only the documented versioned grammar, recognised sections and keys, repeated list fields, and literal values. It rejects ambiguity, unknown references, cycles, and executable syntax without sourcing configuration.

### Resolution boundary

Profile composition and required-tool expansion produce a deterministic selected tool set. Binding selection respects platforms and fails when more than one compatible provider remains.

### Test seam

`bin/rig` may expose its internal functions when sourced and dispatch `main` only when executed. This gives Bats direct resolver coverage while keeping the installed artefact standalone and adding no undocumented command or runtime dependency.

### Adapter validation boundary

Schema 1 requires each provider to name an adapter and, as required by `XDR-RIG-001`, a custom adapter to name one executable. The resolver accepts the documented fields for other adapter names without inventing field combinations; built-in adapter-specific capability and manifest validation belongs to `RIG-CLI-001`.
