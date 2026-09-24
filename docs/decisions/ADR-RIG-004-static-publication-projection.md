---
id: ADR-RIG-004
title: 'Static Publication Projection'
date: 2026-09-22
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, XDR-RIG-001]
---

# ADR-RIG-004: Static Publication Projection

## Context

A public rig should work on a personal subdomain such as `rig.midnight.ninja` or below a site path such as `midnight.ninja/rig`. Hosting systems already own domains, credentials, builds, presentation, caching, deployment, and rollback. Making the remote site authoritative would couple local machine management to network and deployment state. Generating a presentation tree would also make one website design part of Rig's durable contract.

The site that consumes a rig also knows things the workstation does not: where the document will live, what it should be called, and when it should be rebuilt. A workstation's configuration is the wrong place to record them, because the site is the party that changes them.

## Decision

Rig treats a published rig as a derived, versioned data projection of one non-appliable view. Every disclosed declaration and every dependency in its public relationship closure must opt into that view.

`rig export` writes one deterministic `rig.json` artifact without invoking a provider or network operation. The projection contains only the public catalogue meaning needed by a website and identifies its format and schema version. Provider configuration, installation details, managed resources, private ports, local paths, native state, observed state, and unmanaged inventory remain private.

The caller supplies the whole instruction: which view to project, where to write it, and the optional title and canonical URL that describe the document it becomes. Rig holds none of that in configuration, because the consuming site owns it.

Rig does not deploy. A person or a build pipeline takes the exported tree wherever it belongs, using the credentials, transport, and rollback that the receiving system already has.

## Consequences

A person can inspect the generated data before disclosure, and a website can render it without reading private Rig configuration. The same projection can support a subdomain, a sub-page, or another hosting system without adding presentation or hosting dependencies to Rig.

Because the parameters travel with the command, a repository that consumes a rig records its own export in its own pipeline, and the same catalogue can be projected more than once with different titles and URLs without any change to the workstation.

Schema consumers select support by the top-level format version. Presentation, templates, themes, hosting, deployment, and interactive behaviour remain outside Rig.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the private catalogue as authority.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert local configuration.
- [XDR-RIG-001](XDR-RIG-001-executable-provider-boundary.md) — defines the disclosure boundary that separates declarative queries from trusted execution.
