---
id: RIG-CORE-027
area: CORE
title: Catalogue-only is not unavailable
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T13:00:00Z
updated_at: 2026-09-26T13:00:00Z
---

## Goal

A tool the catalogue deliberately does not manage reads as a deliberate choice, not as something wrong with the machine.

## Context

A catalogue-only tool has no installation metadata by design: it is declared so its purpose and rationale are recorded, and Rig is explicitly not asked to materialise it. `rig status` reports thirteen such entries on this workstation as:

```text
builtin-messages         -         unavailable  catalogue-only
microsoft-word           -         unavailable  catalogue-only
paperclip                -         unavailable  catalogue-only
```

`unavailable` is the same token Rig uses for a port whose listener it could not observe and for a provider executable it could not find. Those are faults. A catalogue-only entry is not, and the machine is not in a worse state for having thirteen of them.

The summary then says the same thing twice in two vocabularies: `Summary: present=81 missing=7 drifted=0 unavailable=13 unknown=0 catalogue-only=13`, where both counts describe the same thirteen rows. `rig doctor` gets this right — it reports `catalogue-only=13` alongside `findings=19` and does not fold the two together — which is evidence that the distinction already exists in the model and only status is collapsing it.

The cost is that `unavailable` stops meaning anything. Thirteen rows carrying a token that mostly denotes a fault, in a listing where the reader is scanning for faults, is thirteen reasons to stop scanning carefully.

## Boundary

This is the state a catalogue-only tool is reported in and how it is counted, in `rig status`. It is not a change to what a catalogue-only declaration means, to whether such entries appear at all, or to the state vocabulary for entries Rig does manage. `unavailable` keeps its meaning for genuine faults.

## Discussion

### A token or a section

Reporting catalogue-only entries in their own state token keeps one table. Moving them out of the main table into their own short listing, as `--unmanaged` already does for unclaimed native bundles, makes the point more strongly and shortens the part of the output a reader has to scan. Either way the count belongs beside the others, not inside `unavailable`.

### Whether the exit status should notice

`rig status` exits 1 when something is unhealthy. Catalogue-only entries should not contribute to that, and it is worth confirming they currently do not — the observed run exits 1, but it also has twenty genuine findings, so the case is untested.

### Ordering against the output work

This is independent of [RIG-CLI-017](RIG-CLI-017-report-what-needs-attention.md) but compounds with it: thirteen rows that stop being faults are thirteen rows an attention-first view would no longer show.
