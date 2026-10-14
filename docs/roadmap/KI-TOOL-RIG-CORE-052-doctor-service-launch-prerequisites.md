---
id: KI-TOOL-RIG-CORE-052
area: CORE
title: Doctor service launch prerequisites
purpose: capability
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T06:44:45Z
updated_at: 2026-10-14T06:44:45Z
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

## Dependencies / blocks

Not blocked; it blocks nothing.

## Discussion

Origin: the `sol` Observatory outage diagnosed in the Mac Studio bootstrap thread, and Kris Brown's decision on 2026-10-14 to capture it here. A program path matters as much as the working directory: the same plist names a mise-installed Bun by path, and a removed mise install would fail the same way. Whether a missing path makes the service itself a finding, or only annotates its port finding, is a planning question. Capture only; adoption, priority and plan belong to this repository.
