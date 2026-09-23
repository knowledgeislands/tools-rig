---
id: RIG-CORE-023
area: CORE
title: Schedule unattended updates
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-23T14:43:03Z
updated_at: 2026-09-23T14:43:03Z
---

## Goal

Let a person schedule Rig's own update run in place of each manager's private auto-update job, so one scheduled pass advances everything the profile declares and reports one truthful outcome, instead of Homebrew updating itself on its own timer while uv, mise, npm, chezmoi, and the Skills CLI go unattended.

## Context

Homebrew's `brew autoupdate` tap installs a launchd agent that runs `brew update` and optionally `brew upgrade` on an interval, can prompt for user credentials mid-run, and posts a notification listing failures. It is useful, and it is also narrow: it covers exactly one of the managers Rig orchestrates. A machine running Rig therefore ends up with one manager on a private schedule and the rest advanced only when someone remembers to type `rig update`.

Rig already owns the pieces this needs. `rig update` dispatches independent per-target operations across every supported provider, and since `RIG-ORCH-024` it reports completed, failed, unavailable, and skipped outcomes per task rather than stopping the run at the first finding. Rig also already models `scheduled-job` resources with the launchd provider, so a person can in principle declare a job whose `program` is `rig update` today.

What is missing is the part that makes such a job trustworthy without a person watching it: an unattended execution mode that cannot block on a credential prompt, a durable place for the run's outcome to land, and a documented recipe that says what to declare and what to retire.

## Boundary

This work concerns how an update run behaves when nobody is watching it, and how its outcome is recorded. It does not change what `rig update` selects, which providers it dispatches to, the per-task outcome vocabulary, or exit status semantics for an interactive run.

Rig must not grow a scheduler. The scheduled job belongs in the person's own configuration as a declared `scheduled-job` resource, materialised by the existing launchd provider — portable behaviour here, personal choices in configuration. Rig must not install, modify, or remove another tool's auto-update agent on the person's behalf, and must not acquire a runtime dependency beyond Bash in order to notify.

## Shaping

Questions to settle before this is Ready:

- **Unattended mode.** An update that can prompt for credentials under launchd either hangs or pops a dialog nobody asked for. The likely contract is that an unattended run never prompts: a target needing elevation reports as needing attention and the run returns non-zero, leaving the privileged part for an interactive `rig update`. Does that reuse the existing `unavailable` outcome, or does it need its own state?
- **Where the outcome lands.** A durable last-run report under `${XDG_STATE_HOME}/rig` keeps Rig within its Bash-only boundary and lets anything else — a notification wrapper, `rig doctor`, a status line — read it. Decide the report's shape and whether it is a public contract or human output.
- **Notification.** A macOS notification means `osascript` or `terminal-notifier`, which is a dependency Rig does not have. Leaving notification to the declared job's own wrapper preserves the boundary; baking it in does not. Confirm the split before designing either.
- **Competing schedulers.** Once Rig can do this, a machine with `brew autoupdate` still installed has two things updating Homebrew on different timers. Rig should probably observe and report that, the way it reports unmanaged listeners, rather than silently coexisting or unilaterally retiring it.
- **Scope of the scheduled run.** Whether the job should run `rig update`, `rig maintain`, or both, and whether an unattended run should honour a narrower profile than the interactive default.

## Discussion

The value here is not automation for its own sake — it is that a person currently gets a notification about Homebrew and silence about everything else, which reads as "the machine is up to date" when it is not. One scheduled pass reporting one honest outcome across every declared manager is strictly more informative than one manager reporting well and five not reporting at all.

The design risk is scope creep into a scheduler. Rig's manager-of-managers model works because Rig owns selection, ordering, dispatch, and reporting while native tools keep their own execution. A scheduled job is machine state, and machine state is already a declared resource kind with a provider behind it. The moment Rig grows its own timer, daemon, or notification stack, it has stopped being the thing that describes a working setup and started being one more background agent to maintain.

The credential question is the one that decides whether this is worth building. An unattended run that can block on a password is worse than no scheduled run, because it fails silently and invisibly. If the unattended contract cannot honestly guarantee "never prompts, always reports", this should stay unscheduled.
