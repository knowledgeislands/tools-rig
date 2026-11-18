---
id: KI-TOOL-RIG-CORE-077
area: CORE
title: Stop reloading unchanged agents
kind: deliver
purpose: corrective
component: orchestration
priority: high
size: m
assignee: owner
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: c552d7f2fcb83194a5c92776a24898e37902fcda
created_at: 2026-11-18T05:00:00Z
updated_at: 2026-11-18T06:00:00Z
---

# KI-TOOL-RIG-CORE-077: Stop reloading unchanged agents

## Goal

A full `rig apply --scope resources` leaves a launch agent alone when its rendered plist and its load state already match the declaration, and never boots out the launch agent that hosts the running `rig`.

## Context

Kris, 18 November 2026, hitting it again: "rig apply kills orca every run".

`rig_launchd_apply_resource` in `src/rig/20-orchestration.bash` boots out and bootstraps every declared launch agent on every apply, whether its plist changed or not. Only dependency inclusion consults the observation; the resource loop in `src/rig/23-application.bash` sends every planned resource to `rig_apply_resource`. On `sol` that bounces `com.stablyai.orca.serve`, Orca's own server, on every full apply.

Run from a terminal inside Orca, the bootout also kills the apply itself. On 12 November 2026 a housekeeper's `rig apply --scope resources` from an Orca terminal on `sol` reached step 17 of 74, booted out `com.stablyai.orca.serve`, and was killed with its terminal (exit 137) before the plist move and the bootstrap ran. The server stayed unloaded for five hours, the observatory's retirement was left pending, and no apply-history row was written, because `rig_history_complete` writes the row only after the native apply returns.

The evidence, the timeline and the three proposed fixes are in the dotfiles repository's record PERSONAL-DOTFILES-UE-141 ("Reload unloaded launch agents"), confirmed by `sol`'s housekeeper on 12 November and raised again by Hob Sol at about 04:12 GMT on 18 November. Source revision at capture: `11441988c5f80658f6a40d29b15cf025442fd503`.

The three fixes, in order:

1. **A launchd reconcile is a no-op when nothing differs.** In `rig_launchd_apply_resource`, observe first and return without unloading when the rendered plist is byte-identical to the installed one and the load state is the expected one.
2. **Never boot out the service that hosts the caller.** When the launch agent to unload is the running `rig`'s own process or one of its ancestors, refuse with a named failure rather than killing the apply halfway.
3. **Record a launchd apply as started before it acts,** so an interrupted one leaves a row that `rig doctor` can report.

Interim rule until fixes 1 and 2 are released and installed: housekeepers use only targeted `rig apply --scope resources --target kind:id` runs that leave `service:orca-serve` alone, and no full `rig apply` runs from an Orca terminal.

## Boundary

- **In:** fixes 1 and 2 in the built-in launchd adapter; the RIG-ORCH-023 specification; the changelog and the operational-resources guide; isolated Bats coverage with `launchctl` stubbed.
- **Out:** fix 3, which touches the apply-history transaction and is KI-TOOL-RIG-CORE-078; a live apply on `sol` or `terra` during delivery; a release or install of Rig; Orca's own updater; the hourly load-state check and reload, which the dotfiles repository owns; any personal label in the executable.

## Current state

`rig_launchd_apply_resource` renders, unloads, moves and bootstraps unconditionally. `rig_launchd_observe_resource` already compares the rendered plist byte for byte and the load state with the declared one, so fix 1 can reuse it. `rig_launchd_load_state` discards `launchctl print` output, so nothing reads the job's process. `tests/rig.bats` has a stateful `launchctl` fixture, `write_launchd_fixture`, that records every call and keeps a load-state file, so both fixes can be proved without touching a real launchd domain.

## Steps

- [x] Observe first in `rig_launchd_apply_resource` and return when the resource is `present`.
- [x] Read the job's `pid` in `rig_launchd_load_state`, walk Rig's ancestry with `ps`, and refuse in `rig_launchd_unload` when the job's process is in it, with a message naming the label and process.
- [x] Teach the fixture to report a `pid`; add tests for the no-op, a load-state-only reload, a single drifted plist, the refusal and a non-ancestor reload; keep the release-wait test exercising a replacement.
- [x] Update RIG-ORCH-023, the changelog and the operational-resources guide; reassemble `bin/rig`.
- [x] Run the complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository).

## Files touched

- `src/rig/20-orchestration.bash` and the assembled `bin/rig`.
- `tests/rig.bats`.
- `docs/specs/orchestration.md`, `CHANGELOG.md`, `docs/guides/user/operational-resources.md`.

## Verify

`bats tests/ </dev/null` passes, including `built-in launchd leaves an unchanged loaded resource alone` and `built-in launchd refuses to unload the job that hosts rig`, with the rest of the gate in Develop Rig.

## Dependencies / blocks

None in this repository. The dotfiles repository's hourly load-state check and reload wait on fix 1 being released and installed on `sol`; that need is handed over along the work tree, not recorded here.

## Documentation impact

### Decision Records

None: the change restores the declared contract rather than choosing between designs.

### Specifications

RIG-ORCH-023 gains the no-op and the hosting-caller refusal, with their evidence.

### Guides

The operational-resources user guide says when an apply reloads a launch agent and what the refusal means.

### Roadmap

KI-TOOL-RIG-CORE-078 carries fix 3.

## Review

### Delivered

Fixes 1 and 2 within the Boundary, against baseline `c552d7f2fcb83194a5c92776a24898e37902fcda`: a launchd apply observes first and changes nothing when the installed plist is byte-identical to the rendered one and the load state is the declared one; a job whose process is the running `rig` or one of its ancestors is never unloaded, and its resource fails with `rig: launchd: refusing to unload LABEL: its process PID hosts this rig; run rig from a terminal outside it`. Fix 3 is excluded and carried by KI-TOOL-RIG-CORE-078. Nothing was applied, released or installed on a live machine.

### Change Summary

- `src/rig/20-orchestration.bash`: `rig_launchd_apply_resource` returns early on a `present` observation; `rig_launchd_load_state` reads the job's `pid` from `launchctl print`; the new `rig_process_is_caller_ancestor` walks Rig's ancestry with `ps -o ppid=` from `$$`; `rig_launchd_unload` refuses a job in that ancestry, which also covers retirement. `bin/rig` reassembled.
- `tests/rig.bats`: the `launchctl` fixture reports `pid = N` when `RIG_LAUNCHD_SERVICE_PID` is set; two new tests; the release-wait test now drifts each plist first, since an unchanged loaded resource is no longer reloaded.
- `docs/specs/orchestration.md` (RIG-ORCH-023), `CHANGELOG.md`, `docs/guides/user/operational-resources.md`.
- Decision: the check is generic, by process ancestry, rather than naming Orca's label, because the executable carries no personal label. Without `ps` the walk finds no ancestor and the unload proceeds as before; macOS always has `/bin/ps`.

### Verification

- The complete gate in Develop Rig: ShellCheck, `bash -n`, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1` and `git diff --check` pass; `bats tests/ </dev/null` passes 650 of 650.
- The two new tests fail against the baseline executable and pass after the change; the three existing launchd tests pass on both.
- `ki repo audit --repo .` reports no finding for this record; its one failure, FILES-6 on `.gitignore`, predates the change.

### Outstanding concerns

- The ancestry check catches a terminal whose process tree hangs off the job, as an agent session under Orca's server does on `sol`; a helper that daemonised away from the job's tree would not be caught, though fix 1 already spares it unless its plist changed.
- The interim rule stands until a release carrying this change is installed on `sol` and `terra`; releasing is outside this record.
- Fix 3 is KI-TOOL-RIG-CORE-078.

### Post-change review

The goal is met for both fixes within the Boundary. Regression risk is low: a drifted plist or load state follows the old path unchanged, and a no-op still reports `completed reconciled:LABEL`, so output contracts hold. A loaded job that should be reloaded for a reason the observation does not see, such as a changed program binary behind an unchanged plist, is no longer restarted by apply; that is the intended contract, and `rig upgrade`'s restart question is KI-TOOL-RIG-CORE-075. Ready for acceptance.

### Mini recap

A full `rig apply` no longer restarts healthy launch agents, and never unloads the agent hosting the running `rig`, both proved with stubbed `launchctl` and the full gate green. Learning route proposed, not promoted: the dotfiles repository's interim rule can lift once a release with this change is installed.

## Discussion

- 18 November 2026, Kitteth (the Cairn summit's guardian), under CASCADE-DOWN while no ki.tools session runs: captured from Hob Sol's report and Kris's words above. Fixes 1 and 2 are small and testable through the stateful `launchctl` fixture in `tests/rig.bats`; fix 3 touches the apply-history transaction and is left for separate shaping.
- 18 November 2026, Kitteth: adopted for immediate delivery of fixes 1 and 2 on the overnight brief's authority, without a live apply; fix 3 split to KI-TOOL-RIG-CORE-078 so this record's boundary matches what lands.
- 18 November 2026, Kitteth: fixes 1 and 2 delivered and verified without a live apply; awaiting Kris's review.
