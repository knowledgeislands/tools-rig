---
id: RIG-MIG-004
area: MIG
title: Migrate private declarations
theme: migration
horizon: now
status: draft
blocks: [RIG-MIG-001, RIG-MIG-002, RIG-MIG-003]
blocked_by: [RIG-CLI-001, RIG-CLI-002]
baseline_ref: null
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-16T17:03:44Z
---

# RIG-MIG-004: Migrate private declarations

## Goal

The personal catalogue, profiles, and provider bindings move into private Rig configuration managed by the dotfiles repository without exposing workstation choices in tools-rig.

## Context

The live `.chezmoidata/software.yaml` contains 88 applications across 12 categories with purposes and acquisition sources. Bootstrap scripts, Brewfile, macOS data, and service declarations add provider and host policy that must be classified rather than copied wholesale.

## Boundary

This item changes chezmoi sources only after the public parser, query, and provider contracts exist. It does not delete or replace the live Rig command, apply chezmoi changes without review, or move private package lists and machine paths into tools-rig.

## Current state

The applied schema-1 projection contains 12 categories, 88 tools, and 85 tools selected by `profile.default`. `.chezmoidata/software.yaml` remains the transitional private authority, and `dot_config/rig/private_rig.conf.tmpl` currently derives catalogue and profile records without provider bindings.

The reviewed provider target is 76 Brew-backed tools—61 casks, 3 formulae, and 12 Mac App Store or native declarations represented through the Brew manifest—and 12 catalogue-only tools. Native resolution and state remain owned by the private Brewfile and provider rather than duplicated in Rig.

## Steps

- [ ] Reconcile all 88 tool identities against the native Brewfile and classify exactly 61 casks, 3 formulae, 12 Mac App Store or native Brew-backed entries, and 12 catalogue-only entries.
- [ ] Extend the generated private template with provider and binding records while keeping `.chezmoidata/software.yaml` the single transitional catalogue authority and the Brewfile the native package authority.
- [ ] Add deterministic render tests for the 12/88/85 catalogue and profile counts, the 76/12 binding partition, unique binding ownership, platform compatibility, and absence of unsupported copied fields.
- [ ] Add the private `workstation` and `launchcontrol` declarations required by RIG-MIG-002 and RIG-MIG-003 only through the accepted generic provider and operation schema.
- [ ] Exercise `rig show`, `list`, `explain`, `status`, `doctor`, dry-run apply, and declared-operation validation against the rendered target without invoking mutation.
- [ ] Run `chezmoi diff` for exact source targets and stop before `chezmoi apply` unless the user separately approves it.

## Files touched

Expected private scope is `.chezmoidata/software.yaml`, `dot_config/rig/private_rig.conf.tmpl`, `dot_config/private_homebrew/Brewfile`, and focused catalogue or provider projection tests. Personal data does not enter tools-rig; public parser, adapter, or fixture changes remain with their owning CORE or CLI records.

## Verify

Render twice and compare bytes, then assert 12 categories, 88 tools, 85 default selections, 76 Brew-backed bindings split 61/3/12, and 12 catalogue-only tools. Validate the generated target with the standalone CLI, prove read-only queries and observations do not mutate providers, run the full dotfiles Node suite and relevant tools-rig Bats coverage, and review targeted `chezmoi diff`. Do not run `chezmoi apply` in this item without a separate explicit approval.

## Dependencies / blocks

RIG-CLI-001 must supply the provider adapters and safe execution protocol. The catalogue query contract from RIG-CLI-002 is implemented and provides inspection evidence, but its review remains outside this item. This cross-repository delivery changes only chezmoi sources and blocks RIG-MIG-001 through RIG-MIG-003; no live-home mutation is authorised by moving the roadmap item.

## Delegation

One worker may reconcile the 88-tool classification and another may extend the template and render tests. The coordinator owns source-revision checks, count reconciliation, private/public boundary review, standalone CLI validation, `chezmoi diff`, and the no-apply stop.

## Documentation impact

### Decision Records

No new decision record is expected; the transitional authority and native-manifest boundary follow the accepted configuration and provider decisions.

### Specifications

No personal declarations enter public specifications. Any provider-schema gap discovered by the render must be resolved in the owning public contract before private data depends on it.

### Guides

Update private workstation guidance only when provider-backed status, doctor, apply, and operation examples are executable against the rendered configuration.

### Roadmap

Record count or classification changes in this item and preserve RIG-MIG-001 through RIG-MIG-003 as downstream consumers; live legacy retirement remains RIG-MIG-005.

## Discussion

### Data migration

Application names, categories, purposes, personal rationale, platforms, relationships, profiles, and provider bindings become private declarative Rig data. Native manifests remain native provider inputs.

### Host-local operations

The Bun/macOS audit and launchd service operations remain private executable providers or compatibility commands. Their current safety tests remain until equivalent replacement coverage exists.

### Chezmoi review

All private configuration changes are made in chezmoi sources, followed by `chezmoi diff`; applying them remains a separate explicitly approved action.
