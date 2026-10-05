---
id: ADR-RIG-007
title: 'Resolved Artifact Link Evidence'
date: 2026-10-05
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, ADR-RIG-006]
---

# ADR-RIG-007: Resolved Artifact Link Evidence

## Context

Applications can install their command-line executable as a symbolic link from a shared executable directory into an application bundle. The declaration names the expected artifact, while the filesystem supplies its current target. Refusing all symbolic links makes that legitimate installed state unavailable to observation.

A link may be absent, dangling after an upgrade, cyclic, or pointed at an unsuitable target. A declaration of expectation allows Rig to distinguish those cases from a healthy installed artifact; an inventory of existing files alone cannot establish whether an expected command was never installed.

Both direct paths and symbolic links can change between observations. Their evidence describes the filesystem at the time of the read rather than a permanent installation guarantee.

## Decision

Rig observes a declared artifact symbolic link through its resolved target. Resolution follows at most 40 leaf links using native `readlink`, resolves relative targets against each link's own directory, and reports exhausted bounds, cycles or failed resolution as `unavailable` with an explanatory detail.

Resolution is not constrained to a particular root: the declaration explicitly trusts the expected artifact path, including application bundles outside a shared executable directory. The resolved target independently satisfies the same health checks as a directly declared artifact before it can be `present`. An absent target is `missing`, a damaged application is `drifted`, and an unsupported target type is `unavailable`; indirection never manufactures a healthy answer.

When Rig follows a link, its observation detail identifies the resolved target beside the declared path. Rig does not create, repair or repoint the link. Only leaf links receive this explicit resolution; intermediate directory components are resolved by the operating system as for a direct path.

## Consequences

Application-owned command links can be declared and assessed without treating ordinary installation indirection as a safety failure. Missing commands and dangling links become actionable observations rather than unexplained refusal.

A `present` result states that the declared path resolved to a healthy artifact when read. It cannot guarantee that a link remains unchanged afterward. Reporting both expectation and target makes the scope of that evidence reviewable, while keeping observation read-only and desired state in the catalogue.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue as the declaration of a working setup.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert declarations.
- [ADR-RIG-006](ADR-RIG-006-declarative-operational-resources.md) — establishes declaration as desired state and native observation as evidence.
