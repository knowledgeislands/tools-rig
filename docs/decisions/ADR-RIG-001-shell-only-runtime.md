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

Rig participates in bootstrapping machines where language runtimes and package managers may not exist yet. It must be able to identify and report missing managers, inspect declarations, and reconcile work whose managers are available without first requiring a compiled or interpreted language host.

## Decision

The Rig core is implemented as a Bash 3.2-compatible executable with no runtime dependency beyond Bash. Managed systems, publishers, and optional extension commands are provider dependencies activated only when a selected profile or publication uses them. Development checks such as ShellCheck, Bats, and mandoc are not installed-runtime dependencies.

## Consequences

Rig can run on a fresh macOS or Linux machine where Bash is available. The implementation avoids associative arrays and newer Bash-only features. Rich optional behaviour may remain external and be invoked through configured provider boundaries instead of pulling a language runtime into the core.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — defines providers as independent native authorities beneath the catalogue.
