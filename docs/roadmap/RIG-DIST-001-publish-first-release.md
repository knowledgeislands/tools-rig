---
id: RIG-DIST-001
area: DIST
title: Publish first release
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: [RIG-CLI-001]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-15T09:54:44Z
---

# RIG-DIST-001: Publish first release

## Goal

Rig has a tagged release, verified curl installer, and companion Homebrew formula in `knowledgeislands/homebrew-tap`.

## Context

The tool-repository standard expects direct script installation and Homebrew distribution. The repository scaffold prepares both interfaces but no release should be published before the orchestration contract is usable.

## Boundary

This item covers release distribution, not target implementation or changes to the tap's own governance standard.

## Discussion

### Release threshold

The first release should include a usable configuration contract, orchestration engine, initial targets, completion, manual, and passing cross-platform shell tests rather than publishing the scaffold alone.
