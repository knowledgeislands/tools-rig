---
id: RIG-CORE-009
area: CORE
title: Cache cleanup lifecycle
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T10:40:01Z
updated_at: 2026-09-20T11:56:34Z
---

# RIG-CORE-009: Cache cleanup lifecycle

## Goal

Rig users can identify and safely remove obsolete Rig-owned cached data so upgrades and retained diagnostic artifacts do not consume unbounded disk space.

## Context

Rig uses its XDG cache directory for temporary publication trees and may retain complete failed publication exports for diagnosis. Future versions may introduce other versioned or replaceable cached artifacts. Without an explicit lifecycle, obsolete data can accumulate while users cannot reliably distinguish safe-to-remove Rig data from current state or provider-owned caches.

## Boundary

This item does not make cleanup part of the normal Rig lifecycle, remove provider-native caches, delete configuration or state, or create a broad filesystem cleanup mechanism. It does not infer ownership from filenames, modification times, or process identifiers.

## Current state

Rig's only cache writer is publication staging beneath the effective Rig cache directory. A successful publication removes its staging tree, while a complete export is retained after publisher failure or interruption. Active staging and retained failures currently share one flat filename namespace, so an old-looking entry cannot safely be classified from its name, modification time, or embedded process identifier.

There is no public cleanup command. Rig cannot distinguish an inactive retained export from a concurrent publication strongly enough to delete either safely.

## Steps

- [ ] Accept a cache specification covering explicit staging, retained, and cleanup-claim namespaces; indefinite retention; classification; reporting; exit status; interruption; and concurrency.
- [ ] Move publication staging into an active-only namespace and atomically transfer complete failed or interrupted exports into a retained-only namespace without changing publisher handoff or exported data.
- [ ] Implement `rig clean [--dry-run]` as an explicit command that does not load configuration or invoke providers.
- [ ] Validate every retained candidate beneath a pinned canonical parent, atomically claim it, unlink only its regular non-symlink `rig.json`, and remove only the now-empty directory without recursive traversal.
- [ ] Report legacy flat entries and unsafe or unknown shapes as skipped; continue independent candidates and return a finding status without inferring ownership.
- [ ] Cover no-op, preview, deletion, multiple candidates, claim recovery, concurrent cleaners, interruption, legacy entries, symlinks, unexpected content, parent substitution, and publication compatibility in Bats.
- [ ] Align help, completions, README, consumer command guide, manual, changelog, Specifications, and the public-surface alignment test.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `docs/specs/cache.md`
- `docs/specs/index.md`
- `docs/specs/publishing.md`
- `README.md`
- `docs/guides/user/commands.md`
- `man/rig.1`
- `CHANGELOG.md`
- `docs/roadmap/RIG-CORE-009-cache-cleanup-lifecycle.md`

## Verify

- Run targeted adversarial Bats cases for cache classification, claiming, deletion, concurrency, interruption, and publication success or failure.
- Run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bash -n bin/rig install.sh`, `bats tests/`, and `mandoc -T lint man/rig.1`.
- Inspect `mandoc -T utf8 man/rig.1 | col -b`, generated Bash and Zsh completions, and exact help/documentation command inventory.
- Run focused `ki-repo-tools`, `ki-specs`, `ki-guides`, `ki-authoring`, and `ki-work-roadmap` audits.

## Dependencies / blocks

No dependency blocks delivery. Preserve macOS Bash 3.2, the no-runtime-dependency rule, and XDG and Rig-specific overrides. Cleanup must never visit provider-native caches, configuration, data, state, export destinations, personal declarations, or active publication staging.

## Documentation impact

### Decision Records

No new Decision Record is required. Existing XDG and ownership decisions already define the authority boundary; accepted cleanup behavior belongs in Specifications.

### Specifications

Add a cache area covering namespaces, retention, eligibility, dry-run, bounded deletion, reporting, concurrency, interruption, and exit status. Align publication retention with the new retained namespace.

### Guides

Document `rig clean` as explicit maintenance rather than a normal Rig lifecycle step. Explain dry-run, indefinite retention, ownership boundaries, legacy-unclassified entries, exact deletion scope, report states, and exit codes consistently across public surfaces.

### Roadmap

Keep this record as the canonical delivery and review account; do not create a parallel cleanup plan.

## Discussion

### Ownership boundary

Cleanup is based only on data Rig created beneath its own cache root. Provider ownership remains unchanged: Rig may explain that another system owns storage, but it must not treat that system's cache as Rig-managed data.

### Safety model

The useful operation is narrower than generic disk cleanup. Preview identifies exact candidates and reasons. Deletion fails closed on unexpected file types, substituted paths, active staging trees, or anything outside the pinned Rig cache root.

### Retention policy

Failed publication exports remain indefinitely until an explicit `rig clean`. `--dry-run` performs identical discovery and validation but reports `would-remove` without mutation. No age, count, automatic lifecycle, or successful-retry policy silently removes diagnostic evidence.

### Cache namespaces

Publication uses `publish/staging` only for active work and moves a complete failed or interrupted export atomically into `publish/retained`. Cleanup claims an eligible retained child by renaming it into a cleanup-only namespace before bounded deletion. A later clean may resume an exact-shape interrupted claim; clean never visits staging. Pre-contract flat `publish/*.rig-publish.*` entries remain `legacy-unclassified` and are skipped.

### Command contract

`rig clean [--dry-run]` prints a deterministic table with class, state, action, and absolute path plus final counts. A complete scan or preview returns 0, any independently skipped or failed candidate returns 1 after safe work continues, and invalid syntax or inability to validate the effective Rig cache boundary returns 2. Mutation progress uses the existing stderr progress channel and `RIG_PROGRESS` control.
