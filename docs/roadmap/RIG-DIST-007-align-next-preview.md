---
id: RIG-DIST-007
title: Align next preview
area: DIST
theme: distribution
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-21T23:43:26Z
---

## Goal

The next Rig `0.x` preview should identify one verified contract consistently across the executable, documentation, immutable tag, installer, release notes, manual, completions, and companion Homebrew formula.

## Context

The development checkout is 45 commits beyond `v0.2.0` while still reporting `0.2.0`; README installation examples fetch the tag but describe later behaviour. The changelog uses a `1.0.0 — in progress` heading even though delivery remains incremental `0.x` previews. Fake-based tests are strong, but the staged bootstrap and native macOS behaviours need a small clean-machine or disposable-machine smoke record before recommendation.

## Boundary

This record does not grant authority to tag, push, publish a GitHub release, change the tap, deploy a website, or apply personal configuration. Those remain explicit external mutations after the release candidate is reviewed.

## Current state

The development checkout still identifies as `0.2.0` despite substantial post-tag behaviour, README examples install immutable `v0.2.0` while describing later commands, and the changelog uses a `1.0.0 — in progress` heading although the intended next release is another `0.x` preview. Release checks lack a recorded clean-install and bounded native-adapter smoke result.

## Steps

- [ ] Replace the premature `1.0.0` development heading with `Unreleased` and keep released `0.x` history intact.
- [ ] Make development-version output distinguishable from the last immutable release without choosing or publishing a release tag.
- [ ] Separate README instructions for the latest release from local linked development and avoid claiming unreleased commands for `v0.2.0`.
- [ ] Align executable version, help, manual, completions, changelog, installer fixtures, and release guide around one candidate-version procedure.
- [ ] Add or record clean installation, staged bootstrap, selected native adapter, public export, and release-diff smoke evidence.
- [ ] Prepare the formula and website handoff checklist using a future exact tag and checksum placeholder; do not execute either handoff.

## Files touched

Expected scope includes `bin/rig`, `CHANGELOG.md`, `README.md`, `install.sh`, `tests/`, `man/rig.1`, completion fixtures, and `docs/guides/developer/releasing.md`.

## Verify

Run the complete repository gate, install into an isolated prefix, compare every version-bearing surface, exercise staged bootstrap and safe native observations where available, validate public export, and review the complete diff from `v0.2.0` without tagging, pushing, publishing, or changing external repositories.

## Dependencies / blocks

The final release-candidate alignment pass follows the other product batches so documentation does not advertise unfinished behaviour. External tag, release, tap, and website actions are outside this item and require fresh authority.

## Delegation

Version-surface alignment, isolated installation smoke, and release-diff review are separable lanes. The coordinator owns the candidate judgement and prevents any external publication.

## Documentation impact

### Decision Records

No new decision is needed; this item conforms release evidence to the existing product and distribution model.

### Specifications

Update release and installation conformance evidence only where current version truth is specified.

### Guides

Strengthen the releasing guide with candidate-version, clean-install, native-smoke, public-export, formula-handoff, and external-authority checks.

### Roadmap

A future release action is not implied by this item and should be created only when the user explicitly requests the concrete tag and publication.

## Discussion

### Locked local outcome

This record prepares and verifies a local release candidate only. It neither selects a concrete preview version nor authorises tag, push, GitHub release, tap update, website deployment, or any other external mutation.

### Development truth

Use an honest unreleased marker until a specific preview version is selected. A linked development checkout must be distinguishable from the last immutable release, and documentation must not instruct a tagged installation to use commands or schema absent from that tag.

### Release evidence

Complete the repository gate, command-surface alignment, manual rendering, clean installation, staged bootstrap smoke, selected native adapter smoke, public export validation, and release diff review before choosing the next `0.x` tag.

### Distribution handoff

After explicit release authority, the exact tag and checksum become the companion tap's input, and the website remains a downstream consumer of the immutable installer route rather than release authority.
