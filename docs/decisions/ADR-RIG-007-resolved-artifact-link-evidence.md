---
id: ADR-RIG-007
title: 'Resolved Artifact Link Evidence'
date: 2026-09-23
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001, ADR-RIG-003, ADR-RIG-006]
---

# ADR-RIG-007: Resolved Artifact Link Evidence

## Context

Artifact observation refused a symbolic link outright, reporting `unavailable` with the detail `unsafe` ahead of every other test. The reasoning was that a link can be repointed, so the link is not evidence of what is installed.

The cost of that refusal is an entire class of real installed state that cannot be declared. Applications install their command line as a link from a shared executable directory into their own bundle — `code`, `subl`, `gitup` and their peers. Declaring one did not track it; it reported the owning tool as `unavailable`, so a healthy machine acquired findings for state that was perfectly correct, and the surface stayed unmanaged instead.

The refusal also left the two interesting failures invisible. An upgrade that moves an executable inside its bundle leaves the link dangling, and nothing said so. A command line an application never installed cannot be noticed by any check that enumerates what exists, because only a declaration of expectation can report an absence, and the artifact list is that declaration.

The safety the refusal appeared to buy was not real. Rig already trusts a declared path to be the artifact it names. A link and a path are both names the filesystem resolves; the only difference is that one resolves in two steps.

## Decision

A declared artifact that is a symbolic link is observed through the target it resolves to. Resolution follows at most 40 leaf links with the native `readlink` Rig already uses, resolving a relative target against the link's own directory, and treats an exhausted bound, a cycle, or an absent target as its own failure — `unavailable` with a detail that says resolution failed, never `unsafe`.

Resolution is not constrained to any root. The artifact declaration explicitly names the trusted expectation, so constraining the target would refuse exactly the bundles the declaration was written to describe. The trust boundary sits on the other side instead: the resolved target must independently satisfy every test a directly declared artifact satisfies before it can be `present`. A target that is absent is `missing`; a target that is a damaged application is `drifted`; a target that is neither a regular file nor a directory remains `unavailable`. Resolution can therefore never manufacture a healthy answer.

Because indirection is now observable rather than fatal, it must also be reviewable. Where a link was followed, the reported detail carries the resolved target beside the declared path, so a reader sees both the expectation and the evidence that answered it.

Rig still does not create, repair, or repoint a link. Observation remains read-only, and the declaration remains the only source of desired state.

## Consequences

A class of real installed state becomes declarable. A command line an application installs by link is now `present` on a healthy machine instead of an unexplained `unavailable`, and the five such paths that once took a healthy workstation from four findings to nine can be declared without manufacturing noise. The two failures that mattered become visible: a link left dangling by an upgrade that moved an executable inside its bundle, and a command line an application never installed at all, which no check that enumerates what exists could ever report.

The repository-side check that enumerated a shared executable directory and resolved each link is retired. That compensation belonged in Rig, and a workstation no longer needs local code to answer for a general observation.

Rig accepts a narrower guarantee in exchange. A link can be repointed between observations, so `present` asserts that the declared path resolved to a healthy artifact at the moment it was read, not that the link has always pointed there. That is the same guarantee a direct path already carried, and the detail now names the target, so a reader can see when it changes. Only the leaf link is followed; an intermediate directory component is resolved by the kernel exactly as it is for a direct path.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — establishes the catalogue as the declaration of a working setup.
- [ADR-RIG-003](ADR-RIG-003-declarative-configuration-grammar.md) — establishes inert declarations.
- [ADR-RIG-006](ADR-RIG-006-declarative-operational-resources.md) — establishes declaration as desired state and native observation as evidence.
