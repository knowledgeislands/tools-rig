---
id: ADR-RIG-006
title: 'Declarative Operational Resources'
date: 2026-09-22
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, ADR-RIG-005, XDR-RIG-001]
---

# ADR-RIG-006: Declarative Operational Resources

## Context

Services, scheduled jobs, stable machine settings, and semantic workstation layouts are part of a person's selected setup. Hiding them in provider-local registries prevents Rig from explaining, observing, previewing, or reconciling a complete profile. Treating a whole workstation as one provider creates the same problem: aggregation belongs to the profile, while each native manager owns only its domain.

Long-lived resources also need a safe response to deselection. Once a declaration leaves the resolved profile, the native manager still needs enough former identity to retire it without turning Rig's state into a competing configuration source.

## Decision

Rig models services, scheduled jobs, typed machine settings, and semantic layouts as first-class managed resources. They use the same profile membership and dependency model as catalogue tools, while retaining explicit native ownership. A complete profile therefore describes the workstation shape that Rig can explain and reconcile.

Built-in resource adapters own supported native operations. External resource providers remain possible only through the explicit executable boundary. Rig performs complete-plan preflight, orders resource dependencies, and keeps minimal per-platform reconciliation receipts solely for safe deselection and retirement. The declaration remains the source of desired state; native providers remain the source of observation.

Private TCP ports are related operational declarations, but are observation-only. They describe an expected number, bind scope, mode, and qualified owner. Rig may compare that intent with listeners; it never opens, reserves, closes, kills, or publishes a socket.

Detailed resource fields, supported providers, state vocabulary, application rules, and receipt semantics belong to the Specifications.

## Consequences

Rig configuration is the declaration authority for the selected workstation shape, while native systems retain projection, activation, observation, and retirement mechanics. Resource intent remains visible before mutation and can be explained alongside the tools it supports.

Personal values stay in private configuration. Portable resource schema and built-in behaviour belong in Rig. A platform concern not represented by a bounded resource type remains outside Rig or crosses the explicit extension boundary; it does not become a generic workstation script.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue and profile model.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert declarations.
- [ADR-RIG-005](ADR-RIG-005-provider-execution-contract.md) — establishes orchestration and provider ownership.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — defines external execution boundaries.
