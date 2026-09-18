---
id: ADR-RIG-003
title: 'Declarative Configuration Grammar'
date: 2026-09-16
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-001, ADR-RIG-002]
---

# ADR-RIG-003: Declarative Configuration Grammar

## Context

Rig needs structured categories, tools, profiles, providers, bindings, relationships, publications, and declared operations while its installed core remains compatible with Bash 3.2 and has no required runtime dependency beyond Bash. TOML, YAML, and JSON require either a non-trivial parser in the executable or an external tool. Sourcing shell configuration would be easy to implement but would turn data inspection into arbitrary code execution.

Personal catalogues can be large and should remain convenient to organise in dotfiles without introducing executable include directives or a second configuration authority.

## Decision

Rig adopts a versioned, INI-shaped declarative grammar. `${RIG_CONFIG_HOME}/rig.conf` is the root file and `${RIG_CONFIG_HOME}/conf.d/*.conf` provides optional fragments loaded afterward in deterministic bytewise filename order.

The grammar consists of named sections, `key = literal value` records, blank lines, and whole-line comments. Section types and keys are schema-controlled. Known list fields repeat the key; scalar duplication, unknown fields, conflicting identities, and unsupported schema versions fail closed. The parser splits a record at the first equals sign and performs no quoting, escaping, command evaluation, or general environment expansion. Documented path fields alone expand a leading `~/`. Comparison may derive an absolute artifact identity from a leading `~/` or `$HOME/`, but the authored declaration remains unchanged and no other variable syntax is interpreted.

Initial section types are `rig`, `category`, `tool`, `profile`, `provider`, `binding`, `operation`, and `publication`. Stable identifiers connect sections; declaration order has no semantic effect beyond deterministic fragment loading.

An operation has identity `[operation.TOOL.NAME]`. It binds an existing tool to one declared provider capability, an `observe` or `mutate` mode, literal configured arguments, and an optional exact allow-list for caller-supplied arguments. This keeps machine audits, service actions, and similar host-specific jobs in data without making shell command strings part of the grammar.

## Consequences

Configuration remains inert, reviewable, and parseable in Bash 3.2. The format is deliberately Rig-specific rather than claiming compatibility with every INI dialect. Schema evolution requires an explicit version change when it would alter the meaning of accepted records.

Profiles, provider ordering, operations, and publication use the same resolved data model without learning separate file formats. Personal declarations can be split into managed fragments while the XDG application-directory contract remains unchanged.

Declared operations provide one generic extension point instead of permanent domain-specific command families. They still cross the executable-provider trust boundary when invoked.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue-led product model.
- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — requires a Bash 3.2-compatible dependency-free core.
- [ADR-RIG-002](ADR-RIG-002-xdg-directory-contract.md) — defines the XDG application-directory contract.
