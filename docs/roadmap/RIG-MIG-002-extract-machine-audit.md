---
id: RIG-MIG-002
area: MIG
title: Extract machine audit
theme: migration
horizon: now
status: draft
blocks: [RIG-MIG-005]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T23:11:52Z
---

# RIG-MIG-002: Extract machine audit

## Goal

Rig can expose the current read-only machine-profile audit as an optional extension while portable expected-versus-observed state is handled by the core provider contract.

## Context

The current audit is Bun-based and reads private software, macOS, Brewfile, guide, housekeeping, and `ki-self` sources directly. Those workstation-governance checks are broader than Rig's portable presence and drift model.

## Boundary

This item does not expose the destructive `machine apply` operation, rewrite the audit in Bash, or move personal application and macOS choices into the Rig executable.

## Current state

The private `bin/rig.d/executable_machine` wrapper delegates to the Bun-based `bin/executable_machine` audit. It reads workstation-specific software, macOS, Brewfile, guide, housekeeping, and `ki-self` sources, while the standalone Rig has no generic operation dispatch yet.

The migration maps this extension to private tool `workstation` with operation `audit`, mode `observe`, platform `macos`, and optional allow-listed caller argument `--verbose`. Existing callers move from `rig machine audit --verbose` to `rig run workstation audit -- --verbose`.

## Steps

- [ ] Add `workstation` and its macOS-only `audit` observe operation to the generated private Rig configuration without moving the audit implementation or its data into tools-rig.
- [ ] Bind the operation to an executable provider that invokes the existing Bun audit and accepts no caller argument other than the optional exact value `--verbose`.
- [ ] Rewrite every dotfiles guide, housekeeping instruction, and agent-facing caller from `rig machine audit [--verbose]` to `rig run workstation audit [-- --verbose]`.
- [ ] Add focused operation tests for no-argument and verbose invocation, platform rejection, mutation prohibition, literal argument forwarding, and rejection before invocation of every unlisted argument.
- [ ] Keep the legacy wrapper and its tests live until the parity matrix in RIG-MIG-005 passes.

## Files touched

Expected private scope is `dot_config/rig/private_rig.conf.tmpl`, `bin/rig.d/executable_machine`, `bin/executable_machine`, the machine-audit caller guides and housekeeping record, and their focused Node tests. Public runtime changes belong to RIG-CLI-005; this item may add only fixtures or documentation needed to prove the private mapping.

## Verify

Render the private configuration and assert exactly one `workstation.audit` observe operation selects the existing executable on macOS. Compare legacy and new command exit status and output with and without `--verbose`; prove an unlisted argument and non-macOS platform fail before invocation. Run the relevant dotfiles Node suites, the tools-rig operation Bats coverage, and `chezmoi diff` without applying it.

## Dependencies / blocks

RIG-MIG-004 owns the private declaration projection and RIG-CLI-005 owns safe generic operation dispatch. This item blocks RIG-MIG-005 until callers and tests use the operation form. Any chezmoi application is a separate explicit approval stop.

## Delegation

One worker may add the private declaration and focused render tests while another inventories and rewrites machine-audit callers. The coordinator owns the operation safety review, side-by-side parity evidence, `chezmoi diff`, and the no-apply boundary.

## Documentation impact

### Decision Records

No new decision record is expected because the accepted executable-provider boundary already keeps the Bun audit private and optional.

### Specifications

No machine-specific public contract is added; generic operation specifications must cover observe mode, platform selection, and exact caller-argument allow-listing.

### Guides

Replace every documented `rig machine audit` invocation with `rig run workstation audit`, including the separated `-- --verbose` form.

### Roadmap

Retain RIG-CLI-005 as the public operation owner and RIG-MIG-005 as the retirement gate; do not create a generic machine-command workstream.

## Discussion

### Extension boundary

Machine audit remains a configured executable provider or compatibility command. This keeps Rig dependency-free while allowing a private profile to invoke richer optional tooling when present.
