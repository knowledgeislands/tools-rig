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
status: in-progress
blocks: []
blocked_by: []
baseline_ref: c552d7f2fcb83194a5c92776a24898e37902fcda
created_at: 2026-11-18T05:00:00Z
updated_at: 2026-11-18T05:30:00Z
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

- [ ] Observe first in `rig_launchd_apply_resource` and return when the resource is `present`.
- [ ] Read the job's `pid` in `rig_launchd_load_state`, walk Rig's ancestry with `ps`, and refuse in `rig_launchd_unload` when the job's process is in it, with a message naming the label and process.
- [ ] Teach the fixture to report a `pid`; add tests for the no-op, a load-state-only reload, a single drifted plist, the refusal and a non-ancestor reload; keep the release-wait test exercising a replacement.
- [ ] Update RIG-ORCH-023, the changelog and the operational-resources guide; reassemble `bin/rig`.
- [ ] Run the complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository).

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

## Discussion

- 18 November 2026, Kitteth (the Cairn summit's guardian), under CASCADE-DOWN while no ki.tools session runs: captured from Hob Sol's report and Kris's words above. Fixes 1 and 2 are small and testable through the stateful `launchctl` fixture in `tests/rig.bats`; fix 3 touches the apply-history transaction and is left for separate shaping.
- 18 November 2026, Kitteth: adopted for immediate delivery of fixes 1 and 2 on the overnight brief's authority, without a live apply; fix 3 split to KI-TOOL-RIG-CORE-078 so this record's boundary matches what lands.
