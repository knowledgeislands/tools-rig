---
id: PDR-RIG-001
title: 'Manager of Managers'
date: 2026-09-15
status: current
decision_type: product
decision_type_url: https://knowledgeislands.info/specifications/decision-records/pdr
decision_depends_on: [GDR-RIG-001]
---

# PDR-RIG-001: Manager of Managers

## Context

Machine bootstrap spans package managers, language-tool managers, configuration managers, and user-defined commands. Homebrew, uv, and chezmoi already own mature native semantics and state. A second package database or resolver would duplicate those authorities and reduce interoperability.

## Decision

Rig is a configurable manager of targets. It owns profiles, target selection, dependency ordering, action dispatch, and outcome reporting. Each target owns its native manifest, package resolution, execution semantics, and state. Homebrew, uv, chezmoi, and explicitly configured executables are initial target classes rather than dependencies of Rig itself.

## Consequences

Users can compose a bootstrap profile without abandoning native tooling. Target capabilities may differ, so Rig must expose supported actions honestly instead of forcing every target into one universal lifecycle. Cross-target intent belongs in Rig configuration; target-specific detail stays native wherever practical.

## References

- [GDR-RIG-001](GDR-RIG-001-adopting-decision-records.md) — establishes this decision collection.
