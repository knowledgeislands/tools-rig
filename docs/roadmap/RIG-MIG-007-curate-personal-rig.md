---
id: RIG-MIG-007
title: Curate personal rig
area: MIG
theme: migration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:43:26Z
---

## Goal

The live and chezmoi-source personal Rig should exercise the accepted human configuration, profile, private-resource, skill, and publication model with meaningful rationale and no residual competing authority.

## Context

The active configuration and chezmoi source currently match, and former operation surfaces are absent. The default membership is nevertheless expressed as very long central arrays, 87 application rationales repeat essentially the same placeholder, all 35 settings use generic rationale, and no publication is configured for `rig.midnight.ninja`. Global skills have mixed source authority, while stable port intent is undeclared.

## Boundary

Portable schema, lifecycle, observation, and adapter behaviour must land in tools-rig before personal data adopts it. This record does not invent personal rationale, publish private values, apply chezmoi without explicit approval, or make tools-rig authoritative for the dotfiles repository.

## Current state

The live Rig configuration and chezmoi source agree and former operation scripts are absent, but profile membership remains a very long central array, rationale text is mostly generic, profile configuration is not isolated for discovery, no public view or `rig.midnight.ninja` publication is declared, and stable ports and global skills are outside the model.

## Steps

- [ ] Reconcile the live configuration and chezmoi source immediately before editing and preserve unrelated dotfiles changes.
- [ ] Migrate declaration membership to the accepted implicit-default item model, create a descriptive profile fragment, and remove redundant bootstrap-profile configuration.
- [ ] Create an explicit non-appliable public view and publication declaration for `rig.midnight.ninja`, reviewing the allow-list against all private resources and observed state.
- [ ] Add stable port and trusted global-skill declarations only after `RIG-CORE-016` and `RIG-CORE-017` land, preserving each native owner's authority.
- [ ] Curate purposes and rationales only where the user's intent is known; leave clearly marked reviewable text rather than fabricate preferences.
- [ ] Validate the source and rendered configuration, run `chezmoi diff`, and do not run `chezmoi apply` without explicit current approval.

## Files touched

Expected scope is the chezmoi source under `~/.local/share/chezmoi/dot_config/rig/` and its rendered `~/.config/rig/` projection. Portable repository files change only if migration exposes a separately captured defect.

## Verify

Run Rig configuration validation, `show`, `doctor`, `status`, dry-run apply, public export with disclosure assertions, byte comparison of intended rendered files, dotfiles repository checks, and `chezmoi diff`. Report any unapplied source-to-home changes explicitly.

## Dependencies / blocks

Execute after `RIG-CORE-016`, `RIG-CORE-017`, `RIG-CORE-018`, and `RIG-CORE-019` have delivered portable contracts. Website deployment and actual publication remain outside this record.

## Delegation

Portable-to-personal schema mapping and public-projection privacy review may be prepared independently. One coordinator owns the cross-repository edit set, unrelated-change preservation, chezmoi diff, and decision not to apply without current authority.

## Documentation impact

### Decision Records

No tools-rig decision change is expected; personal configuration consumes already accepted contracts.

### Specifications

No new portable requirement is expected; any migration-discovered behavioural defect must be captured separately.

### Guides

Use the resulting personal configuration only as private validation evidence, not as public example data unless explicitly sanitised.

### Roadmap

Any unknown personal rationale remains an explicit user-review follow-up rather than being invented or silently dropped.

## Discussion

### Locked migration boundary

The migration consumes portable behaviour after it lands. It may edit the dotfiles source and review `chezmoi diff`, but applying rendered changes, publishing the public projection, or deploying the website requires explicit current authority at the point of mutation.

### Configuration migration

Once the portable model is accepted, move profile membership beside each declaration, leaving unqualified items in the default profile and using explicit inheritance for other complete machine profiles. Keep public and minimal views explicit. Separate profile declarations into a discoverable fragment and remove redundant bootstrap selection where fallback is sufficient.

### Meaningful intent

Curate purposes and rationales through human review rather than mechanical rewriting. Add stable ports and user skills only after their native ownership and privacy contracts exist.

### Public projection

Define a deliberate non-appliable public view and publication for `rig.midnight.ninja`. Review its data allow-list independently of installation and ensure private resources, runtime projections, machine paths, and observed state remain excluded.

### Cross-repository authority

The dotfiles repository owns its source edits and `chezmoi diff` review. Any implementation should use a governed trade or explicitly authorised multi-repository delivery rather than silently changing another repository from this record.
