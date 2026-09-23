---
id: RIG-CLI-010
area: CLI
title: Project machine-readable status
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: e8b4f99a425b3516042a9b0c4f25740c7bbaf244
transferred_from: KI-OBS-BRG-001
created_at: 2026-09-22T07:20:00Z
updated_at: 2026-09-23T16:40:00Z
---

## Goal

A program that wants to know what Rig has observed about a machine can read that answer as structured data, rather than by parsing text that Rig formats for a person.

## Context

Rig 0.3.0 has no machine-readable projection of observed state. `status`, `show`, `list`, `diag`, and `doctor` all render for a terminal, and none of them accepts `--json` or `--format`. `rig export PUBLICATION --output DIRECTORY` is the one structured output, and it generates curated public data for publication rather than a projection of what Rig observes locally.

This record exists because another repository needed that projection and declined to invent it. `KI-OBS-BRG-001` in `knowledgeislands/apps-observatory` builds the Observatory's Bridge — a local view of machine state with governed operations over it — and wanted `rig status` as one of its evidence sources. It reports Rig's state as explicitly unavailable, with that reason on screen, rather than parsing decorated output into a dependency that a cosmetic change here would break. Its adapter sits behind the same port seam as every other evidence source, so adopting a contract delivered by this record replaces one file there and reshapes nothing.

The hand-over is deliberate rather than incidental: each repository owns what it can verify. `tools-rig` owns what `rig status` means and what its output promises; `apps-observatory` owns consuming that promise. A consumer that guessed at the shape would be asserting a contract this repository never made.

## Boundary

This record does not change what `rig status` observes, how it resolves a profile, or what it considers drifted — only how an already-computed answer is rendered for a program. It does not add a daemon, a socket, or any long-lived service. It does not extend `rig export`, whose audience is publication rather than local inspection. It does not commit `apps-observatory`, or any other consumer, to adopting the result.

## Current state

`rig status` and `rig doctor` accept only `--profile` and, for status, `--unmanaged`; any other argument is a status 2 syntax error. Observation is already separated from rendering: `rig_command_status` runs `rig_observe_plan`, `rig_observe_resource_plan`, `rig_observe_ports` and `rig_observe_skills` to completion, then reads the resulting `RIG_PLAN_*`, `RIG_SKILL_*`, `RIG_RESOURCE_PLAN_*`, `RIG_PORT_*` and `RIG_UNMANAGED_*` arrays into `rig_table_add_row`. A second renderer therefore reads the same arrays and cannot disagree with the tables about what was observed.

Rig has no JSON encoder. `rig export` writes publication data through its own generators, which are curated for a public projection and are not a projection of local observation, so they are not reusable here.

## Decisions

The Shaping questions are answered as follows, so the payload is stable enough to version.

- **Surface.** A `--format text|json` option, defaulting to `text`, on `rig status` and `rig doctor`. Those are the two commands that project an observation; `show`, `list` and `explain` project declarations, which is what `rig export` already serialises and which no consumer has asked for. One option spelling, set once, avoids a per-command `--json`.
- **Versioning.** The payload is an object carrying `schema` (an integer, `1`) and `rig` (the running version string). A consumer refuses a `schema` it does not recognise instead of misreading it.
- **Contents.** The resolved profile and platform, an observation timestamp, the summary counts already printed for a person, a `healthy` boolean, and one array per observed kind — `tools`, `skills`, `resources`, `ports`, and `unmanaged` when `--unmanaged` was asked for. Each entry carries its identity, its provider or authority, its kind where it has one, its state from the existing vocabulary, and its detail. Provider-specific detail is carried as the same opaque `detail` string a person sees, rather than decomposed: decomposing it would make every provider's detail vocabulary part of this contract, which is a far larger promise than the consumer asked for.
- **Paths.** No structured field carries a local path. `detail` is declared human-facing free text that MAY contain one, so a consumer rendering into a browser can drop exactly one field rather than scanning every value. This is the marking the consumer asked for, expressed as a contract rather than a scrubber.
- **Exit status.** Unchanged. `--format` selects a rendering, and an exit status that varied by rendering would be a trap. Drift still returns 1. The payload also carries `healthy` and the counts, so a consumer that wants the verdict as data never has to read the exit status to get it.
- **Streams.** The payload is the only thing on stdout, is emitted after observation has completed, and is a single line-delimited object. Progress and native diagnostics stay on stderr. A status 2 rejection prints no payload at all.

## Steps

- [ ] Add a JSON string encoder that escapes the characters a detail or identity can actually contain, without a per-character loop that would break the status performance budget.
- [ ] Accept `--format text|json` on `rig status` and `rig doctor`, rejecting any other value with status 2 and the existing syntax-error contract.
- [ ] Emit the versioned `rig status` payload from the observation arrays the text tables already read, so the two renderings cannot disagree.
- [ ] Emit the `rig doctor` payload in the same envelope, carrying its findings and its verdict.
- [ ] Keep the exit status, the stderr progress contract, and every observed state identical between the two renderings.
- [ ] Cover the payload with Bats: shape and version, both commands, a drifted machine's non-zero exit beside `healthy: false`, `--unmanaged`, a rejected `--format` value, and a detail containing a quote and a backslash.
- [ ] Align the CLI specification, the state Specification where it names the rendering, the user command guide, the manual, shell completion, and the changelog.

## Delegation

No delegation is planned. The encoder, the option, both payloads, and the contract documentation are one change.

## Files touched

- `src/rig/00-runtime.bash` for the JSON encoder.
- `src/rig/20-orchestration.bash` for the option and both payloads, and the assembled `bin/rig`.
- `src/rig/30-commands.bash` for completion output if the option appears there.
- `tests/rig.bats` for the payload contract.
- `docs/specs/cli.md`, `docs/guides/user/commands.md`, `man/rig.1`, and `CHANGELOG.md`.
- This roadmap record for delivery evidence.

## Verify

- Bats covering the envelope, both commands, the drift verdict beside a non-zero exit, `--unmanaged`, a rejected format value, and escaping.
- The payload parses: the tests pipe it through a JSON parser rather than matching it as text.
- The complete repository verification gate, including `scripts/benchmark-rig`, which must still show `status` inside its budget.

## Dependencies / blocks

No delivery dependency. `KI-OBS-BRG-001` in `knowledgeislands/apps-observatory` consumes this contract and closed for what it delivered without it; neither waits on the other.

## Documentation impact

### Decision Records

None. The structured projection renders an answer Rig already computes and makes no new architectural commitment; [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) already separates publication data from local inspection, and this record stays on the local side of that line.

### Specifications

The CLI Specification gains the `--format` option, the envelope, its versioning rule, and the stream and exit-status guarantees.

### Guides

The user command guide explains when to ask for the structured form and that the human tables are not a machine interface.

### Roadmap

Record the delivered shape here so the consuming record can cite a version rather than an intention.

## Discussion

### Why a consumer asked rather than parsed

Parsing a human-facing rendering makes every cosmetic improvement here a breaking change somewhere else, without any signal that it happened. The consumer's own record states this as the reason it did not build the adapter: the failure would be silent, land in a repository that did not make the change, and look like a bug in the consumer.

### Open questions

Whether the projection belongs on `status` alone or on the whole family of read commands. Whether `doctor` should project its findings in the same envelope, since a consumer that shows drift will eventually want to show diagnosis too. Whether the payload should include the observation time, which a caching consumer needs and a person reading a terminal does not.

### Hand-over

`KI-OBS-BRG-001` in `knowledgeislands/apps-observatory` names this record as the owner of the contract, and closed for what it delivered without it. This record owns adding the projection; that record owns consuming it. Neither waits on the other to be useful.
