---
id: KI-TOOL-RIG-CORE-075
area: CORE
title: Restart services after upgrade
priority: medium
size: m
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-30T02:30:00Z
updated_at: 2026-10-30T02:30:00Z
---

# KI-TOOL-RIG-CORE-075: Restart services after upgrade

## Goal

When `rig upgrade` advances a tool, a running service that names that tool through its `tool` subject link runs the new version afterwards, and `rig doctor` reports any running service whose process started before its tool was last changed.

## Context

On 27 October 2026 `rig upgrade` advanced the uv tool `headroom` from 0.41.0 to 0.42.0 on `sol`. The always-on Headroom proxy kept running 0.41.0 from 24 October until Kris restarted it by hand on 30 October. Because the proxy reads its dashboard page from the installed package on each request, the page and the data behind it came from different versions, and the dashboard drew an empty frame. Nothing reported the stale process: `rig doctor` checks that a service is loaded and running, not which installed version it runs.

[RIG-ORCH-024](../specs/orchestration.md) makes upgrades declaration-scoped and says nothing about the services that use an upgraded tool. [RIG-CONF-016](../specs/configuration.md) already lets a service or scheduled job name its subject `tool`, so the link the behaviour needs exists in the schema.

The consumer side is in the dotfiles repository: PERSONAL-DOTFILES-UE-101 declares the Headroom deployment as a Rig service carrying that link, and PERSONAL-DOTFILES-UE-099 adds the links for the Paperclip and Observatory services.

## Boundary

- **In:** after a successful upgrade task, restart each selected service with desired state `running` whose `tool` names the upgraded tool, reporting each restart per task; a dry-run preview that lists them; a doctor finding for a running service whose process start time precedes its tool's last install or upgrade, where the provider can observe that time; specification, tests and guide.
- **In, to decide in planning:** whether restart is the default or an opt-in per service, how scheduled jobs are treated (likely none, since each run starts fresh), and whether a service started by a third-party supervisor, such as Headroom's own launch agent today, is in reach.
- **Out:** restarting services whose tool did not change, provider-wide maintenance, and any live restart on `sol` or `terra` during delivery.

## Dependencies / blocks

None in this repository. The first consumer is PERSONAL-DOTFILES-UE-101 in the dotfiles repository, which needs this behaviour for the Headroom service to stay current.

## Discussion

Captured from the 30 October Headroom incident on `sol`; no source has been read for the restart path yet. Source revision at capture: `9297c9caeb23e77c1d6a02eafc38361104de8d5f`. Untriaged: adopt it under `ki-next` and plan it under `ki-plan`. The open design question is whether restart is the default for a linked running service or an opt-in per service.
