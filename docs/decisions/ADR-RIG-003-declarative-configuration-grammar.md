---
id: ADR-RIG-003
title: 'Declarative Configuration Grammar'
date: 2026-09-19
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-001, ADR-RIG-002]
---

# ADR-RIG-003: Declarative Configuration Grammar

## Context

Rig needs structured categories, tools, profiles, providers, relationships, publications, and declared provider actions. People should be able to edit those declarations with familiar tooling, while the installed core remains compatible with Bash 3.2 and has no required runtime dependency beyond Bash. Installation metadata is part of explaining a tool and should not require a second public table.

Sourcing shell configuration would turn data inspection into arbitrary code execution. A complete TOML implementation inside Rig would add disproportionate parsing complexity, but a private INI-like language would look familiar without being interoperable with standard configuration tooling. Rig's schema needs only named tables, strings, one integer version, and lists of strings.

## Decision

Rig uses TOML for schema 1 configuration. It reads the optional root file `${RIG_CONFIG_HOME}/rig.toml` first, then regular `${RIG_CONFIG_HOME}/conf.d/*.toml` fragments in deterministic bytewise filename order. At least one source must exist, and the merged model must contain exactly one `[rig]` table.

Rig implements a strict schema-scoped subset of TOML 1.0 directly in Bash. It accepts its declared table names, bare schema keys, decimal integer `schema = 1`, single-line basic strings, single-line arrays of basic strings, blank lines, and `#` comments. Accepted documents are valid TOML. Rig rejects TOML types and syntax its schema does not need, including literal strings, multiline strings, multiline arrays, floats, booleans, date-time values, inline tables, arrays of tables, dotted assignment keys, and Unicode escape sequences.

Scalar schema fields use TOML basic strings. List fields use one array assignment and plural names such as `platforms`, `tools`, `profiles`, `arguments`, `capabilities`, `alternatives`, `artifacts`, and `allowed-arguments`; `requires` and `related` are already plural or collective. Duplicate keys or tables fail closed across the complete source set.

The parser never sources files, evaluates commands, interprets shell syntax, or performs general environment expansion. Documented path fields alone expand a leading `~/`. Artifact comparison may derive absolute identity from a leading `~/` or `$HOME/`, while retaining the authored value. All other dollar signs, command substitutions, glob characters, separators, and embedded variables remain inert data.

Schema-controlled tables are `rig`, `category`, `tool`, `profile`, `provider`, `publication`, and `action`. Fixed dotted `install.*` keys keep one human-readable table per tool while Rig may normalise them internally for planning. Provider-owned action identities avoid repeating provider and capability fields. Profiles, provider ordering, actions, and publication use the same resolved model. Personal declarations can be split into independently valid fragments without executable include directives or a second configuration authority.

## Consequences

Rig configuration works with standard TOML-aware editors, syntax highlighters, formatters, and readers. Arrays express ordered item boundaries without repeated keys or comma-splitting conventions.

The dependency-free core remains small enough to review because it rejects general TOML features outside the product schema. A valid TOML document may therefore still be unsupported by Rig, and diagnostics must distinguish unsupported value syntax from unknown schema fields.

Configuration remains inert during catalogue queries and validation. Provider, action, and publisher invocation continue to be explicit executable trust transitions rather than side effects of parsing.

Schema 1 operational resources use the same bounded grammar: `[service.ID]` and `[scheduled-job.ID]` tables contain only quoted strings and string arrays, while profile resource selectors remain arrays. Calendar intent is encoded as validated literal strings rather than inline tables, preserving inert Bash 3.2 parsing and ordinary TOML interoperability.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue-led product model.
- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — requires a Bash 3.2-compatible dependency-free core.
- [ADR-RIG-002](ADR-RIG-002-xdg-directory-contract.md) — defines the XDG application-directory contract.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — defines executable trust transitions.
