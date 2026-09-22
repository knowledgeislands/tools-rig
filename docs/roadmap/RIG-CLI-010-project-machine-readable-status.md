---
id: RIG-CLI-010
area: CLI
title: Project machine-readable status
theme: cli
horizon: soon
status: draft
blocks: []
blocked_by: []
baseline_ref: null
transferred_from: KI-OBS-BRG-001
created_at: 2026-09-22T07:20:00Z
updated_at: 2026-09-22T07:20:00Z
---

## Goal

A program that wants to know what Rig has observed about a machine can read that answer as structured data, rather than by parsing text that Rig formats for a person.

## Context

Rig 0.3.0 has no machine-readable projection of observed state. `status`, `show`, `list`, `diag`, and `doctor` all render for a terminal, and none of them accepts `--json` or `--format`. `rig export PUBLICATION --output DIRECTORY` is the one structured output, and it generates curated public data for publication rather than a projection of what Rig observes locally.

This record exists because another repository needed that projection and declined to invent it. `KI-OBS-BRG-001` in `knowledgeislands/apps-observatory` builds the Observatory's Bridge — a local view of machine state with governed operations over it — and wanted `rig status` as one of its evidence sources. It reports Rig's state as explicitly unavailable, with that reason on screen, rather than parsing decorated output into a dependency that a cosmetic change here would break. Its adapter sits behind the same port seam as every other evidence source, so adopting a contract delivered by this record replaces one file there and reshapes nothing.

The hand-over is deliberate rather than incidental: each repository owns what it can verify. `tools-rig` owns what `rig status` means and what its output promises; `apps-observatory` owns consuming that promise. A consumer that guessed at the shape would be asserting a contract this repository never made.

## Boundary

This record does not change what `rig status` observes, how it resolves a profile, or what it considers drifted — only how an already-computed answer is rendered for a program. It does not add a daemon, a socket, or any long-lived service. It does not extend `rig export`, whose audience is publication rather than local inspection. It does not commit `apps-observatory`, or any other consumer, to adopting the result.

## Shaping

- Decide the surface: a `--format json` option on the read commands, matching whatever convention this CLI already sets elsewhere, in preference to a separate `rig status --json` spelling that would have to be repeated per command.
- Version the payload explicitly, so a consumer can refuse a shape it does not recognise rather than misread it.
- Decide what the projection carries: at minimum the resolved profile identity, per-provider selection and observed state, and a drift verdict per declared item. Whether it carries provider-specific detail is the open question.
- Keep local paths out of the payload, or mark them, so a consumer rendering into a browser does not have to strip them. `apps-observatory` currently drops anything path-shaped from every source it reads.
- Settle exit-code semantics for the structured form: whether drift is a non-zero exit, as it is for a person, or purely a field in the payload.
- Promotion condition: the payload shape is agreed and stable enough to version, and at least one consumer has stated what it needs from it. `KI-OBS-BRG-001` has done so.

## Discussion

### Why a consumer asked rather than parsed

Parsing a human-facing rendering makes every cosmetic improvement here a breaking change somewhere else, without any signal that it happened. The consumer's own record states this as the reason it did not build the adapter: the failure would be silent, land in a repository that did not make the change, and look like a bug in the consumer.

### Open questions

Whether the projection belongs on `status` alone or on the whole family of read commands. Whether `doctor` should project its findings in the same envelope, since a consumer that shows drift will eventually want to show diagnosis too. Whether the payload should include the observation time, which a caching consumer needs and a person reading a terminal does not.

### Hand-over

`KI-OBS-BRG-001` in `knowledgeislands/apps-observatory` names this record as the owner of the contract, and closed for what it delivered without it. This record owns adding the projection; that record owns consuming it. Neither waits on the other to be useful.
