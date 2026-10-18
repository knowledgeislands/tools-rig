---
id: KI-TOOL-RIG-CORE-061
area: CORE
title: Removal lock diagnostics
purpose: capability
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T08:00:00Z
updated_at: 2026-10-18T08:00:00Z
---

# Removal Lock Diagnostics

## Goal

`rig remove --apply` takes the same per-platform operation lock as live `rig apply` and `rig upgrade`, so a removal never runs a native manager alongside them, and `rig doctor` names a held operation or reconciliation lock as active, stale or of unknown owner, with the path a person removes by hand once its owner is gone.

## Context

[KI-TOOL-RIG-CORE-058](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-058-apply-lock-handler-history.md) delivered the operation lock at `$state_home/operation/PLATFORM.lock` under RIG-STATE-025: live apply of any scope and live upgrade acquire it before any provider call, and a concurrent run is refused with status 2. Two gaps sit outside that record's boundary:

- `rig_command_remove_impl` in `src/rig/27-software-removal.bash` invokes Homebrew, uv, npm and mise uninstallers under `--apply` and takes no lock, so a removal can still run beside an apply or an unattended upgrade.
- No diagnostic names a held lock. A stale lock left by a killed process refuses every later apply and upgrade, and a person learns of it only from the refusal message or the unattended report's `operation-lock=stale` detail.

## Boundary

- In: `rig remove --apply` acquiring and releasing the operation lock, with refusal before any native call and its preview and dry-run taking none; a doctor finding for each held operation or reconciliation lock, reporting owner state and the owning command without paths in machine-readable output; specification text in RIG-STATE-025 and the doctor specification; isolated tests against fixture locks.
- Out: removing or breaking a lock automatically; queueing or waiting for a lock; locks for read-only commands; Linux-specific lock semantics beyond the existing per-platform path.

## Dependencies / blocks

Follows KI-TOOL-RIG-CORE-058 and assumes its lock design is confirmed at review. Blocks nothing.

## Discussion

Origin: the rig-lock run of 18 October 2026, delivering KI-TOOL-RIG-CORE-058's lock half; captured as a provisional follow-up, for Kris to confirm. Planning questions: whether removal's refusal writes any report (it has no unattended mode today); whether doctor's finding is a warning or a failure for a stale lock; and whether doctor offers the exact `rmdir` path or only names the directory. Capture only; adoption, priority and plan belong to this repository.
