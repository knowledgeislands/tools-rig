---
id: RIG-CORE-024
area: CORE
title: Widen needs-person detection
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-26T10:05:00Z
---

## Goal

An unattended run says ahead of time that a piece of work needs a person, whatever provider that work belongs to, instead of discovering it as an ordinary failure afterwards.

## Context

`rig update --unattended` reports work that cannot proceed without a person as `unavailable` before invoking it. That pre-emptive check currently recognises exactly one case: a Homebrew store-app target. Any other provider that demands an interactive credential instead reads end-of-file and fails, and a post-hoc non-zero exit is indistinguishable from an ordinary failure.

The narrowest instance of the gap is already observed. A `mas` entry inside a Homebrew manifest is invisible to the check, because a manifest dispatches as one task carrying one representative binding: `brew bundle` calls `mas upgrade`, `mas` calls `sudo` to replace a root-owned bundle, and the whole manifest task fails on one stale App Store app while every other Homebrew result is masked. This workstation's chezmoi source works around it in its own scheduled wrapper by setting `HOMEBREW_BUNDLE_MAS_SKIP` from `mas outdated`.

That workaround now runs daily and holds: the scheduled run on 2026-09-26 completed sixteen targets with none failed and none unavailable, exit 0. The gap is therefore masked rather than closed, and masked on one machine only — any other machine following the same guide meets the original failure, where one stale App Store app fails the whole Homebrew manifest task and hides every other Homebrew result.

## Boundary

This is not a cleverer classifier of non-zero exits after the fact. It does not teach Rig `mas` internals, or any other provider's internals, to serve one machine's quirk, and it does not touch the machine's own wrapper — that belongs to the chezmoi source.

## Discussion

### Why not a cleverer classifier

A failure that has already happened carries no reliable evidence that a person was what it wanted. Widening the honest signal means each provider declaring, before dispatch, which of its work needs a credential a scheduled run cannot supply.

### Where the signal has to come from

A manifest is opaque to Rig by design, so either the provider gains a way to report the interactive entries it is about to hand to its own tooling, or a manifest task keeps reporting one outcome for many entries. The second is defensible; it just has to be stated rather than assumed.
