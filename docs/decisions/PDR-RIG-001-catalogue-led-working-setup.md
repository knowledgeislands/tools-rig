---
id: PDR-RIG-001
title: 'Catalogue-led Working Setup'
date: 2026-09-22
status: current
decision_type: product
decision_type_url: https://knowledgeislands.info/specifications/decision-records/pdr
decision_depends_on: [GDR-RIG-001]
---

# PDR-RIG-001: Catalogue-led Working Setup

## Context

A person's working setup is more than a package list or bootstrap sequence. It includes the tools and user-level skills they rely on, the reasons for those choices, the contexts in which they are useful, and the machine resources that support the work. The same declaration should help a person understand their intended setup and compare it with a particular machine.

Package managers, configuration managers, service managers, and platform facilities already own native resolution, execution, and state. Rig coordinates those authorities without requiring ordinary configuration to describe its internal adapters or protocols.

## Decision

Rig is the declarative description and manager of a person's working setup. Its primary product concept is a catalogue of stable, meaningful declarations: tools, user-level skills, managed resources, and private port allocations. Each declaration records what it is for, why it belongs, which platforms support it, and any relationships or native ownership needed to understand it.

Declarations state the profiles to which they belong. Omitted membership means the configured default profile; explicit empty membership means no profile. A complete profile represents appliable intent, while a view represents a deliberately bounded, non-appliable perspective such as a public rig.

Rig's manager-of-managers model sits beneath the catalogue. Rig resolves profiles, orders dependencies, selects native providers, checks trust and capability boundaries, compares expected with observed state, and reports outcomes. It provides an explicit lifecycle for convergence, bootstrap, updates, maintenance, capture, publication, and Rig-owned cache cleanup. Native systems retain authority over their manifests, credentials, resolution, configuration, caches, and state.

Rig may derive an explicitly selected public view as static data for a personal site. The private catalogue remains authoritative; publication never becomes a source of local configuration or observed machine state.

## Consequences

Ordinary configuration describes personal intent and native ownership rather than Rig's dispatch machinery. Catalogue queries remain useful even where no materialisation is requested.

Portable schema, lifecycle, built-in adapters, state comparison, queries, and publication behaviour belong in Rig. Personal choices, host-specific values, provider-native manifests, and credentials remain in private configuration and their native systems. External extensions remain possible through an explicit executable trust boundary.

## References

- [GDR-RIG-001](GDR-RIG-001-adopting-decision-records.md) — establishes the decision collection.
