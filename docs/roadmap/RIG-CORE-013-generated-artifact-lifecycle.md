---
id: RIG-CORE-013
area: CORE
title: Generated artifact ownership
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 52517334dbd39f0b653cb373ede0f7718e9db04e
created_at: 2026-09-21T07:44:37Z
updated_at: 2026-09-21T11:40:38Z
---

# RIG-CORE-013: Generated artifact ownership

## Goal

Keep durable generated paths with the catalogue tool whose capability they expose while preserving the native tool's lifecycle ownership.

## Context

Some tools create launchers, handlers, or comparable durable paths that are useful machine-state evidence. A second catalogue identity misrepresents those paths as separate user capabilities, while a configuration-triggered generator would turn Rig into a task runner.

## Boundary

Keep one tool entry per capability. Artifact declarations are optional and observation-only. Rig must not derive or invoke artifact generators from configuration, and profile deselection does not imply automatic uninstall or deletion.

## Current state

Schema 1 accepts an `artifacts` array on tools. `rig explain` reports ownership, while `rig status` and `rig doctor` observe path health. macOS application-bundle health requires a readable property list and a working nested executable. Apply, bootstrap, update, and maintenance operate only through provider capabilities.

## Steps

- [x] Keep generated paths with their owning tool and expose them through catalogue queries.
- [x] Strengthen generic macOS application-bundle health without adding a product-specific generator.
- [x] Keep artifact declarations inert and reject unknown lifecycle fields.
- [x] Remove the specialised artifact reconciler from parsing, validation, apply, bootstrap, update, progress, and reporting.
- [x] Align README, changelog, manual, guides, Decisions, Specifications, and focused Bats coverage.
- [x] Verify Bash 3.2 compatibility, non-mutating observation, deterministic reports, and the full command suite.

## Files touched

Portable scope covers `bin/rig`, focused Bats fixtures, `README.md`, `CHANGELOG.md`, `man/rig.1`, `docs/decisions/`, `docs/specs/`, `docs/guides/`, and this work record. Personal catalogue choices remain in the owning chezmoi repository.

## Verify

Run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bash -n bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, and `git diff --check`.

## Dependencies / blocks

RIG-CORE-012 supplies the provider lifecycle used by apply, bootstrap, update, and maintenance. Artifact observation remains independent from that lifecycle.

## Documentation impact

### Decision Records

State that artifacts remain tool-owned observation and that their native tool owns creation, update, and removal.

### Specifications

Specify inert artifact declarations, generic health observation, and the absence of artifact-generator orchestration.

### Guides

Explain when a durable generated path is useful Rig evidence and when an internal native detail should be omitted.

### Roadmap

The reciprocal personal migration retains the account-management CLI capabilities while omitting unnecessary application-bundle declarations.

## Delegation

Bounded review may inspect portable integration points and reciprocal personal configuration. The primary agent owns schema choice, integration, verification, commits, and live chezmoi application.

## Review

### Delivered

Tool-owned artifacts are now a generic, observation-only catalogue feature. The Codex-specific lifecycle path is absent from the schema and implementation, while macOS bundle health and artifact explanation remain available.

### Summary of changes

- Removed the specialised reconciler field and all generator dispatch from the dependency-free Bash runtime.
- Preserved generic artifact ownership, path comparison, and stricter macOS application health.
- Reduced focused artifact tests to observation and aligned every public documentation surface.
- Retained provider apply, bootstrap, update, and maintenance behaviour without artifact-specific work.

### Verification

- `ki repo audit --repo .` passed 15 selected skills.
- `shellcheck bin/rig install.sh` and `bash -n bin/rig install.sh` passed.
- `bats tests/` passed all 179 tests.
- `mandoc -T lint man/rig.1` and `git diff --check` passed.
- Help, completions, README, manual, guides, changelog, Decisions, and Specifications remain covered by public-surface alignment tests.

### Outstanding concerns

None in the portable implementation. Whether a personal native artifact is useful enough to declare remains a catalogue-owner decision.

### Post-change review

Implementation commit: `f4e7959b` (`refactor(core): keep generated artifacts observational`).

### Mini recap

Rig can explain and inspect durable tool-owned artifacts without acquiring a hidden task-runner or product-specific launcher lifecycle.

## Discussion

### One capability, one tool

A durable generated path may be useful state evidence, but it is not automatically a separate capability. Its purpose, rationale, installation, profile membership, and optional artifact paths stay with the owning tool.

### Native lifecycle ownership

An artifact declaration does not authorise execution. The native tool or provider may create the path as a side effect, while Rig remains responsible only for describing and observing the declared state.
