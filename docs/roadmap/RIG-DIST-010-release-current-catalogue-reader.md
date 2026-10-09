---
id: RIG-DIST-010
area: DIST
title: Release current catalogue reader
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-09T15:54:23Z
updated_at: 2026-10-09T15:54:23Z
---

# RIG-DIST-010: Release Current Catalogue Reader

## Goal

The next Rig release reads Kris's current chezmoi-rendered catalogue, so a machine that installs Rig from the Homebrew tap can run `rig show`, `rig doctor` and `rig apply` against it. Sol, the Mac Studio, is the first such machine.

## Context

Raised by ki-arcadia-principal in the rig.mac-studio-bootstrap thread on 2026-10-09. Kris approved preparing a newer release for sol (Decision 17, item 3) and kept publishing, the tap update included, as a separate decision.

Sol runs Homebrew `rig` 0.4.0, from tag `v0.4.0`. It rejects the current catalogue at the first CodexBar CLI ownership field:

```text
rig: error: /Users/krisbrown/.config/rig/conf.d/10-applications.toml:249: unknown field 'cli.codexbar.source' in [tool.codexbar]
```

Those fields arrived with [RIG-CORE-040](RIG-CORE-040-manage-app-clis.md) after `v0.4.0`. The laptop runs `0.4.0+dev` from this checkout and reads the catalogue. The catalogue also now ships the per-machine `core`, `laptop` and `studio` profiles, which a release must resolve. Until a release ships, this record blocks Rig apply on sol.

## Boundary

- **In:** choosing the version, aligning the runtime version, changelog baseline, manual and install examples, and verifying the candidate against the live catalogue and a rendered `studio` profile.
- **Out:** the personal catalogue and profile split, which the chezmoi source owns; the Homebrew formula, which `homebrew-tap` updates from the published release.

## Discussion

- **Version.** The unreleased changes since `v0.4.0` are the app CLI fields, a new catalogue capability, and the removal of retired-command migration hints. Both fit a pre-1.0 minor release, `v0.5.0`.
- **Publication.** Pushing `main`, tagging and publishing the GitHub release need Kris's separate approval. Publishing triggers the tap's formula update.
