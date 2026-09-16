---
id: RIG-CLI-001
area: CLI
title: Add provider adapters
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 7eb1ffe07a2e23a8f0bf5e70c85fe6abf45f0fa9
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T22:29:07Z
---

# RIG-CLI-001: Add provider adapters

## Goal

Rig ships provider adapters for Homebrew, uv, chezmoi, direct downloads, and explicitly configured executables, with read-only observation and explicit supported mutations.

## Context

Providers are the manager-of-managers mechanism beneath the catalogue product. They connect selected tools to native systems without making Rig another package resolver or configuration database.

## Boundary

Adapters invoke supported native operations but do not reimplement native resolution, lock files, manifests, configuration, or state. This item does not choose a person's catalogue or publish their rig.

## Current state

Schema 1 parses providers and bindings, resolves one compatible binding, and keeps unselected provider executables optional. No built-in adapter invokes Homebrew, uv, chezmoi, or direct downloads. RIG-CORE-002 has not yet fixed or implemented the executable-provider ABI on which every adapter depends.

## Locked contract

Homebrew supports `formula`, `cask`, and `mas` bindings through per-tool native observation and application while the private Brewfile remains the declaration source. uv supports `tool` bindings, chezmoi supports `target` bindings, and custom providers retain `rig-provider-v1`. Direct downloads require an HTTPS locator, `destination`, and lowercase `sha256:` checksum; they download to a sibling temporary file, verify before replacement, refuse symlink or non-regular destinations, and clean failed temporary files.

Provider executables may be overridden explicitly for isolated tests and non-default installations. Built-in adapters expose only declared exact capabilities and never invoke unselected providers.

## Steps

- [x] Consume the approved RIG-CORE-002 provider ABI and public state contract without adding adapter-specific exceptions to the core.
- [x] Lock a capability and native-command matrix for Homebrew, uv, chezmoi, direct-download, and custom executable providers.
- [x] Define the direct-download integrity, destination, temporary-file, atomic replacement, and failure-cleanup contract before enabling mutation.
- [x] Implement provider detection, observation, dry-run planning, and explicitly supported mutation using literal argument boundaries.
- [x] Test each adapter through recording fakes, including absent unselected executables, unavailable selected providers, native failures, and dependent-work suppression.
- [x] Prove catalogue queries and `status` never invoke mutation, and prove chezmoi mutation occurs only through explicit `rig apply`.
- [x] Align help, completion, README, `rig(1)`, changelog, Specifications, and Bats evidence for the shipped capability set.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/specs/configuration.md`, `docs/specs/orchestration.md`, `docs/specs/state.md`, and this work record. A focused Decision Record may be added if the direct-download contract introduces a durable cross-provider policy.

## Verify

Use fake executables to assert exact arguments, action capabilities, observation results, native exit handling, no calls to unselected providers, no mutation during read-only commands, and checksum failure before direct-download installation. Then run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

RIG-CORE-002 is a genuine build dependency: adapters cannot be implemented until its executable-provider ABI and public state treatment exist. Readiness also requires an explicit adapter capability matrix and a direct-download lifecycle contract; RIG-ORCH-006 names the provider classes and XDR-RIG-001 requires integrity evidence, but neither fixes native invocation semantics, destination ownership, atomic replacement, or cleanup after failure. Recommend locking those details in Specifications, escalating to a Decision Record if one policy must govern multiple adapters.

## Delegation

After RIG-CORE-002 lands, separate workers may implement non-overlapping adapter and fake-test lanes only after the capability matrix assigns exact functions and tests. The coordinator owns shared dispatch integration, safety review, public documentation, full verification, roadmap evidence, and the commit.

## Documentation impact

### Decision Records

Review whether direct-download destination and replacement semantics need a durable Decision Record; no other decision change is expected once ADR-RIG-005 defines the shared provider contract.

### Specifications

Specify each adapter's supported capabilities, native argument mapping, availability behaviour, direct-download integrity lifecycle, and resulting conformance evidence.

### Guides

Add concise provider setup and safety guidance for native prerequisites, manifests, observation, dry-run, and explicit application.

### Roadmap

Record adapter evidence here and unblock RIG-CLI-004, RIG-CLI-005, RIG-DIST-001, RIG-DIST-002, and RIG-MIG-004 only when the shared provider surface has landed.

## Review

### Delivered

Built-in Homebrew, uv, chezmoi, and direct-download adapters now observe and materialise selected bindings through the shared provider engine while custom providers retain the `rig-provider-v1` ABI.

### Summary of changes

Added strict adapter and binding validation, default executable selection with explicit overrides, exact native command construction, stable state mapping, provider preflight, and checksum-verified sibling-file replacement for direct downloads. Updated the public documentation and command surfaces for the supported matrix.

### Verification

The complete Bats suite passes with exact fake-provider argument and failure coverage. ShellCheck, Bash 3.2 syntax checking, mandoc lint, and `git diff --check` pass. The KI repository audit remains 14/15 solely because of nine pre-existing live GitHub settings differences that this batch is not authorised to change.

### Outstanding concerns

None within scope. Direct-download replacement retains the unavoidable local filesystem race present when a destination parent is writable by another actor.

### Post-change review

Independent review identified destination replacement and redirect-protocol hardening opportunities. The implementation now rechecks destination safety immediately before replacement, constrains initial and redirected transfers to HTTPS, validates Mac App Store identities as numeric, and covers exact download arguments and race cleanup in Bats.

### Mini recap

Rig can now turn resolved catalogue bindings into provider-native observations and explicit apply actions without taking ownership of native manifests or provider state.

## Done

Accepted 2026-09-16 by Kris Brown on review packet above.

## Discussion

### Capability vocabulary

Not every provider supports every action. Configuration and help surfaces should expose real capabilities instead of pretending install, update, cleanup, backup, audit, diff, and apply are universal synonyms.

### Optional dependencies

A provider executable is required only when a selected binding uses it. Missing optional providers report `unavailable` rather than becoming Rig core dependencies.

### Chezmoi safety

Chezmoi inspection and mutation remain distinct. Neither catalogue queries nor state inspection may trigger `chezmoi apply`; mutation requires an explicit apply action.

### Download integrity

Direct-download bindings require declared integrity evidence and perform network or filesystem mutation only through explicit application.
