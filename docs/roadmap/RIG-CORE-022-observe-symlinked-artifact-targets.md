---
id: RIG-CORE-022
title: Observe symlinked artifact targets
area: CORE
theme: orchestration
horizon: next
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-22T00:00:00Z
updated_at: 2026-09-22T00:00:00Z
---

# Observe Symlinked Artifact Targets

## Goal

Let a declared artifact that is a symlink be observed through its target, so the command lines applications install into `/usr/local/bin` become declarable state rather than a surface Rig cannot describe.

## Context

Artifact observation refuses a symlink outright: any declared path that is a link is reported `unavailable` with detail `unsafe`, ahead of every other test. The reasoning is sound as far as it goes — a link can be repointed, so the link itself is not evidence of what is installed.

The consequence is that an entire class of real installed state is undeclarable. Applications that ship a command line install it as a symlink from `/usr/local/bin` into their bundle — `code`, `gitup`, `subl` and their peers. Declaring one does not track it; it reports the owning tool as `unavailable`, which is why five such paths once took a healthy machine from four findings to nine and had to be reverted.

That leaves the surface unobserved in both directions. An upgrade that moves an executable inside its bundle leaves the link dangling and nothing says so, and a command line an application never installed is invisible because there is nowhere to declare that it ought to exist.

The refusal also does not buy the safety it appears to. Rig already trusts a declared path to be the artifact it says it is; resolving the link and reporting the resolved target as the evidence puts the claim on exactly the same footing as a direct path, and makes the indirection visible instead of fatal.

## Boundary

This work changes how a declared artifact that is a symlink is observed and what evidence the observation reports. It does not change the artifact declaration schema, introduce a separate command-line resource kind, make Rig install or repair a link, follow a link outside the artifact it resolves to, or relax any existing state for a non-link artifact. Resolution must not become a way for an unreadable or escaping target to report `present`.

## Current state

`rig_observe_tool_artifacts` in `src/rig/20-orchestration.bash:1694` tests `[ -L "$artifact" ]` first and sets `candidate_state=unavailable`, `candidate_detail=unsafe`, `candidate_rank=3` — the highest rank in the function, so a linked artifact dominates every other finding for that tool. Nothing downstream distinguishes a link that resolves into a real bundle from one that resolves nowhere, because resolution never happens.

The reporting workstation carries a repository-side check, `bin/workstation_surfaces` in `krisb/dotfiles`, that enumerates `/usr/local/bin`, resolves each link, and reports one that dangles or one whose bundle no declared tool claims. It exists only because this observation is missing, and its own documented limit — that it cannot see a command line that was never created — is a limit only because the expectation has nowhere to live. Declaring the link as an artifact is that expectation, so this work removes the local check and its blind spot together.

## Steps

- [ ] Resolve a declared artifact that is a symlink to its target, bounding the resolution against cycles and an unreadable path.
- [ ] Report a link whose target does not exist as `missing`, carrying the resolved target in the detail rather than the word `unsafe`.
- [ ] Observe a resolved target with the existing tests, so a link into a damaged application bundle reports `drifted` exactly as the bundle would.
- [ ] Keep `unavailable` for a link that cannot be resolved, and say in the detail that resolution failed rather than that the artifact is unsafe.
- [ ] Decide and document whether a resolved target is constrained to any root, and if so express it as an observation rather than a refusal.
- [ ] Add fixtures for a link into a healthy bundle, a dangling link, a link into a damaged bundle, and a cyclic link.
- [ ] Align the user command guide, the state Specification, the manual, and the changelog with the revised artifact contract.

## Files touched

- `src/rig/20-orchestration.bash` for artifact observation.
- `tests/` for the four link fixtures.
- `docs/guides/user/commands.md`, `docs/specs/state.md`, `man/rig.1`, and `CHANGELOG.md` for the revised artifact contract.
- This roadmap record and the issue ledger for delivery evidence.

## Verify

- Bats fixtures covering the four cases above, including the dangling case that a cask upgrade produces.
- The complete repository verification gate: assembly drift, `bash -n`, ShellCheck, full Bats, manual lint, documentation lint, benchmarks, native-provider smoke, and `ki repo audit`.
- On a machine declaring real command lines as artifacts, `rig doctor`'s finding count is unchanged for the healthy ones, and a deliberately broken link is reported against its owning tool.

## Dependencies / blocks

No delivery dependency. Sibling to `RIG-CORE-021`: both exist because a local repository had to compensate for an observation Rig makes dishonestly, and together they retire `bin/workstation_surfaces` entirely.

## Documentation impact

### Decision Records

Consider one. Refusing symlinks was a deliberate position about what counts as evidence of an install, and resolving them revises that position rather than fixing an oversight — which is the kind of change a Decision Record exists to carry.

### Specifications

The state Specification should say what evidence an artifact observation rests on when the declared path is indirect, and that resolution failure is its own state rather than a synonym for unsafe.

### Guides

Explain that a command line may now be declared as an artifact, and what each state asserts about a link.

### Roadmap

Record the delivered evidence here, and note the downstream repository-side check that this work retires.

## Discussion

The position worth testing is whether a symlink is weaker evidence than a path. Both are names the filesystem resolves; the difference is only that one resolves in two steps. Refusing the second step does not protect the reader, because the alternative on offer is not a stronger observation — it is no observation at all, and the surface stays unmanaged. Reporting what the link resolved to is what makes the indirection reviewable.

The absence case is the larger prize. A check that enumerates what exists can never report what was never created; only a declaration of expectation can, and the catalogue is already that declaration. GitHub Desktop ships a `github.sh` that nothing links, and no amount of local checking can notice, because the only honest place to say "this tool should expose a command line" is the artifact list that today refuses to hold it.
