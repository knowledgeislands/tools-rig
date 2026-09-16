---
id: RIG-CLI-002
area: CLI
title: Add catalogue queries
theme: cli
horizon: now
status: ready
blocks: [RIG-DIST-001, RIG-MIG-004]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-16T11:06:43Z
---

# RIG-CLI-002: Add catalogue queries

## Goal

Rig answers what the declared working setup contains, which tools serve a category or profile, and why a tool belongs through stable read-only commands.

## Context

The inert schema 1 loader and catalogue resolver now provide one tested interpretation of configuration, but they are sourceable internals. The shipped public surface still exposes only paths, completion, help, and version information. Queries are the first user-facing expression of the catalogue-led product.

## Boundary

This item adds `rig show [--profile NAME]`, `rig list [--category ID] [--profile NAME]`, and `rig explain TOOL`. It does not invoke providers, observe or mutate machine state, publish a rig, migrate personal data, or add output formats not specified for v1.

## Current state

The public command dispatcher does not expose catalogue data. The internal resolver is sourceable and covered by Bats, so query delivery can consume it without defining a second parser or model.

## Steps

- [ ] Add strict command-specific argument parsing and namespaced status-2 diagnostics.
- [ ] Render deterministic summaries from the existing resolver for default and named profiles.
- [ ] Render stable catalogue lists with optional category and resolved-profile intersections.
- [ ] Explain declared and derived tool metadata, including rationale, relationships, profile membership, platform support, and compatible binding when one exists.
- [ ] Prove every query remains inside the inert configuration boundary and never invokes a provider.
- [ ] Align help, Bash and Zsh completion, README command inventory, `rig(1)`, and the curated `1.0.0 — in progress` changelog.
- [ ] Mark implemented query requirements conforming only with exact Bats evidence.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/specs/queries.md`, and this work record.

## Verify

Run focused Bats query cases during implementation, then the full repository gate from `AGENTS.md`: `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, and `mandoc -T lint man/rig.1`. Also run `/bin/bash -n bin/rig` and `git diff --check`.

## Dependencies / blocks

The catalogue resolver and configuration contract are complete. Delivery unblocks private declaration migration and satisfies one first-release prerequisite without selecting either item.

## Delegation

One bounded implementation worker may edit `bin/rig` and `tests/rig.bats` against the recorded baseline. The coordinator owns README, manual, changelog, Specification evidence, roadmap lifecycle, integration review, verification, and commits. Both lanes preserve Bash 3.2, the XDG contract, the no-runtime-dependency boundary, and provider non-execution.

## Documentation impact

### Decision Records

No Decision Record change is expected; this implements the accepted catalogue and trust-boundary decisions.

### Specifications

Update only RIG-QUERY requirements demonstrated by the delivered commands and tests.

### Guides

No separate guide is required; command help, README, and the manual carry the concise usage contract.

### Roadmap

Record review evidence here and clear only dependencies demonstrably discharged by delivery.

## Discussion

### Output contract

Human-readable output remains concise and deterministic. It distinguishes explicit profile membership, inherited profile membership, required-tool expansion, and selected provider binding where relevant.

### Execution safety

Queries read and resolve inert declarations only. They never invoke a built-in or custom provider.
