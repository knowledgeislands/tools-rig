---
id: RIG-CLI-018
area: CLI
title: One report renderer
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

Every table Rig prints looks the same, never destroys the identifier a reader needs to act on it, and is available in a machine format from whichever command produced it.

## Context

Rig has two table renderers and uses both, sometimes in one command's output. `rig show` prints its tool table in aligned columns with truncated cells, then prints the settings, Dock, and port tables as raw tab-separated lines with no alignment at all. `rig status` aligns everything. `rig apply` and `rig bootstrap` are tab-separated throughout. Nothing tells a reader which to expect, and a reader who has learned one shape meets the other in the next command.

Where alignment does happen, truncation falls on the wrong field. `rig status` shows `acquire-whatsapp-spool-...`, `finder-show-removable-m...`, `desktopservices-no-netw...`, and owner cells as `service:mcpor...`. The identifier is the one column whose value the reader has to carry to the next command — `rig explain` takes it — and it is the column being cut, while the purpose text beside it is what could safely lose characters.

The machine escape hatch does not cover the gap. `--format text|json` exists on `rig status` and `rig doctor` and nowhere else, so `show`, `list`, `explain`, `apply`, `bootstrap`, `update`, and `maintain` can only be consumed by parsing whichever of the two text shapes they happen to use.

One further defect belongs to the same report. Rig reserves stdout for the application report and routes provider output to stderr, which is the right contract, but on a terminal the two streams merge and provider output lands inside the table. An external provider writing one line during apply produced this:

```text
TOOL	PROVIDER	RESULT	DETAIL	SCOPE
reconciled two agents
paperclip-agents	paperclip	completed	-	declaration
```

## Boundary

This is the presentation layer: how rows are rendered, what gets truncated, and which commands can emit a machine format. It does not change what any command observes, which rows it selects, the state vocabulary, or the outcome contract. It does not change the stdout/stderr split, which is correct as specified — only how a report survives the two streams arriving interleaved on one terminal.

Choosing which rows to show at all is [RIG-CLI-017](RIG-CLI-017-report-what-needs-attention.md).

## Current state

There is one shared aligned renderer and one hand-rolled duplicate, plus raw `printf` with tabs wherever neither was used.

`rig_table_reset`, `rig_table_add_column`, `rig_table_add_row`, `rig_table_print_row`, and `rig_table_print` in `src/rig/30-commands.bash` are the shared renderer. A column is declared as `rig_table_add_column HEADER MAXIMUM [ellipsis]`, and `rig_table_print_row` truncates every cell to the column's observed width through `rig_ellipsize` or `rig_ellipsize_middle`. The maximum is a fixed per-column constant: `rig status` uses `TOOL 28 / PROVIDER 18 / STATE 12 / DETAIL 56`, the resource table `RESOURCE 26 / KIND 14 / PROVIDER 18 / STATE 12 / DETAIL 42`, the skill tables `SKILL 28 / AUTHORITY 20 / STATE 12 / DETAIL 54`, and the port tables `PORT 16 … DETAIL 40`. Twenty-eight characters is what cuts `acquire-whatsapp-spool-...`, and `OWNER 16` is what cuts `service:mcpor...`. The observed-identity table is the only column asking for `middle` ellipsis, at `IDENTITY 32 middle`.

`rig_print_profile_tool_table` in `src/rig/30-commands.bash` is a second aligned renderer, written for `rig show` with its own width variables. The settings, Dock, and port tables in the same command's output are raw tab-separated `printf`. `rig apply`, `rig bootstrap`, `rig update`, and `rig maintain` are tab-separated throughout — `printf 'TARGET\tPROVIDER\tRESULT\tDETAIL\n'` in `src/rig/40-publication-lifecycle.bash` is the shape a reader meets there.

`--format text|json` is parsed only in `rig_command_status` and `rig_command_doctor`. `rig_json_envelope` and `rig_json_field` are already general, so the machine format is a per-command wiring gap rather than missing machinery.

The interleaving defect is not in the renderer. Rig writes the report on stdout and provider output on stderr, which is correct; a terminal merges them, so a provider line lands between two table rows.

## Steps

- [ ] Give `rig_table_add_column` a per-column truncation priority so identifier columns keep their full value and the remaining width budget is spent on prose columns, replacing fixed per-column maxima with a bounded total line width.
- [ ] Retire `rig_print_profile_tool_table` and render `rig show`'s tool table through the shared renderer.
- [ ] Convert `rig show`'s settings, Dock, and port output, and the `TARGET PROVIDER RESULT DETAIL` reports in `rig apply`, `rig bootstrap`, `rig update`, and `rig maintain`, to the shared renderer.
- [ ] Wire `--format text|json` through `rig show`, `rig list`, `rig explain`, `rig apply`, `rig bootstrap`, `rig update`, and `rig maintain`, reusing `rig_json_envelope` and keeping each JSON projection complete regardless of what the text form shows.
- [ ] Buffer a mutation report's rows until the task they describe is complete, so a provider line written to stderr cannot land inside a table on a merged terminal, and confirm progress still reports the slow task as it happens.
- [ ] Add Bats coverage asserting that no rendered identifier cell contains an ellipsis for the longest identifier in the fixture catalogue, that every command accepting `--format json` emits a parseable payload, and that a provider writing to stderr mid-apply leaves the table rows contiguous on stdout.
- [ ] Regenerate completions and update `man/rig.1`, `docs/guides/user/commands.md`, and the README command summaries wherever they state which commands take `--format`.

## Files touched

- `src/rig/30-commands.bash` — the shared renderer, and the removal of `rig_print_profile_tool_table`.
- `src/rig/20-orchestration.bash` — status, doctor, apply, and bootstrap report construction and their `--format` parsing.
- `src/rig/40-publication-lifecycle.bash` — the lifecycle report and its `--format` parsing.
- `src/rig/00-runtime.bash` — generated completion text where the new `--format` options appear.
- `bin/rig` — regenerated by `scripts/assemble-rig`.
- `tests/rig.bats` and `tests/rig-projection.bats` — rendering and JSON assertions.
- `man/rig.1`, `docs/guides/user/commands.md`, `README.md` — the documented option surface.
- `docs/specs/state.md` — the report and projection contract.

## Verify

```sh
scripts/assemble-rig --check
bats tests/
scripts/benchmark-rig
shellcheck bin/rig src/rig/*.bash
mandoc -T lint man/rig.1
rig show --format json | python3 -m json.tool >/dev/null
rig status | grep -c '\.\.\.'
```

Pass means every listed command emits a parseable JSON payload under `--format json`, no identifier cell in a text table is truncated on this workstation's catalogue, one renderer produces every table, and `scripts/benchmark-rig` stays inside budget because buffering a report must not slow it.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. It wants deciding alongside [RIG-CLI-017](RIG-CLI-017-report-what-needs-attention.md) because both change what a reader sees in the same output, and the width-budget decision here is easier to make once the attention-first view has settled how many rows a table usually carries. Either can land first; landing this one first means CLI-017 filters a table that is already consistent.

## Documentation impact

### Decision Records

None on the stdout/stderr split, which stays as specified. If buffering mutation rows changes when a report becomes visible in a way a reader would notice, that is a presentation choice recorded here rather than a new decision.

### Specifications

`docs/specs/state.md` changes because the machine projection reaches seven more commands and the report's rendering contract becomes one renderer rather than two. The exit statuses, outcome contract, and state vocabulary are untouched.

### Guides

`docs/guides/user/commands.md`, `man/rig.1`, and the README command summaries all state which commands accept `--format`, and all three must change together with the generated completions.

### Roadmap

No new follow-on work. A consistent table makes [RIG-CLI-017](RIG-CLI-017-report-what-needs-attention.md) a filtering change rather than a filtering-and-tidying change.

## Discussion

### Which renderer wins

Aligned columns read better and are what the commands a person runs interactively already use. Tab-separated survives `cut` and `awk`, which is presumably why the mutation reports use it. If `--format json` reaches every command, that argument weakens considerably and the text form can simply be the readable one everywhere.

### Truncating the right column

Truncating on a fixed per-column width treats every column as equally disposable. Giving identifier columns their full width and spending the remaining budget on prose would fix every observed case, because the long values are identifiers and the compressible ones are purposes.

### Interleaving

Holding provider output until the row it belongs to is complete would keep the table intact, at the cost of no longer streaming a slow provider's progress as it happens. Whether that trade is right probably depends on whether progress already covers the need.
