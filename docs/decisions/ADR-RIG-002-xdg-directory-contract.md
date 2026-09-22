---
id: ADR-RIG-002
title: 'XDG Directory Contract'
date: 2026-09-22
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [ADR-RIG-001]
---

# ADR-RIG-002: XDG Directory Contract

## Context

Rig needs predictable locations for configuration, reusable data, operational state, and disposable cache content. Ad hoc files directly beneath a user's home directory would conflict with an XDG-aligned workstation and make backup, migration, and cleanup boundaries unclear.

Executables and manual pages need installation locations as well, but the XDG Base Directory specification does not define an executable directory.

## Decision

Rig separates its persistent surfaces using the XDG Base Directory model. Configuration belongs beneath `${XDG_CONFIG_HOME:-$HOME/.config}/rig`, reusable data beneath `${XDG_DATA_HOME:-$HOME/.local/share}/rig`, operational state beneath `${XDG_STATE_HOME:-$HOME/.local/state}/rig`, and disposable cache content beneath `${XDG_CACHE_HOME:-$HOME/.cache}/rig`.

`RIG_CONFIG_HOME`, `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME` override the complete application directory for their respective surfaces. Installation defaults to `~/.local/bin` and allows an explicit installation-directory override. The exact owned paths and environment variables belong to the Specifications and manual.

## Consequences

Configuration, durable data, operational evidence, and disposable cache retain distinct backup and cleanup semantics. Tests can isolate each surface through environment overrides. Provider implementations and lifecycle commands must not introduce undeclared home-directory files.

The installer cannot derive an executable destination from XDG alone, so its `~/.local/bin` default remains a deliberate convention rather than an XDG claim.

## References

- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — establishes the portable core constraint.
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) — defines the base-directory model.
