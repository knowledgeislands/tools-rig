---
id: RIG-CORE-002
area: CORE
title: Build orchestration engine
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 6925c31d2bf8bdeb1a2eb9ed65b57ba375ecebad
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T21:37:27Z
---

# RIG-CORE-002: Build orchestration engine

## Goal

Rig can observe provider state, compare it with a resolved profile, and dispatch supported materialisation actions in dependency order with predictable failure reporting.

## Context

The catalogue resolver supplies deterministic tools and bindings but does not invoke providers or model observed state. The legacy dotfiles Rig has install-safe ordered dispatch and provider-specific protections. The standalone engine must generalise that behaviour without hard-coding one machine's subsystem names, package choices, or host paths.

## Boundary

This item builds the provider execution protocol, expected-versus-observed state model, dependency planner, and public `status` and `apply` orchestration over explicitly configured executable providers. It does not implement Homebrew, uv, chezmoi, or direct-download adapters; declared tool operations; doctor synthesis; private declarations; or publication.

## Current state

Rig resolves profiles, transitive tool relationships, platform compatibility, and provider bindings without invoking providers. No public command observes machine state or performs materialisation. ADR-RIG-005 now fixes the custom-provider ABI, dependency-first work model, public state vocabulary, catalogue-only treatment, preflight boundary, deterministic output, and command exit meanings.

## Locked contract

Custom providers use `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER TOOL KIND LOCATOR [BINDING_ARGUMENT ...]`, where `VERB` is exact capability `observe` or `apply`. Observation returns exactly one accepted state token. Rig owns deterministic stdout, translates native failures into stable details, and uses command statuses 0, 1, and 2 for success, operational findings, and syntax or preflight failure respectively.

Execution creates one work unit per selected binding and orders it dependency-first by `tool.requires`, with bytewise identity as the stable tie-break. Catalogue-only tools are neutral `unavailable` or `skipped` rows. Apply validates the complete selected plan before mutation; dry-run invokes nothing. This item implements only custom providers and leaves built-in adapters to RIG-CLI-001.

## Steps

- [x] Record the executable-provider ABI: action verbs, argument order, observation response syntax, output ownership, and native failure translation.
- [x] Lock the public state contract: deterministic ordering, catalogue-only and unavailable treatment, summaries, and exit meanings for `status` and `apply --dry-run`.
- [x] Define a literal-argument provider protocol and recording test seam for observation and application capabilities.
- [x] Derive deterministic binding work from a resolved profile and its selected bindings.
- [x] Report each expected tool as `present`, `missing`, `drifted`, `unavailable`, or `unknown` with its responsible provider.
- [x] Add `rig status [--profile NAME]` as an observation-only command.
- [x] Add `rig apply [--profile NAME] [--dry-run]` with explicit preflight, dependency ordering, native outcomes, and dependent-work suppression after failure.
- [x] Reject unknown providers, unsupported capabilities, ambiguous bindings, and invalid dependency plans before mutation.
- [x] Align help, completion, README, `rig(1)`, changelog, Bats coverage, and implemented Specification evidence.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/decisions/ADR-RIG-005-provider-execution-contract.md`, `docs/decisions/README.md`, `docs/specs/state.md`, `docs/specs/orchestration.md`, and this work record.

## Verify

Use fake recording executables for exact invocation and failure assertions. Run focused Bats cases during implementation, then `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

The catalogue resolver is complete and no roadmap build dependency remains. ADR-RIG-005 records the approved execution and public state contracts, so implementation can proceed. Delivery then unblocks RIG-CLI-001; it does not itself implement Homebrew, uv, chezmoi, or direct-download adapters.

## Delegation

One bounded implementation worker may edit `bin/rig` and `tests/rig.bats` against the recorded baseline. The coordinator owns public documentation, Specification evidence, roadmap lifecycle, integration review, verification, and commits. A read-only reviewer may inspect the provider protocol and failure boundaries without changing files.

## Documentation impact

### Decision Records

ADR-RIG-005 locks the executable-provider ABI and public state treatment. XDR-RIG-001 continues to own the trust transition rather than transport or presentation semantics.

### Specifications

Update state and orchestration requirements to reflect the approved ABI, public state treatment, and recording-provider evidence.

### Guides

No separate guide is required for the initial concise `status` and `apply` procedures.

### Roadmap

Record review evidence here and leave adapter, doctor, operation, migration, and distribution work in their owning items.

## Review

### Delivered

From baseline `6925c31d2bf8bdeb1a2eb9ed65b57ba375ecebad`, Rig now provides custom-provider observation and application through the versioned `rig-provider-v1` ABI. The delivery includes dependency-first work planning, stable state and result reports, neutral catalogue-only rows, complete apply preflight, non-mutating dry-run, native failure detail, and transitive dependency suppression. Built-in adapters remain excluded.

### Summary of changes

`bin/rig` adds `status` and `apply`, Bash 3.2-compatible plan and result arrays, executable and capability checks, literal invocation construction, response validation, and provider output routing. `tests/rig.bats` adds recording-provider coverage for ordering, literal arguments, state boundaries, output channels, preflight atomicity, native exits, explicit profiles, unselected providers, dry-run, and failure suppression. README, manual, completions, changelog, ADR-RIG-005, and the state and orchestration Specifications now describe one command and execution contract.

### Verification

ShellCheck and Bash syntax checks passed. All 59 Bats tests passed. `mandoc -T lint man/rig.1`, `git diff --check`, and the `ki-decision-records`, `ki-specs`, `ki-authoring`, `ki-repo-tools`, and `ki-work-roadmap` audits passed. An independent contract review found no Bash 3.2, argument-safety, preflight, ordering, or suppression defect; its documentation and test-coverage findings were addressed before the final gate.

### Outstanding concerns

The full KI repository audit remains 14 of 15 checks passing because nine pre-existing live GitHub settings differ from policy. Those settings are outside this item and were not changed without explicit approval. Homebrew, uv, chezmoi, and direct-download adapters remain pending in RIG-CLI-001.

### Post-change review

The implementation stays within the approved custom-provider boundary, adds no runtime dependency or persistent observed-state database, and preserves non-execution for catalogue queries and diagnostics. Complete apply preflight prevents configuration or environment errors from causing partial mutation; runtime failures remain visible while independent work continues. Public command, manual, completion, changelog, Decision Record, and Specification surfaces are aligned.

### Mini recap

Rig can now compare a selected rig with custom-provider observations and materialise it through an explicit, dependency-aware apply boundary. The item is ready for human review and has not been self-accepted.

## Done

Accepted 2026-09-16 by Kris Brown on review packet above.

## Discussion

### State model

For each tool expected by a resolved profile, the engine reports `present`, `missing`, `drifted`, `unavailable`, or `unknown` and identifies its responsible provider. Observation is capability-gated and read-only.

### Execution model

The engine fails closed on unknown providers, unsupported capabilities, ambiguous bindings, dependency cycles, and failed prerequisites. A provider failure stops dependent work while preserving the native command's outcome in Rig's report.

### Shell compatibility

Implementation remains compatible with Bash 3.2 and avoids associative arrays and newer shell conveniences.
