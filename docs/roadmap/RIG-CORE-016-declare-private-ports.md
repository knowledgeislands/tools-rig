---
id: RIG-CORE-016
title: Declare private ports
area: CORE
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T17:54:55Z
updated_at: 2026-09-21T17:54:55Z
---

## Goal

Rig should declare the stable private port allocations and listener expectations that belong to a selected machine setup, explain what owns each one, and compare them with observed listeners without disclosing them through public Rig data.

## Context

The current workstation has several loopback-only development and user services with stable-looking ports: apps-observatory on TCP 1675, the MCP proxy on TCP 3333, and Headroom on TCP 8787. It also has dynamic application listeners and normal macOS listeners that are useful as local observations but are not necessarily durable Rig declarations.

Port intent is presently implicit in service arguments, project commands, or personal knowledge. Rig cannot answer which ports have been allocated, whether a required listener is absent, whether an on-demand allocation has been occupied by something else, or whether a listener expected to remain loopback-only has become reachable on broader interfaces.

## Boundary

This work does not make Rig a firewall, reverse proxy, socket activator, or arbitrary process manager. It does not open, close, reserve, or kill listeners. Service and tool owners retain their native lifecycle. Ephemeral application and operating-system listeners do not all become declarations merely because they are observable.

Port declarations, observations, process details, bind addresses, and unmanaged-listener inventory remain private machine information and must never enter the public Rig projection.

## Discussion

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
