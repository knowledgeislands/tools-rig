---
id: XDR-RIG-001
title: 'Executable Provider Boundary'
date: 2026-09-30
status: current
decision_type: security
decision_type_url: https://knowledgeislands.info/specifications/decision-records/xdr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003]
---

# XDR-RIG-001: Executable Provider Boundary

## Context

Rig must inspect declarative intent without silently executing it. Built-in providers invoke reviewed native commands, while external providers and publishers may execute arbitrary code that can inspect, change, or disclose local state. Commands hidden in configuration would blur that transition and make arguments, review, and failure behaviour unreliable.

Publication creates a separate disclosure boundary because useful private configuration can contain native ownership, paths, machine policy, and relationships that do not belong on a public website. User-level skills add another trust concern: a declaration can refer to reviewed content, but Rig must not infer trust from an observed directory or evaluate that content itself.

## Decision

Rig never sources or evaluates configuration. Built-in adapters are reviewed Rig code with fixed provider identities, supported operations, platform gates, and argument construction. External providers and publishers are explicit executable trust transitions with narrowly allowed operations and deterministic executable resolution. Configuration cannot supply hidden commands or grant built-in capabilities.

Declaration queries invoke no provider code. Status and doctor, including verbose diagnostics, may invoke only bounded observation. Apply and upgrade explicitly authorise machine mutation and complete required preflight first. Init creates missing configuration only; capture observes supported inventory and emits additive proposals outside active configuration for deliberate review. Neither operation installs packages. Rig does not expose generic provider-action dispatch, destructive package cleanup or network publication.

Static export is offline and accepts only an explicitly selected public view. Its allow-list excludes provider configuration, installation metadata, machine resources, private ports, commands, arguments, native manifests, local paths, credentials, other profiles, observed state, and unmanaged inventory.

Skills require an explicit authority, trust classification, and reviewable source identity. Rig does not evaluate instruction content or treat an observed local directory as proof of trust. Direct downloads require declared integrity evidence before installation.

## Consequences

Read-only inspection remains safe for inert configuration. Built-in mutation is reviewable as part of Rig, while external integrations remain powerful but visible and narrowly authorised. A person must review both public-view membership and the generated artifact before deployment.

The exact operation allow-lists, observation formats, lifecycle commands, and disclosure fields remain in the Specifications rather than this security rationale.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — defines the declarative product boundary.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert configuration.
