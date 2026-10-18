---
id: KI-TOOL-RIG-CORE-052
area: CORE
title: Doctor service launch prerequisites
purpose: capability
theme: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 7cbe3407552b21ec395223dad7b6b2aef5c108b7
created_at: 2026-10-14T06:44:45Z
updated_at: 2026-10-18T04:15:00Z
---

# Doctor Service Launch Prerequisites

## Goal

`rig doctor` checks that each selected service or scheduled job can be launched: its program exists and is executable, and its declared working directory exists. When one is missing, doctor reports that as the finding and its cause, so a port the service owns is not left to explain the failure as only `not-listening` with `action=start-owner`.

## Context

[Operational resource state](../specs/state.md#rig-state-018--operational-resource-state) has doctor observe every selected service through the provider registry, and [private port state](../specs/state.md#rig-state-026--private-port-expected-versus-observed-state) turns a missing listener into `action=start-owner` in [observation](../../src/rig/22-observation.bash). Neither looks at whether the declared `program` or `working-directory` exists on the machine.

On 14 October 2026 the Mac Studio `sol` received the new `~/workspaces/<group>/<repo>` layout in its configuration before its repositories were moved into it. The Observatory's launch agent was rewritten to run from `~/workspaces/knowledge-islands/apps-observatory.local/apps/site`, which did not exist, so launchd failed every start with status 78 (spawn failed) and the service had been down since the machine's restart. Doctor reported the service as present and gave a single finding, `port.observatory: missing (not-listening)`, with `action=start-owner`. Starting the owner could never work; cloning the repository into the new layout was the fix.

## Boundary

- In: a read-only existence check of each selected launchd and systemd resource's program and working directory, with `~` expanded the way the adapters expand it; a doctor finding naming the missing path and an action to restore it; attributing a dependent port finding to that cause; specifications and isolated tests on both platforms.
- Out: creating the missing path, cloning repositories or restarting the service; reading launchd's or systemd's own failure status; validating a program's arguments or its runtime dependencies.

## Current state

Delivered locally to Awaiting review on 18 October 2026 by the tools-burndown run, from baseline `7cbe340`, against fixtures only; see Review.

## Steps

- [x] Add a read-only `rig_resource_launch_blocker` for selected services and scheduled jobs: the first `program` value, home-expanded, when it is a path, must exist and be executable; a declared `working-directory` must be a directory.
- [x] Report a blocked resource as its own doctor finding, `unlaunchable`, with the reason and path, `owner=configuration` and `action=restore-launch-path`, counted once with any other finding for the same item.
- [x] Attribute a missing listener on a port owned by a blocked service or scheduled job to that cause, `cause:owner-unlaunchable` with `action=restore-owner-launch-path`, instead of `start-owner`.
- [x] Add RIG-STATE-046, the manual text, the changelog and an isolated launchd fixture test; assemble and run the gate.

## Files touched

- [Observation](../../src/rig/22-observation.bash) and the assembled [executable](../../bin/rig).
- [Test isolation](../../tests/helpers/isolate.bash), [Rig tests](../../tests/rig.bats) and [Homebrew authority tests](../../tests/rig-homebrew-authority.bats).
- [State specification](../specs/state.md), [manual](../../man/rig.1) and [changelog](../../CHANGELOG.md).

## Verify

- Isolated launchd fixture with a required port owned by the service: a missing program reports `unlaunchable (program-missing:PATH)` with `owner=configuration` and `action=restore-launch-path`, and the port reports `missing (not-listening;cause:owner-unlaunchable)` with `action=restore-owner-launch-path`.
- A non-executable program reports `program-not-executable`, and a missing working directory `working-directory-missing`.
- With program and working directory present, the port falls back to `action=start-owner`, and no launchd load or unload is logged throughout.
- `bats tests/rig.bats </dev/null`, then the full developer gate.

## Dependencies / blocks

Not blocked; it blocks nothing.

## Documentation impact

### Decision Records

None: a bounded extension of the existing doctor and port contracts.

### Specifications

New RIG-STATE-046, Launch prerequisites.

### Guides

The manual and changelog carry the new findings; the user guides describe doctor generically and need no change.

### Roadmap

Planned together with KI-TOOL-RIG-CORE-052, KI-TOOL-RIG-CORE-054 and KI-TOOL-RIG-CORE-055 and delivered in one commit; no acceptance, prune or release has been performed.

## Review

### Delivered

Delivered locally against fixtures only, from baseline `7cbe340`. Nothing ran against a live service manager.

### Change Summary

- `rig_resource_launch_blocker` in `22-observation.bash` checks a selected launchd service's or scheduled job's path-form program and working directory.
- Doctor adds `SECTION: unlaunchable (REASON:PATH); owner=configuration; action=restore-launch-path` and counts it only when the resource is otherwise present, so one item fails once.
- The port loop marks a missing listener whose owning service or scheduled job is blocked with `cause:owner-unlaunchable` and `action=restore-owner-launch-path`.
- RIG-STATE-046, the manual's doctor entry and the changelog describe it; `tests/rig.bats` adds the Observatory-shaped fixture.

### Verification

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark within budget, mandoc and diff checks. All 566 Bats tests pass.

Withheld by authority: `scripts/smoke-native-providers` and any live doctor run on `sol` or `terra`.

### Outstanding concerns

- **Provisional plan choice.** The missing path makes the service itself a finding (`unlaunchable`) and also annotates its port, rather than only annotating the port. Kris to confirm.
- **Launchd only.** Rig declares services and scheduled jobs through launchd today, so there is no systemd case to check; the Boundary's systemd mention has no current subject.
- A bare program name resolved through `PATH` at launch is not checked, because launchd's `PATH` differs from doctor's.

### Post-change review

Existing doctor and port tests pass unchanged; a fully present service adds no finding and no extra check.

### Mini recap

Doctor now says a service cannot start because its program or working directory is missing, instead of only asking for its port's owner to be started.

## Discussion

Origin: the `sol` Observatory outage diagnosed in the Mac Studio bootstrap thread, and Kris Brown's decision on 2026-10-14 to capture it here. A program path matters as much as the working directory: the same plist names a mise-installed Bun by path, and a removed mise install would fail the same way. Whether a missing path makes the service itself a finding, or only annotates its port finding, is a planning question. Capture only; adoption, priority and plan belong to this repository.

Adopted, planned and delivered on 18 October 2026 by the tools-burndown run, under the rig-lane report's RIG-ORDER a) ("plan KI-TOOL-RIG-CORE-055, KI-TOOL-RIG-CORE-052 and KI-TOOL-RIG-CORE-054 to Ready in one ki-plan sitting") and Kris's overnight instruction of 18 October 2026, 04:30 BST, to burn the roadmap down as far as possible and take the recommended course on a judgement call. The record was triage, so its adoption to `deliver` / Now and its plan choices below are provisional, for Kris to confirm at review.
