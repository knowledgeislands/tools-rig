---
id: KI-TOOL-RIG-CLI-027
area: CLI
title: Command-line convention departures
purpose: debt
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T19:22:21Z
updated_at: 2026-10-18T19:22:21Z
---

# Command-Line Convention Departures

## Goal

Rig's option handling follows the `ki-repo-tools` command-line conventions: `--format=json` is accepted as well as `--format json`, machine output uses the house form, `--dry-run` has `-n`, and `--` ends option parsing.

## Context

[KI-HARNESS-GOV-218](/Users/krisbrown/workspaces/knowledge-islands/ki-agentic-harness/docs/roadmap/KI-HARNESS-GOV-218-cli-conventions.md) added the command-line conventions reference to `ki-repo-tools`. Its run of 18 October 2026 compared tools-rig with it, read-only, and found four departures ([cli-conventions report](https://github.com/knowledgeislands/ki-principal/blob/06acbc19def494109edcf74fae37aab592f4f3a2/+/_WORK/ki.ways-of-working/cli-conventions.report.md)):

- `--format=json` is not accepted; only `--format json` works.
- Machine output uses `--format text|json` rather than `--json`, which mgit uses.
- `--dry-run` has no `-n`.
- No `--` end-of-options handling was found in the option code. The run searched for it but did not test it.

Kris answered CLI-DEPARTURES a) on 18 October 2026 (ki.tools-burndown work file, messages acted on at the mark): add each departure to the record that owns the command, else the nearest CLI or conventions record, else one triage record, and fix it at the tool's next change. No open tools-rig record owns Rig's shared option parsing, so this record carries all four.

## Boundary

- In: the four departures above across every Rig command that takes the options; help, completion, manual and specification updates for them; isolated tests.
- Out: `-f, --filter`, excluded under CLI-F-FILTER; changing the conventions themselves; other tools' departures.

## Dependencies / blocks

None. Blocks nothing.

## Discussion

Capture only; adoption, priority and plan belong to this repository. The fix is due at Rig's next change. Planning questions: whether `--format text|json` stays as Rig's form, with `--json` added as an alias, or the conventions reference settles one house form first; and whether `--` handling is confirmed absent by a test before it is added.
