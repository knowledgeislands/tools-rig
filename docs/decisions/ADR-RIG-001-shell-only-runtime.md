---
id: ADR-RIG-001
title: 'Shell-only Runtime'
date: 2026-09-15
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001]
---

# ADR-RIG-001: Shell-only Runtime

## Context

Rig participates in bootstrapping machines where language runtimes and package managers may not exist yet. The current dispatcher is Bash, while one subordinate machine-audit implementation requires Bun. A compiled or interpreted language host would add an installation prerequisite at the point Rig is intended to establish prerequisites.

## Decision

The Rig core is implemented as a Bash 3.2-compatible executable and has no runtime dependency beyond Bash. Managed systems and optional extension commands are target dependencies activated only when a selected profile uses them. Development checks such as ShellCheck, Bats, and mandoc are not installed-runtime dependencies.

## Consequences

Rig can run on a fresh macOS or Linux machine with Bash available. The implementation avoids associative arrays and newer Bash-only features. Rich optional behaviour may remain external and be invoked through configured target boundaries instead of pulling its language runtime into the core.

## References

- [PDR-RIG-001](PDR-RIG-001-manager-of-managers.md) — defines targets as independent native authorities.
