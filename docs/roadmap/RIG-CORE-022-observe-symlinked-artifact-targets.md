---
id: RIG-CORE-022
title: Observe symlinked artifact targets
area: CORE
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 0603938d0c8041b3409193706aaac84d834ae9c1
created_at: 2026-09-22T00:00:00Z
updated_at: 2026-09-23T16:05:00Z
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

A repository-side check enumerating `/usr/local/bin` and resolving each link was written in `krisb/dotfiles` and then removed, on the grounds that a general defect in Rig should not acquire a local answer. It could report a dangling link, but never a command line that was never created, because that expectation has nowhere to live but the artifact list. That workstation now leaves the surface unobserved until this lands.

The approved implementation follows at most 40 declared leaf-link hops with the native `readlink` already used elsewhere by Rig. Relative targets resolve from the link's containing directory. A missing resolved target is `missing`; a target that resolves to a damaged application is `drifted`; a cycle or unreadable link is `unavailable`; and existing non-file, non-directory targets remain unavailable. Resolution is not constrained to the link's parent root because the artifact declaration explicitly names the trusted expectation, but the resolved target must independently pass the existing artifact checks before it can be `present`. ADR-RIG-007 records this revised evidence boundary.

## Steps

- [x] Resolve a declared artifact that is a symlink to its target, bounding the resolution against cycles and an unreadable path.
- [x] Report a link whose target does not exist as `missing`, carrying the resolved target in the detail rather than the word `unsafe`.
- [x] Observe a resolved target with the existing tests, so a link into a damaged application bundle reports `drifted` exactly as the bundle would.
- [x] Keep `unavailable` for a link that cannot be resolved, and say in the detail that resolution failed rather than that the artifact is unsafe.
- [x] Decide and document whether a resolved target is constrained to any root, and if so express it as an observation rather than a refusal.
- [x] Add fixtures for a link into a healthy bundle, a dangling link, a link into a damaged bundle, and a cyclic link.
- [x] Align the user command guide, the state Specification, the manual, and the changelog with the revised artifact contract.

## Delegation

No delegation is planned. Symlink resolution, artifact classification, adversarial fixtures, Decision Record, and consumer documentation form one tightly coupled safety change.

## Files touched

- `src/rig/20-orchestration.bash` for artifact observation, and the assembled `bin/rig`.
- `tests/rig-artifacts.bats` for the link fixtures.
- `docs/decisions/ADR-RIG-007-resolved-artifact-link-evidence.md` and `docs/decisions/README.md` for the evidence boundary.
- `docs/guides/user/commands.md`, `docs/specs/state.md`, `man/rig.1`, and `CHANGELOG.md` for the revised artifact contract.
- This roadmap record for delivery evidence.

## Verify

- Bats fixtures covering the four cases above, including the dangling case that a cask upgrade produces.
- The complete repository verification gate: assembly drift, `bash -n`, ShellCheck, full Bats, manual lint, documentation lint, benchmarks, native-provider smoke, and `ki repo audit`.
- On a machine declaring real command lines as artifacts, `rig doctor`'s finding count is unchanged for the healthy ones, and a deliberately broken link is reported against its owning tool.

## Dependencies / blocks

No delivery dependency. Sibling to `RIG-CORE-021`: both exist because a local repository had to compensate for an observation Rig makes dishonestly, and together they retire `bin/workstation_surfaces` entirely.

## Documentation impact

### Decision Records

Add ADR-RIG-007 to record why a declared artifact link is trusted as an expectation but its resolved target must still provide the installation evidence.

### Specifications

The state Specification should say what evidence an artifact observation rests on when the declared path is indirect, and that resolution failure is its own state rather than a synonym for unsafe.

### Guides

Explain that a command line may now be declared as an artifact, and what each state asserts about a link.

### Roadmap

Record the delivered evidence here, and note the downstream repository-side check that this work retires.

## Review

### Delivered

A declared artifact that is a symbolic link is now observed through the target it resolves to, so the command line an application installs into a shared executable directory is declarable state. The artifact declaration schema, the state vocabulary, every non-link artifact observation, and Rig's refusal to create or repair anything are unchanged.

### Summary of changes

- `rig_resolve_artifact_link` follows at most 40 leaf links with the native `readlink`, resolving a relative target against the link's own directory, and fails closed on a cycle, an exhausted bound, or an empty target.
- Resolution is not constrained to any root. The declaration is the trusted expectation; the resolved target then runs the existing existence, file-kind, and application-bundle tests before it can be `present`, so resolution cannot manufacture a healthy answer.
- A dangling link is `missing`, a link into a damaged bundle is `drifted`, a target that is neither a regular file nor a directory stays `unavailable` with `unsafe`, and a link that cannot be resolved is `unavailable` with the new `unresolved-link` detail rather than `unsafe`.
- Where a link was followed, `rig_artifact_home_form` renders the resolved target beside the declared path in the detail, so the indirection is reviewable instead of silent.
- The blanket `-L` refusal that set `unavailable`/`unsafe` at rank 3 ahead of every other test is gone.

### Verification

- `tests/rig-artifacts.bats` covers a relative link to a regular file, a link into a healthy application, a dangling link that names its resolved target, a link into a damaged bundle, a cyclic link, and a link to a FIFO that must not become `present`.
- Full gate green: `scripts/assemble-rig --check`, ShellCheck, `bash -n`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1`, and 235 Bats cases.

### Outstanding concerns

Only the leaf link is followed; a symlinked intermediate directory component is still resolved by the kernel rather than reported. That is the same footing a directly declared path has, so it is deliberate rather than a gap. The `->` detail form is human output, not a parsing contract, per `RIG-CLI-010`.

### Post-change review

This retires the repository-side check in `krisb/dotfiles` that enumerated `/usr/local/bin` and resolved each link: that check was removed on the grounds that a general defect in Rig should not acquire a local answer, and the answer now lives here. Together with `RIG-CORE-021` it retires `bin/workstation_surfaces` entirely. The absence case the local check could never cover — a command line an application never installed — is now reportable, because the artifact list can hold the expectation.

### Mini recap

A healthy `code` or `subl` now reads `present` instead of `unavailable`, a link left dangling by an upgrade says which target went missing, and nothing a link points at can report healthy without passing the same tests a direct path passes.

## Discussion

The position worth testing is whether a symlink is weaker evidence than a path. Both are names the filesystem resolves; the difference is only that one resolves in two steps. Refusing the second step does not protect the reader, because the alternative on offer is not a stronger observation — it is no observation at all, and the surface stays unmanaged. Reporting what the link resolved to is what makes the indirection reviewable.

The absence case is the larger prize. A check that enumerates what exists can never report what was never created; only a declaration of expectation can, and the catalogue is already that declaration. GitHub Desktop ships a `github.sh` that nothing links, and no amount of local checking can notice, because the only honest place to say "this tool should expose a command line" is the artifact list that today refuses to hold it.
