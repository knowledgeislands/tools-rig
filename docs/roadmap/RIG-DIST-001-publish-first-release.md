---
id: RIG-DIST-001
area: DIST
title: Publish first release
theme: distribution
horizon: now
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T23:37:31Z
---

# RIG-DIST-001: Publish first release

## Goal

Rig has a tagged release, a verified curl installer, and a companion Homebrew formula in `knowledgeislands/homebrew-tap` after its catalogue query, doctor, bootstrap, and provider surfaces are usable.

## Context

The tools-repository standard expects direct script installation and Homebrew distribution. The repository scaffold prepares the executable, installer, manual, completion, tests, and CI, but no release should be published before a person can inspect a resolved rig, diagnose its health, and compare it with provider state.

## Boundary

This item covers release distribution and the cross-repository formula handoff. It does not implement providers, catalogue queries, doctor, bootstrap migration, personal-site publication, or the Homebrew tap's own governance contract.

## Current state

Rig has an installer, manual, completion, CI, and a curated `1.0.0 — in progress` changelog, but the declared v1 provider, doctor, bootstrap, and release-threshold dependencies are not all complete. No immutable release tag, release archive, checksum, published release, or Homebrew formula exists.

## Locked contract

The release candidate is version `1.0.0`, uses an annotated tag, GitHub's immutable tagged source archive, a recorded SHA-256 checksum, and release notes derived from the curated changelog. Local delivery prepares and verifies that candidate and cross-platform CI. Tag creation, push, GitHub release publication, changelog dating, and the checksum-bound Homebrew formula remain serial external stops under the repository's explicit publication rule.

## Steps

- [ ] Confirm every `blocked_by` item is accepted and the shipped help, command-specific help, README inventory, completion, manual, and changelog describe one command surface.
- [ ] Approve the release contract and external actions: version `1.0.0`, final changelog date, signed or annotated tag policy, archive origin, checksum recording, release-note source, GitHub release action, and explicit permission to push and publish.
- [ ] Run the complete repository gate and cross-platform shell CI at the exact release candidate revision.
- [ ] Finalise `CHANGELOG.md` from `1.0.0 — in progress` to the approved dated `1.0.0` release without adding unshipped work.
- [ ] With separate publication approval, create and push the immutable tag and publish the release archive and notes; record the archive checksum.
- [ ] In `knowledgeislands/homebrew-tap`, follow that repository's workflow to add `Formula/rig.rb` against the immutable archive and checksum, then verify installation, `rig --help`, `rig --version`, and `rig(1)`.
- [ ] Verify the documented curl installer against the immutable release rather than `main`, and update release installation guidance where required.

## Files touched

- `CHANGELOG.md`
- `README.md`
- `install.sh`
- `man/rig.1`
- `.github/` release configuration if the approved release contract requires it
- `docs/roadmap/RIG-DIST-001-publish-first-release.md`
- `Formula/rig.rb` in `knowledgeislands/homebrew-tap`
- Git tag and release state only after explicit publication approval

## Verify

- `ki repo audit --repo .`
- `shellcheck bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- Pass the repository's cross-platform CI at the release revision.
- Install from the immutable release with the documented curl command in a clean temporary home.
- Run the Homebrew tap's required audit, style, install, help, version, and manual checks.

## Dependencies / blocks

RIG-CLI-001, RIG-CLI-002, RIG-CLI-004, RIG-DIST-003, and RIG-MIG-001 are release gates; bootstrap parity is therefore explicit rather than implied by prose. Readiness additionally requires approval of the release decisions and external publication actions listed in Steps. The Homebrew formula is a cross-repository handoff after, never before, the immutable tag and checksum exist.

## Delegation

After every dependency and release decision is satisfied, release-candidate verification and preparation of the tap change can be separate bounded lanes. Tagging, pushing, release publication, checksum confirmation, and final cross-repository integration remain serial human-approved stops.

## Documentation impact

### Decision Records

No new product decision is expected. Record a new decision only if the release mechanism changes the shell-only runtime, installer trust, or provider boundary.

### Specifications

Update conformance evidence only for behaviour actually present in the released revision; release mechanics do not make pending product requirements conforming.

### Guides

Align installation and upgrade guidance with the immutable curl archive and Homebrew formula after both paths are verified.

### Roadmap

Retain this item through cross-repository formula verification and record the exact release and tap revisions in its review packet before acceptance.

## Discussion

### Release threshold

The first release includes a usable configuration contract, catalogue queries, orchestration engine, initial providers, top-level doctor and bootstrap commands, completion, manual, and passing cross-platform shell tests rather than publishing the scaffold alone.

The active `--help`, command-specific help, README command inventory, Bash and Zsh completion, `rig(1)`, and curated changelog must describe the same shipped command surface. The changelog's pre-v1 run-up stays under one `1.0.0 — in progress` baseline until v1 is released.

### Homebrew formula

After an immutable release tag exists, the delivery adds `Formula/rig.rb` to `knowledgeislands/homebrew-tap` with the release archive URL, verified checksum, MIT license, executable and `rig(1)` installation, and help and version tests. The tap change follows its own repository workflow and is not approximated by a formula pointing at `main`.
