---
id: ADR-RIG-005
title: 'Provider Execution Contract'
date: 2026-09-16
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, XDR-RIG-001]
---

# ADR-RIG-005: Provider Execution Contract

## Context

Rig resolves profiles into tools and managed resources, then compares that desired state with native systems or asks those systems to materialise it. Built-in managers and external extensions need one public state model without making users configure Rig's internal adapter registry or making Rig a competing package database.

External executables cross the trust boundary established by XDR-RIG-001. Their invocation must preserve literal argument boundaries, distinguish observation from mutation, and remain evolvable without exposing the protocol as ordinary user configuration.

## Decision

Rig contains a registry of built-in providers and their supported tool kinds, resource kinds, observation operations, mutation operations, executable defaults, and platform constraints. Homebrew, uv, chezmoi, direct downloads, launchd, macOS application inventory, macOS defaults, and semantic Dock management use this registry. A user selects them by stable provider identity in a tool or resource declaration and does not repeat adapter or capability metadata.

Rig builds dependency-ordered work from the resolved profile. Tool requirements run before dependants; typed settings and layouts, services, and scheduled jobs run only after their required tools. A failed work unit suppresses only transitive dependants, while independent work continues. Catalogue-only tools remain valid declarations with no provider work.

`rig bootstrap` is a native staged workflow. It validates and resolves the selected profile, identifies the built-in and extension managers the profile needs, verifies their availability, preflights the complete plan, and reconciles the declared state. `rig apply` reconciles an already operable profile through the same planning and outcome model. Both provide a non-mutating dry run.

An external provider is explicitly declared with `adapter = "custom"` and an allow-list of trusted operations. An explicit executable takes precedence; when it is omitted, Rig resolves exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID` without searching. Rig invokes the resolved executable with a version marker as the first protocol argument after configured provider arguments:

```text
EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER SUBJECT KIND LOCATOR [ARGUMENT ...]
```

`rig-provider-v1` is an internal extension ABI marker inserted by Rig. Users do not place it in configuration or command invocations. Built-in providers do not receive this protocol.

External observation returns exactly one state token: `present`, `missing`, `drifted`, `unavailable`, or `unknown`. Invalid output or a non-zero native exit becomes public state `unknown` with bounded diagnostic detail. Mutation diagnostics remain separate from Rig's deterministic report.

Rig owns planning, preflight, progress, stable reports, failure isolation, and minimal resource reconciliation receipts. Providers retain their native manifests, resolution, execution semantics, credentials, and observed state. Rig does not persist observed installation state.

## Consequences

Ordinary users declare intent without maintaining a parallel registry of adapters and capabilities. Built-in integrations can provide richer typed validation and more useful diagnostics while remaining Bash 3.2-compatible and platform-gated.

Extension authors receive a small versioned protocol usable from any implementation language. Protocol changes remain isolated to the extension boundary, and custom integrations are required only when a selected declaration uses them.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue-led product model.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — defines inert declarative configuration.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — establishes executable trust transitions.
