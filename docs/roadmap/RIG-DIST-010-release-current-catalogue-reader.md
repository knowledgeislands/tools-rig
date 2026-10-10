---
id: RIG-DIST-010
area: DIST
title: Release current catalogue reader
kind: deliver
purpose: capability
project: mac-studio-bootstrap
component: distribution
status: done
blocks: []
blocked_by: []
baseline_ref: 2d84bd94aca70cffbdb4f208c7f0d43fe3866801
created_at: 2026-10-09T15:54:23Z
updated_at: 2026-10-10T16:40:00Z
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

Those fields arrived with RIG-CORE-040 after `v0.4.0`. The laptop runs `0.4.0+dev` from this checkout and reads the catalogue. The catalogue also now ships the per-machine `core`, `laptop` and `studio` profiles, which a release must resolve. Until a release ships, this record blocks Rig apply on sol.

## Boundary

- **In:** choosing the version, aligning the runtime version, changelog baseline, manual and install examples, and verifying the candidate against the live catalogue and a rendered `studio` profile.
- **Out:** the personal catalogue and profile split, which the chezmoi source owns; the Homebrew formula, which `homebrew-tap` updates from the published release.

## Current state

Rig v0.5.0 is published as an immutable GitHub release at tag `v0.5.0` (`a0cafaa`). The Homebrew tap's formula points at it, and sol runs Homebrew `rig 0.5.0`. With its `rig.toml` re-rendered from chezmoi, `rig show` and `rig status` work on sol. The checkout is back at `0.5.0+dev`.

## Steps

- [x] Choose the version, `v0.5.0`, and align the runtime version, manual, README and install examples with the candidate.
- [x] Verify the candidate against the live catalogue and a rendered `studio` profile, with `v0.4.0` as the rejecting control.
- [x] Publish the release under Kris's separate approval, and let the tap advance its formula.
- [x] Upgrade sol to the release and confirm it reads the current catalogue.
- [x] Return the checkout to `0.5.0+dev` after publication.

## Files touched

`src/rig/00-runtime.bash`, the assembled `bin/rig`, `README.md`, `docs/guides/user/getting-started.md`, `docs/guides/developer/releasing.md`, `man/rig.1`, `tests/rig.bats` and this work record.

## Verify

The complete developer gate passes on the candidate. The candidate reads the live catalogue and a rendered `studio` profile, and `v0.4.0` rejects the same render. On sol, `rig --version` reports `rig 0.5.0`, and `rig show` and `rig status` exit 0.

## Dependencies / blocks

Publication needed Kris's separate approval, given in Decision 19 of the mac-studio-bootstrap thread. Sol's `rig.toml` re-render belongs to the chezmoi source repository, not to this record.

## Documentation impact

### Decision Records

None. A pre-1.0 minor release follows the existing release-on-demand policy.

### Specifications

None. The release ships behaviour that its own records already specified.

### Guides

The user and developer guides, the README and the manual name `v0.5.0` as the latest immutable release.

### Roadmap

None. The Rig apply run on sol belongs to the mac-studio-bootstrap Project, not to a Rig record.

## Review

### Delivered

Rig v0.5.0 reads Kris's current chezmoi-rendered catalogue, the `cli.codexbar.*` fields and the per-machine profiles included. A machine that installs Rig from the Homebrew tap can now use it. The personal catalogue, the profile split and the tap formula stayed with their owners. Baseline `2d84bd9`; delivery `a0cafaa` (tag `v0.5.0`) and `7f6d7d6` (return to `0.5.0+dev`).

### Change Summary

`a0cafaa` set `RIG_VERSION` to `0.5.0`, reassembled `bin/rig`, and aligned the README, getting-started guide, releasing guide, manual and release-surface tests with the candidate. `7f6d7d6` restored `0.5.0+dev` and named `v0.5.0` as the latest immutable release in those surfaces. The tap's own automation merged homebrew-tap pull request 31, which advanced its formula. No deviation from the boundary.

### Verification

- Candidate gate: 456 Bats tests passed, two skipped for lack of `tomllib`; ShellCheck, `bash -n`, `assemble-rig --check`, `mandoc -T lint`, `git diff --check`, the benchmark and the native-provider smoke checks passed. `ki repo audit --repo .` showed no failures.
- Against the live catalogue, `rig show` exited 0. Against a rendered `studio` profile, `rig show` and `rig doctor` passed (206 pass, 0 fail), and `v0.4.0` rejected the same render at `cli.codexbar.source`.
- Publication: branch and tag CI passed, the release is immutable, and the installer from `v0.5.0/install.sh` reported `rig 0.5.0` with its manual resolving.
- Sol: `brew upgrade rig` gave `rig 0.5.0`. Once its `rig.toml` was re-rendered from chezmoi, `rig show` and `rig status` worked, and `rig doctor` and the apply history ran under 0.5.0.
- Post-release: 456 Bats tests passed, and the repository audit was unchanged at no failures.

### Outstanding concerns

None for Rig. Sol's first `rig show` failed on a stale, pre-profile `rig.toml`; that was a chezmoi rendering gap, closed by the re-render. Findings from sol's apply runs belong to the mac-studio-bootstrap Project and to their own Rig records.

### Post-change review

The goal is met: the published reader accepts the current catalogue on the first tap-installed machine. Scope stayed within version alignment, documentation and verification. The regression risk is low, because the runtime change since the reviewed candidate gate is the version string alone.

### Mini recap

v0.5.0 is released, on the tap and running on sol, where it reads the current catalogue. A first `rig show` on a newly provisioned machine can fail when its rendered `rig.toml` predates the profile split. That lesson belongs in the chezmoi rollout checklist rather than in Rig.

## Done

Accepted 2026-10-10 by Kris Brown on the review packet above (mac-studio-bootstrap decisions log, Decision 32: "RIG-DIST-010 'accepted' - accept through ki-accept").

## Discussion

- **Version.** The unreleased changes since `v0.4.0` are the app CLI fields, a new catalogue capability, and the removal of retired-command migration hints. Both fit a pre-1.0 minor release, `v0.5.0`.
- **Publication.** Pushing `main`, tagging and publishing the GitHub release need Kris's separate approval. Publishing triggers the tap's formula update.

### Lifecycle

The record stayed in triage while the release was prepared and published under Decisions 17 and 19. After Kris accepted it in Decision 32, the adoption, plan, review packet and closure landed together, recording delivery that had already happened.
