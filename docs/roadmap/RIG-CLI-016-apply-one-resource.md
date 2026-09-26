---
id: RIG-CLI-016
area: CLI
title: Apply one resource
theme: cli
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T10:00:00Z
updated_at: 2026-09-26T10:00:00Z
---

## Goal

Somebody who has declared one new thing can materialise that one thing, without asking Rig to reconcile everything else the profile declares at the same time.

## Context

`rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` has no finer selector than `--scope`. Installing a single new scheduled job on this workstation therefore meant running `rig apply --scope resources`, which reconciled all forty-three declared resources.

That was safe only because `rig status` was read first and showed forty-two of the forty-three already `present`, so the one material change was the new agent. Checking beforehand is a procedural habit standing in for a missing selector, and the habit is what fails: the wider the blast radius of a one-line declaration, the more likely somebody applies without looking.

The workaround costs time as well as safety. Reconciling forty-three resources to install one is the slowest way to get there, and a failure anywhere in the pass obscures whether the intended change landed — the first `--scope resources` run reported one failure that a second run did not reproduce, and the failing target was never identified because the output covered everything.

## Boundary

This is a selector for an existing command, not a new command, and not a change to how any provider materialises anything. It does not add partial-profile resolution: the profile still resolves in full, and the selector narrows only what gets dispatched.

## Discussion

### What the selector selects

A target name is the obvious unit, since that is what `rig status` reports and what the outcome lines already name. Whether it accepts several, accepts a glob, or must be exact is open; exact and repeatable is the smaller change.

### Interaction with dependency ordering

Rig orders dispatch by declared dependency. Applying one target either ignores that ordering, which can dispatch something whose prerequisite is absent, or honours it and quietly applies more than was asked for. Saying which, and reporting it, matters more than the choice itself.
