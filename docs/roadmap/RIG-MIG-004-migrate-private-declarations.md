---
id: RIG-MIG-004
area: MIG
title: Migrate private declarations
theme: migration
horizon: triage
status: draft
blocks: [RIG-MIG-001, RIG-MIG-002, RIG-MIG-003]
blocked_by: [RIG-CLI-001, RIG-CLI-002]
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-MIG-004: Migrate private declarations

## Goal

The personal catalogue, profiles, and provider bindings move into private Rig configuration managed by the dotfiles repository without exposing workstation choices in tools-rig.

## Context

The live `.chezmoidata/software.yaml` contains 89 applications across 12 categories with purposes and acquisition sources. Bootstrap scripts, Brewfile, macOS data, and service declarations add provider and host policy that must be classified rather than copied wholesale.

## Boundary

This item changes chezmoi sources only after the public parser, query, and provider contracts exist. It does not delete or replace the live Rig command, apply chezmoi changes without review, or move private package lists and machine paths into tools-rig.

## Discussion

### Data migration

Application names, categories, purposes, personal rationale, platforms, relationships, profiles, and provider bindings become private declarative Rig data. Native manifests remain native provider inputs.

### Host-local operations

The Bun/macOS audit and launchd service operations remain private executable providers or compatibility commands. Their current safety tests remain until equivalent replacement coverage exists.

### Chezmoi review

All private configuration changes are made in chezmoi sources, followed by `chezmoi diff`; applying them remains a separate explicitly approved action.
