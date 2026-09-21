---
id: RIG-CORE-012
area: CORE
title: Provider lifecycle
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T05:50:39Z
updated_at: 2026-09-21T05:50:39Z
---

# RIG-CORE-012: Provider lifecycle

## Goal

Let a person install, update, maintain, and deliberately capture the provider-owned parts of a declared Rig without installing personal dispatcher scripts or exposing arbitrary commands in configuration.

## Context

The native declarative model now handles ordinary convergence, but the live personal setup still relies on eight chezmoi-delivered scripts beneath `${RIG_DATA_HOME}/operations`. Their common `install|update|cleanup|backup` interface is a remnant of the former bootstrap dispatcher, not a current Rig contract. Homebrew, mise, npm, and uv have real native ownership boundaries that Rig can coordinate directly; several other scripts are repository maintenance, one-time host repair, or native client configuration rather than Rig providers.

The approved direction is for those scripts to disappear. Each behaviour must become a bounded built-in lifecycle capability or move to an explicit non-Rig boundary. Rig must not replace native manifests, accept configuration-defined shell commands, or revive the omnibus provider model.

## Boundary

Keep personal packages, paths, manifests, credentials, and profile selection in private configuration. Do not make `clean` an implicit setup lifecycle stage, update unselected custom providers, invent a generic task runner, source TOML as shell, or make Rig edit a chezmoi source tree. Direct-download and chezmoi remain convergence-only until a truthful update contract exists.

## Current state

`rig apply` and `rig bootstrap` reconcile declared installations and resources. `rig clean` removes only provably Rig-owned cache artifacts. Homebrew and uv are built in; mise-managed runtimes and npm global packages are still hidden inside a personal script. No public command coordinates provider-native updates, maintenance, or manifest capture.

## Steps

- [ ] Specify the lifecycle: convergence stays under `apply` and `bootstrap`; `update` advances selected provider state; `maintain` performs explicit provider maintenance; `capture` refreshes one explicitly named native manifest; `clean` remains Rig-cache-only.
- [ ] Add implicit built-in mise and npm providers with typed installation metadata, observation, application, update, and maintenance operations while preserving native manifests and literal argument boundaries.
- [ ] Add bounded Homebrew and uv update/maintenance behaviour plus explicit Homebrew manifest capture, complete preflight, dry-run, progress, failure isolation, and deterministic reporting.
- [ ] Keep external providers extension-only and reject lifecycle dispatch not fixed by Rig; do not expose arbitrary lifecycle commands through TOML.
- [ ] Align help, per-command usage, completions, manual, README, changelog, specifications, decisions, user/developer guides, definition-of-done coverage, and release checklist.
- [ ] Verify Bash 3.2 compatibility, provider fakes, non-mutation in dry-run, selected-profile scoping, manifest safety, and existing command regressions.

## Files touched

Expected scope is `bin/rig`, `tests/`, `README.md`, `CHANGELOG.md`, `man/rig.1`, `docs/decisions/`, `docs/specs/`, `docs/guides/`, and this roadmap record. Coupled personal migration is owned by `DOTFILES-UE-034` in the chezmoi repository.

## Verify

Run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, and `git diff --check`. Exercise every new lifecycle command against isolated fake provider executables and manifests; prove dry-run and validation failures make no provider mutation.

## Dependencies / blocks

RIG-CORE-011 supplied the native declarative provider registry and plan engine this work extends. Its implementation exists, so no build-order blocker remains. The private migration may be prepared alongside this item but cannot retire live scripts until the public replacement passes its full gate.

## Documentation impact

### Decision Records

Amend the catalogue-led product, configuration grammar, and provider execution records to distinguish convergence, update, maintenance, capture, and Rig-cache cleanup while preserving native authority and the executable trust boundary.

### Specifications

Add accepted command, configuration, orchestration, state, progress, portability, and safety requirements for built-in lifecycle capabilities and truthful unsupported-provider behaviour.

### Guides

Teach the everyday lifecycle, when each mutation boundary is appropriate, how provider-native manifests remain authoritative, and why repository maintenance and host-specific repair are not lifecycle adapters.

### Roadmap

This item owns portable lifecycle capabilities. `DOTFILES-UE-034` owns migration and removal of the personal residual operations.

## Discussion

### Lifecycle vocabulary

`apply` answers whether declared state is present. `update` asks native managers to advance selected declared tools. `maintain` is an explicit, separately authorised housekeeping action and never runs as a hidden phase of apply or bootstrap. `capture` reverses one provider's observed state into its native manifest and therefore requires an explicit provider target. `clean` continues to mean Rig-owned cache cleanup only.

### Provider selection

Homebrew manifest operations are provider-wide because the Brewfile is the native authority. uv and npm can operate on selected declared package locators. mise consumes its native configuration and manages selected runtime identities. Providers without a fixed built-in lifecycle capability report unsupported before any mutation.

### Residual classification

SSH key loading belongs in SSH client configuration, completion generation belongs in source maintenance, and broad filesystem permission repair is a reviewed host prerequisite. Ruby and Oh My Zsh self-maintenance should use their native interfaces unless a future declared package set establishes a reusable provider boundary. Those outcomes remove false Rig ownership rather than replacing one wrapper with another.
