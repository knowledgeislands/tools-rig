---
id: RIG-CLI-003
area: CLI
title: Export public rig
theme: cli
horizon: triage
status: draft
blocks: [RIG-DIST-002]
blocked_by: [RIG-CORE-003]
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-CLI-003: Export public rig

## Goal

Rig can generate a deterministic static representation of an explicitly selected public profile for a personal website.

## Context

A publishable rig lets someone explain their working setup at an address such as `rig.midnight.ninja` or `midnight.ninja/rig` while retaining the local catalogue as the source of truth.

## Boundary

This item generates a local static artifact. It does not deploy hosting, publish private profiles, expose provider configuration or machine state, or make a network request.

## Discussion

### Disclosure model

Publication is opt-in at the profile and publication declaration. The export includes only public catalogue fields and relationships whose endpoints are also public.

### Portable location

Generated links honour a configured base URL so the same projection works at a domain root, subdomain, or subpath.
