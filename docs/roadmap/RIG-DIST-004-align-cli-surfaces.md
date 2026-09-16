---
id: RIG-DIST-004
area: DIST
title: Align public CLI surfaces
theme: distribution
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-16T13:25:02Z
updated_at: 2026-09-16T13:25:02Z
---

# RIG-DIST-004: Align public CLI surfaces

## Goal

Rig's help, completion, README, manual, and curated pre-v1 changelog present one accurate public command and installation contract consistent with the established Knowledge Islands CLI tools.

## Context

The shipped command inventory is accurate across the current surfaces, but completion omits accepted help and version flags, top-level help understates the no-argument form, and the manual lacks the installation and completion guidance used by sibling tools. The changelog also separates current `0.1.0` capabilities from its evolving `1.0.0 — in progress` baseline instead of using the established shipped-command, behaviour, and distribution groups.

## Boundary

This item aligns existing public behaviour and documentation only. It does not add a command, make `completion --help` valid, publish a release, add a Homebrew formula, apply private configuration, or advertise planned `doctor`, `status`, `apply`, `run`, or publication commands as shipped.

## Current state

`rig --help`, README, manual, and changelog name every shipped command and no retired command. Bash and Zsh completions register correctly, but omit valid root flags and local help flags for catalogue commands. The installer already supports release and linked-development executable and manual installation.

## Steps

- [ ] Match help's optional-command synopsis and purpose-first shape to sibling tools.
- [ ] Complete Bash and Zsh candidates for every accepted root and command-local option.
- [ ] Add executable completion registration and candidate coverage.
- [ ] Add release, linked-development, completion, and schema-reference guidance to `rig(1)`.
- [ ] Add the bare `rig` behaviour and release installation route to README.
- [ ] Reshape the in-progress v1 changelog into shipped commands, behaviours, and distribution baseline without prospective commands.
- [ ] Verify every public surface and the complete repository gate.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, this work record, and the roadmap issue ledger.

## Verify

Compare `rig --help`, command-local help, both completion outputs, README, `rig(1)`, and changelog. Run functional Bash and Zsh completion registration checks, `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, inspect `mandoc -Tutf8 man/rig.1 | col -b`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

No implementation dependency remains. This alignment must stay current as later command roadmap items land.

## Delegation

One read-only reviewer may compare Rig with `tools-mgit` and `tools-ki`. The coordinator owns all edits, verification, roadmap lifecycle, and commits.

## Documentation impact

### Decision Records

No change; this applies the accepted tool-repository distribution contract.

### Specifications

No behaviour requirement changes; completion and documentation expose behaviour the parser already accepts.

### Guides

README and `rig(1)` gain the missing installation and completion routes; no separate guide is needed.

### Roadmap

This record is the canonical delivery boundary. Planned commands remain in their existing roadmap records rather than the changelog.

## Discussion

### Completion truth

Completion offers only syntax the CLI currently accepts. Root help and version flags and command-local help for `show`, `list`, `explain`, and `diag` are included; `completion --help` remains absent because the parser rejects it.

### Pre-v1 changelog

The single `1.0.0 — in progress` entry inventories shipped commands, behaviours, and distribution. Future work belongs in the roadmap until it ships.
