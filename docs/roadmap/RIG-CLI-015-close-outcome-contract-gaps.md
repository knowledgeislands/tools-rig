---
id: RIG-CLI-015
area: CLI
title: Close outcome contract gaps
theme: cli
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-25T15:00:00Z
---

## Goal

Every command ends with an outcome line a reader and a script can both rely on, including the commands that reject their input and the commands that do their work in a subshell.

## Context

Stating an outcome for every command left two gaps behind, both recorded as deliberate at the time.

The result vocabulary emits five values and does not include `rejected`. The decisions listed `rejected` in the vocabulary while also deciding that a status-2 rejection is not restated on an outcome line, and those cannot both hold, so rejection is left to what the `rig: error:` line already says. If a rejection should carry a machine-readable result, that is a change to the error line rather than to the outcome line.

`rig clean` runs its work in a subshell, so a detail noted inside it cannot escape. Its outcome line therefore carries a result derived from the exit status with no detail clause, and the same will be true of any command that later adopts that shape.

## Boundary

This does not revisit the five emitted result values for the commands that already report correctly, and it does not restructure `rig clean` for reasons other than letting its detail out.

## Discussion

### Two changes or one

They share a section here because both are gaps in one contract, but they are independent: the rejection question is about the error line's shape, and the subshell question is about how a command returns detail alongside a status. Either can land alone.

### Open questions

Whether any consumer wants rejection to be machine-readable at all. Nothing observed asks for it; the vocabulary listing it was the only pressure, and that has been resolved by not emitting it.
