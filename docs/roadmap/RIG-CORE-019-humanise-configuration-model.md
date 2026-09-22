---
id: RIG-CORE-019
title: Humanise configuration model
area: CORE
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 6c2db6a6399ad60850c5d20917c5428eca46f27e
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-22T01:07:13Z
---

## Goal

Rig configuration should remain inert and Bash-readable while being pleasant for a person to understand, edit, review, and extend across realistic catalogues and more than one machine context.

## Context

Schema 1 rejects multiline arrays, producing a 1,305-character default tool-membership line in the current personal rig. Profiles have membership but no display name or purpose. Repeated platform and installation fields add noise, and one logical tool cannot yet express provider variants for different platforms. Managed resources can depend on tools but cannot express ordering between resources.

The proposed item-centric membership model can remove the largest profile arrays, but other arrays, schedules, programs, and ordered layouts still need a humane representation. Configuration usability is part of the product contract, not only guide formatting.

## Boundary

This work does not adopt YAML, a complete general-purpose TOML evaluator, arbitrary environment expansion, last-wins overrides, or executable configuration. Personal values and rationale remain private data rather than defaults embedded in Rig.

## Current state

The inert parser handles one-line arrays only, the personal default membership line exceeds 1,300 characters, profiles lack human labels and purpose, platform-specific installation requires duplicated logical tools, and managed resources cannot order themselves relative to other resources. Diagnostics expose parser rules more readily than author intent.

## Steps

- [x] Extend the schema-1 parser with bounded multiline arrays of basic strings while preserving duplicate rejection, literal values, and Bash 3.2 operation.
- [x] Add profile `name`, `purpose`, `inherits`, and appliable/view metadata using the membership semantics from `RIG-CORE-018`.
- [x] Add bounded platform installation and artifact variants beneath one logical tool identity with deterministic single-match validation.
- [x] Add resource-to-resource `depends-on` ordering with cycle, missing-reference, and selected-profile validation.
- [x] Improve diagnostics and examples so fragment composition, duplicate intent, profile meaning, and invalid variants are understandable to a configuration author.
- [x] Update the canonical sample configuration and every schema, manual, guide, completion-adjacent, and changelog surface.

## Files touched

Expected scope includes `bin/rig`, `tests/rig.bats`, `docs/specs/configuration.md`, `docs/specs/orchestration.md`, `docs/guides/user/`, `man/rig.1`, `README.md`, and `CHANGELOG.md`.

## Verify

Run the complete repository gate and fixtures for multiline arrays, item membership, profile metadata and inheritance, zero/one/multiple platform-variant matches, resource dependency order and cycles, duplicate declarations across fragments, and unchanged rejection of interpolation or executable values.

## Dependencies / blocks

The plan uses the locked profile semantics in `RIG-CORE-018`, but parser and diagnostic work can be prepared independently in the same ordered foundation batch. Personal configuration migration remains in `RIG-MIG-007`.

## Delegation

Parser fixtures, variant and dependency resolution, and documentation examples are separable lanes. The coordinator owns schema compatibility, trust-boundary review, and integrated validation.

## Documentation impact

### Decision Records

Amend the inert-configuration decision only for durable representation choices; retain detailed fields in the Configuration Specification.

### Specifications

Specify multiline arrays, profile metadata, item membership, bounded platform variants, resource dependencies, validation, and schema-1 compatibility.

### Guides

Teach a small readable configuration incrementally and show how one logical tool varies safely by platform without duplicating identity.

### Roadmap

The personal-data rewrite and rationale curation remain in `RIG-MIG-007`; no alternative configuration-format item is needed.

## Review

### Delivered

The schema-1 configuration model now supports readable multiline arrays, bounded platform-specific installation and artifact variants beneath one tool identity, and qualified resource dependencies with deterministic ordering, while preserving the inert Bash 3.2 trust boundary and the profile authority delivered by `RIG-CORE-018`.

### Summary of changes

- `bin/rig` now parses bounded multiline basic-string arrays and rejects split strings, unterminated arrays, and oversized constructs.
- Tool variants use dotted `variant.ID.*` fields, require exactly one matching variant when variants are declared, select the correct provider binding and artifacts by platform, and keep installation detail out of public projections.
- Services, scheduled jobs, settings, and Dock layouts accept qualified `depends-on` references, validate missing references and cycles, resolve transitively, run in stable topological order, and suppress only transitive dependants after failure.
- `rig diag`, `show`, and `explain` expose the resulting human model without invoking providers.
- Decision, Specification, README, guide, manual, changelog, and test surfaces describe and verify the same schema-1 model.

### Verification

- `ki repo audit --repo .`
- `shellcheck bin/rig install.sh`
- `bash -n bin/rig install.sh`
- `bats tests/` — 199/199 passed
- `mandoc -T lint man/rig.1`
- `git diff --check`

All required checks passed on the delivery tree.

### Outstanding concerns

No delivery blocker remains. Platform variants intentionally support one matching variant per tool and resource dependencies remain a bounded acyclic graph; conditional execution and arbitrary lifecycle hooks remain excluded.

### Post-change review

The delivered grammar is materially easier to maintain while remaining deterministic and inert. Variant and dependency resolution are covered independently and in the full suite, public data remains allow-listed, and the change preserves the single logical tool and typed resource models.

### Mini recap

Rig configuration can now be formatted for humans, describe one tool across supported platforms, and order related managed resources without returning to duplicate identities or generic scripts. Personal-data migration remains separately owned by `RIG-MIG-007`.

## Discussion

### Locked representation

Schema 1 gains bounded multiline basic-string arrays. Profiles gain `name`, `purpose`, explicit `inherits`, and appliable/view kind. Item-local `profiles` follows `RIG-CORE-018`; a configuration cannot combine that mode with central membership arrays. One logical tool may contain bounded platform-specific installation and artifact variants, exactly one of which may match. Resources may depend on other resources through the existing acyclic dependency model, without conditions or arbitrary commands.

### Schema 1 evolution

A bounded multiline array of basic strings can remain valid TOML and inert Bash-parsed data. Profile name, purpose, safe item-centric membership, and concise defaults should be considered as compatible schema 1 evolution while the format is still personal and pre-v1.

### Cross-machine variants

Preserve one logical tool identity while deciding whether a bounded installation and artifact variant can select a native owner by platform or machine context. Do not reintroduce separate binding declarations or duplicate tools merely to choose Homebrew on macOS and another manager elsewhere.

### Resource dependencies

Determine whether explicit resource-to-resource ordering is needed for settings before services or daemons before jobs. Any addition should remain a dependency graph, not a generic task runner.

### Human validation

Examples and diagnostics should help an owner distinguish purpose from rationale, understand fragment composition, and locate conflicting or duplicated intent without requiring knowledge of Rig's internal parser representation.
