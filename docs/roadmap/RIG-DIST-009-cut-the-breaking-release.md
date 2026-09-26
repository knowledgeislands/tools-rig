---
id: RIG-DIST-009
area: DIST
title: Cut the breaking release
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-26T10:05:00Z
---

## Goal

The Rig people install carries the changed export surface, marked plainly as a breaking change, and no machine that follows the upgrade quietly stops working.

## Context

Two delivered items left a release unblocked but uncut. The export instruction moved onto the command line, which is a breaking change to a published command's shape, and the verification gate was restored so a release has evidence behind it — including a Linux runner that covers the plist escaping defect no Bash 3.2 workstation can regression-test locally. Nothing is tagged, so the last released Rig still accepts the old export form and the breakage is currently invisible. The change is on `origin/main` and unreleased; the gate passes there, including the bats suite at 243 tests, the benchmarks inside budget, and the native-provider smoke run.

One known consumer follows this repository's releases. `kit-midnight.ninja` calls `rig export midnight-ninja` in `apps/site-rig/pipeline/pull.ts` and will break on the next Rig it installs. That repository owns its own migration; the release must not ship before it lands.

## Boundary

This item does not make the consuming change inside `kit-midnight.ninja` — that repository owns it. It does not revise the release process, and it does not reopen the question of publishing to any package registry.

## Discussion

### Sequencing

The consumer migration is a precondition rather than a dependency of this repository's work: the tag can be prepared at any time, but publishing it before the site has migrated hands a broken pipeline to the next install.

### Open questions

Whether the version is `v0.4.0` or something else, and whether the Homebrew tap needs a matching update in the same pass, are both undecided.
