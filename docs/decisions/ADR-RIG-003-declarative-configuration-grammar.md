---
id: ADR-RIG-003
title: 'Declarative Configuration Grammar'
date: 2026-09-21
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-001, ADR-RIG-002]
---

# ADR-RIG-003: Declarative Configuration Grammar

## Context

Rig needs structured categories, tools, profiles, managed resources, relationships, publications, and explicitly trusted extensions. People should describe the setup they want without repeating adapter classes, capability lists, or executable protocol details that Rig already knows for built-in managers.

Configuration must remain editable with familiar tooling while the installed core stays compatible with Bash 3.2 and has no required runtime dependency beyond Bash. Sourcing shell configuration would turn inspection into arbitrary execution, while a complete TOML implementation would add disproportionate parser complexity.

## Decision

Rig uses TOML for schema 1 configuration. It reads the optional root file `${RIG_CONFIG_HOME}/rig.toml` first, then regular `${RIG_CONFIG_HOME}/conf.d/*.toml` fragments in deterministic bytewise filename order. At least one source must exist, and the merged model must contain exactly one `[rig]` table.

Rig implements a strict schema-scoped subset of TOML 1.0 directly in Bash. It accepts declared table names, bare schema keys, decimal integer `schema = 1`, single-line basic strings, single-line arrays of basic strings, blank lines, and `#` comments. Accepted documents are valid TOML. Unsupported TOML types and syntax fail closed.

The declarative model contains categories, one table per tool, composable profiles, services, scheduled jobs, typed settings, semantic Dock layouts and items, publications, optional provider configuration, and explicitly allowed extension actions. Profiles select tools and managed resources. Fixed dotted `install.*` keys keep installation metadata with its tool. An `artifacts` array keeps generated paths with the capability that owns them; an optional `artifact.reconciler` may select only a closed Rig-owned reconciler whose installation identity, destination, executable, and arguments are fixed in product code.

Built-in provider identifiers resolve without a `[provider.ID]` table. Rig owns their adapter class, supported installation kinds, and fixed lifecycle operations. An optional table for a built-in may contain only documented provider-native configuration such as a manifest path, arguments, or executable override; it cannot grant a lifecycle capability or supply commands. A non-built-in provider requires `adapter = "custom"` and an allow-list of trusted extension operations. Its executable is either an explicit path or the exact conventional `${RIG_DATA_HOME}/providers/PROVIDER-ID` path; its invocation protocol never appears in ordinary configuration.

The parser never sources files, evaluates commands, interprets shell syntax, or performs general environment expansion. Documented path fields alone expand a leading `~/`. All other dollar signs, substitutions, glob characters, separators, and embedded variables remain inert data.

## Consequences

Rig configuration works with standard TOML-aware editors while remaining small enough for a dependency-free Bash parser. A valid TOML document may still be unsupported by the schema, and diagnostics distinguish unsupported syntax from unknown declarative fields.

Normal configuration says what belongs and which native authority owns it. Adapter selection, built-in capability discovery, generated-artifact reconciliation, lifecycle sequencing, native command selection, and protocol versioning stay inside Rig. A reconciler identifier cannot introduce an arbitrary command. External executables remain explicit trust transitions rather than side effects of parsing.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue-led declarative model.
- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — requires a Bash 3.2-compatible dependency-free core.
- [ADR-RIG-002](ADR-RIG-002-xdg-directory-contract.md) — defines the XDG application-directory contract.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — defines executable trust transitions.
