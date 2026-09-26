---
id: RIG-CLI-017
area: CLI
title: Report what needs attention
theme: cli
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T13:00:00Z
updated_at: 2026-09-26T13:00:00Z
---

## Goal

Somebody who runs `rig status` on a healthy-but-imperfect workstation learns what needs their attention without reading past everything that does not.

## Context

`rig status` on this workstation's default profile emits 166 lines. Twenty of them are rows in a state other than `present`: seven missing npm tools, seven drifted launchd resources, two missing skills, three unavailable ports, and one unknown external tool. The other 146 lines say that something is fine.

There is no way to ask for less. The command takes `--profile`, `--unmanaged`, and `--format`, and none of those narrow by state. So the reader either scrolls, or pipes the output through a filter they have to write themselves, and the exit status of 1 tells them a problem exists without telling them where.

The summaries do not rescue this, because each one arrives after the section it summarises. `Summary: present=81 missing=7 ...` is on line 106, `Resource summary: selected=44 retire-pending=0 unhealthy=7` near the end, `Port summary: selected=3 unhealthy=3` last of all, and the skill table carries no summary at all. There is no single line anywhere that says how many things need a person.

The same shape costs more than attention. The run took eighty seconds, and because progress is a terminal-aware stderr affordance, a redirected or piped run prints nothing at all until it finishes and then prints everything at once.

## Boundary

This is about which rows and summaries a reader gets and in what order. It is not a change to what Rig observes, to the state vocabulary, to exit statuses, or to the JSON projection's completeness — a filtered text view and a complete machine view can coexist, and the machine view should stay complete.

It does not cover making the tables themselves consistent, which is [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md), nor the separate question of whether `catalogue-only` entries should be counted as unhealthy at all, which is [RIG-CORE-027](RIG-CORE-027-catalogue-only-is-not-unavailable.md).

## Discussion

### A selector, a default, or both

A `--problems` flag is the smallest change and leaves every existing invocation untouched. Making attention-first the default is the larger claim — that the full listing is the special case — and it would change what every existing reader and script sees. The two are not exclusive: the ordering change is cheap and safe on its own, and the filter can follow.

### One verdict line

Four per-section summaries and no overall one means the reader assembles the verdict themselves. A single leading line naming the count that needs a person, before any table, would answer the question most runs are actually asking.

### Progress on a redirected run

Eighty seconds of silence is a property of progress being stderr-and-TTY-only. `RIG_PROGRESS=lines` already exists for this. Whether a long read-only command should default to line progress when its stdout is redirected is worth deciding here rather than leaving to each caller.
