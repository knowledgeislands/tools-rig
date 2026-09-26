---
id: RIG-CLI-019
area: CLI
title: Describe every option
theme: cli
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T13:00:00Z
updated_at: 2026-09-26T15:45:00Z
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

## Current state

Every command's help is a literal string at its own `-h|--help` branch, and the usage string is duplicated again at each rejection path. `rig status` prints its one line at `src/rig/20-orchestration.bash:3261`, `rig doctor` at `:3561`, `rig apply` at `:4142`, `rig bootstrap` at `:4504`; `rig show`, `rig list`, `rig explain`, `rig run`, and `rig diag` in `src/rig/30-commands.bash`; `rig export`, `rig capture`, and the shared `rig update` / `rig maintain` in `src/rig/40-publication-lifecycle.bash`; `rig completion` in `src/rig/90-main.bash`. `rig_command_apply` alone repeats its usage string seven times across `syntax_error` calls.

Top-level help is `print_help` in `src/rig/00-runtime.bash`, which opens at line 112 with `Usage: rig [options] [command]` and closes with the two operational notes the record identifies, including `Add '--unattended' to update or maintain when nobody is watching the run.`

Completion is generated in the same file, from hand-written option lists rather than from the help text: `print_bash_completion` embeds `--profile --dry-run --unattended` per command at line 584, and `print_zsh_completion` embeds the same options again with descriptions at line 634. The Zsh completion already carries per-option descriptions such as `--unattended[run with nobody watching and record the outcome]`, which no help output shows. So there are three hand-maintained renderings of one option surface, and the one with the best descriptions is the one nobody reads.

## Steps

- [ ] Add one authored option table per command — identifier, argument placeholder, and a one-line description — as data in `src/rig/00-runtime.bash`, replacing the seven scattered copies of each usage string with a single lookup.
- [ ] Generate each command's `--help` output from that table: the usage line, one line per option, an exit-status note where the command's statuses are meaningful, and one worked example.
- [ ] Generate the Bash and Zsh completion option lists from the same table, so a flag that is not described is a flag that does not complete, and delete the duplicated hand-written lists.
- [ ] Generate each `syntax_error` usage string from the same table, so a rejection and its help can no longer disagree.
- [ ] Move the two operational notes out of `print_help` into the per-command help for `update` and `maintain`, and leave top-level help as a command list.
- [ ] Add the destructive warning to `rig apply` help — that it reconciles rather than verifies, and will restart applications mid-run — as a description line, without adding a prompt or changing the default.
- [ ] Add Bats coverage asserting that every option accepted by every command appears in that command's `--help` with a description, and that the completion option lists match the help exactly.

## Files touched

- `src/rig/00-runtime.bash` — the option tables, the help generator, `print_help`, `print_bash_completion`, and `print_zsh_completion`.
- `src/rig/20-orchestration.bash`, `src/rig/30-commands.bash`, `src/rig/40-publication-lifecycle.bash`, `src/rig/90-main.bash` — each `-h|--help` branch and each `syntax_error` usage string replaced by the shared lookup.
- `bin/rig` — regenerated by `scripts/assemble-rig`.
- `tests/rig.bats` — help and completion alignment assertions.
- `man/rig.1` — only where its option descriptions and the new help text would otherwise disagree.

## Verify

```sh
scripts/assemble-rig --check
bats tests/
shellcheck bin/rig src/rig/*.bash
mandoc -T lint man/rig.1
for c in show list explain status doctor apply bootstrap update maintain capture run export diag completion; do rig "$c" --help; done
rig completion bash | bash -n /dev/stdin
rig completion zsh >/dev/null
```

Pass means every command's `--help` lists each of its options with a description, the new Bats case finds no option present in argument parsing but absent from help, generated completions still parse, and `rig --help` no longer carries per-command operational notes.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. It touches the same `-h|--help` branches that [RIG-CLI-017](RIG-CLI-017-report-what-needs-attention.md) and [RIG-CLI-016](RIG-CLI-016-apply-one-resource.md) add options to, so whichever lands second describes its new flag through the table rather than by editing a literal. Landing this one first is cheaper for both.

## Documentation impact

### Decision Records

None on the help text itself. If the `rig apply` warning is judged insufficient without a confirmation prompt or a dry-run default, that is a behaviour change outside this item's boundary and would need its own item and decision.

### Specifications

`docs/specs/orchestration.md` or `docs/specs/state.md` changes only if either states the help surface as a contract. The command surface, options, and behaviour are unchanged, so the CLI contract itself does not move.

### Guides

`man/rig.1` is the manual and keeps its fuller treatment; this item only ensures the help subset does not contradict it. `docs/guides/user/commands.md` needs no change, because it already describes what the options do — the point of the work is that the terminal now does too.

### Roadmap

No new follow-on work. Generating help, completion, and rejection text from one table removes the drift risk the record names, so no follow-on alignment item is needed.

## Discussion

### How much help is enough

A line per option, an exit-status note where the status is meaningful, and one worked example is the usual floor and is probably right here. Anything longer competes with the manual and will drift from it.

### Keeping it honest

Help, completion, and the manual are three renderings of one surface and are currently maintained as three. Whichever of them is authored by hand will be the one that goes stale; deciding which is generated from which is more of the work than writing the text.

### What is generated from what, settled

Planning chose the option table as the single authored source, with help, both completions, and every `syntax_error` usage string generated from it. The manual stays authored by hand, because it carries prose the table cannot hold, and the Bats alignment case is what keeps the two honest. The alternative — generating help from the manual — would make the runtime depend on a document format for no gain, and the third rendering nobody expected to matter turns out to be the rejection strings, of which `rig apply` alone has seven copies.

### Where the destructive facts go

Some of what a person most needs to know before running `rig apply` is a warning, not a description. Whether help is the right place for it, or whether that belongs to a confirmation prompt or a dry-run default, is worth settling before the text is written.

Planning settled it as a description line in help, and deliberately not as a prompt or a changed default. Help is the surface this item owns; a prompt or a dry-run default changes what `rig apply` does, which the Boundary excludes and which an unattended caller would have to be protected from separately. Saying plainly in help that apply reconciles rather than verifies is the whole of what this item can honestly deliver, and it is worth having on its own. If a stronger guard is wanted afterwards, it is a behaviour item with its own decision.
