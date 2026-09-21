---
id: PDR-RIG-001
title: 'Catalogue-led Working Setup'
date: 2026-09-21
status: current
decision_type: product
decision_type_url: https://knowledgeislands.info/specifications/decision-records/pdr
decision_depends_on: [GDR-RIG-001]
---

# PDR-RIG-001: Catalogue-led Working Setup

## Context

A person's working setup is more than a package list or bootstrap sequence. It includes preferred tools, the purposes they serve, why they were chosen, how they relate, the contexts in which they are useful, which machine settings and operational resources belong with them, and whether the declared choices are present on a particular machine.

Package managers, configuration managers, service managers, and platform facilities already own native resolution, execution, and state. Rig must coordinate those authorities without requiring a person to describe Rig's adapter implementation or provider protocol in ordinary configuration.

## Decision

Rig is the declarative description and manager of a person's working setup. Its primary product concept is a catalogue of categorised tools with stable identities, purposes, personal rationale, relationships, supported platforms, and optional provider-backed installation metadata.

Profiles select tools and managed resources for machines, roles, or contexts. Services, scheduled jobs, typed machine settings, and semantic layouts are first-class declarations rather than hidden provider policy. A workstation is therefore a profile assembled from those declarations, not a provider or synthetic catalogue tool.

Providers are independently existing native authorities such as Homebrew, uv, mise, npm, chezmoi, launchd, macOS defaults, and direct downloads. Rig recognises its built-in providers and their supported operations without requiring adapter or capability declarations. A provider table is needed only to configure an optional built-in detail or explicitly trust an external extension.

Rig owns a small explicit lifecycle over the resolved declaration. `apply` and `bootstrap` converge declared state, `update` advances selected tools through their native managers, `maintain` performs bounded provider-native maintenance, `capture` refreshes a deliberately named provider manifest, and `clean` removes only Rig-owned cache data. These commands are native Rig behaviour rather than configuration-defined tasks, setup tools, or synthetic providers.

Rig may derive an explicitly selected public profile into a static personal-site projection. The private catalogue remains canonical; publication never makes the website an authority for local configuration or machine state.

## Consequences

Ordinary configuration describes desired state and native ownership rather than Rig's internal dispatch. Catalogue queries remain valuable before any mutation exists, while manager-of-managers remains the underlying orchestration model.

Portable lifecycle, schema, built-in adapters, state comparison, queries, and publication behaviour belong in tools-rig. Personal choices, host-specific values, provider-native manifests, and credentials remain in private configuration or their native systems. Rig may coordinate a provider-native manifest, but it does not become that manifest's authority.

External extensions remain possible through an explicit executable trust boundary, but their versioned invocation protocol is an extension-author concern rather than part of the everyday configuration model.

## References

- [GDR-RIG-001](GDR-RIG-001-adopting-decision-records.md) — establishes the decision collection.
