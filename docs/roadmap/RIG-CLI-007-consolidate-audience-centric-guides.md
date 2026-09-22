---
id: RIG-CLI-007
title: Consolidate audience-centric guides
area: CLI
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
transferred_from: ki-website
baseline_ref: 8e3dc95af5d7631300f46368d62386b87533df48
created_at: 2026-09-21T17:20:00Z
updated_at: 2026-09-22T05:08:23Z
---

## Goal

Practical instruction for Rig lives in a guide collection organised around audience needs, while the repository README orients readers and routes them to the right next step.

## Context

The guide collection already separated user and developer audiences, but its instructional material competed with a long README. Installation, first configuration, profiles, artifacts, commands, and safety boundaries appeared in more than one place and could drift independently.

The Knowledge Islands website derives public guidance from repository-owned guides. Rig therefore owns the quality and stability of these source documents; the website remains a consumer rather than an authority.

## Boundary

- Compare instructional README sections with the user guides covering the same outcomes.
- Keep only purpose, mental model, status, and navigation in the README.
- Make `docs/guides/user/commands.md` the explanatory command map and keep exhaustive reference material in `man rig`.
- Ensure the journey starts with one readable catalogue and introduces profiles, machine resources, skills, extensions, and publication incrementally.
- Check Specifications and `AGENTS.md` for practical instruction that belongs in the guide collection without duplicating normative contracts.

## Current state

`docs/guides/` contains audience indexes and a complete, ordered user journey. README orientation points directly to that journey and no longer embeds setup procedures or the complete command reference.

## Steps

- [x] Map instructional README sections to the user guides covering the same outcomes.
- [x] Choose one authoritative practical home for each outcome.
- [x] Reduce the README to product orientation and durable navigation.
- [x] Sweep Specifications and `AGENTS.md`; retain their normative and contributor-specific content rather than duplicating it in user guides.
- [x] Run guide, authoring, repository, and public-command coherence checks.

## Files touched

`README.md`, `docs/guides/`, `tests/rig.bats`, and this roadmap record.

## Verify

`ki repo audit --skill ki-guides --repo .` and `ki repo audit --skill ki-authoring --repo .` pass. The full repository gate and the focused public-command documentation test pass.

## Dependencies / blocks

Nothing blocks this work. The collection already uses audience directories, so it also satisfies the proposed `ki-guides` audience-directory shape if that becomes mandatory.

## Documentation impact

### Decision Records

No architectural decision changed. The guides link durable rationale rather than reproducing it.

### Specifications

No behaviour-level contract changed. Specifications remain the accepted-behaviour authority and are linked rather than copied into guides.

### Guides

This item establishes the guide collection as the practical authority for adoption, operation, development, and release workflows.

### Roadmap

No follow-up roadmap item was exposed by the guide rewrite.

## Review

### Delivered

From immutable baseline `8e3dc95af5d7631300f46368d62386b87533df48`, consolidated Rig's practical documentation into a reader-first, audience-centred journey. The implementation changes no runtime behaviour and does not publish or mutate external systems.

### Summary of changes

- Reduced `README.md` to product purpose, a plain-language model, maturity, and routes into the guide collection.
- Reworked the guide indexes into an explicit incremental learning sequence.
- Rewrote user guides around concrete outcomes with human-readable multiline TOML and clear read, observe, preview, mutate, and publish boundaries.
- Reworked developer guides around the repository boundary, one complete verification gate, definition of done, commit safety, and explicit external authority.
- Updated the public-command coherence test so README navigation is checked without forcing the complete command inventory back into the landing page; exact command synopses remain checked across the command guide, changelog, manual, help, and completions.

### Verification

- `bats --filter 'public command inventory stays aligned across documentation' tests/rig.bats` — pass.
- `rumdl check README.md docs/guides docs/roadmap/RIG-CLI-007-consolidate-audience-centric-guides.md` — pass.
- `ki repo audit --skill ki-guides --repo .` — pass.
- `ki repo audit --skill ki-authoring --repo .` — pass.
- ShellCheck and Bash syntax gates for the executable, installer, authored modules, and support scripts — pass.
- `scripts/assemble-rig --check` — pass.
- `scripts/benchmark-rig` — pass within all budgets.
- `scripts/smoke-native-providers` — pass for all available native providers.
- `bats tests/` — 221 tests pass.
- `mandoc -T lint man/rig.1` — pass.
- `ki repo audit --repo .` — pass across 16 selected skills.
- `git diff --check` — pass.

### Outstanding concerns

None. The version shown in installation examples remains the current documented preview; release-candidate alignment belongs to the separate distribution work item.

### Post-change review

The new structure gives a first-time reader a short route from purpose to a safe first preview, then exposes advanced concepts only when needed. Normative details remain in Specifications and `man rig`, reducing drift risk without hiding the complete CLI contract. The change is ready for human acceptance review.

### Mini recap

Rig now has one coherent practical documentation journey for users and maintainers. Verification found no behaviour, portability, assembly, manual, or repository-governance regression, and no further work was created.

## Done

Accepted 2026-09-22.

## Discussion

The deciding test is whether a reader who has never opened the source can understand what Rig is, create a small declaration, assess the machine, and choose the next safe command without learning the implementation first.
