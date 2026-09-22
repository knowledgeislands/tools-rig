---
id: ADR-RIG-001
title: Shell-only Runtime
date: 2026-09-22
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-RIG-001]
---

# ADR-RIG-001: Shell-only Runtime

## Context

Rig participates in bootstrapping machines where language runtimes and package managers may not exist yet. It must identify and report missing managers, inspect declarations, and reconcile work when managers are available without first requiring another compiled or interpreted language host.

The installed tool is easier to distribute and diagnose as one executable, while a single large authored source file makes unrelated configuration, provider, and command changes unnecessarily coupled.

## Decision

Rig installs one Bash 3.2-compatible executable with no runtime dependency beyond Bash. Maintainers author that executable as ordered, domain-focused Bash modules and assemble `bin/rig` deterministically; the committed executable remains the release and installation payload. Managed systems, publishers, and optional extension commands are dependencies activated only when a selected profile or publication uses them. Development checks such as ShellCheck, Bats, and mandoc are not installed-runtime dependencies.

## Consequences

Rig can run on a macOS or Linux machine where Bash is available. The implementation avoids associative arrays and newer Bash-only features. Module assembly adds a development integrity gate but no installed dependency or loader. Rich optional behaviour may remain external and be invoked through configured provider boundaries instead of pulling a language runtime into the core.

## References

- [PDR-RIG-001](PDR-RIG-001-catalogue-led-working-setup.md) — defines providers as independent native authorities beneath the catalogue.
