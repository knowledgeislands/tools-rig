---
id: ADR-RIG-005
title: 'Provider Execution Contract'
date: 2026-09-22
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, XDR-RIG-001]
---

# ADR-RIG-005: Provider Execution Contract

## Context

Rig resolves profiles into tools, skills, and managed resources, then asks native systems to observe or materialise that intent. Built-in managers and external extensions need one public state model without turning Rig into a competing package database. External executables also cross the trust boundary established by XDR-RIG-001.

Provider work must preserve native argument boundaries, distinguish observation from mutation, disclose the breadth of consequential operations, and fail predictably. Ordinary users should not have to configure Rig's internal adapter registry or invocation protocol.

## Decision

Rig owns orchestration; providers own their native domains. Rig resolves a complete profile, validates the full plan, detects conflicting native targets, orders dependencies, selects supported operations, reports progress and outcomes, and isolates failures from independent work. Tools run before user-level skills, and managed resources run after the tools or resources on which they depend.

Rig contains a fixed registry for built-in providers and supported lifecycle operations. Ordinary configuration names a stable provider identity and any bounded native policy, but cannot grant capabilities or supply arbitrary lifecycle commands. Bootstrap, apply, update, maintenance, manifest capture, and cache cleanup are native Rig lifecycles rather than generic task-runner entries.

An external provider is an explicitly trusted executable with an operation allow-list. Rig invokes it through a versioned, argument-safe protocol; built-in providers do not use that protocol. Providers return bounded observations to Rig's public state vocabulary, while their native output and state remain provider-owned.

Rig keeps only minimal reconciliation evidence where a long-lived resource needs safe retirement. It does not persist a parallel database of observed installation state. Receipt-backed reconciliation is serialised per platform target and replaces evidence atomically only after successful resource work.

The exact operation matrix, extension ABI, lifecycle ordering, progress contract, and failure outcomes belong to the Specifications.

## Consequences

People declare intent and ownership rather than adapter mechanics. Built-in integrations can provide typed validation and useful diagnostics while remaining compatible with Bash 3.2. Extension authors receive a small language-neutral boundary, but must opt into each operation and handle their own native semantics.

Provider-wide work remains visible before execution. Profile deselection does not imply package or generated-artifact removal unless a resource type has an explicit, receipt-backed retirement contract.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the manager-of-managers product boundary.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — keeps ordinary configuration declarative.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — establishes executable trust transitions.
