---
id: RIG-DIST-003
area: DIST
title: Curate v1 baseline
theme: distribution
horizon: now
status: ready
blocks: [RIG-DIST-001]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T13:04:11Z
updated_at: 2026-09-15T13:20:41Z
---

# RIG-DIST-003: Curate v1 baseline

## Goal

Rig's changelog records one honest, curated `1.0.0 — in progress` baseline throughout the pre-v1 run-up.

## Context

Rig currently reports version `0.1.0` but has no tag or GitHub release, and `CHANGELOG.md` opens with a generic `Unreleased` section. MGit, KI, and Git Almanac keep their intended v1 public surface under one in-progress baseline while tags and commit history record individual 0.x deliveries.

## Boundary

This item changes release documentation only. It does not bump the executable version, create a tag or GitHub release, advertise unimplemented commands as shipped, add the Homebrew formula, or alter runtime behaviour.

## Current state

`CHANGELOG.md` has one generic `Unreleased` heading and lists only the bootstrap command surface. It does not yet express the curated pre-v1 baseline used by the comparable KI tools.

## Steps

- [ ] Replace the generic heading with one `1.0.0 — in progress` baseline.
- [ ] Separate capabilities available in the current executable from accepted direction still being built, without presenting planned commands as shipped.
- [ ] Verify the changelog remains concise, accurate, and aligned with the current help and version output.

## Files touched

`CHANGELOG.md` and this canonical work record.

## Verify

Run `rig --help` and `rig --version` against the changelog claims, `ki repo audit --skill ki-authoring --repo .`, `ki repo audit --skill ki-repo-tools --repo .`, and `git diff --check`.

## Dependencies / blocks

No build dependency remains. This baseline must be delivered before `RIG-DIST-001`; later command items will maintain it as their public surfaces land.

## Delegation

One bounded worker may change `CHANGELOG.md` only. The coordinator owns lifecycle evidence, accuracy review, repository audits, and commits.

## Documentation impact

### Decision Records

No Decision Record change is needed; release-document curation applies the accepted product direction.

### Specifications

No Specification change is needed because the changelog records delivery state rather than accepted behavior.

### Guides

No guide change is needed; no user procedure changes.

### Roadmap

Delivery satisfies the changelog prerequisite recorded by `RIG-DIST-001`; no additional work item is created.

## Discussion

### Baseline shape

The heading is `## [1.0.0] — in progress`. It explains that pre-v1 work is summarised in one baseline and separates shipped foundation commands from accepted v1 direction so readers can tell what the executable does today.

Each later command delivery moves its entry into the shipped command baseline while updating help, completion, README, manual, tests, and changelog together. At v1 release, the heading receives its release date and becomes the formula's public command baseline.
