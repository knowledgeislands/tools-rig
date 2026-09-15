---
id: XDR-RIG-001
title: 'Executable Provider Boundary'
date: 2026-09-15
status: current
decision_type: security
decision_type_url: https://knowledgeislands.info/specifications/decision-records/xdr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003]
---

# XDR-RIG-001: Executable Provider Boundary

## Context

Rig must inspect declarative intent without silently executing it, yet providers and publishers necessarily invoke programs that can inspect, change, or disclose local state. A command string hidden in data would blur that transition and make argument boundaries, review, and failure behaviour unreliable. Even a nominally read-only custom observer is arbitrary code from Rig's perspective.

Publication adds a second risk: a useful catalogue contains rationale and relationships, while provider commands, manifest paths, host identity, private profiles, and observed machine state may disclose sensitive operational detail.

## Decision

Rig never sources or evaluates configuration. Built-in adapters are trusted code shipped with Rig. A custom provider or publisher is an explicit executable trust transition and must identify one executable; Rig passes configured arguments literally without `eval`, shell command strings, or implicit shell expansion.

`show`, `list`, and `explain` resolve declarations without invoking provider code. `status` may invoke only a declared observation capability and remains non-mutating by contract, although a custom observer must still be trusted by its owner. Machine mutation occurs only through an explicit apply command. Network publication occurs only through an explicit publish command.

Static export accepts only an explicitly selected public profile. It excludes provider configuration, command arguments, native manifest paths, host and account identifiers, private profiles, credentials, and observed machine state. Relationships whose other endpoint is not public are omitted. Direct-download application requires declared integrity evidence before installing content.

## Consequences

Read-only catalogue queries are safe against executable configuration. Provider and publisher invocation remains powerful and visibly trusted rather than disguised as parsing. Custom integrations can use any implementation language without becoming core dependencies because they are required only when selected.

Public projection is deliberately narrower than the local catalogue. A user must review both public-profile membership and the generated artifact before deployment; Rig cannot infer whether free-form public rationale is socially safe to disclose.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — makes publication a derived catalogue view.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert configuration.
