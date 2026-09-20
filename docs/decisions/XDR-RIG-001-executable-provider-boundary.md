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

Rig must inspect declarative intent without silently executing it, yet providers and publishers necessarily invoke programs that can inspect, change, or disclose local state. A command string hidden in data would blur that transition and make argument boundaries, review, and failure behaviour unreliable. Even a nominally read-only custom observer is arbitrary code from Rig's perspective.

Publication adds a second risk: a useful catalogue contains rationale and relationships, while provider commands, manifest paths, host identity, private profiles, and observed machine state may disclose sensitive operational detail.

## Decision

Rig never sources or evaluates configuration. Built-in adapters are trusted code shipped with Rig. A custom provider or publisher is an explicit executable trust transition and must resolve one executable, either from its literal `executable` declaration or the exact `${RIG_DATA_HOME}/providers/PROVIDER-ID` convention. Rig performs no search or discovery and passes configured arguments literally without `eval`, shell command strings, or implicit shell expansion.

`show`, `list`, and `explain` resolve declarations without invoking provider code. `status` and `doctor` may invoke only declared observation capabilities and remain non-mutating by contract, although a custom observer must still be trusted by its owner.

Machine mutation occurs only through an explicit `apply` command or an explicitly selected `mutate` action invoked as `rig run PROVIDER ACTION`. `rig run` accepts only a declared provider action. Configured arguments and caller arguments accepted by Rig's exact allowlist—or explicitly delegated through `argument-policy = "provider"`—cross the provider boundary as literal values. Rig rejects undeclared actions, invalid policies, and non-allow-listed caller arguments before provider invocation. Network publication occurs only through an explicit `publish` command.

Static export accepts only an explicitly selected public profile. It excludes provider configuration, command arguments, native manifest paths, host and account identifiers, private profiles, credentials, and observed machine state. Relationships whose other endpoint is not public are omitted.

Direct-download application requires declared integrity evidence before installing content.

Operational-resource queries expose deferred program, environment, schedule, and policy as inert data without crossing the executable boundary. Status and doctor may invoke only `resource-observe`; apply and bootstrap may invoke `resource-apply` and `resource-retire` only after complete preflight. Resource-aware actions resolve one selected qualified resource before its declaration crosses the same literal-argument boundary.

## Consequences

Read-only catalogue queries are safe against executable configuration. Provider, operation, and publisher invocation remains powerful and visibly trusted rather than disguised as parsing. Custom integrations can use any implementation language without becoming core dependencies because they are required only when selected.

Host-specific audits and service controls can be described in private Rig configuration without being hard-coded into the public CLI. Observation and mutation remain distinct, reviewable transitions.

The public projection is deliberately narrower than the local catalogue. The user must review both public-profile membership and the generated artifact before deployment; Rig cannot infer whether free-form public rationale is socially safe to disclose.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — makes publication a derived catalogue view.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert configuration.
