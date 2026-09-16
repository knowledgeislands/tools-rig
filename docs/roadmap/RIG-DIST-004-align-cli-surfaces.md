---
id: RIG-DIST-004
area: DIST
title: Align public CLI surfaces
theme: distribution
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: a26e5c382237ad997e248609739baad251919485
created_at: 2026-09-16T13:25:02Z
updated_at: 2026-09-16T21:37:27Z
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

- [x] Match help's optional-command synopsis and purpose-first shape to sibling tools.
- [x] Complete Bash and Zsh candidates for every accepted root and command-local option.
- [x] Add executable completion registration and candidate coverage.
- [x] Add release, linked-development, completion, and schema-reference guidance to `rig(1)`.
- [x] Add the bare `rig` behaviour and release installation route to README.
- [x] Reshape the in-progress v1 changelog into shipped commands, behaviours, and distribution baseline without prospective commands.
- [x] Verify every public surface and the complete repository gate.

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

## Review

### Delivered

Rig's help, completion definitions, README, manual, and pre-v1 changelog now present the same shipped command, option, installation, and configuration contract.

### Summary of changes

- Changed top-level help to the sibling CLI shape with optional options and command plus a purpose line.
- Added every accepted root and command-local option to Bash and Zsh completion.
- Added functional completion evaluation and Zsh registration coverage.
- Added release installation, shell completion, schema 1, and linked-development sections to `rig(1)`.
- Added the release installer and bare `rig` behaviour to README.
- Reduced the `1.0.0 — in progress` changelog to shipped commands, behaviours, and distribution; prospective work remains in the roadmap.

### Verification

- `ki repo audit --skill ki-authoring --repo .`: pass.
- `ki repo audit --skill ki-repo-tools --repo .`: pass.
- `shellcheck bin/rig install.sh` and `/bin/bash -n bin/rig`: pass.
- `bats tests/`: 41 tests pass.
- `mandoc -T lint man/rig.1`: pass; the rendered manual was inspected.
- `git diff --check`: pass.
- Full `ki repo audit --repo .`: 14 of 15 skills pass; `ki-repo` reports nine pre-existing live GitHub-settings discrepancies. No remote setting was changed.

### Outstanding concerns

The live GitHub settings remain outside this item's authority and require explicit approval before any mutation. Planned commands and the Homebrew formula remain in their canonical roadmap records.

### Post-change review

The comparison against `tools-mgit` and `tools-ki` found no retired command in Rig's surfaces and confirmed that the Zsh definition registers under `compinit`. The identified option, installation, manual, and changelog gaps are now addressed without broadening the CLI.

### Mini recap

Rig now follows the shared KI CLI presentation and distribution pattern while remaining a deliberately smaller pre-v1 tool.

## Done

Accepted 2026-09-16 by Kris Brown on review packet above.

## Discussion

### Completion truth

Completion offers only syntax the CLI currently accepts. Root help and version flags and command-local help for `show`, `list`, `explain`, and `diag` are included; `completion --help` remains absent because the parser rejects it.

### Pre-v1 changelog

The single `1.0.0 — in progress` entry inventories shipped commands, behaviours, and distribution. Future work belongs in the roadmap until it ships.
