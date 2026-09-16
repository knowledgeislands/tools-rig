---
id: RIG-CORE-004
area: CORE
title: Optimise catalogue queries
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: f344e2829978f258e5ad86b68ff454a5de1a104a
created_at: 2026-09-16T12:57:39Z
updated_at: 2026-09-16T17:32:00Z
---

# RIG-CORE-004: Optimise catalogue queries

## Goal

Catalogue diagnostics and queries remain responsive for a realistic personal catalogue while preserving Bash 3.2, deterministic results, and the no-runtime-dependency contract.

## Context

An isolated render of the current 88-tool private catalogue is valid, but observed execution is approximately 4.3 seconds for `diag`, 6.4 seconds for `show`, 5.2 seconds for a filtered `list`, and 4.4 seconds for `explain` on the target Mac. The current indexed-array model repeatedly scans sections and fields during validation and resolution.

## Boundary

This item profiles and optimises the existing Bash implementation without changing schema meaning, query output, provider boundaries, or requiring a runtime dependency. It does not reduce the private catalogue to conceal the cost or combine performance work with migration.

## Current state

The applied private catalogue contains 88 tools. On the target Mac, isolated runs take approximately 4.3 seconds for `rig diag`, 6.4 seconds for `rig show`, 5.2 seconds for `rig list --category development`, and 4.4 seconds for `rig explain one-password`; repeated linear section and field scans dominate validation and resolution. No reproducible large-catalogue fixture or performance acceptance measurement exists yet.

## Steps

- [x] Add a deterministic approximately one-hundred-tool fixture that exercises categories, relationships, profiles, platforms, providers, and bindings.
- [x] Record five-run median baselines for `diag`, `list`, `show`, and `explain` with command output captured for equivalence checks.
- [x] Instrument or count repeated section and field scans to identify the dominant validation and resolution paths.
- [x] Add Bash 3.2-compatible indexed lookup data during parsing so repeated queries reuse section and field locations without external tools.
- [x] Prove query output, ordering, diagnostics, exit status, provider non-execution, and sourceable test seams remain unchanged.
- [x] Re-run the benchmark and require at least a 60% median improvement, with each catalogue query completing within two seconds on the target Mac.

## Files touched

`bin/rig`, `tests/rig.bats`, `tests/helpers/large-catalogue-fixture.bash`, and this work record. Generated benchmark data remains outside the repository.

## Verify

Run focused large-catalogue Bats cases and compare captured output before and after optimisation. Record five-run median timings for `rig diag`, `rig list`, `rig show`, and `rig explain` against the deterministic fixture, then run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

The work is independent: the catalogue parser and query commands already exist, the performance evidence is reproducible locally, and no unresolved product or trust decision is required. The optimisation must not establish an ABI for the separate provider execution work in RIG-CORE-002.

## Delegation

One bounded worker may profile `bin/rig` and propose the indexed lookup change with focused tests. The coordinator owns baseline and final measurements, output-equivalence review, Bash 3.2 verification, roadmap evidence, and the commit.

## Documentation impact

### Decision Records

No Decision Record change is needed because this work preserves the accepted runtime, configuration, query, and trust contracts.

### Specifications

No behaviour-level Specification change is planned; existing query and portability requirements remain the acceptance contract.

### Guides

No user guide change is needed because command syntax and observable behaviour remain unchanged.

### Roadmap

Record measured baseline, final timings, and optimisation evidence in this item; create follow-on work only if the accepted target cannot be met within Bash 3.2 constraints.

## Review

### Delivered

From baseline `f344e2829978f258e5ad86b68ff454a5de1a104a`, Rig now builds a sorted section-name lookup and per-section field spans while parsing. A deterministic 100-tool fixture and focused query assertions cover the optimisation without adding a runtime dependency, persistent cache, provider execution, or schema change.

### Summary of changes

Section lookup now uses a Bash 3.2-compatible binary search over a sorted in-memory index. Field consumers inspect only the owning section's contiguous field span instead of repeatedly scanning all 1,216 fixture fields. The fixture covers 211 sections, five categories, three profiles, two providers, relationships, platforms, and 100 bindings.

### Verification

Five-run fixture medians fell from 15.03 to 0.76 seconds for `diag`, 16.50 to 0.79 seconds for filtered `list`, 21.41 to 0.99 seconds for `show`, and 15.36 to 0.77 seconds for `explain`, improvements of 94.9–95.4%. Captured before-and-after outputs were byte-identical. The live 88-tool catalogue completed in 0.34–0.45 seconds. ShellCheck, Bash syntax, all 43 Bats tests, mandoc lint, and `git diff --check` passed.

### Outstanding concerns

The full KI repository audit remains 14 of 15 checks passing because nine pre-existing live GitHub settings differ from policy. Those settings are outside this item and were not changed because live repository settings require explicit approval. No implementation concern remains within the scoped optimisation.

### Post-change review

The implementation preserves the parser's contiguous-field invariant, rejects duplicate sections before indexing, handles an empty lookup, and keeps all observable query ordering and provider non-execution behavior covered by tests. The index is rebuilt per process and does not widen Rig's trust boundary.

### Mini recap

Realistic catalogue queries now complete comfortably inside the two-second acceptance target with no public contract change. The item is ready for human review; it has not been self-accepted.

## Discussion

### Evidence first

Planning should add a deterministic large-catalogue fixture, establish repeatable before-and-after measurements, identify repeated scans, and set a proportionate target before selecting an indexing or caching strategy.

### Portability

Any optimisation must work in macOS Bash 3.2 and retain the current sourceable test seam. Associative arrays and external parsers are not available solutions.
