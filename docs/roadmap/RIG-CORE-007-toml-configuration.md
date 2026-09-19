---
id: RIG-CORE-007
area: CORE
title: TOML configuration
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-19T08:39:31Z
updated_at: 2026-09-19T08:39:31Z
---

# RIG-CORE-007: TOML configuration

## Goal

Rig uses a clear, tool-compatible TOML configuration while retaining its inert, dependency-free Bash 3.2 core.

## Context

Schema 1 currently uses a custom INI-shaped grammar. Its section headings and assignments resemble TOML, but bare string values and repeated keys mean the files are not TOML. Rig has one current user and no compatibility commitment for this unpublished configuration contract, so schema 1 can be corrected in place without carrying a second parser or migration command.

The approved direction uses `${RIG_CONFIG_HOME}/rig.toml` followed by `conf.d/*.toml`. Rig accepts a deliberately bounded TOML subset sufficient for its declared schema: named tables, a decimal integer schema value, basic strings, and single-line arrays of basic strings. Every accepted file remains valid TOML, while unsupported TOML types and syntax fail closed.

## Boundary

This item does not add a general-purpose TOML implementation, external parser dependency, schema 2, legacy `rig.conf` compatibility mode, automatic personal-configuration rewrite, or release. It does not alter provider execution semantics or the public `rig-publication` data format.

## Current state

`bin/rig` discovers `rig.conf` and `.conf` fragments, parses unquoted literal values, and models list values as repeated keys. Tests, examples, diagnostics, the manual, and the accepted configuration specification all expose that contract.

## Steps

- [ ] Rewrite the living configuration decision and accepted requirements around the bounded TOML schema 1 and its trust boundary.
- [ ] Replace configuration discovery and parsing with dependency-free Bash 3.2 handling of `rig.toml`, `.toml` fragments, basic strings, arrays, comments, and strict rejection.
- [ ] Convert configuration fixtures and tests, including parser safety, deterministic fragments, diagnostics, arrays, and unsupported syntax.
- [ ] Align README, guide, manual, help/completion surfaces where affected, and the curated changelog.
- [ ] Run the complete repository gate and inspect the resulting command contract.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `docs/decisions/ADR-RIG-003-declarative-configuration-grammar.md`
- `docs/specs/configuration.md`
- `README.md`
- `docs/guides/rig.md`
- `man/rig.1`
- `CHANGELOG.md`
- `docs/roadmap/RIG-CORE-007-toml-configuration.md`
- Additional existing user-facing examples or completion tests only where the configuration filename or syntax is exposed

## Verify

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh
bats tests/
mandoc -T lint man/rig.1
```

Manual inspection must also confirm that all documented configuration examples parse as TOML and that help, manual, README, guide, diagnostics, and completion behaviour agree.

## Dependencies / blocks

The catalogue, profile, provider, operation, publication, and schema 1 field contracts already exist. No external dependency or unresolved decision blocks delivery.

## Documentation impact

### Decision Records

Rewrite ADR-RIG-003 in place because it owns the live grammar decision.

### Specifications

Revise RIG-CONF requirements in place so accepted schema 1 behaviour describes TOML rather than the custom grammar.

### Guides

Convert every user-facing configuration example and explain the supported TOML subset.

### Roadmap

This record is the sole implementation plan; no follow-on roadmap work is expected unless delivery exposes a distinct gap.

## Discussion

### Schema identity

Schema version identifies the current product data model, not an already-consumed public serialization contract. Keeping schema 1 avoids ceremonial versioning when the sole current user has explicitly approved an in-place correction.

### Parser scope

Rig must be honest about supporting a schema-scoped TOML subset rather than claiming general TOML support. Accepted documents can be read by ordinary TOML tooling, but Rig rejects valid TOML constructs its schema does not need. This keeps parser behaviour bounded, testable, and independent of runtime packages.

### Single authority

Removing `rig.conf` discovery avoids dual configuration authorities and ambiguous precedence. Personal data conversion remains an explicit reviewed dotfiles change after the replacement has equivalent tests.
