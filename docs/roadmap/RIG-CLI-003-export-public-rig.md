---
id: RIG-CLI-003
area: CLI
title: Export public rig
theme: cli
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 7eb1ffe07a2e23a8f0bf5e70c85fe6abf45f0fa9
created_at: 2026-09-15T11:53:55Z
updated_at: 2026-09-16T22:26:36Z
---

# RIG-CLI-003: Export public rig

## Goal

Rig can generate a deterministic static representation of an explicitly selected public profile for a personal website.

## Context

A publishable rig lets someone explain their working setup at an address such as `rig.midnight.ninja` or `midnight.ninja/rig` while retaining the local catalogue as the source of truth.

## Boundary

This item generates a local static artifact. It does not deploy hosting, publish private profiles, expose provider configuration or machine state, or make a network request.

## Current state

Rig can parse and resolve catalogue profiles and publication declarations, but it has no `export` command, public-projection model, or static artifact renderer. The publishing Specification defines the disclosure and determinism requirements; the exact command and artifact ownership contract still needs approval before implementation can be marked Ready.

## Locked contract

`rig export PUBLICATION --output DIRECTORY` writes a complete deterministic `index.html` and `assets/rig.css` tree without timestamps, providers, paths, credentials, profiles outside the selected publication, or observed state. Relationships are included only when both endpoints are public. All free text is HTML-escaped and configured base URLs work at a root, subdomain, or subpath.

Rig renders through a sibling temporary directory and replaces only an explicit safe output directory as one complete tree, never merges stale files, follows a symlink, accepts `/`, `.`, or `..`, invokes a provider or publisher, or performs network access.

## Steps

- [x] Approve `rig export PUBLICATION --output DIRECTORY` as the initial command contract: the publication selects its configured profile, title, and base URL; the caller owns the explicit output directory; Rig performs no publisher, provider, or network invocation.
- [x] Approve the artifact contract: a complete deterministic static directory, generated through a sibling temporary directory and installed without merging stale files, whose public data is limited to the RIG-PUB-002 allow-list.
- [x] Resolve the publication's profile and project categories, tools, and relationships, omitting relationships whose endpoints are not both public.
- [x] Render portable navigation for root, subdomain, and subpath base URLs using Bash 3.2-compatible code with no runtime dependency beyond Bash.
- [x] Add success, validation, disclosure, relationship-closure, deterministic-tree, portable-URL, offline, and output-safety tests.
- [x] Align top-level and command help, completion, README command inventory, `rig(1)`, Specifications, and the curated v1 changelog.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `README.md`
- `CHANGELOG.md`
- `man/rig.1`
- `docs/specs/publishing.md`
- `docs/roadmap/RIG-CLI-003-export-public-rig.md`

## Verify

- `shellcheck bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- Compare trees from semantically equivalent, differently ordered configurations.
- Inspect every generated file for forbidden provider, path, host, private-profile, credential, and observed-state fixture values.

## Dependencies / blocks

The completed catalogue resolver supplies deterministic profile selection and publication validation. This item blocks RIG-DIST-002. Readiness is gated on explicit approval of the recommended command and artifact contracts above, including replacement behaviour for an existing output directory.

## Delegation

After the export and artifact contracts are approved, renderer implementation and disclosure-focused fixture tests can proceed as bounded parallel lanes. One owner must retain the command contract, final integration, deterministic-tree comparison, and documentation alignment.

## Documentation impact

### Decision Records

No new decision is expected if implementation stays within ADR-RIG-004 and XDR-RIG-001. Amend those records only if the approved artifact or trust boundary changes.

### Specifications

Mark RIG-PUB-001 through RIG-PUB-006 conforming only with implementation evidence, and state the approved output replacement and artifact layout contract.

### Guides

Add practical export guidance only when the stable command exists, including review-before-publish and root, subdomain, and subpath examples.

### Roadmap

Keep this record canonical for export delivery and update RIG-DIST-002 only through its declared dependency relationship.

## Review

### Delivered

`rig export PUBLICATION --output DIRECTORY` now generates a complete deterministic public rig as `index.html` and `assets/rig.css` from an explicitly declared publication profile.

### Summary of changes

Added allow-listed and HTML-escaped catalogue rendering, public relationship closure, root/subdomain/subpath navigation, strict base-URL validation, offline generation, and sibling-tree replacement that rejects unsafe targets. Help, completions, README, manual, guide, changelog, and publishing conformance evidence now describe the command.

### Verification

The complete Bats suite passes, including deterministic ordering, disclosure, URL portability, offline execution, malformed authorities, and target safety. ShellCheck, Bash 3.2 syntax checking, mandoc lint, and `git diff --check` pass. The KI repository audit remains 14/15 solely because of nine pre-existing live GitHub settings differences that this batch is not authorised to change.

### Outstanding concerns

None within scope. Complete directory replacement has an unavoidable local TOCTOU window when another actor can mutate the parent directory concurrently.

### Post-change review

Independent review found malformed URL authorities could pass validation and the offline test shadowed only curl. The implementation now validates host, port, user-information, and bracketed IPv6 authority shapes, while the test shadows curl, wget, ssh, and git.

### Mini recap

Rig can now produce a safe, portable public projection suitable for `rig.midnight.ninja` or a personal-site subpath without publishing or exposing private machine state.

## Discussion

### Disclosure model

Publication is opt-in at the profile and publication declaration. The export includes only public catalogue fields and relationships whose endpoints are also public.

### Portable location

Generated links honour a configured base URL so the same projection works at a domain root, subdomain, or subpath.
