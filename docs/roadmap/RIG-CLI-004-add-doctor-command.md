---
id: RIG-CLI-004
area: CLI
title: Add doctor command
theme: cli
horizon: triage
status: draft
blocks: [RIG-DIST-001]
blocked_by: [RIG-CLI-001]
baseline_ref: null
created_at: 2026-09-15T13:04:11Z
updated_at: 2026-09-15T13:04:11Z
---

# RIG-CLI-004: Add doctor command

## Goal

`rig doctor [--profile NAME]` gives one concise top-level answer about whether Rig is valid and whether the selected working setup can operate on this machine.

## Context

`status` provides the detailed expected-versus-observed tool inventory. Doctor should synthesise configuration, provider, and installed-tool findings without becoming a rich diagnostic command tree or reproducing another tool's interface.

The check is useful on a newly bootstrapped machine and before apply. It must reuse catalogue resolution and provider observations rather than maintaining separate health rules.

## Boundary

This item adds one read-only top-level command. It does not repair configuration, install tools, invoke mutation or publisher capabilities, contact the network, inspect unrelated machine software, or add doctor subcommands.

## Discussion

### Checks

Doctor validates configuration readability and schema, category and tool references, profile and dependency graphs, platform binding selection, XDG path accessibility, required provider command availability, and each selected tool's provider observation. Missing, drifted, unavailable, and unknown tools become findings rather than hidden detail.

### Output and exit status

The default output is a compact healthy summary or grouped actionable findings. Exit status `0` means every required check is healthy, `1` means valid execution found health findings, and `2` means owned command syntax is invalid.

### Public surface

The delivery updates `rig --help`, `rig doctor --help`, Bash and Zsh completion, README command inventory, `rig(1)`, the curated v1 changelog, and Bats coverage in the same commit. None of those surfaces should advertise a doctor option that is not shipped.
