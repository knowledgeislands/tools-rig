---
id: RIG-CORE-002
area: CORE
title: Build orchestration engine
theme: orchestration
horizon: now
status: draft
blocks: [RIG-CLI-001]
blocked_by: []
baseline_ref: null
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T17:02:37Z
---

# RIG-CORE-002: Build orchestration engine

## Goal

Rig can observe provider state, compare it with a resolved profile, and dispatch supported materialisation actions in dependency order with predictable failure reporting.

## Context

The catalogue resolver supplies deterministic tools and bindings but does not invoke providers or model observed state. The legacy dotfiles Rig has install-safe ordered dispatch and provider-specific protections. The standalone engine must generalise that behaviour without hard-coding one machine's subsystem names, package choices, or host paths.

## Boundary

This item builds the provider execution protocol, expected-versus-observed state model, dependency planner, and public `status` and `apply` orchestration over explicitly configured executable providers. It does not implement Homebrew, uv, chezmoi, or direct-download adapters; declared tool operations; doctor synthesis; private declarations; or publication.

## Current state

Rig resolves profiles, transitive tool relationships, platform compatibility, and provider bindings without invoking providers. No public command observes machine state or performs materialisation, and no provider execution protocol exists yet. XDR-RIG-001 fixes the executable trust boundary and literal arguments, while the executable-provider ABI and public treatment of observed state remain undecided.

## Steps

- [ ] Record the executable-provider ABI: action verbs, argument order, observation response syntax, output ownership, and native failure translation.
- [ ] Lock the public state contract: deterministic ordering, catalogue-only and unavailable treatment, summaries, and exit meanings for `status` and `apply --dry-run`.
- [ ] Define a literal-argument provider protocol and recording test seam for observation and application capabilities.
- [ ] Derive deterministic provider work from a resolved profile and its selected bindings.
- [ ] Report each expected tool as `present`, `missing`, `drifted`, `unavailable`, or `unknown` with its responsible provider.
- [ ] Add `rig status [--profile NAME]` as an observation-only command.
- [ ] Add `rig apply [--profile NAME] [--dry-run]` with explicit preflight, dependency ordering, native outcomes, and dependent-work suppression after failure.
- [ ] Reject unknown providers, unsupported capabilities, ambiguous bindings, and invalid dependency plans before mutation.
- [ ] Align help, completion, README, `rig(1)`, changelog, Bats coverage, and implemented Specification evidence.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/decisions/ADR-RIG-005-provider-execution-contract.md`, `docs/decisions/README.md`, `docs/specs/state.md`, `docs/specs/orchestration.md`, and this work record.

## Verify

Use fake recording executables for exact invocation and failure assertions. Run focused Bats cases during implementation, then `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

The resolver is complete and no roadmap build dependency remains, but two design locks block readiness. The executable-provider ABI must define invocation and response boundaries before built-in adapters and declared operations can interoperate. The public state treatment must define aggregation, ordering, summaries, and exit meanings before `status`, `apply --dry-run`, and doctor can share one stable model. Record both in ADR-RIG-005 before implementation; delivery then unblocks RIG-CLI-001.

## Delegation

One bounded implementation worker may edit `bin/rig` and `tests/rig.bats` against the recorded baseline. The coordinator owns public documentation, Specification evidence, roadmap lifecycle, integration review, verification, and commits. A read-only reviewer may inspect the provider protocol and failure boundaries without changing files.

## Documentation impact

### Decision Records

Add ADR-RIG-005 to lock the executable-provider ABI and public state treatment. XDR-RIG-001 owns the trust transition but deliberately does not define transport or presentation semantics.

### Specifications

Update state and orchestration requirements to reflect the approved ABI, public state treatment, and recording-provider evidence.

### Guides

No separate guide is required for the initial concise `status` and `apply` procedures.

### Roadmap

Record review evidence here and leave adapter, doctor, operation, migration, and distribution work in their owning items.

## Discussion

### State model

For each tool expected by a resolved profile, the engine reports `present`, `missing`, `drifted`, `unavailable`, or `unknown` and identifies its responsible provider. Observation is capability-gated and read-only.

### Execution model

The engine fails closed on unknown providers, unsupported capabilities, ambiguous bindings, dependency cycles, and failed prerequisites. A provider failure stops dependent work while preserving the native command's outcome in Rig's report.

### Shell compatibility

Implementation remains compatible with Bash 3.2 and avoids associative arrays and newer shell conveniences.
