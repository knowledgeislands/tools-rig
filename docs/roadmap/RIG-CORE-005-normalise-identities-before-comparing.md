---
id: RIG-CORE-005
area: CORE
title: Normalise identities before comparing
theme: orchestration
horizon: now
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-17T00:00:00Z
updated_at: 2026-09-17T00:00:00Z
---

# RIG-CORE-005: Normalise Identities Before Comparing

## Goal

Reconciliation compares identities rather than raw strings, so a declaration and an observation that name the same thing in different but equivalent forms agree.

## Context

Both directions of reconciliation compare declared text against provider-reported text with an exact string match. Where the two sides legitimately spell the same identity differently, Rig reports a finding that is purely an artefact of the comparison.

Two instances are confirmed against a live catalogue of 81 tools:

- A Homebrew cask declared with a tap-qualified locator is reported `missing` while installed. `locator = 1password/tap/1password-cli` and `locator = steipete/tap/codexbar` do not match Homebrew's installed short names `1password-cli` and `codexbar`. Both casks are installed; Rig reports `missing=2`.
- An `artifact` path containing `$HOME` or a leading `~` never matches a provider-reported absolute path. `bin/rig` compares `RIG_QUERY_ITEMS` entries to the reported identity directly, with no expansion, while every other path-valued field is expanded.

The second case is currently worked around outside Rig: the chezmoi repository expands `$HOME` when rendering its catalogue, so its rendered artifacts are absolute. That workaround only exists because the consumer happens to have a templating layer, which is exactly the dependency that consumer is trying to remove.

## Boundary

This item covers identity normalisation in comparison paths only. It does not change the configuration schema, add aliasing or fuzzy matching between genuinely different identities, alter what any provider reports, or introduce a general path-rewriting facility.

## Current state

`rig status` reports two false `missing` findings against a live 81-tool catalogue. `rig status --unmanaged` is correct only because its consumer pre-expands `$HOME`.

## Steps

- [ ] Expand `~` and `$HOME` in `artifact` values on the comparison path, matching how executable and manifest paths are already expanded.
- [ ] Normalise a tap-qualified Homebrew cask or formula locator to the short name the adapter observes, keeping the qualified form authoritative for acquisition.
- [ ] Decide whether normalisation belongs to the adapter or the comparison, and apply that consistently to both cases rather than fixing each where it was found.
- [ ] Cover both cases in `tests/rig.bats`, including a tap-qualified locator that is installed and an artifact declared with each of `~` and `$HOME`.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `CHANGELOG.md`

## Verify

- `bats tests/`
- `shellcheck bin/rig`
- Against the live workstation catalogue, `rig status` reports `missing=0` with both tap-qualified casks installed, and `rig status --unmanaged` is unchanged when its consumer stops pre-expanding `$HOME`.

## Dependencies / blocks

None. The chezmoi consumer can drop its render-time `$HOME` expansion once this ships, but neither change blocks the other.

## Documentation impact

### Decision Records

None expected. Normalising equivalent spellings of one identity is within the existing provider execution contract rather than a change to it.

### Specifications

Record the normalisation rule wherever the comparison semantics of `artifact` and `locator` are specified.

### Guides

None unless the rule changes how a locator should be written.

### Roadmap

None.

## Discussion

### Why this is one item

Both cases have the same shape: a comparison that treats a formatted string as an identity. Fixing them separately would leave the third instance to be found in production as well.
