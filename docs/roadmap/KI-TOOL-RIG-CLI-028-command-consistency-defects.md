---
id: KI-TOOL-RIG-CLI-028
area: CLI
title: Command consistency defects
priority: medium
size: m
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-24T12:02:30Z
---

# KI-TOOL-RIG-CLI-028: Command consistency defects

## Goal

Rig's commands agree with one another where a person levelling a Mac relies on them: `rig upgrade --dry-run` says what is actually outdated, `rig doctor`'s help says what it does, `rig status --unmanaged` and its JSON carry the same sections, one problem has one name across commands, and it is clear which `rig` is the managed one.

## Context

On 24 October 2026, levelling sol under Rig 0.8.0, ten inconsistencies were seen and routed to tools-rig as RIG-CLI-CONSISTENCY. The [rig-intake report](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/setup/rig-intake.report.md) (20 October to 1 November) proposed one bounded record for the five that are defects seen failing, with four design questions in Discussion and item (8) held with the footprint group. Kris agreed the captures on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (RIG-INTAKE).

The five defects, numbered as reported:

- (3) `rig upgrade --dry-run` lists every declared item as `planned upgrade` (122 on sol) without checking for a newer version, so `brew outdated` is still needed.
- (4) `rig doctor`'s help says "Check whether Rig can operate", but it reports the declared setup's health, and its findings repeat `rig status --problems`.
- (5) `rig status --unmanaged` prints the whole managed table before the unmanaged items, and its listener and skill sections were missing from `--json`.
- (6) the same UTM problem is `drifted` in `status` and `doctor` but `unavailable` in `upgrade --dry-run`.
- (9) with the checkout's `~/.local/bin/rig` ahead of Homebrew's `rig` on PATH, `doctor` says `Installation: local` while `status` and `upgrade` plan for the Homebrew `rig` tool.

A spot check on sol on 24 November 2026, with `rig 0.8.0+dev`: `rig --help` still describes `doctor` as "Check whether Rig can operate"; `rig status --json` now carries `skills` and `ports` keys, so part of (5) may have landed; both `~/.local/bin/rig` and `/opt/homebrew/bin/rig` are on PATH. Planning rechecks each item.

## Boundary

- **In:** items (3), (4), (5), (6) and (9) above; help text, specification and tests for them.
- **Out:** removing unmanaged items, item (8), which stays held with the footprint group and the KI-TOOL-RIG-CORE-072 idea; the terminal dashboard, KI-TOOL-RIG-CLI-029; any change to `rig remove`'s preview-by-default, which the specification requires.

## Discussion

Consistency questions carried for planning, not defects: (1) `rig remove` previews by default and needs `--apply`, while `apply` and `upgrade` act by default and take `--dry-run`, which is by specification; (2) `rig upgrade` takes no `--target` or `--scope`, which `rig apply` has; (7) tools take bare `--target` ids, but resources need `--scope resources --target default-application:toml`; (10) progress lines on stderr are on by default and fill the output. Original report: [ki-principal messages, L128](https://github.com/knowledgeislands/ki-principal/blob/fbe4ebb0/+/_WORK/ki/messages.md?plain=1#L128). Captured as triage for Kris to adopt or cancel.
