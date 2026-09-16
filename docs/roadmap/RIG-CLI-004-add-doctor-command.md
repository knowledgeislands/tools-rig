---
id: RIG-CLI-004
area: CLI
title: Add doctor command
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 8807b5579585f1f22b7de832a97d5af68e7181db
created_at: 2026-09-15T13:04:11Z
updated_at: 2026-09-16T23:17:36Z
---

# RIG-CLI-004: Add doctor command

## Goal

`rig doctor [--profile NAME]` gives one concise top-level answer about whether Rig is valid and whether the selected working setup can operate on this machine.

## Context

`status` provides the detailed expected-versus-observed tool inventory. Doctor should synthesise configuration, provider, and installed-tool findings without becoming a rich diagnostic command tree or reproducing another tool's interface.

The check is useful on a newly bootstrapped machine and before apply. It must reuse catalogue resolution and provider observations rather than maintaining separate health rules.

## Boundary

This item adds one read-only top-level command. It does not repair configuration, install tools, invoke mutation or publisher capabilities, contact the network, inspect unrelated machine software, or add doctor subcommands.

## Current state

`rig diag` reports runtime, paths, and configuration validity without invoking providers. Rig has no expected-versus-observed `status`, provider observations, or top-level health synthesis yet, so doctor cannot distinguish a missing required tool from an unavailable optional provider using one shared state model.

## Locked contract

Selected bound tools are healthy only when present. Missing, drifted, unavailable, and unknown observations are findings; catalogue-only tools are informational. Unselected providers are ignored. Doctor returns 0 for a healthy valid rig, 1 for completed checks with findings, and 2 for syntax, configuration, or resolution failure. It invokes observation capabilities only and never repairs, applies, publishes, or contacts the network.

## Steps

- [x] Consume the provider observations and public state treatment delivered by RIG-CORE-002 and the built-in availability checks delivered by RIG-CLI-001.
- [x] Lock doctor aggregation for required, optional, catalogue-only, incompatible-platform, unavailable, drifted, and unknown tools without inventing a second state vocabulary.
- [x] Implement `rig doctor [--profile NAME]` as a read-only synthesis of configuration, XDG accessibility, profile resolution, provider availability, and selected-tool observations.
- [x] Emit one compact healthy summary or deterministic grouped findings with actionable ownership and no mutation or network activity.
- [x] Test exit statuses `0`, `1`, and `2`, provider non-mutation, missing configuration, invalid graphs, missing provider executables, mixed observations, and explicit profile selection.
- [x] Align top-level and command help, Bash and Zsh completion, README, `rig(1)`, changelog, Specifications, and Bats coverage in the delivery commit.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/specs/state.md`, `docs/specs/portability.md`, and this work record.

## Verify

Use recording providers to prove doctor invokes only observation capabilities and never network or mutation commands. Assert exact healthy and mixed-finding output plus statuses `0`, `1`, and `2`, then run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

RIG-CLI-001 is a genuine build dependency because doctor must report real adapter availability and observations rather than maintain duplicate checks; RIG-CORE-002 is therefore a transitive dependency. Before readiness, lock how the shared state contract maps required, optional, catalogue-only, incompatible-platform, unavailable, drifted, and unknown results into findings. That policy blocks implementation because it determines both exit status and whether doctor reports a healthy rig. Delivery then unblocks RIG-DIST-001 and RIG-MIG-005.

## Delegation

Once dependencies land, one worker may implement doctor aggregation and focused Bats cases in `bin/rig` and `tests/rig.bats`. The coordinator owns the finding-policy review, public-surface alignment, mutation-safety audit, full verification, roadmap evidence, and the commit.

## Documentation impact

### Decision Records

No separate Decision Record is expected if ADR-RIG-005 fully defines public state treatment; otherwise extend that decision before doctor assigns health meaning to state.

### Specifications

Add doctor synthesis, finding aggregation, read-only behaviour, deterministic output, and exit-status requirements with recording-provider evidence.

### Guides

Document when to use `diag`, `status`, and `doctor`, and how to interpret actionable doctor findings without implying automatic repair.

### Roadmap

Record delivery evidence here and unblock distribution health checks and final legacy migration only after the command and all aligned public surfaces land.

## Review

### Delivered

Commit `003c509` delivers the doctor command from immutable baseline `8807b5579585f1f22b7de832a97d5af68e7181db`. The command remains read-only and does not repair, apply, publish, or contact the network.

### Summary of changes

Doctor now aggregates configuration, XDG, profile, provider-availability, and selected-tool observations into a concise health report. It distinguishes actionable required-tool findings from informational catalogue-only or incompatible-platform entries, honours explicit profile selection, returns `0`, `1`, or `2` according to the locked contract, and keeps help, completion, README, manual, changelog, Specifications, and Bats coverage aligned.

### Verification

Delivery verification passed ShellCheck, Bash syntax, `mandoc -T lint`, `git diff --check`, focused doctor cases, and the then-current 80-test Bats suite. The integrated tree at `97d98fa` passes all 89 Bats tests and the same static gates.

### Outstanding concerns

None. A configured custom provider remains a trusted observation boundary; Rig itself performs no network activity for doctor.

### Post-change review

The delivered command satisfies the locked health policy, uses the shared state vocabulary, and is ready for human acceptance.

### Mini recap

Rig now offers a compact top-level health answer above detailed `status`, with aligned user guide, Specifications, help, completion, and manual coverage.

## Done

Accepted 2026-09-17 by Kris Brown on review packet above.

## Discussion

### Checks

Doctor validates configuration readability and schema, category and tool references, profile and dependency graphs, platform binding selection, XDG path accessibility, required provider command availability, and each selected tool's provider observation. Missing, drifted, unavailable, and unknown tools become findings rather than hidden detail.

### Output and exit status

The default output is a compact healthy summary or grouped actionable findings. Exit status `0` means every required check is healthy, `1` means valid execution found health findings, and `2` means owned command syntax is invalid.

### Public surface

The delivery updates `rig --help`, `rig doctor --help`, Bash and Zsh completion, README command inventory, `rig(1)`, the curated v1 changelog, and Bats coverage in the same commit. None of those surfaces should advertise a doctor option that is not shipped.
