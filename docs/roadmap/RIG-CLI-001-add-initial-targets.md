---
id: RIG-CLI-001
area: CLI
title: Add provider adapters
theme: cli
horizon: now
status: draft
blocks: [RIG-CLI-004, RIG-CLI-005, RIG-DIST-001, RIG-DIST-002, RIG-MIG-004]
blocked_by: [RIG-CORE-002]
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T17:05:41Z
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

## Steps

- [ ] Consume the approved RIG-CORE-002 provider ABI and public state contract without adding adapter-specific exceptions to the core.
- [ ] Lock a capability and native-command matrix for Homebrew, uv, chezmoi, direct-download, and custom executable providers.
- [ ] Define the direct-download integrity, destination, temporary-file, atomic replacement, and failure-cleanup contract before enabling mutation.
- [ ] Implement provider detection, observation, dry-run planning, and explicitly supported mutation using literal argument boundaries.
- [ ] Test each adapter through recording fakes, including absent unselected executables, unavailable selected providers, native failures, and dependent-work suppression.
- [ ] Prove catalogue queries and `status` never invoke mutation, and prove chezmoi mutation occurs only through explicit `rig apply`.
- [ ] Align help, completion, README, `rig(1)`, changelog, Specifications, and Bats evidence for the shipped capability set.

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

## Discussion

### Capability vocabulary

Not every provider supports every action. Configuration and help surfaces should expose real capabilities instead of pretending install, update, cleanup, backup, audit, diff, and apply are universal synonyms.

### Optional dependencies

A provider executable is required only when a selected binding uses it. Missing optional providers report `unavailable` rather than becoming Rig core dependencies.

### Chezmoi safety

Chezmoi inspection and mutation remain distinct. Neither catalogue queries nor state inspection may trigger `chezmoi apply`; mutation requires an explicit apply action.

### Download integrity

Direct-download bindings require declared integrity evidence and perform network or filesystem mutation only through explicit application.
