---
id: RIG-DIST-001
area: DIST
title: Publish first release
theme: distribution
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 02a63f55aefb8f7d9b11cdaddbe020af898c2982
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-17T06:31:05Z
---

# RIG-DIST-001: Publish first release

## Goal

Rig has a tagged release, a verified curl installer, and a companion Homebrew formula in `knowledgeislands/homebrew-tap` after its catalogue query, doctor, bootstrap, and provider surfaces are usable.

## Context

The tools-repository standard expects direct script installation and Homebrew distribution. The repository scaffold prepares the executable, installer, manual, completion, tests, and CI, but no release should be published before a person can inspect a resolved rig, diagnose its health, and compare it with provider state.

## Boundary

This item covers release distribution and the cross-repository formula handoff. It does not implement providers, catalogue queries, doctor, bootstrap migration, personal-site publication, or the Homebrew tap's own governance contract.

## Current state

Rig v0.1.0 is published from the verified pre-v1 command baseline with immutable release notes, a checksum-bound archive, a tested curl installer, and a Homebrew formula. The curated `1.0.0 — in progress` changelog remains open for ongoing development.

## Locked contract

The first preview release candidate is `0.1.0`, matching the executable's existing version, and leaves the curated `1.0.0 — in progress` baseline open. It uses an annotated `v0.1.0` tag, GitHub's immutable tagged source archive, a recorded SHA-256 checksum, and release notes derived from a dated `0.1.0` changelog entry. Local delivery prepares and verifies the candidate and cross-platform CI. Tag creation, push, GitHub release publication, and the checksum-bound Homebrew formula remain serial external stops under the repository's explicit publication rule.

## Steps

- [x] Confirm every `blocked_by` item is accepted and shipped help, command-specific help, README inventory, completion, manual, and changelog describe one command surface.
- [x] Lock the local preview contract: version `0.1.0`, dated changelog snapshot while `1.0.0 — in progress` stays open, annotated `v0.1.0` tag, tagged archive checksum, and changelog-derived release notes.
- [x] Run the complete repository gate and cross-platform shell CI on the exact release-candidate revision.
- [x] Add the approved dated `0.1.0` release snapshot to `CHANGELOG.md` without closing or duplicating the ongoing `1.0.0 — in progress` baseline.
- [x] Obtain separate publication approval, push the exact candidate, create and push the annotated tag, publish the GitHub release and notes, and record the archive checksum.
- [x] In `knowledgeislands/homebrew-tap`, follow its repository workflow to add `Formula/rig.rb` against the immutable archive checksum and verify installation, `rig --help`, `rig --version`, and `rig(1)`.
- [x] Verify the documented curl installer against the immutable release rather than `main`, then update release installation guidance.

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

## Release-candidate audit

Local hardening landed in `3fc0759`: CI now triggers for version tags, exercises Bash 3.2 on macOS as well as Ubuntu, and rejects tag/version mismatches; the installer validates both executable and manual before replacing either; command-local completion and help coverage is aligned. The complete local gate passes with 98 Bats tests. The repository audit remains 14/15 only because of nine approval-gated live GitHub settings.

The exact candidate `5c00ca7` passed hosted main run `35189621552` and tag run `35189698096`. Annotated tag `v0.1.0` and its GitHub release publish the immutable archive with SHA-256 `5edcbe3b0a753b499c7dcb1b62640957c61f24b378cd2d3a520af01e10fd2bf6`. The pinned curl installer and Homebrew formula both install `rig 0.1.0`, its help, and its manual successfully.

## Review

### Delivered

Published Rig v0.1.0 as the first public preview, including the annotated tag, GitHub release, immutable source archive checksum, verified curl installation, and checksum-bound Homebrew formula.

### Summary of changes

The release candidate fixes hosted ShellCheck and Linux completion dependencies, keeps the ongoing `1.0.0 — in progress` changelog open, adds the dated v0.1.0 snapshot, and pins documentation to the immutable release. Homebrew tap commit `1c3d202` adds `Formula/rig.rb` and its README catalogue entry.

### Verification

The release revision passed 98 Bats tests, ShellCheck, Bash syntax, mandoc lint, diff checks, Ubuntu CI, macOS Bash 3.2 CI, and tag/version validation. GitHub Actions runs `35189621552` and `35189698096` passed. The tagged curl installer returned `rig 0.1.0` and installed a lint-clean manual. Homebrew strict online audit and style passed; source installation, `brew test`, explicit version/help execution, and installed-manual lint passed from `knowledgeislands/tap/rig`.

### Outstanding concerns

The Rig repository still has nine approval-gated live GitHub settings findings; no settings changed. The Homebrew tap's hosted governance run `35190059122` remains red because of its pre-existing `BREW-002` roadmap-record finding, while the Rig formula-specific KI audit and all Homebrew checks pass.

### Post-change review

The published release points only at tag `v0.1.0`; its archive checksum matches both the release notes and formula. The formula installs the executable and `rig(1)` without adding runtime dependencies. The live chezmoi cutover remains a separate, unapplied review boundary.

### Mini recap

Rig v0.1.0 and its Homebrew formula are published and independently installation-tested. This record is ready for human acceptance; v1 remains explicitly in progress.

## Discussion

### Release threshold

The first release includes a usable configuration contract, catalogue queries, orchestration engine, initial providers, top-level doctor and bootstrap commands, completion, manual, and passing cross-platform shell tests rather than publishing the scaffold alone.

The active `--help`, command-specific help, README command inventory, Bash and Zsh completion, `rig(1)`, and curated changelog must describe the same shipped command surface. The changelog's pre-v1 run-up stays under one `1.0.0 — in progress` baseline until v1 is released.

### Homebrew formula

After an immutable release tag exists, the delivery adds `Formula/rig.rb` to `knowledgeislands/homebrew-tap` with the release archive URL, verified checksum, MIT license, executable and `rig(1)` installation, and help and version tests. The tap change follows its own repository workflow and is not approximated by a formula pointing at `main`.
