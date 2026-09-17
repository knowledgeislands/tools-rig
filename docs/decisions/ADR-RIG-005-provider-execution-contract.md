---
id: ADR-RIG-005
title: 'Provider Execution Contract'
date: 2026-09-16
updated: 2026-09-17
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, XDR-RIG-001]
---

# ADR-RIG-005: Provider Execution Contract

## Context

Rig resolves a profile to tools and compatible provider bindings, but declarative resolution alone cannot compare that selection with a machine or materialise it. Built-in adapters and custom executables need one state model and orchestration boundary without making Rig a competing package database. Schema 1 describes tool dependencies but no provider dependency graph, so execution order must follow resolved tool relationships.

Custom providers cross the executable trust boundary established by XDR-RIG-001. Their invocation must preserve literal argument boundaries, distinguish observation from mutation, keep public output deterministic, and expose native failures without allowing an arbitrary provider exit code to become Rig's command contract. Catalogue-only tools also remain valid declarations even though no provider can observe or materialise them.

## Decision

Rig builds one work unit for each selected tool with a compatible binding. It orders work dependency-first by `tool.requires`, using bytewise tool identity to break ties. A failed work unit suppresses only its transitive dependants; independent work continues. Catalogue-only tools have no work unit.

The initial execution engine supports only `adapter = custom`. It invokes a custom provider using this versioned argument protocol:

```text
EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER TOOL KIND LOCATOR [BINDING_ARGUMENT ...]
```

`VERB` is exactly `observe` or `apply` in the per-tool protocol. Every configured value occupies one literal argument boundary. Rig performs no shell evaluation, implicit word splitting, environment-variable protocol, or automatic interpretation of provider `command` and `manifest`. Capability values are atomic literals: a provider must declare exact `observe` or `apply` values.

An `observe` invocation reserves stdout for exactly one state token: `present`, `missing`, `drifted`, `unavailable`, or `unknown`. Provider stderr remains diagnostic output. Invalid output or a non-zero native exit produces public state `unknown`; Rig records `invalid-response` or `exit:N` as detail. An `apply` invocation's stdout and stderr are provider diagnostics routed to Rig's stderr. Rig records `completed` for exit zero and `failed` with `exit:N` otherwise.

Reverse reconciliation uses a separate fixed protocol, as publication already does, because it enumerates a provider's whole domain rather than observing one declaration:

```text
EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 inventory PROVIDER
```

A provider declaring the exact `inventory` capability returns zero or more stdout lines, each beginning with an identity comparable to a binding `locator`, optionally followed by a space and opaque provider detail. Inventory is an observation and must not mutate. A non-zero native exit yields state `unknown` with detail `exit:N`; a non-custom adapter or unresolvable executable yields `unavailable`. Rig, not the provider, performs the comparison: it reports every returned identity that no binding declares. A binding declares an identity through its `locator`, matched only within that binding's own provider namespace because identity spaces collide across providers, or through a repeatable `artifact` value naming a machine-observable path the declaration materialises, matched irrespective of which provider observed it. Artifacts let one provider inventory what another provider installed, which a per-tool binding cannot express because a tool resolves to exactly one compatible binding per platform.

`rig status [--profile NAME]` reports selected tools in stable dependency order with `TOOL`, `PROVIDER`, `STATE`, and `DETAIL` columns. A catalogue-only tool reports provider `-`, state `unavailable`, and detail `catalogue-only`; this is informational rather than unhealthy. A bound missing, drifted, unavailable, or unknown tool makes the result unhealthy.

`rig status --unmanaged` additionally invokes every provider declaring `inventory` and appends an `IDENTITY`, `PROVIDER`, `STATE`, `DETAIL` table of observed identities that no binding declares, followed by an `Unmanaged:` count. Unmanaged rows are informational and never make the result unhealthy: undeclared software is a fact about the machine to review, not a failure of the declared profile, and treating it as failure would make a first run permanently red. Without the flag, status behaviour is unchanged.

`rig apply [--profile NAME] [--dry-run]` preflights every selected bound work unit before the first mutation. Preflight requires the custom adapter, exact `apply` capability, and a resolvable executable. Dry-run performs the same preflight, prints `planned` work in execution order, and invokes no provider. Normal application reports `completed`, `failed`, or `skipped`; catalogue-only tools are neutral skipped rows, while dependency-suppressed rows identify `blocked-by:TOOL`.

Rig owns deterministic stdout and fixed-order summaries. Command status `0` means a valid healthy observation or successful application, including neutral catalogue-only rows; `1` means a valid comparison or execution found drift, unavailability, an unknown result, a native failure, or dependency suppression; `2` means syntax, configuration, resolution, or preflight failure. Rig does not persist observed state.

Built-in Homebrew, uv, chezmoi, and direct-download adapters may group native work internally later, but they must preserve this public state, ordering, preflight, and outcome contract. Unsupported adapters remain safe for catalogue queries, report unavailable during status, and fail apply preflight before mutation.

Catalogue-led description is therefore bidirectional: `status` answers whether declared tools are present, and `status --unmanaged` answers whether present software was declared. Neither direction makes Rig a package database, because Rig persists no observed state in either.

## Consequences

Provider authors receive a small versioned protocol that works in any implementation language while Rig remains Bash 3.2-compatible. Users receive stable state and outcome reporting independent of provider-native output. Full-plan preflight prevents a late declarative or environment error from causing partial mutation, while runtime failures remain visible and do not block independent work.

Per-tool invocation may be less efficient than a provider-native batch operation. Built-in adapters can optimise behind the same public contract, but schema 1 does not imply a provider graph or automatic manifest semantics. Catalogue-only tools remain first-class descriptive declarations without making every status or apply command fail.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue-led product model.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — defines the inert schema used by providers and bindings.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — establishes the executable trust transition and explicit mutation boundary.
