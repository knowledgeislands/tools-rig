---
id: ADR-RIG-004
title: 'Static Publication Projection'
date: 2026-09-15
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, XDR-RIG-001]
---

# ADR-RIG-004: Static Publication Projection

## Context

A public rig should be usable at a personal subdomain such as `rig.midnight.ninja` or beneath a site path such as `midnight.ninja/rig`. Hosting systems already own domain configuration, credentials, builds, presentation, caching, deployment, and rollback. Making a remote site the catalogue authority would couple local machine management to network availability and deployment state.

Generating an HTML and CSS tree would make one presentation part of Rig's durable contract. A receiving website can make better use of reviewed catalogue data while retaining its own navigation, accessibility, and visual conventions.

## Decision

Rig treats a published rig as a derived, versioned data projection of one explicitly configured non-appliable view. Every disclosed declaration opts into that view. A view cannot inherit a complete profile, and each dependency in its resolved relationship closure must also opt in explicitly. `rig export` generates exactly one `rig.json` file in a complete local output tree without invoking providers, publishers, or the network.

The projection is platform-neutral: profile membership records public intent, while each tool retains its declared supported platforms. It has top-level format identity `rig-publication`, integer schema version `1`, publication metadata, profile identity, selected categories, and selected tools with public catalogue metadata and closed relationships. The publication's configured `base-url` is projected as `canonical_url` metadata.

`rig publish` remains a separate explicit operation that invokes the publication's configured trusted publisher. The publisher and receiving website own rendering, credentials, hosting destination, deployment, and rollback. Rig owns deterministic selection, schema serialization, bounded artifact generation, trusted dispatch, and outcome reporting.

The local catalogue remains canonical. A published file is never authority for private configuration or observed machine state. Rebuilding from the same schema version, resolved public profile, and publication configuration produces byte-equivalent data regardless of declaration order or publishing host platform.

Port declarations, port numbers, qualified owners, listener observations, and unmanaged listener inventory are categorically private. They never enter a public projection, even when a port is assigned to the publication view.

## Consequences

A person can inspect or validate `rig.json` before disclosure, and a website can render it without reading private Rig configuration. The same artifact can support a personal server, Cloudflare, GitHub, or another site without adding a hosting or presentation dependency to Rig core.

Schema consumers must select support by the top-level format and version. Presentation previews, templates, themes, and interactive or server-side features remain outside Rig. Hosting-specific setup remains in the selected publisher or external site configuration rather than entering the catalogue schema.

## Related decisions

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md)
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md)
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md)
