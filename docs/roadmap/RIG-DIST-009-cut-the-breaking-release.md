---
id: RIG-DIST-009
area: DIST
title: Cut the breaking release
theme: distribution
horizon: next
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-30T22:25:21Z
---

## Goal

Publish the completed Rig finishing round as a clearly documented new 0.x release, with compatible consumer migrations and a verified installation path.

## Context

The user requested release after the remaining reliability, unattended-contract and live-display work, while repair-lifecycle design stays deferred. The command cutover is implemented locally and is a much larger break than the export-only change described by this item's previous plan. Publication must cover removed verbs, retired Homebrew configuration, reviewed capture and initialization, report paths and host wrappers.

The release plan returns from Ready to draft because its candidate contents and migration evidence have changed. Do not execute its former export-only checklist as though it covers this release.

## Boundary

This item prepares and publishes Rig only. It does not edit dotfiles, the website or the Homebrew tap, install software on the workstation, or bypass another repository's review/apply policy. Repair-lifecycle design is explicitly outside this release. Do not publish before the finishing scope, exact version, candidate verification and coordinated consumer migrations are settled.

## Current state

Read-only local and remote tag inspection on 2026-09-30 found v0.1.0 and v0.2.0 only. The authored runtime still reports 0.3.0 and the changelog carries a dated 0.3.0 entry without a corresponding tag. Installer examples naming v0.3.0 therefore need correction; a changelog entry is not evidence of a published release. Recheck remote state before selecting the candidate.

The CLI cutover is committed locally, not pushed by this delivery. Its latest suite has 311 tests; the final release must use the actual post-finishing test count and evidence rather than preserving a stale count. The previously identified website export consumer and chezmoi's catalogue, Bundle machinery, scheduled commands and report readers need fresh compatibility evidence.

## Steps

- [ ] Confirm delivery and review of failure history, Dock observation, narrowed unattended handling and the agreed live display; record repair-lifecycle deferral explicitly.
- [ ] Recheck local and remote release state and select the exact next 0.x version. Keep 0.4.0 as the existing candidate, not a claim that a tag exists.
- [ ] Verify the website export consumer's current invocation and the reviewed chezmoi migration plan, including package-intent coverage and wrapper/report compatibility; coordinate deployment order without applying another repository's changes here.
- [ ] Reconcile the unpublished 0.3.0 changelog material and Unreleased changes into accurate release notes, clearly identifying all breaking command and configuration migrations.
- [ ] Set the selected authored runtime version, regenerate bin/rig, and align README, manual and immutable installer examples with the intended tag.
- [ ] Run the complete local gate and the release guide's isolated installation/export checks; verify the final candidate on the supported CI platforms before publication.
- [ ] Review the exact candidate commit, migration evidence and publication scope, then create and publish the selected annotated tag and GitHub release under the user's conditional release instruction.
- [ ] Verify the immutable installer and clean-install version/manual, then hand the exact version and URL to the tap and website owners through their own workflows.

## Files touched

The authored runtime version, generated executable, changelog, README, getting-started guide, manual and this record. No feature implementation or cross-repository edits belong in this release unit.

## Verify

Use the complete gate in AGENTS.md and [the release checklist](../guides/developer/releasing.md). The candidate version, assembled executable, release notes, intended tag and installer URLs must agree. Test installation in a disposable directory rather than replacing the operator's executable. A tag must be absent before creation and resolve to the verified candidate afterwards. Confirm migration examples against the actual CLI and inventory all retired commands/configuration fields in known consumers.

## Dependencies / blocks

The user selected release last, after the finishing items, not after the deferred repair investigation. This is a release sequencing condition, not an invented build dependency. Consumer migration and deployment coordination are external publication preconditions; source preparation can precede host deployment, but the new Rig and compatible host configuration must be rolled out in an explicit order.

## Documentation impact

### Decision Records

No new runtime authority or provider model is selected by release; those decisions belong to their implementation records.

### Specifications

Ship the verified final specifications without introducing new behavior in a version bump.

### Guides

Align immutable installation examples, the breaking-migration guide and the actual release artifact. Describe the compatible deployment order for host configuration without claiming it was applied.

### Roadmap

Retain the repair investigation in Waiting for. Close this item only after publication and immutable-install verification, not merely after preparing release notes.

## Discussion

### A new 0.x version

The user confirmed another 0.x release rather than a 1.0 stability declaration. The existing candidate is 0.4.0, which avoids reusing the historical unpublished 0.3.0 entry for a materially different snapshot. Verify that the number remains free and select it explicitly at release preparation; do not retroactively publish an extra historical preview.

### Migration is part of release readiness

Changing the executable does not update personal Rig declarations, native manifests, launchd wrappers or downstream export consumers. ChezMoi's source migration must retain intentional formulae, casks, App Store apps, extensions and any necessary native bootstrap semantics before Brewfile removal. Source review and live application are separate gates; a package inventory mismatch must not be hidden by deleting the old authority first.

### Immediate host compatibility and Brewfile retirement

Read-only source inspection found that the active local Rig executable is a development symlink to this checkout, while the personal provider configuration still names the retired Homebrew manifest and its scheduled wrapper still calls update. The mismatch already exists locally; do not defer it until publication or claim that leaving chezmoi untouched makes the linked runtime unchanged. The source owner must prepare compatible configuration and wrapper changes, then obtain scoped diff-review approval before applying them.

The source Brewfile contains 73 formulae, 60 casks, nine App Store entries, 39 VS Code extensions and nine taps. Rig already declares the cask/App Store acquisitions and seven formulae. The 66 unmatched formula entries include resolver dependencies and an overlapping acquisition route; they are not automatically 66 intentional tools to adopt. Existing dotfiles item DOTFILES-UE-036 owns formula intent and DOTFILES-UE-027 owns honest rationale. Preserve each intentional acquisition before deleting the old inventory.

Extensions and tap/trust choices need native source-owned homes rather than another Rig core feature. Prefer an explicit native extension list/helper and reviewed Homebrew prerequisite metadata/procedure; do not create implicit chezmoi hooks or discard unmatched taps. Reconcile source tests, software-lifecycle guidance and audits as well as the files themselves. Preserve the scheduled resource identity, wrapper path and logs while changing its command/report contract, so migration does not replace launchd resources unnecessarily. Remove the managed Brewfile target through chezmoi's removal mechanism only after its remaining intent is accounted for.

### Publication boundary

The current instruction requests release after the last agreed work is finished. It does not authorise publishing an incomplete candidate, pushing unrelated commits, changing another repository, or bypassing required verification. Recheck that condition and the exact ref scope at the publication boundary.
