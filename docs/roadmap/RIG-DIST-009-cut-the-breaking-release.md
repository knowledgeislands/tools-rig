---
id: RIG-DIST-009
area: DIST
title: Cut the breaking release
theme: distribution
horizon: triage
status: done
intake_disposition: rejected
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-10-02T08:17:23Z
---

## Goal

Publish the completed Rig finishing round as a clearly documented new 0.x release, with compatible consumer migrations and a verified installation path.

## Context

The user requested a new 0.x release after the finishing work. The command cutover and release preparation are committed locally, and version 0.4.0 is the current candidate, but no push, tag or GitHub release has occurred. Publication still needs current migration evidence, the complete candidate gate and the release guide's CI and immutable-install checks.

## Boundary

Disposing of this tracking item does not publish Rig, edit dotfiles, the website or the Homebrew tap, install software on the workstation, or bypass another repository's review/apply policy. The release remains a separate action under the release guide.

## Intake disposition

Outcome: rejected. No retained roadmap target applies.

Rationale: The release remains intended, but it no longer needs a separate roadmap delivery item. The authoritative publication checklist and safety gates are in [Release Rig](../guides/developer/releasing.md). The local 0.4.0 candidate at `38542ba` is preparation, not a published release; push, tag, CI and GitHub release steps are still outstanding and must follow the guide with publication authority.

Approval: Kris explicitly requested removal of RIG-DIST-009 on 2026-10-02, with release to follow once the remaining work is settled. This closes only the tracking record, not the release obligation.

## Done

Disposed 2026-10-02 by Kris as rejected on the intake evidence above.

## Discussion

### Release remains separate

The release guide governs final candidate review, compatible consumer migration, CI, tag publication, immutable installation verification and downstream handoff. Removing this work item is not evidence that any of those steps occurred.
