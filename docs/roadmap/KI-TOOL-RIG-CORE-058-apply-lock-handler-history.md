---
id: KI-TOOL-RIG-CORE-058
area: CORE
title: Apply lock, handler history
purpose: corrective
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-15T00:53:34Z
updated_at: 2026-10-15T00:53:34Z
---

# Apply Lock, Handler History

## Goal

`rig apply` and `rig upgrade`, including an upgrade started by a scheduled `rig-update` job, take one shared per-platform lock, and either refuses to start while the other holds it. A default-application step records its outcome in the apply history like every other dispatched target, so a failed handler assignment shows in `rig status` and `rig doctor`.

## Context

Two defects, found together in one apply on Mac Studio `sol` on 15 October 2026 ([apply-check run report](/Users/krisbrown/.local/state/ki/agents/mac-studio-bootstrap/apply-check.report.md)):

- **No shared lock.** Kris started `rig apply` at about 01:19 BST while the sol-clt run's `rig upgrade` was running; the upgrade finished at 01:25:11 BST. Both reached Homebrew and mise in the same minutes. The only lock is the resource reconciliation lock (RIG-STATE-025), which `rig_command_apply` in `src/rig/23-application.bash` takes only when the plan has resource work; tool installation runs outside it, and `rig upgrade` (`rig_command_lifecycle`) takes no lock at all. The scheduled `rig-update` job runs the same upgrade at 08:30 unattended, so the overlap can happen without anyone at the keyboard. That night every Homebrew step exited 0, so the overlap caused none of the nine failures, but two native managers running side by side is the risk.
- **Default applications leave no history.** `rig_history_prepare` in `src/rig/25-apply-history.bash` keys tools, skills, services, scheduled jobs, settings and the Dock, not default applications. The SVG handler step (`default-application.svg`, Google Chrome) failed with "handler assignment not effective; native confirmation may be required", most likely because macOS asked for confirmation on screen. It counted in the apply's failed total but wrote no history entry, so the apply-check run could only identify it by elimination from the counts. RIG-STATE-035 already says the ledger covers declared targets that Rig dispatches.

## Boundary

- In: one exclusive per-platform lock that live `rig apply` (every scope, tools included) and live `rig upgrade` (attended and `--unattended`) hold for the whole run; a refusal before any provider call that names the active, stale or unknown owner and its command, matching RIG-STATE-025's owner detail and never removing an unverified lock; how the existing resource reconciliation lock fits into it; recording default-application dispatches in the apply history and projecting their failures in status and doctor; specification amendments to RIG-STATE-025 and RIG-STATE-035; isolated Bats coverage with a held fixture lock and stubbed handler setter.
- Out: queueing or waiting for the lock (refuse only); `rig doctor`, `status`, `show`, dry runs and other read-only commands, which take no lock; changing how the `rig-update` job is scheduled; Homebrew's and mise's own locking; the macOS confirmation prompt itself.

## Dependencies / blocks

Not blocked; blocks nothing.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of APPLY-UPGRADE-LOCK option a) on 2026-10-15 (decision 85 in the mac-studio-bootstrap thread's decisions log): "one unadopted tools-rig triage record (local commit): rig apply and rig upgrade share one lock and refuse to run concurrently, and default-application outcomes are recorded in the apply history". Kris chose one record over two. No open record already owned either half. Planning questions: whether the shared lock replaces the reconciliation lock or wraps it, given a targeted tool-only apply must not take the reconciliation lock today (RIG-ORCH-037); how an unattended upgrade that finds the lock held reports in its last-run report (RIG-STATE-030) and exits; and the history key for a default application (content type or extension, with the owning tool as provider). Capture only; adoption, priority and plan belong to this repository.
