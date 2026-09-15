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

A public rig should be usable at a personal subdomain such as `rig.midnight.ninja` or beneath a site path such as `midnight.ninja/rig`. Hosting systems already own domain configuration, credentials, uploads, builds, caching, and rollback. Making a remote site the catalogue authority would couple local machine management to network availability and deployment state.

Generating and deploying a site also have different trust and portability properties. Rendering can be deterministic and offline, while deployment necessarily invokes a trusted external system.

## Decision

Rig treats a published rig as a derived static projection of one explicitly configured public profile. `rig export` generates the projection into a local output directory without invoking providers, publishers, or the network. The publication declaration supplies a base URL so generated navigation works at a domain root, subdomain, or subpath.

`rig publish` is a separate explicit operation that invokes the publication's configured trusted publisher. The publisher owns deployment, credentials, destination state, and rollback. Rig owns selection of the public profile, generation of the bounded artifact, publisher dispatch, and outcome reporting.

The local catalogue remains canonical. Rebuilding the same schema version, resolved public profile, and publication configuration produces equivalent content independent of the hosting service.

## Consequences

A person can host their rig using a personal server, Cloudflare Pages, GitHub Pages, or another static destination without adding a hosting dependency to Rig core. Exported artifacts can be inspected before any disclosure occurs and can be tested without network access.

Interactive or server-side features are outside the initial publication contract. Hosting-specific setup remains in the selected publisher or external site configuration rather than entering the catalogue schema.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — defines the published rig as a derived public view.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — defines publication declarations.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — defines disclosure and publisher trust boundaries.
