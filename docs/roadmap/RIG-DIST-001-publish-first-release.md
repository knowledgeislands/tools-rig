---
id: RIG-DIST-001
area: DIST
title: Publish first release
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CLI-001, RIG-CLI-002]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T11:53:55Z
---

# RIG-DIST-001: Publish first release

## Goal

Rig has a tagged release, a verified curl installer, and a companion Homebrew formula in `knowledgeislands/homebrew-tap` after its catalogue query and provider surfaces are usable.

## Context

The tools-repository standard expects direct script installation and Homebrew distribution. The repository scaffold prepares both interfaces, but no release should be published before a person can inspect a resolved rig and compare it with provider state.

## Boundary

This item covers release distribution, not provider implementation, personal-site publication, or changes to the tap's own governance standard.

## Discussion

### Release threshold

The first release should include a usable configuration contract, catalogue queries, orchestration engine, initial providers, completion, manual, and passing cross-platform shell tests rather than publishing the scaffold alone.
