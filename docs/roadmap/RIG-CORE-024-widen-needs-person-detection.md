---
id: RIG-CORE-024
area: CORE
title: Harden unattended upgrade contract
theme: orchestration
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-10-01T04:07:40Z
---

## Goal

An unattended upgrade distinguishes known work requiring a person from ordinary native failures without hiding independent results or promising that arbitrary native programs cannot prompt.

## Context

The user approved simplifying this item after the command cutover. Its former motivating defect was a mixed Homebrew Bundle task in which one App Store failure could mask other entries. Declaration-scoped upgrades have removed that task shape. Selected App Store bindings now receive individual unavailable results, while independent upgrades continue.

The old optional provider action, manifest exclusions and custom lifecycle extension are no longer justified by that removed defect. The residual work is an honest, tested unattended contract, not a universal credential detector.

## Boundary

Do not add a provider-protocol action, custom upgrade dispatch, schema field, manifest parser, credential probe, retry loop or process supervisor. Do not skip every cask or classify failures by stderr text. Do not modify workstation schedules, credentials, packages or chezmoi source here.

## Current state

The lifecycle preflight conservatively excludes selected App Store bindings when unattended, provider stdin is redirected from /dev/null, and Homebrew receives its noninteractive environment flag. Ordinary failures and successful independent tasks remain distinct and the unattended report is written to last-upgrade. The mixed App Store/uv fixture covers the known exclusion, but not a failed cask and successful formula within the same native manager.

Closing stdin prevents stdin questions from waiting for input. It does not guarantee that subprocesses never use a controlling terminal, graphical authentication or an independent credential helper.

## Steps

- [ ] Reconcile the unattended specification, manual, guide, lifecycle source comment and stdin-test title with declaration-scoped upgrades. Replace the unprovable never-blocks claim with the specific stdin-EOF guarantee; regenerate the executable for the comment change.
- [ ] Preserve the existing App Store exclusion and ordinary failure semantics without introducing a protocol or schema extension.
- [ ] Add an isolated mixed Homebrew fixture with a skipped App Store entry, failed cask upgrade and successful formula upgrade; assert independent outcomes, exit status, persisted rows, stdin handling and noninteractive environment.
- [ ] Prove the fixture never dispatches Bundle, cleanup or the excluded App Store operation; retain interactive and dry-run coverage.
- [ ] Run the full repository gate and record a review packet stating both the proven contract and its native-program limitation.

## Files touched

`tests/rig-lifecycle.bats`, `docs/specs/orchestration.md`, `docs/guides/user/unattended-updates.md`, `man/rig.1`, the inaccurate unattended comment in `src/rig/40-publication-lifecycle.bash`, and generated `bin/rig`. Runtime behavior changes are limited to a demonstrated deviation from the preserved contract.

## Verify

Use inert provider stubs and isolated state homes. Assert the App Store target is not invoked and reports unavailable/interactive-required, the cask reports failed/exit:N, and the independent formula reports completed/upgrade. All three rows must persist in last-upgrade with aggregate exit 1. Interactive mode permits the App Store operation; dry-run changes no state or packages. Run the complete AGENTS.md gate, with Bats stdin redirected from /dev/null. No live scheduled or interactive upgrade is a verification step.

## Dependencies / blocks

No missing build dependency: the command cutover already exists. This complements [apply failure history](RIG-CORE-035-surface-permanent-apply-failures.md), but does not block it. Both precede the live-display finishing batch by delivery priority rather than a dependency edge.

## Delegation

One bounded worker owns lifecycle regression tests and related contract clarification. The coordinator owns roadmap state, integration, independent review, assembly when needed and the aggregate gate. No live provider mutation or worker Git writes.

## Documentation impact

### Decision Records

No protocol expansion or new authority decision; preserve the existing native-provider execution boundary.

### Specifications

Clarify unattended guarantees, the known exclusion and ordinary native failures without expanding the outcome vocabulary.

### Guides

Explain native interaction limits and investigation of failures. Remove obsolete Bundle assumptions rather than recommending another wrapper.

### Roadmap

This narrowed item replaces the mixed-manifest implementation plan. A future explicit interactivity declaration would need a separately evidenced product decision.

## Discussion

### Readiness

Prepared for Ready under the user's 2026-10-01 request. Scope, implementation boundary and verification are fixed below; this planning transition does not start implementation or authorise live-machine changes.

### Why the original design was withdrawn

The old proposal required custom lifecycle support and a protocol for excluding entries from opaque manifests. The command cutover removed the Homebrew manifest task that motivated those additions. Rebuilding that protocol would preserve complexity around a problem the new boundary eliminated.

### Honest detection limits

Known interactivity and an unexplained failure are different facts. Preserve the conservative App Store policy without inferring credential requirements for every cask or private source. Standard-input isolation is not process supervision; broader preflight work should follow a demonstrated remaining case.

### Host migration boundary

The user separately requested replacing chezmoi's Brewfile and Bundle machinery with Rig declarations. That source migration must prove package-intent coverage, preserve any non-package stanzas and respect chezmoi's diff-review/apply boundary. Removing the Bundle workaround does not prove App Store update detection accurate; still-relevant host observation work retains its owner.
