---
id: RIG-CORE-016
title: Declare private ports
area: CORE
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 5e5e2a574516aac249d9824cdfe5f1e1b3e7499a
created_at: 2026-09-21T17:54:55Z
updated_at: 2026-09-22T01:35:43Z
---

## Goal

Rig should declare the stable private port allocations and listener expectations that belong to a selected machine setup, explain what owns each one, and compare them with observed listeners without disclosing them through public Rig data.

## Context

The current workstation has several loopback-only development and user services with stable-looking ports: apps-observatory on TCP 1675, the MCP proxy on TCP 3333, and Headroom on TCP 8787. It also has dynamic application listeners and normal macOS listeners that are useful as local observations but are not necessarily durable Rig declarations.

Port intent is presently implicit in service arguments, project commands, or personal knowledge. Rig cannot answer which ports have been allocated, whether a required listener is absent, whether an on-demand allocation has been occupied by something else, or whether a listener expected to remain loopback-only has become reachable on broader interfaces.

## Boundary

This work does not make Rig a firewall, reverse proxy, socket activator, or arbitrary process manager. It does not open, close, reserve, or kill listeners. Service and tool owners retain their native lifecycle. Ephemeral application and operating-system listeners do not all become declarations merely because they are observable.

Port declarations, observations, process details, bind addresses, and unmanaged-listener inventory remain private machine information and must never enter the public Rig projection.

## Current state

Rig has no port declaration, profile membership, listener observation, query, health, or unmanaged-listener model. Stable port intent remains implicit in service arguments and personal knowledge. The initial design questions are recorded below but have not been resolved into accepted behaviour.

## Steps

- [x] Decide the human term, declaration shape, required versus on-demand semantics, owner relationship, state mapping, and publication exclusion.
- [x] Record durable rationale and accepted behaviour in the owning Decision Records and Specifications.
- [x] Extend schema, profile resolution, queries, status, doctor, and built-in read-only listener observation.
- [x] Add deterministic fixtures for loopback, all-interface, absent, conflicting, unavailable, and unmanaged listeners without opening real sockets during tests.
- [x] Align help, manual, completion, changelog, README, user guides, and the private-config migration contract.

## Files touched

Expected scope includes `bin/rig`, `tests/`, `docs/decisions/`, `docs/specs/`, `docs/guides/`, `man/rig.1`, `README.md`, and `CHANGELOG.md`. Personal declarations remain a separate migration outcome.

## Verify

Run the complete repository gate, exercise every declared listener state through isolated command fakes, prove declaration queries and dry runs do not inspect or mutate sockets unexpectedly, and prove every publication form excludes port data.

## Dependencies / blocks

No existing delivery record is a build prerequisite. Planning must settle the open authority and observation questions before this item can become Ready. Personal port declarations follow only after the portable contract lands.

## Documentation impact

### Decision Records

Amend the product, operational-resource, and trust-boundary decisions if ports become first-class private declarations.

### Specifications

Add configuration, query, state, orchestration, portability, and publication-exclusion requirements with test evidence.

### Guides

Teach when to declare a stable port, how required and on-demand expectations differ, how bind-scope findings should be interpreted, and why dynamic listeners usually remain unmanaged inventory.

### Roadmap

The personal-config migration remains separate from this portable implementation item.

## Review

### Delivered

Delivered the approved private-port boundary from immutable baseline `5e5e2a574516aac249d9824cdfe5f1e1b3e7499a`. Rig now models selected observation-only `[port.ID]` declarations without turning ports into managed resources, apply work, receipts, or public data. Personal port declarations and dotfiles migration remain excluded for `RIG-MIG-007`.

### Summary of changes

- Added schema-1 TCP declarations with numeric range, exact bind scope, required, on-demand, and allocated modes, qualified tool, service, or scheduled-job owners, item-owned profile membership, central-profile compatibility, and selected-port conflict detection.
- Added cached read-only macOS `lsof -F` observation, least-safe scope aggregation, owner comparison, status and doctor findings, and informational unmanaged-listener inventory with unavailable fallback on unsupported or failed observation.
- Added inert show and qualified explain output, distinct mode semantics, and categorical exclusion from apply plans, reconciliation receipts, and every public projection.
- Added deterministic command fakes that never open real sockets and aligned Decision Records, Specifications, guides, README, manual, help, completions, changelog, and diagnostics.

### Verification

- `ki repo audit --repo .` — PASS, 16 selected skills.
- `shellcheck bin/rig install.sh` — PASS.
- `bats tests/` — PASS, 205 tests.
- `mandoc -T lint man/rig.1` — PASS.
- `rumdl check README.md CHANGELOG.md docs/decisions/ docs/specs/ docs/guides/ docs/roadmap/RIG-CORE-016-declare-private-ports.md` — PASS, 33 files.
- `git diff --check` — PASS.

### Outstanding concerns

None within the approved portable boundary. Linux listener observation and personal declaration migration remain explicit future work rather than hidden partial support.

### Post-change review

The delivered model answers which stable ports are allocated, who owns them, whether they should be continuously present, and whether their observed scope or occupant conflicts with intent. Ports remain separate from materialised operational resources, so apply and receipt authority did not expand. The cached observation and fail-closed unknown or unavailable outcomes avoid false absence or ownership claims, while the fixed publication allow-list preserves the private-information boundary. The item is ready for human acceptance.

### Mini recap

Rig gained a human-readable private TCP declaration, profile-aware inert queries, one bounded macOS observation source, state and doctor synthesis, and optional unmanaged listener discovery. Verification covers the complete accepted behavior without real sockets. Durable learning landed in the existing product, configuration, publication, and operational-resource Decision Records; configuration, query, state, orchestration, and publication Specifications; and the user resource guide. Personal values route to `RIG-MIG-007` after acceptance.

## Discussion

### Locked declaration model

The public configuration term is `[port.ID]`. A declaration names `protocol`, numeric `port`, expected `scope`, `mode`, and an owning tool or managed resource; it follows item-centric profile membership. The first version supports TCP with normalized `loopback` and `all-interfaces` scopes and `required`, `on-demand`, and `allocated` modes. Ownership matching uses bounded observable process evidence when available but never treats an inaccessible command line as proof of drift.

`required` absence is missing, an unexpected occupant is conflicting, and broader-than-declared exposure is drifted. `on-demand` and `allocated` absence is healthy; an occupant is reported with the safest available ownership evidence. Unsupported or inaccessible observation is unavailable rather than healthy. Rig observes only: it never opens, reserves, closes, or kills a socket. Port declarations and all listener evidence are excluded from every public projection.

The exploratory observations below are retained as rationale; the declaration model above resolves their open choices for implementation.

### Declarative resource

A first version should consider a first-class private resource with a human-facing identity such as `[port.mcporter-http]`. Its intent would include a name, purpose, rationale, protocol, port number, expected bind scope, platforms, an optional tool or service owner, and whether the listener is required continuously or used on demand.

Profiles should select these declarations. `rig show` should summarise them, qualified explanation should retain complete intent, and `rig status` and `rig doctor` should compare that intent with a built-in read-only listener observation. `rig apply` must not pretend that declaring a port can materialise a socket; a related service remains responsible for doing so.

### State interpretation

For a required listener, absence is a finding. A listener on the declared port but broader network scope is drift and potentially a security finding. A different occupant is a conflict. Failure to inspect native listeners remains unavailable or unknown through Rig's existing state vocabulary.

An on-demand allocation needs different semantics: absence is healthy, while an occupant should be reported with enough local detail to decide whether it is the intended owner. The exact owner-matching evidence needs design because process names and command lines can be unstable or inaccessible.

### Initial declarations

TCP 3333 is the clearest initial candidate because it belongs to the declared `mcporter-http-bridge` service and should remain loopback-only. TCP 8787 may belong to the Headroom tool or a future declared service. TCP 1675 appears to be an on-demand project listener rather than a continuously managed service.

Dynamic listeners from Zed, Warp, RendApp, GitHub Desktop, Linear, and OneDrive are better initial candidates for optional unmanaged inventory. Normal Control Centre and `rapportd` listeners should remain informational unless the owner deliberately adopts a local policy for them.

### Naming and observation questions

The design must decide whether the public configuration term should be `port`, which is immediately understandable, or `endpoint`, which can represent protocol and scope more naturally. It must also define a stable distinction between required, on-demand, and purely allocated intent; whether owner references are mandatory; and how macOS and later Linux observations normalize IPv4, IPv6, loopback, and all-interface bindings.
