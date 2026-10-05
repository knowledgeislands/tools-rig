---
id: ADR-RIG-008
title: 'Catalogue-Scoped Resource Retirement'
date: 2026-10-05
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, ADR-RIG-006]
---

# ADR-RIG-008: Catalogue-Scoped Resource Retirement

## Context

A profile selects a subset of the catalogue for one run. A declaration outside that selection can still describe a desired, running service or scheduled job. Profile absence and catalogue deletion therefore express different intentions.

Managed-resource receipts identify what Rig has materialised. If a receipt describes only the latest selection, a narrow run loses evidence for resources that remain declared elsewhere. The next observation cannot distinguish that still-managed estate from resources Rig never owned.

Services and scheduled jobs have a destructive retirement action: unloading the running resource. Deselection of a tool, skill, setting, Dock layout or port does not remove it. Resource retirement needs an equally explicit ownership boundary.

## Decision

Rig retires a receipted resource only when no declaration in the catalogue for the current platform matches its provider, kind and locator. Deleting a declaration or removing its platform applicability can make that receipt stale; profile deselection cannot. Apply never unloads a resource solely because it is outside the selected profile.

The receipt records the resources Rig has materialised on the platform, not only the current run's selection. A successful reconciliation writes its selected rows and carries forward other rows the catalogue still declares. A deleted declaration's row leaves the receipt only after retirement succeeds. Selected-resource or retirement failures withhold receipt replacement.

Catalogue validation keeps resource locators unique, so the provider, kind and locator identify ownership independently of the declaration's profile membership. Reusing the locator under a different declaration identity transfers ownership without retirement. A view loads no retirement work, and a dry run mutates neither native resources nor receipts.

## Consequences

Choosing a narrower profile bounds the work selected for reconciliation without granting authority to dismantle the rest of the catalogue. Status can retain evidence for healthy services outside that selection instead of reporting them as pending retirement.

Receipts describe the managed estate rather than the last run. A resource removed from the catalogue can remain running until a successful complete reconciliation on its platform retires it. That orphan remains visible and reportable; preserving it after failure is safer than silently unloading an unexamined resource.

Deliberate teardown requires a reviewable catalogue change, not merely a different profile option. The extra declaration edit makes removal intent explicit while preserving safe failure behaviour.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue as the declaration of a working setup.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes profiles as catalogue subsets.
- [ADR-RIG-006](ADR-RIG-006-declarative-operational-resources.md) — establishes declaration as desired state and the receipt as managed identity.
