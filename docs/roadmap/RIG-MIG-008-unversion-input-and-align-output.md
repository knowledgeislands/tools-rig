---
id: RIG-MIG-008
area: MIG
title: Align schema contracts
theme: migration
horizon: next
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 6f049c71170fc0a169dafb3cdeeeab3fb8740fc9
created_at: 2026-10-03T04:00:16Z
updated_at: 2026-10-03T07:00:13Z
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

- [x] Inventory all Rig input, operational output and publication version uses and their consumers.
- [x] Accept and write the current unversioned config shape; keep recognised `schema = 1` readable and provide an explicit, previewed repair that never rewrites active configuration on a read.
- [x] Renumber the export contract to v1 without reducing payload capability, and make downstream consumers additive-field tolerant.
- [x] Align help, completion, manual, guides, specifications and tests; run the full isolated Rig gate.

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

## Review

### Delivered

From baseline `6f049c71170fc0a169dafb3cdeeeab3fb8740fc9`, Rig now writes and reads the current unversioned configuration shape, accepts only structurally valid legacy `schema = 1` input, and emits the complete public projection under its own version-1 identity. Repair is explicit: preview the exact amended source or write a new proposal outside active configuration for manual replacement. No ordinary read rewrites configuration, no live workstation apply was run, and no release or push is included.

### Change Summary

The authored Bash modules and assembled `bin/rig` implement input compatibility, a guarded init repair proposal, and export v1. The diagnostic snapshot no longer presents a nested configuration-schema field that could imply the user must declare one. `tests/rig-schema-migration.bats` adds isolated migration and help/completion coverage; existing export assertions and the root-cardinality test were aligned. README, changelog, manual, user guides, configuration and publication Specifications, and the configuration Decision Record describe the current contract. An adjacent-repository search found no checked-in consumer of Rig's export; the publication Specification now requires future consumers to tolerate additive fields.

### Verification

`ki repo audit --repo .`, full ShellCheck, Bash syntax, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `bats tests/ < /dev/null`, `mandoc -T lint man/rig.1`, and `git diff --check` passed. The new focused migration suite passed five tests; the full suite passed after the rebuilt executable was tested.

### Outstanding concerns

No blocking concern. An external export consumer not present in the adjacent repositories may have pinned version 2; it must verify version-1 acceptance at its next integration. The exported fields and behaviour were not reduced.

### Post-change review

The requested input and generated-output contracts are aligned without a parallel parser-version regime. The repair path is deliberately non-destructive: it refuses unknown semantics and never targets active configuration. Regression risk is concentrated in version-pinned external export readers; local and isolated checks passed, so the item is ready for acceptance review.

### Mini recap

Rig's current input is unversioned, recognised legacy input is repairable through a reviewed proposal, and operational and public JSON each identify their own v1 contract. Verification passed with no live apply. The configuration Decision Record, Specifications, and user guide carry the durable behaviour; any newly discovered external consumer should be evaluated at integration rather than adding a speculative compatibility mode here.

## Discussion

The v2-to-v1 change is a contract label correction in this pre-release period, not a rollback of export capability. It must still be checked against actual consumers.
