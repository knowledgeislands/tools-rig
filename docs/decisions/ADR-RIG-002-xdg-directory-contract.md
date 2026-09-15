---
id: ADR-RIG-002
title: 'XDG Directory Contract'
date: 2026-09-15
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [ADR-RIG-001]
---

# ADR-RIG-002: XDG Directory Contract

## Context

Rig needs predictable locations for configuration, reusable data, operational state, and disposable cache content. Writing ad hoc files directly beneath a user's home directory would conflict with the workstation's XDG-aligned layout and make backup or cleanup boundaries unclear.

## Decision

Rig uses the XDG Base Directory locations with standard fallbacks: configuration beneath `${XDG_CONFIG_HOME:-$HOME/.config}/rig`, data beneath `${XDG_DATA_HOME:-$HOME/.local/share}/rig`, state beneath `${XDG_STATE_HOME:-$HOME/.local/state}/rig`, and cache beneath `${XDG_CACHE_HOME:-$HOME/.cache}/rig`. `RIG_CONFIG_HOME`, `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME` override the complete application directory. Because XDG defines no executable directory, installation defaults to `~/.local/bin` with `RIG_INSTALL_DIR` as the override.

## Consequences

Configuration, durable state, and disposable cache have separate backup and cleanup semantics. Tests can isolate every persisted surface through environment overrides. Documentation and provider implementations must not introduce undeclared home-directory files.

## References

- [ADR-RIG-001](ADR-RIG-001-shell-only-runtime.md) — establishes the portable core constraint.
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) — defines the base-directory environment contract.
