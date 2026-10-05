---
id: GDR-RIG-001
title: 'Adopting Decision Records'
date: 2026-09-20
status: current
decision_type: governance
decision_type_url: https://knowledgeislands.info/specifications/decision-records/gdr
---

# GDR-RIG-001: Adopting Decision Records

## Context

Rig coordinates independently evolving package and configuration systems. Its product boundary, runtime constraints, configuration trust model, and architectural choices need compact records that remain readable without implementation detail.

Code, tests and practical guides express behaviour and procedures, but do not explain the forces behind an architectural boundary. Commit history preserves implementation changes rather than one readable statement of the current decision. Rig's users and maintainers encounter these concerns at different levels of detail.

## Decision

Rig adopts Decision Records under `docs/decisions/`. This collection follows the shared Knowledge Islands Decision Records standard and indexes records in deliberate reveal order.

Rig records an independent, durable choice in the type that describes its subject: product intent, architecture, security or governance. Maintainers first identify the existing record that owns a concern and amend that living record when a change refines the same choice. They create a separate record only for an independently meaningful decision. Each record states its context, active decision and consequences without depending on a linked procedure or implementation file.

## Consequences

Significant product, architecture, security, operations, and governance choices are written as living records. Behavioural obligations remain in Specifications, practical instructions remain in Guides, and delivery sequencing remains in roadmap records.

The index lets a reader encounter the product model before its dependent runtime and provider decisions. Git retains earlier revisions; the current collection describes the present system rather than a historical sequence. Routine fixes need no new record unless they change a durable choice.
