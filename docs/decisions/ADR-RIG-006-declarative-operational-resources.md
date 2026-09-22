---
id: ADR-RIG-006
title: 'Declarative Operational Resources'
date: 2026-09-20
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, ADR-RIG-005, XDR-RIG-001]
---

# ADR-RIG-006: Declarative Operational Resources

## Context

Services, scheduled jobs, stable machine settings, and semantic workstation layouts are part of a person's selected setup. Hiding them in provider-local registries prevents Rig from explaining, observing, previewing, and reconciling the complete profile. Treating the whole workstation as a provider has the same problem: the aggregation belongs to a profile, while each native manager owns only its own domain.

Removing a selected long-lived resource also creates a reconciliation problem. Once its declaration disappears, a native manager still needs the former locator to retire it safely without making Rig persist a competing copy of observed state.

## Decision

Schema 1 provides first-class services, scheduled jobs, typed settings, and semantic Dock layouts. Profiles select them alongside tools. Every managed declaration carries stable identity, purpose, rationale, supported platforms, native ownership, desired state, and the provider-specific data Rig needs to validate and explain it.

Launchd is a built-in macOS provider for services and scheduled jobs. macOS defaults and semantic Dock layout are built-in typed resource providers. Application-bundle inventory is a built-in read-only observation source. None requires a custom executable, adapter declaration, capability list, or provider-owned configuration registry.

A workstation is a complete profile resolving its applications, command-line tools, settings, Dock layout, services, and scheduled jobs through item-owned membership and explicit inheritance. `rig show`, qualified `rig explain`, `rig status`, `rig doctor`, `rig apply --dry-run`, and `rig apply` operate on that resolved declaration. Provider-specific escape-hatch actions do not replace desired-state declarations.

Rig stores minimal successful-application receipts only for services and scheduled jobs whose safe retirement requires former identity and locator evidence. Deselecting one of those resources from the next complete profile schedules retirement. Deselecting a package, artifact, setting, Dock layout, port, or skill is non-destructive unless a separate explicit cleanup contract applies. A non-appliable view neither reads retirement ownership into its result nor writes a receipt. Receipts are not observed state and cannot recreate a declaration. Built-in and external providers receive the same resolved intent, but only an external provider crosses the versioned executable protocol boundary.

Private TCP allocations use qualified tool, service, or scheduled-job ownership and required, on-demand, or allocated semantics. `rig show` and qualified `rig explain` expose their intent; `rig status` and `rig doctor` perform built-in read-only listener observation on macOS. Ports never enter apply plans or receipts, and Rig never opens, reserves, closes, or kills sockets.

## Consequences

Rig configuration is the sole declaration authority for the selected workstation shape, while native managers retain projection, observation, activation, and retirement mechanics. Deferred execution and machine policy are visible before mutation.

Personal values stay in private Rig configuration, but the portable schema and built-in macOS behaviour belong in tools-rig. A platform concern that cannot yet be expressed remains an explicit manual or external-extension boundary rather than being hidden behind a generic workstation provider.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md)
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md)
- [ADR-RIG-005](ADR-RIG-005-provider-execution-contract.md)
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md)
