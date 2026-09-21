---
id: RIG-CORE-011
area: CORE
title: Native declarative Rig
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 998b7fc766e66d3ad542d2b367e718d1c3819c58
created_at: 2026-09-20T17:28:14Z
updated_at: 2026-09-21T12:10:46Z
---

# RIG-CORE-011: Native declarative Rig

## Goal

Let a person declare the tools, managed resources, profiles, and desired machine state that make up their Rig while Rig owns ordinary lifecycle and adapter mechanics without configuration boilerplate.

## Context

The current private configuration models bootstrap and workstation as custom providers. Nine synthetic setup tools dispatch to chezmoi-installed helper scripts, while workstation policy depends on a Bun executable and a separate YAML declaration. Launchd is a genuine native manager, but its portable adapter is also installed privately and therefore reaches Rig through the extension ABI.

This makes ordinary configuration expose `adapter`, capability arrays, helper installation, and `rig-provider-v1` concepts. It also lets bootstrap observation report helper presence instead of the managed state. The approved correction keeps providers only for genuine native authorities, makes canonical built-ins implicit, treats workstation as a profile, and reserves the versioned executable protocol for genuine extensions.

## Boundary

Keep personal catalogue choices, package lists, paths, service commands, macOS values, and credentials in private configuration. Keep native Homebrew, uv, chezmoi, launchd, defaults, Dock, and other external systems authoritative for their own manifests and state. Do not add a general task runner or shell escape, hard-code private mcporter restart behaviour, apply chezmoi without an explicit reviewed diff, publish a release, or push.

## Current state

Rig has built-in Homebrew, uv, chezmoi, and direct-download tool adapters, but their provider identities and capabilities must still be declared. Operational resources are forced through custom providers. `rig bootstrap` resolves a profile and uses the core plan engine, but the live bootstrap profile consists of custom-provider pseudo-tools. Workstation defaults, Dock state, and application inventory are combined in one private Bun/YAML provider. The live launchd adapter is portable Bash but lives in chezmoi and uses the custom protocol.

## Steps

- [x] Amend the living product, architecture, security decisions and specifications around declarative nouns, implicit built-ins, native bootstrap, typed machine resources, and the extension-only ABI.
- [x] Add a canonical built-in manager registry so ordinary tool and resource declarations need no provider table or capability boilerplate while genuine extensions retain explicit executable authority.
- [x] Add scoped reconciliation and make bootstrap a native staged lifecycle over honest declarations rather than synthetic setup tools.
- [x] Promote launchd into Rig as a Bash 3.2 built-in with observation, application, retirement, and ordinary resource actions, excluding private label-specific behaviour.
- [x] Replace the workstation provider with profile-selected macOS settings, Dock layout, and application inventory that participate in status, doctor, dry-run, and apply.
- [x] Migrate the private Rig TOML and chezmoi sources to the declarative model, retaining narrowly private operations only where no typed model exists and removing obsolete providers only after parity tests.
- [x] Align README, user and developer guides, manual, help, completions, changelog, definition of done, and release checklist with the resulting interface.
- [x] Run public and private verification, review `chezmoi diff`, and leave the live system unapplied unless separately approved.

## Files touched

Expected public scope is `bin/rig`, `tests/rig.bats`, `README.md`, `CHANGELOG.md`, `man/rig.1`, decisions, specifications, guides, completions and this roadmap record. Expected private scope is the Rig configuration, provider sources, coupled tests, chezmoi removal metadata, and current/future-focused dotfiles documentation under `/Users/krisbrown/.local/share/chezmoi`.

## Verify

Run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, and `mandoc -T lint man/rig.1`. In chezmoi, run its declared test suite, `chezmoi diff`, and `chezmoi status`; compare bootstrap, launchd, macOS settings, Dock, application inventory, status, and doctor intent before removing legacy providers.

## Dependencies / blocks

The current private declarations and providers are migration evidence, not authority for the public design. Removal depends on equivalent public tests and private dry-run parity. Applying rendered chezmoi changes remains a separate explicit approval boundary.

## Delegation

Use bounded read-only audits for core architecture, public documentation/schema, and private migration classification. During implementation, delegate non-overlapping test or documentation lanes only after the core schema is fixed; the primary agent owns integration, private cutover review, and final verification.

## Documentation impact

### Decision Records

Amend the living records that currently define configuration, provider execution, operational resources, executable trust, and the catalogue-led product boundary.

### Specifications

Update accepted configuration, orchestration, state, query, portability, and publication behaviour; preserve append-only requirement identities and record truthful conformance.

### Guides

Rewrite the normal user journey around declarative tools, profiles, services, jobs, settings, layouts, status, doctor, bootstrap, and apply. Isolate extension protocol detail in developer guidance.

### Roadmap

This record owns the complete correction and private migration. Capture only independently valuable follow-on adapters or typed resource families that are not required for the current live parity boundary.

## Review

### Delivered

Delivered the native declarative Rig model from immutable baseline `998b7fc766e66d3ad542d2b367e718d1c3819c58`. Ordinary configuration now declares tools and typed resources while Rig owns built-in orchestration; the executable protocol remains available only for explicit extensions and publishers.

### Summary of changes

Canonical Homebrew, uv, chezmoi, direct-download, launchd, macOS defaults, Dock, and application-inventory adapters are implicit. Bootstrap is a scoped native lifecycle, launchd resources reconcile and retire through atomic receipts, settings and Dock layouts participate in queries and state, and artifact health refines installed-tool observations. Help, completions, manual, changelog, decisions, specifications, and user and developer guides describe the same interface.

### Verification

The repository audit passed all 15 selected skills. ShellCheck passed for `bin/rig` and `install.sh`; all 168 Bats cases passed; `mandoc -T lint man/rig.1` and `git diff --check` passed. The private candidate validates as schema 1 and resolves its bootstrap profile to 89 tools, two services, three scheduled jobs, 35 settings, and one Dock layout.

### Outstanding concerns

The chezmoi source migration is prepared but deliberately not applied to the live home directory. Private maintenance, completion regeneration, permission repair, and SSH-loading operations remain explicit scripts because this item does not invent an unbounded task runner. Package-cache cleanup remains separate roadmap work.

### Post-change review

The implementation now matches the corrected schema-1 contract and keeps provider-native manifests and state authoritative. Full-plan preflight, dry-run non-mutation, dependency suppression, resource retirement, extension trust boundaries, and Bash 3.2 portability are covered by focused tests. The item is ready for acceptance after review of the public diff and coupled chezmoi source diff.

### Mini recap

Rig configuration now says what belongs in a working setup and what state is desired; Rig handles ordinary execution mechanics. The main follow-up learning route is to decide whether any retained private operations deserve future bounded resource types.

## Done

Accepted 2026-09-21 by Kris Brown on the review packet above.

## Discussion

### Provider test

A provider represents an independently existing authority that owns native resolution, execution, or state. Bootstrap, workstation, machine, audit, and maintenance fail that test; Homebrew, uv, chezmoi, launchd, defaults, Dock tooling, and package managers pass it at an appropriate typed boundary.

### Configuration altitude

Ordinary configuration should state desired nouns and their owner. Rig should infer the implementation and capability matrix for shipped built-ins. Only genuine executable extensions need registration and an explicit operation allow-list.

### Compatibility

Schema 1 may be corrected in place because Rig remains a personal pre-1.0 product. Preserve old explicit built-in provider declarations long enough to make migration reviewable, but do not preserve misleading pseudo-state or private-provider architecture as permanent compatibility surface.

### Extension protocol

`rig-provider-v1` remains a stable literal-argument protocol marker for executable extensions and publishers. Built-ins do not invoke it, and normal user documentation does not require understanding it.
