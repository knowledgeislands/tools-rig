---
id: RIG-CORE-001
area: CORE
title: Define configuration contract
theme: orchestration
horizon: now
status: done
blocks: [RIG-CORE-003]
blocked_by: []
baseline_ref: 4789f4ad53a123c79916499b37a7afa7717b4235
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T13:18:23Z
---

# RIG-CORE-001: Define configuration contract

## Goal

Rig has an accepted catalogue-first product model and a documented, versioned configuration contract that separates inert declarations from trusted provider execution.

## Context

The bootstrap repository frames Rig as a manager of package and configuration targets. The approved direction instead makes the catalogue the primary description of a person's working setup, profiles selected views of that catalogue, providers the materialisation mechanism, and state the comparison between declared intent and a machine.

The live dotfiles implementation already contains a useful private catalogue and operational behaviour, but it mixes personal declarations, chezmoi paths, macOS audits, and provider commands. The public contract must establish a migration boundary before portable code is extracted.

## Boundary

This item decides and documents the product, configuration, trust, publication, specification, and migration contracts. It does not implement a parser, query command, provider adapter, state engine, publisher, or deployment; change the live chezmoi repository; or publish a release.

## Current state

`PDR-RIG-001` makes manager-of-managers the product concept. The Specifications cover target orchestration and portability but not catalogue metadata, typed relationships, public queries, expected-versus-observed state, or safe publication. Existing roadmap items do not yet separate the catalogue resolver, public export, site publication, or private declaration migration.

## Steps

- [x] Revise the product decision and repository orientation around the catalogue-first model.
- [x] Record the declarative configuration grammar, executable-provider trust boundary, and static publication projection as living Decision Records.
- [x] Extend the Specifications for catalogue, profiles, providers, queries, state, and publication while retaining existing requirement identities.
- [x] Update existing roadmap records and capture missing follow-on work with consistent dependencies and issue-ledger allocations.
- [x] Run the complete repository verification gate and review the resulting documentation as one coherent contract.

## Files touched

`AGENTS.md`, `README.md`, `docs/decisions/`, `docs/specs/`, `docs/roadmap/`, and `docs/roadmap/_ISSUES.md`.

## Verify

Run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, and `mandoc -T lint man/rig.1`; inspect the scoped Git diff for product, trust, requirement, and dependency consistency.

## Dependencies / blocks

No implementation dependency blocks this documentation contract. It establishes the decisions required by `RIG-CORE-003`; parser, query, provider, migration, and publication work remain in their own records.

## Documentation impact

### Decision Records

Retitle and revise `PDR-RIG-001` in place, then add decisions for configuration grammar, provider execution trust, and static publication.

### Specifications

Add accepted pending requirements for the catalogue, public queries, machine state, publication, profile composition, and provider behaviour.

### Guides

No procedural guide is added because no executable user workflow exists yet.

### Roadmap

Update the existing configuration, orchestration, provider, migration, and release records; capture the catalogue resolver, query, export, publication, and private-declaration work.

## Review

### Delivered

Against immutable baseline `4789f4ad53a123c79916499b37a7afa7717b4235`, the delivery establishes the approved catalogue-first product, configuration, trust, state, query, migration, and personal-site publication contracts. It does not change `bin/rig`, the live chezmoi repository, GitHub settings, hosting, or release state.

### Summary of changes

`AGENTS.md` and `README.md` now orient contributors and readers around the catalogue. `PDR-RIG-001` is revised in place and retitled; `ADR-RIG-003`, `XDR-RIG-001`, and `ADR-RIG-004` record the inert grammar, executable boundary, and static publication projection. The Specifications add configuration, catalogue, query, state, and publication areas and revise orchestration terminology without reusing an existing requirement ID. The planning commit updated existing roadmap boundaries and captured five separate follow-on records.

The material choices are an INI-shaped schema parsed without evaluation, explicit public-profile disclosure, offline static export separated from trusted deployment, and preservation of native provider authority and private dotfiles data.

### Verification

`ki repo audit --skill ki-authoring --repo .`, `ki repo audit --skill ki-decision-records --repo .`, `ki repo audit --skill ki-specs --repo .`, and `ki repo audit --skill ki-work-roadmap --repo .` pass. `shellcheck bin/rig install.sh`, all seven `bats tests/` cases, and `mandoc -T lint man/rig.1` pass. `git diff --check` passes and no reference to the retired PDR filename remains.

The complete `ki repo audit --repo .` was run. Fourteen of fifteen declared skill audits pass; `ki-repo` reports ten live GitHub-setting findings that pre-date this item and are outside its approved boundary.

### Outstanding concerns

The repository's live GitHub metadata and settings remain divergent: the remote license and description are unset, and merge, auto-delete, dependency-graph, and secret-scanning settings do not match the declared repository contract. The user explicitly withheld authority to change live GitHub settings, so this delivery leaves all ten findings untouched. No item-scoped documentation or local verification concern remains.

### Post-change review

The delivered records answer what Rig is, how its initial schema remains inert and Bash-compatible, where executable trust begins, what is public, how expected state differs from provider evidence, and how the live implementation migrates without exposing personal data. Follow-on implementation remains bounded in separate dependency-linked records. The documentation-only scope held, existing runtime behaviour remains unchanged, and the item is ready for acceptance review with the external GitHub findings visible.

### Mini recap

Rig now has one catalogue-led product narrative, three supporting architecture and security decisions, five new specification areas, revised provider orchestration requirements, and canonical follow-on work for resolver, query, export, publication, and private migration. All scoped gates pass; only pre-existing out-of-scope GitHub configuration findings remain.

## Done

Accepted 2026-09-15 by Kris Brown on review packet above.

## Discussion

### Declarative grammar

The initial contract uses versioned, INI-shaped inert data under Rig's existing XDG configuration directory. It supports a root file and lexically ordered fragments, recognised section types, repeatable list keys, and literal values without shell evaluation or general interpolation.

### Catalogue semantics

Categories and tools carry stable identifiers. Tools record a display name, category, purpose, personal rationale, supported platforms, typed relationships, and provider bindings. Profiles select tools and may compose other profiles; dependency expansion and platform selection must remain deterministic and fail closed on ambiguity or cycles.

### Trust boundary

Built-in adapters are trusted Rig code. A custom executable provider is an explicit trust transition and receives literal arguments without `eval` or shell command strings. Declarative queries execute no provider. State observation may execute a declared read-only capability, and mutation occurs only through an explicit apply surface.

### Publication boundary

A personal site such as `rig.midnight.ninja` is a derived read-only projection of an explicitly selected public profile. Static export and deployment remain separate. Provider commands, native manifest paths, host identity, private profiles, and observed machine state never enter the publication projection.

### Migration boundary

Portable resolution, orchestration, provider, state, and reporting behaviour belongs in tools-rig. Personal catalogue contents and provider choices remain private configuration. Bun/macOS auditing and launchd operations remain host-local extensions until stable portable contracts exist. The live Rig remains in place until equivalent standalone tests protect its safety behaviour.
