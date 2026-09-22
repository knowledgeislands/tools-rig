---
id: RIG-DIST-007
title: Align next preview
area: DIST
theme: distribution
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: da0ddd42bd0aa10d684af7f8f4e3cbdc970368d7
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-22T05:08:23Z
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

- [x] Replace the premature `1.0.0` development heading with `Unreleased` and keep released `0.x` history intact.
- [x] Make development-version output distinguishable from the last immutable release without choosing or publishing a release tag.
- [x] Separate README instructions for the latest release from local linked development and avoid claiming unreleased commands for `v0.2.0`.
- [x] Align executable version, help, manual, completions, changelog, installer fixtures, and release guide around one candidate-version procedure.
- [x] Add or record clean installation, staged bootstrap, selected native adapter, public export, and release-diff smoke evidence.
- [x] Prepare the formula and website handoff checklist using a future exact tag and checksum placeholder; do not execute either handoff.

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

## Review

### Delivered

A local post-v0.2.0 development candidate now identifies itself as `0.2.0+dev` without choosing the next preview. The changelog uses `Unreleased`, immutable v0.1.0 and v0.2.0 history remains intact, and release-facing surfaces distinguish v0.2.0 installation from linked development. No tag, push, GitHub release, tap change, website deployment, personal apply, or other external mutation occurred.

### Summary of changes

- Changed the sole authored version marker and assembled payload to `0.2.0+dev`; aligned top-level help, Zsh completion text, diagnostics fixtures, and sourceability fixtures.
- Aligned README, getting-started guide, manual, installer help, changelog, portability specification, and releasing guide around immutable v0.2.0 versus local linked development.
- Added exact-final-version validation to the release-tag workflow and Bats assertions covering version-bearing release surfaces and the disposable linked executable.
- Reviewed the complete candidate diff from `v0.2.0`: 72 committed changes plus this item, 81 files, 26,965 insertions, and 3,764 deletions, excluding the coordinator-owned batch ledger.

### Verification

- `rumdl check CHANGELOG.md README.md docs/guides/developer/releasing.md docs/guides/user/getting-started.md docs/specs/portability.md`
- `shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers`
- `bash -n bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers`
- `scripts/assemble-rig --check`
- `scripts/benchmark-rig` — diag 1s, show 2s, list 2s, status 5s; all within portable guards.
- `scripts/smoke-native-providers` — Homebrew, uv, mise, npm, chezmoi, and mas read-only probes passed.
- `bats tests/` — 222 tests passed, including isolated release-installer, public-export, and staged-bootstrap coverage.
- Disposable `./install.sh --link` prefix — executable and manual symlinks, `rig 0.2.0+dev`, Bash completion, Zsh completion, and manual lint passed.
- `mandoc -T lint man/rig.1` and rendered-manual inspection passed.
- `git diff --check v0.2.0 -- . ':(exclude)+/_BATCHES/RIG-BATCH-006.md'` passed.

### Outstanding concerns

The next exact `0.x` version remains deliberately unselected. A later, explicitly authorised release must replace the development marker, date the changelog entry, update immutable examples, rerun the full candidate gate, and separately obtain authority for tag, push, GitHub release, tap, and website actions. This item leaves the candidate uncommitted for coordinator review as required by the active batch.

### Post-change review

The candidate is internally consistent and preserves the release authority boundary. `0.2.0+dev` is valid SemVer build metadata, remains visibly different from the immutable v0.2.0 executable, and avoids implying that v0.3.0 is already selected. Native package managers were observed only through bounded read-only smoke operations; public export remained offline and privacy-filtered.

### Mini recap

Development truth, immutable-install truth, command surfaces, release procedure, and verification evidence now agree. The candidate is ready for human review; publication work is explicitly deferred.

## Done

Accepted 2026-09-22.

## Discussion

### Locked local outcome

This record prepares and verifies a local release candidate only. It neither selects a concrete preview version nor authorises tag, push, GitHub release, tap update, website deployment, or any other external mutation.

### Development truth

Use an honest unreleased marker until a specific preview version is selected. A linked development checkout must be distinguishable from the last immutable release, and documentation must not instruct a tagged installation to use commands or schema absent from that tag.

### Release evidence

Complete the repository gate, command-surface alignment, manual rendering, clean installation, staged bootstrap smoke, selected native adapter smoke, public export validation, and release diff review before choosing the next `0.x` tag.

### Distribution handoff

After explicit release authority, the exact tag and checksum become the companion tap's input, and the website remains a downstream consumer of the immutable installer route rather than release authority.
