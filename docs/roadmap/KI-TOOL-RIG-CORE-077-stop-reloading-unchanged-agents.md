---
id: KI-TOOL-RIG-CORE-077
area: CORE
title: Stop reloading unchanged agents
priority: high
size: m
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-18T05:00:00Z
updated_at: 2026-11-18T05:00:00Z
---

# KI-TOOL-RIG-CORE-077: Stop reloading unchanged agents

## Goal

A full `rig apply --scope resources` leaves a launch agent alone when its rendered plist and its load state already match the declaration, never boots out the launch agent that hosts the running `rig`, and leaves a record behind when a launchd apply is interrupted.

## Context

Kris, 18 November 2026, hitting it again: "rig apply kills orca every run".

`rig_launchd_apply_resource` in `src/rig/20-orchestration.bash` boots out and bootstraps every declared launch agent on every apply, whether its plist changed or not. Only dependency inclusion consults the observation; the resource loop in `src/rig/23-application.bash` sends every planned resource to `rig_apply_resource`. On `sol` that bounces `com.stablyai.orca.serve`, Orca's own server, on every full apply.

Run from a terminal inside Orca, the bootout also kills the apply itself. On 12 November 2026 a housekeeper's `rig apply --scope resources` from an Orca terminal on `sol` reached step 17 of 74, booted out `com.stablyai.orca.serve`, and was killed with its terminal (exit 137) before the plist move and the bootstrap ran. The server stayed unloaded for five hours, the observatory's retirement was left pending, and no apply-history row was written, because `rig_history_complete` writes the row only after the native apply returns.

The evidence, the timeline and the three proposed fixes are in the dotfiles repository's record PERSONAL-DOTFILES-UE-141 ("Reload unloaded launch agents"), confirmed by `sol`'s housekeeper on 12 November and raised again by Hob Sol at about 04:12 GMT on 18 November. Source revision at capture: `11441988c5f80658f6a40d29b15cf025442fd503`.

The three fixes, in order:

1. **A launchd reconcile is a no-op when nothing differs.** In `rig_launchd_apply_resource`, observe first and return without unloading when the rendered plist is byte-identical to the installed one and the load state is the expected one.
2. **Never boot out the service that hosts the caller.** When the launch agent to unload is the running `rig`'s own process or one of its ancestors, refuse with a named failure rather than killing the apply halfway.
3. **Record a launchd apply as started before it acts,** so an interrupted one leaves a row that `rig doctor` can report.

Interim rule until fixes 1 and 2 land: housekeepers use only targeted `rig apply --scope resources --target kind:id` runs that leave `service:orca-serve` alone, and no full `rig apply` runs from an Orca terminal.

## Boundary

- **In:** the three fixes above in the built-in launchd adapter and apply history; the RIG-ORCH-023 specification; isolated Bats coverage with `launchctl` and `ps` stubbed.
- **Out:** a live apply on `sol` or `terra` during delivery; Orca's own updater; the hourly load-state check and reload, which the dotfiles repository owns; any personal label in the executable.

## Discussion

- 18 November 2026, Kitteth (the Cairn summit's guardian), under CASCADE-DOWN while no ki.tools session runs: captured from Hob Sol's report and Kris's words above. Fixes 1 and 2 are small and testable through the stateful `launchctl` fixture in `tests/rig.bats`; fix 3 touches the apply-history transaction and is left for separate shaping.
