---
id: RIG-CLI-019
area: CLI
title: Describe every option
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

`rig COMMAND --help` tells somebody what the command's options do, not only that they exist.

## Context

Every subcommand's help is one usage line and nothing else:

```text
$ rig status --help
Usage: rig status [--profile NAME] [--unmanaged] [--format text|json]
```

That names three options and explains none. What `--unmanaged` adds, that `--format json` exists at all on only two of the fourteen commands, that `rig apply` reconciles rather than verifies and will restart applications mid-run, that an interrupted cask upgrade is what strands a half-replaced bundle — all of it lives in the guides and the manual, and none of it is reachable from the terminal where somebody is about to run the command.

`rig --help` has the same shape one level up: a command list with a one-line description each, and no indication of which options matter. Its closing lines carry two genuinely operational facts — that interactive operations draw a progress bar on stderr, and that `--unattended` exists for `update` and `maintain` — which is evidence that the top-level help is already being asked to do a job the per-command help should be doing.

The cost is not theoretical for a shell-only tool. Completion is generated from the same surface, so a flag that help does not describe is a flag nobody discovers.

## Boundary

This is help text and its generation, not the CLI's shape. No option is added, removed, or renamed here, and no behaviour changes. The manual and the guides stay where they are; this is about the subset a person needs at the moment of invocation.

## Discussion

### How much help is enough

A line per option, an exit-status note where the status is meaningful, and one worked example is the usual floor and is probably right here. Anything longer competes with the manual and will drift from it.

### Keeping it honest

Help, completion, and the manual are three renderings of one surface and are currently maintained as three. Whichever of them is authored by hand will be the one that goes stale; deciding which is generated from which is more of the work than writing the text.

### Where the destructive facts go

Some of what a person most needs to know before running `rig apply` is a warning, not a description. Whether help is the right place for it, or whether that belongs to a confirmation prompt or a dry-run default, is worth settling before the text is written.
