---
id: RIG-MIG-008
area: MIG
title: Align schema contracts
theme: migration
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-03T04:00:16Z
updated_at: 2026-10-03T06:43:53Z
---

## Goal

Make newly written Rig configuration unversioned, and give each generated output contract its own v1 identity without losing current capability.

## Context

`rig.toml` currently requires schema 1, operational JSON reports schema 1, and `rig export` publishes version 2. The agreed pre-1.0 treatment removes the field from newly authored input, recognises old known shapes for explicit repair, and renumbers generated contracts above v1 to v1 without removing fields or behaviour.

## Boundary

Do not introduce `latest`, `pre-release`, `0`, a shared estate version, or parallel old/new schemas solely because of a historical marker. Never rewrite config on ordinary reads, prompt in non-interactive runs, or accept unknown semantics based only on a numeric field. Preserve Bash 3.2 and zero runtime dependencies. Treat published export consumers and persistence separately from input parsing.

## Current state

Input parsing and examples require a schema field; export output names version 2. Existing capabilities and safe machine isolation must remain intact.

## Steps

- [ ] Inventory all Rig input, operational output and publication version uses and their consumers.
- [ ] Accept and write the current unversioned config shape; keep recognised `schema = 1` readable and provide an explicit, previewed repair that never rewrites active configuration on a read.
- [ ] Renumber the export contract to v1 without reducing payload capability, and make downstream consumers additive-field tolerant.
- [ ] Align help, completion, manual, guides, specifications and tests; run the full isolated Rig gate.

## Files touched

- `src/rig/*.bash` and generated `bin/rig`
- Relevant `tests/*.bats` and isolated fixtures
- `man/rig.1`, README, user guides and configuration specification
- This roadmap item

## Verify

Run the complete `AGENTS.md` gate, including ShellCheck, Bash syntax, assembly check, benchmark, native-provider smoke, isolated Bats and manual lint. Test unversioned new config, recognised legacy preview/repair, unknown shape rejection, no-write ordinary reads, and unchanged export payload with v1 identity.

## Dependencies / blocks

Check whether public export consumers require coordination before changing the version number; if so, keep that substep separate while completing safe input work.

## Documentation impact

### Decision Records

Record any consumer compatibility trade-off that exceeds this bounded treatment.

### Specifications

Update configuration and export identities while preserving semantics.

### Guides

Explain unversioned input, explicit repair and v1 export contract.

### Roadmap

Record implementation and verification here.

## Discussion

The v2-to-v1 change is a contract label correction in this pre-release period, not a rollback of export capability. It must still be checked against actual consumers.
