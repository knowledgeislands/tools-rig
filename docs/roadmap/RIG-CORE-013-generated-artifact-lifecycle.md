---
id: RIG-CORE-013
area: CORE
title: Generated artifact lifecycle
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 52517334dbd39f0b653cb373ede0f7718e9db04e
created_at: 2026-09-21T07:44:37Z
updated_at: 2026-09-21T09:10:19Z
---

# RIG-CORE-013: Generated artifact lifecycle

## Goal

Let one catalogue tool describe both its native installation and the application bundle it generates, while Rig safely creates or refreshes bundles that require a known explicit generator.

## Context

Tool `artifacts` already make generated paths observable, but they do not materialise those paths. The personal rig therefore has a managed `codex-multi-auth` CLI and a separately described app bundle, while `claude-code` and its URL-handler bundle are split across two catalogue entries. That makes one capability look like multiple tools and leaves the Codex launcher outside normal apply and update behaviour.

The installed Codex Multi Auth package exposes an idempotent `codex-multi-auth-app-launcher` command with a non-mutating `--dry-run`. Claude Code creates its own URL-handler bundle and needs observation only.

## Boundary

Keep one tool entry per capability. Add no arbitrary executable, hook, task-runner, or provider command to configuration. The initial native reconciler is a closed Rig-owned integration for `codex-multi-auth-app-launcher`; other artifact generators require explicit product work. Artifact deselection follows existing tool semantics and does not imply automatic uninstall or deletion.

## Current state

Schema 1 accepts an `artifacts` array and status validates each selected path, including macOS application-bundle integrity. Apply, bootstrap, and update materialise the owning installation but do not invoke a generator after successful provider work. Explain reports artifacts but has no reconciler metadata.

## Steps

- [x] Add optional `artifact.reconciler` metadata to a tool, validate it against a closed built-in registry, require compatible installation and artifact declarations, and keep configuration inert.
- [x] Implement the Codex Multi Auth app reconciler with fixed executable and arguments, bounded path expectations, dry-run planning, progress, and native failure propagation.
- [x] Run the reconciler after successful tool application in `rig apply` and `rig bootstrap`, and after the owning tool is successfully advanced by `rig update`.
- [x] Keep artifact observation authoritative for status and doctor, expose reconciler metadata through `rig explain`, and prove catalogue-only and automatically generated artifacts retain observation-only behaviour.
- [x] Align README, changelog, manual, user and developer guidance, Decision Records, Specifications, help/completion conformance evidence, and reciprocal personal configuration guidance.
- [x] Verify Bash 3.2 compatibility, full-plan safety, dry-run non-mutation, deterministic reporting, exact generator invocation, failure isolation, and all existing command behaviour.

## Files touched

Expected public scope is `bin/rig`, focused Bats fixtures, `README.md`, `CHANGELOG.md`, `man/rig.1`, `docs/decisions/`, `docs/specs/`, `docs/guides/`, and this work record. Personal catalogue migration remains a separate reviewed change in the chezmoi repository.

## Verify

Run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, and `git diff --check`. Use isolated fake npm and launcher executables to prove apply, bootstrap, update, dry-run, invalid declarations, absent generators, native failures, observation-only artifacts, and exact argument boundaries.

## Dependencies / blocks

RIG-CORE-012 supplies the built-in npm lifecycle and complete application plan used here. Its implementation is present in the current baseline, so no build-order blocker remains.

## Documentation impact

### Decision Records

Amend the declarative grammar and provider execution decisions so generated artifacts remain tool-owned and fixed reconcilers are product capabilities rather than configured commands.

### Specifications

Extend configuration, state, orchestration, progress, and safety requirements for the closed reconciler field, observation boundary, supported lifecycle points, and non-mutating preview.

### Guides

Explain when an artifact is observation-only, when Rig can reconcile it, and why deselection does not uninstall a tool or delete its artifacts.

### Roadmap

The reciprocal personal migration must retain Codex and Claude account-switching capabilities while collapsing each capability into its owning tool entry.

## Review

### Delivered

Schema 1 now supports one closed `artifact.reconciler` field. Codex Multi Auth uses a fixed native generator after successful apply, bootstrap, and update work; ordinary artifacts remain observation-only. Application-bundle health now detects missing or broken nested executables, and `rig explain` reports artifact ownership.

### Summary of changes

- Added closed schema validation, preflight, invocation, progress, dry-run, postcondition, and failure reporting.
- Resolve npm's global package root and invoke the installed launcher module through Node, avoiding an inert upstream symlink entrypoint.
- Kept the generated bundle on the owning tool and strengthened generic macOS application artifact observation.
- Aligned public documentation and executable contract evidence without changing the command or completion surface.

### Verification

- `ki repo audit --repo .` passed all selected skills.
- `shellcheck bin/rig install.sh` and `bash -n bin/rig install.sh` passed.
- `bats tests/` passed the complete suite, including 21 generated-artifact cases.
- `mandoc -T lint man/rig.1` and `git diff --check` passed.
- Help, completions, README, manual, guides, changelog, Decisions, and Specifications remain covered by the public-surface alignment tests.

### Outstanding concerns

None in the portable implementation. Personal catalogue migration is tracked independently by the owning configuration repository.

### Post-change review

Implementation commits: `5ac349a561bc5594bdb780006adb9df781f57e69`, `55905076aab1471791f420972ee5c66c6b6190e2`.

### Mini recap

Generated application bundles now belong to one catalogue capability. Rig owns only explicitly implemented artifact lifecycles and cannot be configured as a generic hook runner.

## Delegation

Use bounded read-only review lanes for public integration points and personal configuration migration. The primary agent owns schema choice, implementation, integration, full verification, commits, and any live chezmoi application.

## Discussion

### One capability, one tool

An application bundle generated by a CLI is observable output of that tool, not another catalogue identity. Relationships, rationale, profile membership, installation, and artifacts therefore stay together.

### Closed reconciler

`artifact.reconciler` names a Rig-owned adapter, not an executable path. Rig fixes the executable name, accepted installation identity, destination contract, and arguments. Configuration cannot introduce another command or change the invocation.

### Presence semantics

Rig profiles express selected desired presence. As with package managers, removing a tool from a profile does not request uninstall. Generated artifact retirement therefore remains outside this item; status can subsequently report an undeclared bundle through normal inventory.
