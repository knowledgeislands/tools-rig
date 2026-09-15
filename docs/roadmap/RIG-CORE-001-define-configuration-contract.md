---
id: RIG-CORE-001
area: CORE
title: Define configuration contract
theme: orchestration
horizon: now
status: ready
blocks: [RIG-CORE-003]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T11:53:55Z
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

- [ ] Revise the product decision and repository orientation around the catalogue-first model.
- [ ] Record the declarative configuration grammar, executable-provider trust boundary, and static publication projection as living Decision Records.
- [ ] Extend the Specifications for catalogue, profiles, providers, queries, state, and publication while retaining existing requirement identities.
- [ ] Update existing roadmap records and capture missing follow-on work with consistent dependencies and issue-ledger allocations.
- [ ] Run the complete repository verification gate and review the resulting documentation as one coherent contract.

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
