---
id: RIG-CLI-012
title: Render readable status tables
area: CLI
theme: cli
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 55130abbe1307d425a1b5de7e9b2d2cf9d1a33c1
created_at: 2026-09-22T06:43:59Z
updated_at: 2026-09-22T07:13:37Z
---

## Goal

Make a large `rig status` report easy to scan by rendering aligned, bounded human tables instead of tab-separated fields whose columns drift and wrap unpredictably.

## Context

`rig show` already renders a bounded table, but `status` and its tool, skill, resource, port, listener, and unmanaged sections still emit raw tab-separated rows. Real personal configurations contain long identifiers, provider names, owners, and details, so terminal tab stops produce irregular columns and unreadable wrapping.

## Boundary

This work changes the human presentation of `rig status` only. It does not change observation, health classification, summaries, exit status, progress, provider calls, configuration, or publication data. Machine-readable status is independently captured by `RIG-CLI-010`; this item must not invent a second parsing contract from the human table.

## Current state

The report has deterministic row ordering and accurate values, but each section prints literal tabs. Long values shift later fields far beyond their headings. There is no shared bounded status-table formatter or visible indication when a cell has been abbreviated.

The approved design uses Bash-native dynamic column widths capped per table, two-space separators, header rules, deterministic ellipsis, and a maximum 120-character row. Every status section uses the same visual grammar while retaining section-specific columns.

## Steps

- [x] Add a reusable Bash 3.2-compatible bounded table renderer with no external command dependency.
- [x] Convert tool, skill, resource, port, listener, and unmanaged status sections to aligned tables.
- [x] Preserve summaries, row order, health accounting, exit status, stdout determinism, and provider invocation counts.
- [x] Add long-value fixtures proving bounded rows, aligned columns, ellipsis, and readable section separation.
- [x] Align the user command guide, manual, changelog, and public-surface tests.
- [x] Run the complete repository verification gate and keep the v0.3.0 candidate aligned.

## Files touched

- Authored Bash modules and assembled `bin/rig` for shared table rendering and status sections.
- `tests/` for exact and bounded status presentation.
- `docs/guides/user/commands.md`, `docs/specs/state.md`, `man/rig.1`, and `CHANGELOG.md` for the human-output contract.
- This roadmap record and issue ledger for delivery evidence.

## Verify

- Run focused status tests throughout implementation.
- Run assembly drift, Bash syntax, ShellCheck, full Bats, manual lint, documentation lint, benchmarks, native-provider smoke, and the complete KI repository audit before review.

## Dependencies / blocks

No delivery dependency. Preserve `RIG-CLI-010` as the sole machine-readable status work and do not alter the accepted adaptive progress renderer.

## Documentation impact

### Decision Records

No new Decision Record expected; this is presentation within the accepted CLI boundary.

### Specifications

Require bounded, deterministic human status tables without making their spacing a machine interface.

### Guides

Show the table shape and direct automation to the future machine-readable projection rather than terminal parsing.

### Roadmap

Keep the human table work separate from `RIG-CLI-010` and record delivery evidence here.

## Review

### Delivered

All human `rig status` sections now share a Bash-native table renderer with adaptive widths, two-space gutters, header rules, deterministic ellipsis, and a 120-character ceiling. Unmanaged path identities use middle ellipsis so their identifying tail remains visible.

### Summary of changes

The tool, skill, managed-resource, private-port, unmanaged-identity, unmanaged-listener, and unmanaged-skill views now buffer rows before rendering aligned columns. Existing ordering, state vocabulary, summaries, health accounting, exit statuses, and provider behaviour remain unchanged. Tests now assert semantic table rows rather than the retired tab-delimited presentation.

### Verification

- `ki repo audit --repo .`
- `shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers`
- `bash -n bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers`
- `scripts/assemble-rig --check`
- `scripts/benchmark-rig`
- `scripts/smoke-native-providers`
- `bats tests/` — 224 tests passed
- `mandoc -T lint man/rig.1`
- `git diff --check`

### Outstanding concerns

The human table remains intentionally unsuitable for automation. `RIG-CLI-010` remains the owner of a future machine-readable status projection.

### Post-change review

The implementation adds no runtime dependency and remains compatible with the assembled Bash 3.2 executable. Help and completion surfaces require no textual change because no command, option, or argument changed; the guide, Specification, manual, changelog, and tests describe the new output contract.

### Mini recap

Large status reports are now consistently aligned and bounded without altering what Rig observes or how it classifies machine state.

## Discussion

Readable output takes precedence over preserving literal tab bytes. Ellipsis must be obvious and deterministic so a person can use `rig explain` for full declaration context without mistaking an abbreviated cell for complete data.
