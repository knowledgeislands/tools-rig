---
id: RIG-CORE-008
area: CORE
title: Tool-centred configuration
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: db8d44e32a6c9ffa1ddc0e8052f7431e326d70c2
created_at: 2026-09-19T11:24:39Z
updated_at: 2026-09-19T16:17:51Z
---

# RIG-CORE-008: Tool-centred configuration

## Goal

Rig configuration presents one coherent declaration per tool and concise provider-owned actions without exposing an internal relational model.

## Context

Schema 1 TOML currently separates every tool from a `[binding.TOOL.PROVIDER]` table and describes provider commands as `[operation.TOOL.NAME]` with repeated provider and capability fields. The model is mechanically explicit but difficult to read and author. The sole current user has approved correcting schema 1 in place before wider adoption.

## Boundary

Add fixed `install.*` dotted keys to tool tables and replace operation tables with provider-owned action tables. Preserve provider-native manifests, the Bash 3.2/no-runtime-dependency core, the XDG contract, inert parsing, exact argument handling, and existing catalogue/profile/state behaviour. Do not add a second schema, compatibility loader, release, or personal declarations to the public repository.

## Current state

Tools and bindings are separate public tables. Operations repeat their provider and capability and are addressed as tool operations even when they are provider maintenance surfaces. Rig alone must allowlist every argument before a trusted custom provider can perform its own domain validation.

## Steps

- [x] Specify one-table tool installation metadata and provider-owned actions, including the trust boundary for provider-validated arguments.
- [x] Parse and validate `install.*` fields and `[action.PROVIDER.NAME]` tables while retaining an efficient internal resolved model.
- [x] Make `rig run PROVIDER ACTION [-- ARGUMENT...]` dispatch declared actions and preserve safe literal argument passing.
- [x] Align help, completions, manual, README, guide, changelog, fixtures, and conformance tests.
- [x] Run the complete repository gate and inspect the resulting public contract.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `tests/helpers/large-catalogue-fixture.bash`
- `docs/decisions/ADR-RIG-003-declarative-configuration-grammar.md`
- `docs/decisions/ADR-RIG-005-provider-execution-contract.md`
- `docs/specs/configuration.md`
- `docs/specs/orchestration.md`
- `README.md`
- `docs/guides/user/README.md`
- `man/rig.1`
- `CHANGELOG.md`
- `docs/roadmap/RIG-CORE-008-tool-centred-configuration.md`

## Verify

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh
bats tests/
mandoc -T lint man/rig.1
```

Manual inspection must confirm that a tool's installation declaration is co-located, action authority remains explicit, and help, completion, manual, README, guide, and changelog agree.

## Dependencies / blocks

Builds on the schema-1 TOML parser delivered by RIG-CORE-007. No unresolved dependency blocks implementation.

## Documentation impact

### Decision Records

Amend the configuration grammar and provider execution records in place because they own the living schema and trust-boundary decisions.

### Specifications

Revise configuration and orchestration requirements in place to state accepted schema-1 behaviour.

### Guides

Replace split binding/operation examples with tool-centred installation and provider action examples.

### Roadmap

This record owns the public contract change; the private declaration and provider relocation remain a separate dotfiles item.

## Review

### Delivered

Delivered the approved schema-1 correction from immutable baseline `db8d44e32a6c9ffa1ddc0e8052f7431e326d70c2`: co-located tool installation metadata and provider-owned actions. The Bash 3.2, XDG, native-manifest, and private-data boundaries remain intact; no release or personal catalogue was added.

### Summary of changes

`bin/rig` now parses and validates `install.*` fields, normalises them into the existing resolver, dispatches `[action.PROVIDER.NAME]` through `rig run PROVIDER ACTION`, and supports provider-side argument policy. Decisions, specifications, README, guide, changelog, manual, help, completions, and Bats coverage describe the same contract.

### Verification

`ki repo audit --repo .`, `shellcheck bin/rig install.sh`, all 123 `bats tests/` cases, and `mandoc -T lint man/rig.1` passed.

### Outstanding concerns

The resolver still uses internal binding terminology and accepts the former binding section shape in test fixtures; it is not documented or used by the live configuration. Review should decide whether rejecting that residual parser surface is required in this item.

### Post-change review

The delivered public configuration meets the one-entry-per-tool goal and retains provider isolation. Regression risk is concentrated in configuration parsing and provider dispatch, both covered by the full shell suite. The item is ready for acceptance subject to the residual-parser decision above.

### Mini recap

Rig now presents tools and actions in the intended public model, with synchronized user surfaces and a clean verification gate. A useful learning route is whether internal normalisation vocabulary should also be renamed after the public contract is accepted.

## Discussion

The public schema should optimise for explaining a person's rig. Internal normalisation is an implementation detail and may remain if it keeps resolution simple.
