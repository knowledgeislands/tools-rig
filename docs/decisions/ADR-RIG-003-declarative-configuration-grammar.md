---
id: ADR-RIG-003
title: 'Declarative Configuration Grammar'
date: 2026-09-15
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-001, ADR-RIG-002]
---

# ADR-RIG-003: Declarative Configuration Grammar

## Context

Rig needs structured categories, tools, profiles, providers, bindings, relationships, and publications while its installed core remains compatible with Bash 3.2 and has no required runtime dependency beyond Bash. TOML, YAML, and JSON require either a non-trivial parser in the executable or an external tool. Sourcing shell configuration would be easy to implement but would turn data inspection into arbitrary code execution.

Personal catalogues can be large and should remain convenient to organise in dotfiles without introducing executable include directives or a second configuration authority.

## Decision

Rig adopts a versioned, INI-shaped declarative grammar. `${RIG_CONFIG_HOME}/rig.conf` is the root file and `${RIG_CONFIG_HOME}/conf.d/*.conf` provides optional fragments loaded afterward in deterministic bytewise filename order.

The grammar consists of named sections, `key = literal value` records, blank lines, and whole-line comments. Section types and keys are schema-controlled. Known list fields repeat their key; scalar duplication, unknown fields, conflicting identities, and unsupported schema versions fail closed. The parser splits a record at its first equals sign and performs no quoting, escape, command, or general environment expansion. Documented path fields alone may expand a leading `~/`.

Initial section types are `rig`, `category`, `tool`, `profile`, `provider`, `binding`, and `publication`. Stable identifiers connect sections; declaration order has no semantic effect beyond deterministic fragment loading.

## Consequences

Configuration remains inert, reviewable, and parseable in Bash 3.2. The format is deliberately Rig-specific rather than claiming compatibility with every INI dialect. Schema evolution requires explicit versions and migrations rather than permissive interpretation.

Profiles, provider ordering, and publication use the same resolved data model without learning separate file formats. Personal declarations can be split into managed fragments while the XDG application-directory contract remains unchanged.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — defines the catalogue, profile, provider, state, and publication model.
- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — requires a Bash 3.2-compatible dependency-free core.
- [ADR-RIG-002](ADR-RIG-002-xdg-directory-contract.md) — defines the configuration directory.
