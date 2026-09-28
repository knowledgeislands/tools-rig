---
id: ADR-RIG-008
title: 'Catalogue-Scoped Resource Retirement'
date: 2026-09-28
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, ADR-RIG-006]
---

# ADR-RIG-008: Catalogue-Scoped Resource Retirement

## Context

Rig retired a receipted service or scheduled job whenever the current selection did not contain its provider, kind, and locator. The selection is filtered by the applied profile, so the rule read as "this profile did not ask for it" and acted as "nobody wants it any more".

Those are different statements, and the difference is destructive. Applying a narrow profile unloaded resources declared for other profiles, which had been reconciled, were running, and were never examined by the run that tore them down. A profile that selected no resources at all retired the entire estate and left an empty receipt. That is what happened on 27 September 2026: nine launchd agents were booted out of a user domain, a live agent-coordination service lost three in-flight runs, and two MCP transports went with it. The property lists were still on disk and the declarations were still in the catalogue; only the domain and the receipt had been emptied.

The receipt compounded it. Rig rewrote it from the selection too, so a narrow apply forgot which resources it had materialised. Even without a retirement, the next run could no longer observe those resources as its own, and a genuine catalogue deletion afterwards could never be retired at all.

Profiles were never meant to carry that authority. A profile selects a subset of the catalogue for one run; it is not a statement that the rest of the catalogue is unwanted. Every other declaration kind already respects that: deselecting a tool, skill, setting, Dock layout, or port removes nothing. Services and scheduled jobs were the single exception, and the exception was the one case where the consequence is a process being killed.

## Decision

Retirement follows the catalogue. A receipt row is stale when no resource the catalogue declares for that platform matches its provider, kind, and locator — that is, when the declaration has been deleted or no longer supports the platform. Profile deselection is not retirement work, and an apply never unloads a resource outside its own selection.

The receipt records every resource Rig has materialised on the platform, not merely the ones the current run selected. A successful reconciliation writes its selected rows and carries forward each remaining row the catalogue still declares. Rows for deleted declarations leave the receipt only after their retirement succeeds, because a retirement failure already withholds the receipt replacement.

Both rules rest on locators already being unique across the catalogue, which validation enforces. Matching provider, kind, and locator therefore identifies a declaration unambiguously, whichever profile selects it and whatever identity it carries.

Nothing else moves. Deleting a declaration still retires the resource on the next complete reconciliation. Reusing a locator under a new identity still transfers ownership without retirement. A view still loads no retirement work, a selected-resource failure still withholds every retirement and the receipt, and dry runs still mutate nothing.

## Consequences

An apply can no longer unload work it never looked at. The blast radius of a profile choice is now bounded by that profile, which is what a person reading `rig apply --profile services` expects, and status stops reporting another profile's healthy services as pending retirement.

Rig accepts a weaker guarantee about the receipt in exchange. It now describes the whole managed estate rather than the last selection, so a row can outlive the run that wrote it, and a resource removed from the catalogue survives until some reconciliation of the platform succeeds. That is the right direction to fail in: an orphan is visible, reportable, and retirable, whereas a resource unloaded without being examined is a silent outage.

Deliberately tearing down a resource now requires deleting or narrowing its declaration, which is a reviewable change to the catalogue, rather than running an apply under a narrower profile. That is one more step for a rare intention, and it is the step that leaves evidence.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue as the declaration of a working setup.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes profiles as catalogue subsets.
- [ADR-RIG-006](ADR-RIG-006-declarative-operational-resources.md) — establishes declaration as desired state and the receipt as managed identity.
