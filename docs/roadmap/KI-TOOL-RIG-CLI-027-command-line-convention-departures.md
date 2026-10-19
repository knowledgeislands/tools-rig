---
id: KI-TOOL-RIG-CLI-027
area: CLI
title: Command-line convention departures
purpose: debt
theme: rig
kind: deliver
horizon: now
status: ready
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T19:22:21Z
updated_at: 2026-10-19T22:52:00Z
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

## Current state

Confirmed on 19 October 2026 against the committed `bin/rig` (`0.7.0+dev`) in a disposable HOME and XDG tree, using only `show`, `init -n` and `help`: `show --`, `show --format=json`, `show --json` and `init -n` each exit 2 with the command's usage, and `help --` exits 2 as an unknown command. All four departures are real, and `--` is rejected, not merely untested.

Each command parses its own arguments by hand (`rig_command_show` in `src/rig/30-commands.bash`, `rig_command_status` and `rig_command_doctor` in `22-observation.bash`, `rig_command_apply_impl` in `23-application.bash`, `rig_command_remove_impl` in `27-software-removal.bash`, `rig_command_init`, `rig_command_repair` and `rig_command_capture` in `35-adoption.bash`, `rig_command_export` and `rig_command_lifecycle_impl` in `40-publication-lifecycle.bash`, `rig_command_diag` and `main` in `90-main.bash`), and every one rejects any other `-*` word. `rig_command_options` in `00-runtime.bash` is the single authored option inventory behind usage, help and both completions, and it records whether each long option takes a value. Only `show`, `capture` and `completion` take operands; `help` takes a command name.

The [command-line conventions](/Users/krisbrown/workspaces/knowledge-islands/ki-agentic-harness/skills/repo-structure/ki-repo-tools/references/standards-cli-conventions.md) settle the format question: `--json` is the common form, and `--format <name>` is for a command that offers several formats. Every Rig command offers one machine format beside its default text, so `--json` is the house form. The same reference says a shipped departure is reconciled through the tool's own record and changelog rather than by renaming a flag in passing, and `--format text|json` runs through the suites, the guides and `rig(1)`. This plan therefore adds `--json` as the documented machine-output form and keeps `--format text|json` as an accepted, documented equivalent; nothing is removed.

## Design

The normaliser applies these rules left to right, up to `--`:

- `--name=value` for an option the inventory gives a value becomes `--name value`; the text after `=` is kept literally, empty included, so each parser's existing value checks still apply. `--name=value` for a flag option is a syntax error. An unknown `--name=value` passes through for the parser to reject as today.
- The word after a value option is consumed verbatim, so `--purpose -n` or `--profile --json` stay values.
- `--json` becomes `--format json` on a command whose inventory has `--format`. Giving both is a duplicate `--format` and keeps the parser's existing syntax error.
- `-n` becomes `--dry-run` on a command whose inventory has `--dry-run` (`init`, `apply`, `remove`, `upgrade`, `capture`); elsewhere it stays unknown.
- `--` ends option processing: it is consumed, and every later word is an operand even when it begins with `-`. A command without operands accepts a trailing lone `--` and rejects any word after it with its usage.

## Steps

- [ ] Add one shared normaliser beside `rig_command_options` in `src/rig/00-runtime.bash`, driven by that inventory and following the rules under Design, which rewrites a command's arguments into the shape the existing parsers already accept and returns them through a global array. `main` in `90-main.bash` calls it for each command before dispatch, so no parser grows its own copy.
- [ ] Give the operand-taking parsers an end-of-options branch so a word after `--` reaches them as an operand: `show` (`ITEM`), `capture` (`ITEM...`), `completion` (`bash|zsh`) and `help` (`COMMAND`). Keep each command's existing operand validation, so `show -- --all` is an unknown item, not a selector.
- [ ] Extend the inventory with an optional short form, used only for `-n`, and add a `--json` entry to every command that has `--format`. Help prints `-n, --dry-run` and lists `--json`; Bash and Zsh completion offer both; the synopsis shows the same forms on every surface `RIG-PORT-007` aligns.
- [ ] Add tests to `tests/rig-cli-surface.bats`: `--format=json` and `--json` give byte-identical output to `--format json` for `show` and `status`; `--profile=NAME`, `--category=ID`, `--scope=tools` and repeated `--target=ID` parse as their separate forms; `--dry-run=x` and `--json --format text` exit 2; `-n` matches `--dry-run` for `init` (no configuration written) and `apply` (no provider invocation, through `rig_test_provider`) and exits 2 on `show`; `show -- selected` resolves the item, `show -- --all` is an unknown item, `status --` succeeds and `status -- x` exits 2; `show --profile -n` reports an unknown profile rather than a dry run; `help -- apply` and `completion -- bash` work; the completion definitions expose `-n` and `--json`. Existing `--format json` tests stay unchanged as the compatibility proof.
- [ ] Update `rig(1)`, the [command guide](../guides/user/commands.md), the README synopsis, the [command-surface guide](../guides/developer/command-surface.md) (the normaliser's ownership, and that parsers see normalised arguments) and the changelog baseline. Use `--json` in new machine-output examples; leave existing `--format json` examples where they read naturally.
- [ ] Add `RIG-PORT-014 — Command-line option grammar` to [portability](../specs/portability.md): equals and separate long-option values, `--json` and `--format json` equivalence, `-n` for `--dry-run`, `--` as end of options, and exit 2 for every violation.
- [ ] Regenerate `bin/rig` with `scripts/assemble-rig` and run the complete gate.

## Files touched

- `src/rig/00-runtime.bash`, `src/rig/90-main.bash`, `src/rig/30-commands.bash`, `src/rig/35-adoption.bash`; another parser module only if its end-of-options or duplicate handling needs it.
- `bin/rig`, regenerated.
- `tests/rig-cli-surface.bats`; `tests/rig.bats` only where its alignment or completion assertions enumerate options.
- `man/rig.1`, `README.md`, `docs/guides/user/commands.md`, `docs/guides/developer/command-surface.md`, `CHANGELOG.md`, `docs/specs/portability.md`.
- This record.

## Verify

- The new `tests/rig-cli-surface.bats` cases pass, and every existing `--format json` case passes unchanged.
- `RIG-PORT-007`'s alignment tests pass with `-n` and `--json` on every surface.
- [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository) passes, `bats tests/ </dev/null` included, with assembly drift, Bash 3.2 syntax and ShellCheck clean. No live apply; any manual check uses read-only commands in a disposable HOME and XDG tree.

## Dependencies / blocks

None. Blocks nothing. [KI-TOOL-RIG-CLI-026](KI-TOOL-RIG-CLI-026-per-tool-development-mode-switch.md) adds behaviour rather than option grammar, and inherits the normaliser if it lands later.

## Documentation impact

### Decision Records

None; the conventions reference is the authority and this record applies it.

### Specifications

`RIG-PORT-014` is added to [portability](../specs/portability.md), conforming with its evidence.

### Guides

The command guide, command-surface guide, README and `rig(1)` gain the forms above.

### Roadmap

This record moves to Awaiting review at delivery.

## Discussion

Capture only; adoption, priority and plan belong to this repository. The fix is due at Rig's next change. Planning questions: whether `--format text|json` stays as Rig's form, with `--json` added as an alias, or the conventions reference settles one house form first; and whether `--` handling is confirmed absent by a test before it is added.

Planned on 19 October 2026 under Kris's RIG-ORDER decision of that evening, option a ("All three are high confidence to do them"). The conventions reference already settles `--json` as the house form, so `--json` is added and `--format` kept as its equivalent. A direct probe confirmed `--` absent; the new tests prove the handling once it is added.
