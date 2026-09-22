---
id: RIG-CORE-020
title: Improve runtime scalability
area: CORE
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 28b7d426b1caa9c8228843931b3df3f16d292731
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-22T03:16:26Z
---

## Goal

Rig should load and query a realistic personal catalogue quickly, observe provider state without avoidable repetition, and remain reviewable as its Bash-only capability grows.

## Context

On the 1,893-line personal configuration, `rig diag` took about 16.8 seconds and `rig show` about 15.7 seconds. A bounded doctor run displayed progress but had only begun the first of 99 tool observations after 30 seconds. The single executable now contains more than 7,000 lines and about 229 functions, while functional large-catalogue tests impose no performance budget.

## Boundary

This work does not change the installed Bash 3.2 and zero-required-runtime contract merely to gain speed. It does not weaken validation, remove progress reporting, cache observed provider state as competing authority, or make completion invoke an expensive model resolution.

## Current state

The 1,893-line personal configuration takes roughly 16 seconds for declaration-only `diag` and `show`, while `doctor` repeatedly observes individual tools. Parsing and section lookup rescan text, provider observations are mostly per declaration, no representative performance budget guards regression, and one 7,000-line authored executable increases change coupling.

## Steps

- [x] Add a deterministic large-catalogue benchmark fixture and budgets for configuration loading, `show`, `diag`, profile resolution, and fake-provider observation.
- [x] Profile parser and lookup paths, index parsed sections once, and remove repeated whole-configuration scans without weakening validation.
- [x] Batch observations by native provider where a fixed literal provider operation can return equivalent evidence; retain per-item fallbacks and truthful unavailable states.
- [x] Keep slow-work progress aligned with `RIG-CLI-009` and prove completion remains cheap and side-effect free.
- [x] Split authored implementation into domain-focused Bash modules assembled deterministically into the single installed `bin/rig`, with an assembly drift check.
- [x] Add a bounded disposable-environment smoke matrix for native manager discovery and harmless observations while retaining fake-based behavioural coverage.

## Files touched

Expected scope includes authored shell modules, generated `bin/rig`, the assembly script and drift check, `tests/`, `docs/specs/`, `docs/guides/developer/`, `AGENTS.md`, and `CHANGELOG.md`.

## Verify

Run the complete repository gate, assembly drift check, deterministic benchmark fixture within documented budgets, Bash 3.2 syntax and ShellCheck across authored modules and assembled runtime, and the bounded native smoke matrix where its prerequisites are available.

## Dependencies / blocks

No semantic prerequisite blocks profiling. Coordinate observation phase reporting with `RIG-CLI-009`; document any environment-dependent native smoke as explicitly unavailable rather than fabricating a pass.

## Delegation

Benchmark design, parser indexing, provider batching, and source-module extraction are separable lanes after profiling establishes a shared baseline. The coordinator owns performance comparison, generated-runtime integrity, and the final gate.

## Documentation impact

### Decision Records

Retain the single installed Bash runtime decision while clarifying that authored sources may be modular and deterministically assembled.

### Specifications

Add measurable declaration-only and observation performance requirements plus assembly and native-smoke evidence expectations.

### Guides

Document contributor assembly, benchmark, and smoke-test workflows; user guides mention progress rather than internal optimisation.

### Roadmap

Performance regressions beyond the representative budgets become new evidence-backed records; this item owns the present scaling correction.

## Review

### Delivered

Delivered the approved scalability boundary from immutable baseline `28b7d426b1caa9c8228843931b3df3f16d292731`: deterministic query and observation budgets, indexed declaration lookup, equivalent built-in observation coalescing, deterministic authored-module assembly, and bounded disposable native smoke. The installed Bash 3.2 runtime, exact native command matrix, custom-provider isolation, and progress semantics remain unchanged.

### Summary of changes

- Replaced quadratic model-wide declared-field scans with per-section indexes and added validated fast paths for comment-free lines, unescaped strings, and complete arrays. The 1,434-line fixture improved from approximately 11.4 seconds for `diag` and `show` to measured runs of 1–2 seconds on macOS Bash 3.2.
- Coalesced only identical built-in read-only invocations, keyed by executable and length-delimited literal arguments. Results remain command-local and each tool still performs dependency, identity, artifact, result, and progress evaluation; custom providers are never coalesced.
- Split authored implementation into six domain-focused files beneath `src/rig/`; `scripts/assemble-rig` produces byte-identical committed `bin/rig` and fails closed on drift. The assembled file remains the single installed payload without a runtime loader.
- Added a self-contained 100-tool benchmark with five-second portable query and eight-second fake-provider observation guards, a two-second reference query target, a disposable-XDG native version-probe matrix, focused Bats coverage, and contributor and release guidance.
- Updated the shell-runtime Decision Record, portability and orchestration Specifications, developer guides, repository instructions, and changelog.

### Verification

- `ki repo audit --repo .` — passed.
- Focused `ki-authoring`, `ki-decision-records`, `ki-specs`, `ki-guides`, and `ki-work-roadmap` audits — passed.
- `shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers` — passed.
- `/bin/bash -n` across the installed payload, installer, authored modules, and scripts — passed.
- `scripts/assemble-rig --check` and its drift-failure Bats case — passed.
- `RIG_BENCHMARK_BUDGET_SECONDS=2 scripts/benchmark-rig` — passed with `diag` 1–2 seconds, `show` 2 seconds, `list` 1–2 seconds, and fake-provider `status` 5–6 seconds within its eight-second guard.
- `scripts/smoke-native-providers` — passed read-only version probes for Homebrew, uv, mise, npm, chezmoi, and mas in a disposable HOME and XDG environment; unavailable commands would report explicit skips.
- `bats tests/` — all 217 tests passed.
- `mandoc -T lint man/rig.1`, `rumdl check` for touched Markdown, and `git diff --check` — passed.

### Outstanding concerns

None within the approved boundary. Wall-clock benchmark assertions deliberately retain portable headroom above the measured two-second reference target, and the native smoke matrix proves bounded command availability rather than replacing fake-based provider behaviour tests.

### Post-change review

The implementation removes the measured parser bottleneck without weakening duplicate detection or configuration validation, preserves exact provider commands while reducing repeated identical uv-style inventory work, and lowers maintenance coupling without changing installation. Fresh semantic review found no competing cache authority, custom-provider reuse, runtime loader, unsafe native mutation, or CLI progress regression. The item is ready for human acceptance.

### Mini recap

Rig now queries a representative personal catalogue near the two-second reference target, reuses only equivalent command-local observations, and is authored in reviewable modules while shipping the same standalone Bash executable. Durable rationale, accepted quality requirements, contributor procedure, release procedure, and regression evidence are all recorded in their canonical homes; no additional learning promotion is required.

## Discussion

### Locked delivery boundary

This item has three ordered phases under one measurable outcome: establish budgets and optimise declaration-only paths; batch equivalent provider observations; then modularise authored sources without changing the assembled runtime contract. The final gate covers all three, so none can be mistaken for a separately completed item.

### Performance evidence

Introduce representative query and observation budgets, profile parser and repeated lookup cost, and batch provider observations where native systems support it. Declaration-only commands should normally complete quickly enough that progress is unnecessary; slow observation should retain explicit progress.

### Authored structure

One installed executable does not require one authored source file. Consider deterministic assembly from domain-focused Bash modules with a drift check so parser, model, providers, resources, publication, cache, and presentation can be reviewed independently without introducing a runtime dependency.

### Native confidence

Retain exact fake-based contract tests and add a small disposable-machine smoke matrix for real manager commands and platform effects. Performance evidence and native smoke evidence should complement rather than replace deterministic unit coverage.
