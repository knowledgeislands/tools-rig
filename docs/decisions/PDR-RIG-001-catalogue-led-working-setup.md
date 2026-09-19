---
id: PDR-RIG-001
title: 'Catalogue-led Working Setup'
date: 2026-09-16
status: current
decision_type: product
decision_type_url: https://knowledgeislands.info/specifications/decision-records/pdr
decision_depends_on: [GDR-RIG-001]
---

# PDR-RIG-001: Catalogue-led Working Setup

## Context

A person's working setup is more than a package list or bootstrap sequence. It includes preferred tools, the purposes they serve, why they were chosen, how they relate, the contexts in which they are useful, and whether the declared choices are present on a particular machine. Existing package and configuration systems already own mature native manifests, resolution, execution semantics, and state.

The same description can help its owner inspect and maintain a machine, explain how they work, and publish a deliberate public view at a personal address such as `rig.midnight.ninja`. Treating orchestration as the product would hide the catalogue that gives those operations meaning.

## Decision

Rig is the declarative description and manager of a person's working setup. Its primary product concept is a catalogue of categorised tools with stable identities, purposes, personal rationale, relationships, supported platforms, and provider-backed installations.

Profiles select catalogue subsets for machines, roles, or contexts. Providers such as Homebrew, uv, chezmoi, direct downloads, and configured executables materialise selected tools while retaining authority over their native manifests and state. Rig compares a resolved profile with provider observations and coordinates only explicitly supported actions.

Named operations attach to catalogue tools. This allows audits, maintenance jobs, and service actions to remain configuration-led without adding permanent domain-specific commands such as `rig machine` or `rig services`. Rig exposes the generic operation through `rig run` and leaves its implementation to a declared provider capability.

Rig may derive an explicitly selected public profile into a static personal-site projection. The private catalogue remains canonical; publication never makes the website an authority for local configuration or machine state.

## Consequences

Catalogue queries are valuable before any installation mutation exists. Manager-of-managers remains the underlying orchestration model rather than the product's organising idea.

Personal choices and host-specific operations belong in configuration outside the executable, while portable schema, resolution, provider, state, query, operation, and publication behaviour belongs in tools-rig. The catalogue can contain sensitive operational context, so publication requires an explicit disclosure boundary.

Provider capabilities differ, and Rig must report those differences rather than force every system into one universal lifecycle.

## References

- [GDR-RIG-001](GDR-RIG-001-adopting-decision-records.md) — establishes the decision collection.
