---
id: XDR-RIG-001
title: 'Executable Provider Boundary'
date: 2026-09-16
status: current
decision_type: security
decision_type_url: https://knowledgeislands.info/specifications/decision-records/xdr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003]
---

# XDR-RIG-001: Executable Provider Boundary

## Context

Rig must inspect declarative intent without silently executing it. Built-in providers necessarily invoke native programs, while external providers and publishers may execute arbitrary code that can inspect, change, or disclose local state. A command string hidden in data would blur that transition and make argument boundaries, review, and failure behaviour unreliable.

Publication adds a separate disclosure risk because a useful private rig can contain rationale, machine policy, paths, and relationships that do not belong in a public projection.

## Decision

Rig never sources or evaluates configuration. Built-in adapters are trusted code shipped and reviewed with Rig. Their provider identities, supported operations, executable defaults, platform gates, and argument construction are owned by the executable rather than granted through user capability declarations.

An external provider or publisher is an explicit executable trust transition. Configuration must declare `adapter = "custom"` and allow each operation Rig may invoke. It may name an executable, or omit that field to select exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`. Rig performs no executable search or adjacent-file discovery and passes configured values literally without `eval`, shell command strings, or implicit expansion.

Rig inserts the `rig-provider-v1` marker only when invoking an external extension. The marker is an implementation-language-neutral ABI version, not a user option, configuration value, or protocol used by built-in providers.

Catalogue queries and diagnostics invoke no provider code. Status and doctor may invoke only observation operations. Machine mutation occurs only through explicit apply or bootstrap commands, or an explicitly allowed extension mutation. Network publication occurs only through an explicit publish command.

Static export accepts only an explicitly selected public profile. It excludes providers, installation metadata, machine resources, commands, arguments, native manifests, host identity, credentials, other profiles, and observed machine state.

Direct-download application requires declared integrity evidence before installing content. Deferred programs, schedules, settings, and layouts remain inert data until an explicit mutation command completes full-plan preflight.

## Consequences

Read-only declaration inspection remains safe against executable configuration. Built-in mutation stays reviewable as part of Rig, while external integrations remain powerful but visibly trusted and narrowly allowed.

The public projection is deliberately narrower than the private declaration. The user must review both public-profile membership and the generated artifact before deployment.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — defines the declarative product boundary.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert configuration.
