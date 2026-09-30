---
id: RIG-CORE-035
area: CORE
title: Surface permanent apply failures
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T00:00:00Z
updated_at: 2026-09-30T00:00:00Z
---

## Goal

A materialisation that fails on every `rig apply` is visible to `rig doctor` and `rig status`, so a person learns about a permanently broken install path from a read-only command rather than by reading the failure rows of a mutating run.

## Context

On this workstation `rig apply` ended `failed=5` on every run for weeks while `rig doctor` reported `findings=0` and `rig status` reported every tool `present`. Both were right under their own rules. Presence is the native manager's receipt: Homebrew listed the cask, `mas` listed the app, so the tool was present. The failures were in the act of materialising — `mas` could not resolve the iWork ADAM IDs, the Zoom cask upgrade needed `sudo` and could not prompt, `npm-check-updates` failed its install, and the `paperclip` provider ran while its service was still restarting — and nothing Rig observes between applies carries that.

No apply record persists either. `${XDG_STATE_HOME}/rig/reconciliation/` held only a lock, and the one report Rig does write, `last-update`, is for unattended `update` and `maintain` runs only. So the last apply's failure set lived in a terminal scrollback that, in this case, had been garbled by the progress rendering collision that [RIG-CLI-020](RIG-CLI-020-steady-the-progress-line.md) and the earlier phase-rendering fix addressed.

The iWork three have since been moved to catalogue-only, Zoom's receipt was repaired by hand, and Paperclip's provider ordering is fixed. The shape recurs though: an application that updates itself behind its manager's back, a store entry the store can no longer resolve, a provider that needs a credential it cannot ask for. [RIG-CORE-024](RIG-CORE-024-widen-needs-person-detection.md) owns predicting the credential case ahead of an unattended run; this item is about the general case being remembered and reported afterwards.

## Boundary

This is Rig's portable observation and reporting model. It does not decide how any one workstation declares Zoom or iWork, which is the host configuration's business, nor does it make `rig doctor` run providers' mutating paths to find out whether they would fail — a read-only command stays read-only.

It is not [RIG-CORE-024](RIG-CORE-024-widen-needs-person-detection.md), which predicts a needs-person outcome before invocation, and not [RIG-CLI-015](RIG-CLI-015-close-outcome-contract-gaps.md), which is the outcome line. It may reuse `last-update`'s report shape, and planning should say whether it does.

## Discussion

### Two candidate shapes

The smaller shape is memory: `rig apply` persists its result rows beside `last-update`, and `rig doctor` reads them, reporting a tool whose last materialisation failed as a finding with the recorded detail, aged by the apply's timestamp. This adds no provider protocol and asks nothing of providers. Its weakness is staleness: the finding is about the last run, not now, and the report must say so.

The larger shape is a provider capability — a `check` or `materialisable` observation that asks whether the install path is sound without taking it. It answers the question live, but every provider would need to implement it and most native managers offer no such primitive, so it would be partial by construction.

Planning should start from memory and treat the capability as a possible follow-on that the evidence has not yet justified.

### What counts as permanent

One failed apply is weather; the same target failing on consecutive applies is a finding. A record of the last run alone cannot distinguish them, so the persisted report may need to carry a consecutive-failure count per target, or `rig doctor` may simply report the last failure and let the reader judge. Say which.
