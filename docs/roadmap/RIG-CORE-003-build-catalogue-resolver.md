---
id: RIG-CORE-003
area: CORE
title: Build catalogue resolver
theme: orchestration
horizon: now
status: ready
blocks: [RIG-CORE-002, RIG-CLI-002, RIG-CLI-003]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-15T13:20:41Z
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

- [ ] Add a sourceable, internal catalogue data model and inert loader to `bin/rig` without changing the public command list.
- [ ] Validate schema version, section identities, allowed fields, scalar and repeatable cardinality, required fields, references, and provider-specific declarations before resolution succeeds.
- [ ] Resolve composed profiles, transitive tool requirements, platform support, and exactly one compatible materialisation binding deterministically with cycle detection.
- [ ] Add isolated Bats coverage for literal parsing, fragment order, validation failures, profile and tool graphs, platform binding selection, and stable output.
- [ ] Update the implemented configuration, catalogue, and orchestration requirements with test evidence.

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

## Discussion

### Parser boundary

The parser accepts only the documented versioned grammar, recognised sections and keys, repeated list fields, and literal values. It rejects ambiguity, unknown references, cycles, and executable syntax without sourcing configuration.

### Resolution boundary

Profile composition and required-tool expansion produce a deterministic selected tool set. Binding selection respects platforms and fails when more than one compatible provider remains.

### Test seam

`bin/rig` may expose its internal functions when sourced and dispatch `main` only when executed. This gives Bats direct resolver coverage while keeping the installed artefact standalone and adding no undocumented command or runtime dependency.
