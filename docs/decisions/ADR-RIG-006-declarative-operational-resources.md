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

Services and scheduled jobs are part of a person's selected working setup, but provider-local registries make Rig unable to explain, observe, preview, or reconcile them. A provider that calls another configuration manager to discover its authority also reverses Rig's manager-of-managers boundary. Scheduled execution raises an additional trust concern: applying configuration authorises code to run later outside the interactive command.

Removing a selected resource creates a reconciliation problem. Once its declaration disappears, a provider still needs the former native locator to retire it safely. Persisting observed native state would make Rig a competing service database, while keeping no application evidence would strand deselected resources.

## Decision

Schema 1 adds first-class `[service.ID]` and `[scheduled-job.ID]` declarations. Profiles select them through `services` and `scheduled-jobs`; resource `requires` fields select tool dependencies. Rig owns identity, purpose, rationale, provider, locator, desired state, literal program arguments, environment, working directory, logs, and execution or scheduling policy. Providers retain native projection, observation, activation, and retirement mechanics.

Rig passes each selected declaration across the existing executable trust boundary as versioned, literal `key=value` arguments. Custom providers declare the separate `resource-observe`, `resource-apply`, and `resource-retire` capabilities. They do not parse Rig TOML or discover an authoritative provider-local registry. Resource-aware generic actions receive one selected qualified resource and its complete declaration before any remaining caller arguments.

Read-only catalogue queries disclose operational declarations without invoking providers. Status and doctor observe them. Apply and bootstrap preflight all selected tool and resource work before mutation; dry-run prints complete deferred-execution data without invoking providers.

Rig stores one application receipt beneath `${RIG_STATE_HOME}/resources/PLATFORM.tsv`. Each line contains only the provider, resource kind, Rig identity, and native locator last managed by a fully successful reconciliation. It is not observed state and cannot recreate a declaration. A later profile resolution compares the selected set with that receipt, applies selected resources first, retires stale locators afterward, and replaces the receipt atomically only after success. Reusing the same provider, kind, and locator transfers receipt ownership during a rename without retiring the live native resource.

## Consequences

- Rig configuration is the sole declaration authority for services and scheduled jobs.
- Deferred execution is visible in `show`, qualified `explain`, status, doctor, and apply dry-run before mutation.
- Providers receive more arguments but remain implementation-language independent and preserve literal boundaries.
- Rig persists minimal successful-application evidence for safe retirement while continuing not to persist provider observations.
- Applying a different profile reconciles operational resources to that profile's exact selected set; bootstrap participates in the same contract.
- Native manifests remain provider-owned projections and may be installed by another manager, but they are not a second declaration registry.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md)
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md)
- [ADR-RIG-005](ADR-RIG-005-provider-execution-contract.md)
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md)
