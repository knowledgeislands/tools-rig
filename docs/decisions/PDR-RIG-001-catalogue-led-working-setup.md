---
id: PDR-RIG-001
title: 'Catalogue-led Working Setup'
date: 2026-09-30
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

Rig's manager-of-managers model sits beneath the catalogue. Rig resolves profiles, orders dependencies, selects native providers, checks trust and capability boundaries, compares expected with observed state, and reports outcomes. Rig configuration is the authority for desired package selection; Homebrew, uv and other managers execute that intent without a competing Brewfile. Init creates configuration, show explains intent, status compares reality, capture prepares additive reviewed declarations, apply reconciles including prerequisites, upgrade advances selected software, and doctor diagnoses health. Native tools retain imperative operations, housekeeping, credentials, resolution and installation state. ChezMoi retains its native source, templates and application semantics.

Rig may derive an explicitly selected public view as static data for a personal site. The private catalogue remains authoritative; publication never becomes a source of local configuration or observed machine state.

## Consequences

Ordinary configuration describes personal intent and native ownership rather than Rig's dispatch machinery. Catalogue queries remain useful even where no materialisation is requested.

Portable schema, lifecycle, built-in adapters, state comparison, queries, and publication behaviour belong in Rig. Personal choices and host-specific values remain in private Rig configuration; provider execution state, credentials and chezmoi source remain native. Capture never invents purpose or rationale, overwrites active configuration, or removes declarations absent from a particular machine. External extensions remain possible through an explicit executable trust boundary.

## References

- [GDR-RIG-001](GDR-RIG-001-adopting-decision-records.md) — establishes the decision collection.
