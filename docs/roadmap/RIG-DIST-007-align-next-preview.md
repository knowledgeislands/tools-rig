---
id: RIG-DIST-007
title: Align next preview
area: DIST
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:35:16Z
---

## Goal

The next Rig `0.x` preview should identify one verified contract consistently across the executable, documentation, immutable tag, installer, release notes, manual, completions, and companion Homebrew formula.

## Context

The development checkout is 45 commits beyond `v0.2.0` while still reporting `0.2.0`; README installation examples fetch the tag but describe later behaviour. The changelog uses a `1.0.0 — in progress` heading even though delivery remains incremental `0.x` previews. Fake-based tests are strong, but the staged bootstrap and native macOS behaviours need a small clean-machine or disposable-machine smoke record before recommendation.

## Boundary

This record does not grant authority to tag, push, publish a GitHub release, change the tap, deploy a website, or apply personal configuration. Those remain explicit external mutations after the release candidate is reviewed.

## Discussion

### Development truth

Use an honest unreleased marker until a specific preview version is selected. A linked development checkout must be distinguishable from the last immutable release, and documentation must not instruct a tagged installation to use commands or schema absent from that tag.

### Release evidence

Complete the repository gate, command-surface alignment, manual rendering, clean installation, staged bootstrap smoke, selected native adapter smoke, public export validation, and release diff review before choosing the next `0.x` tag.

### Distribution handoff

After explicit release authority, the exact tag and checksum become the companion tap's input, and the website remains a downstream consumer of the immutable installer route rather than release authority.
