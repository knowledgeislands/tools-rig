---
id: RIG-DIST-001
area: DIST
title: Publish first release
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CLI-001, RIG-CLI-002, RIG-CLI-004, RIG-DIST-003]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T13:04:11Z
---

# RIG-DIST-001: Publish first release

## Goal

Rig has a tagged release, a verified curl installer, and a companion Homebrew formula in `knowledgeislands/homebrew-tap` after its catalogue query, doctor, bootstrap, and provider surfaces are usable.

## Context

The tools-repository standard expects direct script installation and Homebrew distribution. The repository scaffold prepares the executable, installer, manual, completion, tests, and CI, but no release should be published before a person can inspect a resolved rig, diagnose its health, and compare it with provider state.

## Boundary

This item covers release distribution and the cross-repository formula handoff. It does not implement providers, catalogue queries, doctor, bootstrap migration, personal-site publication, or the Homebrew tap's own governance contract.

## Discussion

### Release threshold

The first release includes a usable configuration contract, catalogue queries, orchestration engine, initial providers, top-level doctor and bootstrap commands, completion, manual, and passing cross-platform shell tests rather than publishing the scaffold alone.

The active `--help`, command-specific help, README command inventory, Bash and Zsh completion, `rig(1)`, and curated changelog must describe the same shipped command surface. The changelog's pre-v1 run-up stays under one `1.0.0 — in progress` baseline until v1 is released.

### Homebrew formula

After an immutable release tag exists, the delivery adds `Formula/rig.rb` to `knowledgeislands/homebrew-tap` with the release archive URL, verified checksum, MIT license, executable and `rig(1)` installation, and help and version tests. The tap change follows its own repository workflow and is not approximated by a formula pointing at `main`.
