---
id: RIG-DIST-003
area: DIST
title: Curate v1 baseline
theme: distribution
horizon: triage
status: draft
blocks: [RIG-DIST-001]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T13:04:11Z
updated_at: 2026-09-15T13:04:11Z
---

# RIG-DIST-003: Curate v1 baseline

## Goal

Rig's changelog records one honest, curated `1.0.0 — in progress` baseline throughout the pre-v1 run-up.

## Context

Rig currently reports version `0.1.0` but has no tag or GitHub release, and `CHANGELOG.md` opens with a generic `Unreleased` section. MGit, KI, and Git Almanac keep their intended v1 public surface under one in-progress baseline while tags and commit history record individual 0.x deliveries.

## Boundary

This item changes release documentation only. It does not bump the executable version, create a tag or GitHub release, advertise unimplemented commands as shipped, add the Homebrew formula, or alter runtime behaviour.

## Discussion

### Baseline shape

The heading is `## [1.0.0] — in progress`. It explains that pre-v1 work is summarised in one baseline and separates shipped foundation commands from accepted v1 direction so readers can tell what the executable does today.

Each later command delivery moves its entry into the shipped command baseline while updating help, completion, README, manual, tests, and changelog together. At v1 release, the heading receives its release date and becomes the formula's public command baseline.
