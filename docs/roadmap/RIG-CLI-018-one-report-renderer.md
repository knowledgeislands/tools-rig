---
id: RIG-CLI-018
area: CLI
title: One report renderer
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

## Discussion

### Which renderer wins

Aligned columns read better and are what the commands a person runs interactively already use. Tab-separated survives `cut` and `awk`, which is presumably why the mutation reports use it. If `--format json` reaches every command, that argument weakens considerably and the text form can simply be the readable one everywhere.

### Truncating the right column

Truncating on a fixed per-column width treats every column as equally disposable. Giving identifier columns their full width and spending the remaining budget on prose would fix every observed case, because the long values are identifiers and the compressible ones are purposes.

### Interleaving

Holding provider output until the row it belongs to is complete would keep the table intact, at the cost of no longer streaming a slow provider's progress as it happens. Whether that trade is right probably depends on whether progress already covers the need.
