---
id: RIG-DIST-005
area: DIST
title: Adopt website tool routes
theme: distribution
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: bb7715cb08b11f07b761fd308e7ecadda93abee3
created_at: 2026-09-17T21:05:58Z
updated_at: 2026-09-18T04:06:34Z
---

# RIG-DIST-005: Adopt website tool routes

## Goal

Keep the website's advertised `rig` version aligned with the release this repository recommends, and align Rig's version-pinning interface with other Knowledge Islands installers.

## Context

`knowledgeislands/ki-website` delivered `KI-WEB-SITE-007`, which gives every released Knowledge Islands tool the same two public routes: `/tooling/<tool>/` for people and `/install/<tool>` for machines. Both are generated from one website-owned registry.

Rig now has a product page at `https://knowledgeislands.info/tooling/rig/` and a stable installer endpoint at `https://knowledgeislands.info/install/rig`, which redirects to `https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.1.0/install.sh`. The registry currently advertises v0.1.0.

The website does not discover releases. It advances only when the releasing repository hands over a new version, keeping the public recommendation deliberate but allowing an omitted handoff to leave the site advertising an older release.

Rig's installer accepts an explicit version only through `RIG_VERSION`, while `ki` and `git-almanac` accept positional `vX.Y.Z`. The same inconsistency is tracked for `tools-ki` by `KI-TOOL-CLI-076`.

## Boundary

This work does not move release authority, installer behaviour, artifact hosting, or checksum verification to the website. The website remains an indirection layer over artifacts this repository publishes.

Do not remove the latest-release default from the installer. Pinning remains an explicit opt-in, and an unpinned `curl | sh` must continue to work.

## Current state

The website registry, `/tooling/rig/` page, and `/install/rig` redirect already advertise the released v0.1.0 installer. Rig's installer discovers the latest release when unpinned and accepts an explicit tag only through `RIG_VERSION`; it does not accept positional `vX.Y.Z`. Rig has no developer release guide naming the website registry update as a required post-release handoff.

## Steps

- [x] Extend `install.sh` to accept one optional exact `vX.Y.Z` positional version while retaining unpinned latest-release discovery, `RIG_VERSION`, and the separate `--link` mode; reject malformed versions and extra arguments before network or filesystem mutation.
- [x] Add installer tests for latest discovery, positional pinning, `RIG_VERSION` compatibility, positional precedence, invalid syntax, help output, and unchanged staged executable-and-manual validation.
- [x] Align installer usage, README installation examples, `rig(1)`, portability specification, and changelog with the positional version contract.
- [x] Add a developer release guide that makes the `ki-website` registry update a named follow-up after each recommended Rig release, carrying the exact version and immutable installer target.
- [x] Link the release guide from the developer guide index and verify the current website routes without changing website authority or state; both intended Knowledge Islands routes returned HTTP 404 while `rig.midnight.ninja` returned HTTP 200.

## Files touched

- `install.sh`
- `tests/rig.bats`
- `README.md`
- `man/rig.1`
- `CHANGELOG.md`
- `docs/specs/portability.md`
- `docs/guides/developer/README.md`
- `docs/guides/developer/releasing.md`

## Verify

- `shellcheck install.sh`
- `bash -n install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`
- Installer fixtures prove positional `v0.1.0` resolves only immutable v0.1.0 executable and manual URLs, malformed input performs no download or replacement, and an unpinned invocation still discovers the latest release.
- The website registry still reports Rig v0.1.0 at `/tooling/rig/` and `/install/rig` until a later release invokes the documented handoff.

## Dependencies / blocks

No build dependency remains. `knowledgeislands/ki-website` item `KI-WEB-SITE-007` is delivered, and the website already advertises the current Rig release. Future registry updates remain explicit cross-repository release follow-ups rather than an implementation dependency here.

## Documentation impact

### Decision Records

No new decision record is required. This work aligns an installer input with the established immutable-release distribution model and does not change release authority or trust boundaries.

### Specifications

Update the portability specification with the optional exact positional version, retained latest-release default, environment compatibility, and fail-before-mutation syntax rules.

### Guides

Add the developer release handoff procedure and align user-facing installation examples, manual syntax, and README guidance.

### Roadmap

No additional local work item is required. A future release creates a concrete website handoff in the receiving repository under its own workflow.

## Review

### Delivered

Rig's installer now supports exact positional release selection while preserving unpinned latest-release discovery, exact-version environment compatibility, local link mode, and staged executable-and-manual replacement. The developer documentation defines the cross-repository website handoff without moving release authority.

### Summary of changes

`install.sh` validates optional `vX.Y.Z` input before network access or destination mutation, gives it precedence over `RIG_VERSION`, validates discovered tags, and no longer falls back to `main`. Installer fixtures cover pinning, precedence, latest discovery, malformed input, local help, and staged artifact validation. README, manual, changelog, portability specification, and developer release guidance now describe the same contract.

### Verification

Focused installer tests, ShellCheck, Bash syntax validation, manual lint, and diff hygiene pass. The complete repository gate is recorded in the enclosing batch review. A read-only live check on 2026-09-18 found `https://knowledgeislands.info/tooling/rig/` and `https://knowledgeislands.info/install/rig` both returning HTTP 404; `https://rig.midnight.ninja/` returned HTTP 200.

### Outstanding concerns

The intended Knowledge Islands website routes do not currently expose the advertised v0.1.0 state described when this item was planned. That receiving-site deployment remains outside this repository and requires its own workflow. No website, GitHub setting, tag, release, or remote repository was mutated here.

### Post-change review

The implementation keeps immutable release selection explicit and avoids a mutable-branch fallback. Regression risk centres on installer URL selection and early validation; isolated fixtures cover both. The website handoff is documented as recommendation drift rather than a build dependency, so unavailable receiving routes remain visible without weakening Rig's release boundary.

### Mini recap

Rig can now install an exact release with `install.sh vX.Y.Z`, automation can retain `RIG_VERSION=vX.Y.Z`, and unpinned use still discovers the latest exact release. The intended website routes need receiving-site follow-through before they can truthfully advertise v0.1.0.

## Done

Accepted 2026-09-18 by Kris Brown on the review packet above.

## Discussion

### Release handoff

After publishing a release intended as the general recommendation, hand `ki-website` an item naming the exact version and immutable installer target with the new tag substituted. The website updates its registry entry and ships it.

The website verifies declared routes before deployment and reports upstream drift as a warning rather than a failure, making an outstanding handoff visible without breaking either repository's build.

### Version pinning

Keep `RIG_VERSION` for automation compatibility, but make `./install.sh vX.Y.Z` the documented interactive form. A positional version takes precedence over the environment value, matching the established `git-almanac` installer shape; both forms require an exact v-prefixed semantic version.

### Related work

The originating repository item is `knowledgeislands/ki-website` `KI-WEB-SITE-007`. It is delivered and does not block this item. The route contract is documented in that repository's `docs/guides/tool-routes.md`.
