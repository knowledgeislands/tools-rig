---
id: KI-TOOL-RIG-CORE-050
area: CORE
title: Mise observed executables
purpose: corrective
initiative: rig
kind: deliver
status: draft
horizon: next
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T23:36:16Z
updated_at: 2026-10-14T06:52:07Z
---

# Mise Observed Executables

## Goal

A mise tool declaration can name the executable, or executables, Rig checks separately from the locator it installs. Tools whose binary name differs from their mise locator, such as `rust` or a `cargo:` backend package, can then be declared in a Rig catalogue, observed by `rig status` and installed by `rig apply`.

## Context

The built-in mise `tool` kind uses its locator for every native operation. [Provider state](../../src/rig/21-provider-state.bash) observes with `mise which LOCATOR` and applies with `mise install LOCATOR`, as the [orchestration specification](../specs/orchestration.md) requires; `rig upgrade` runs `mise upgrade LOCATOR`. `mise which` takes an executable name, so observation succeeds only when the binary is named exactly as the locator.

`rust` installs `rustc` and `cargo` but no `rust` executable, so its observation reports it missing on every run. A `cargo:` backend package, for example `cargo:cargo-nextest` providing `cargo-nextest`, has the same mismatch, as does any tool whose binary carries a different name. The chezmoi workstation therefore pins these tools only in its global mise manifest, outside Rig's catalogue and status.

## Boundary

- In: an optional configuration field naming one or more executables for observation, its validation and default to the locator's tool name, observation reporting when several executables are named, specifications and tests.
- Out: changes to the install, upgrade and removal locator; reading mise's global manifest; any other provider kind.

## Current state

Not yet grounded. `ki-plan` records the current source facts before Ready.

## Steps

- [ ] Plan this record under `ki-plan` before Ready, replacing these placeholder sections.

## Files touched

Not yet planned.

## Verify

Not yet planned.

## Dependencies / blocks

Not blocked; it blocks nothing.

## Documentation impact

### Decision Records

Not yet assessed.

### Specifications

Not yet assessed.

### Guides

Not yet assessed.

### Roadmap

Not yet assessed.

## Discussion

Origin: the chezmoi source (`krisb/dotfiles`), whose workstation keeps `rust` and `cargo:` tools out of its Rig catalogue for this reason; Kris Brown approved the handoff on 2026-10-14. Capture only; adoption, priority and plan belong to this repository.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `deliver / Next` as a defect fix. The mise `tool` kind reports `rust` and `cargo:` tools missing on every run, so the chezmoi workstation keeps them out of Rig's catalogue. The fix is a small optional field. Adoption grants no planning, implementation or acceptance authority.
