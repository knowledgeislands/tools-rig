---
id: ADR-RIG-003
title: 'Declarative Configuration Grammar'
date: 2026-09-22
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-001, ADR-RIG-002]
---

# ADR-RIG-003: Declarative Configuration Grammar

## Context

Rig needs a structured way to describe catalogue entries, profiles, managed resources, publications, and explicitly trusted extensions. People should be able to read and edit that declaration with familiar tools without repeating internal adapter or protocol details.

The installed core must remain compatible with Bash 3.2 and require no runtime beyond Bash. Sourcing shell configuration would turn inspection into arbitrary execution, while implementing every TOML feature would add complexity unrelated to Rig's schema.

## Decision

Rig uses TOML schema 1. It reads an optional root file at `${RIG_CONFIG_HOME}/rig.toml`, then regular `${RIG_CONFIG_HOME}/conf.d/*.toml` fragments in deterministic bytewise order. At least one source exists, and the merged model contains exactly one root declaration.

The schema gives each catalogue capability one declaration. Installation and platform variants remain with their owning tool; managed-resource dependencies remain an inert graph; profile membership remains with each selectable item. A profile records identity, purpose, inheritance, and whether it is complete intent or a non-appliable view. Built-in providers are selected by stable identity without repeating their adapter capabilities. External providers are explicit, narrowly allowed executable extensions.

Rig implements only the TOML surface required by the schema. Every accepted source is valid TOML, but valid TOML outside the supported subset is rejected clearly. The parser never sources configuration, evaluates commands, interprets shell syntax, or performs general environment expansion. Only documented path fields receive bounded home-directory expansion; all other text remains inert.

The complete table and field contract belongs to the Specifications and the `rig(1)` configuration reference.

## Consequences

Configuration remains approachable in standard TOML-aware editors while the runtime keeps its dependency-free Bash parser. A valid TOML document may still be outside schema 1, so diagnostics distinguish unsupported TOML from unknown Rig declarations.

Ordinary configuration states intent and native ownership. Adapter selection, capability discovery, lifecycle sequencing, native command selection, and extension protocol versioning remain implementation concerns. External executables stay explicit trust transitions, while declaration queries remain free of provider side effects.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue-led declarative model.
- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — requires a Bash 3.2-compatible dependency-free core.
- [ADR-RIG-002](ADR-RIG-002-xdg-directory-contract.md) — defines the XDG application-directory contract.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — defines executable trust transitions.
