---
id: RIG-CLI-005
area: CLI
title: Add declared operations
theme: cli
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 8807b5579585f1f22b7de832a97d5af68e7181db
created_at: 2026-09-16T11:06:43Z
updated_at: 2026-09-16T23:17:36Z
---

# RIG-CLI-005: Add declared operations

## Goal

Rig can invoke a named, configuration-defined tool operation through `rig run TOOL OPERATION` without acquiring permanent machine-audit or service command families.

## Context

The live chezmoi Rig exposes machine auditing and launchd service operations through dedicated commands. Much of that behaviour is already declaration-led, but the wrapper remains tied to chezmoi paths and macOS concepts. A generic operation contract lets private configuration retain those useful actions while the public tool stays catalogue-led.

## Boundary

This item adds the operation schema, resolution, validation, generic command, help, completion, manual, changelog, and tests. It does not hard-code service labels, host paths, workstation data, or arbitrary shell strings; implement provider adapters; migrate private declarations; or permit unrestricted argument pass-through.

## Current state

XDR-RIG-001 defines the explicit trust transition, and RIG-CONF-015 plus RIG-ORCH-012 and RIG-ORCH-013 state the intended operation schema and bounded dispatch behaviour. The parser does not yet accept operation sections, no `rig run` command exists, and the provider ABI and adapter capability mapping needed for dispatch are not implemented.

## Locked contract

An operation declares provider, capability, mode (`observe` or `mutate`), description, optional platforms, repeated configured arguments, and repeated exact caller arguments. Only custom providers dispatch arbitrary operations in v1. They receive `rig-provider-v1`, verb `observe` or `apply` according to mode, provider, tool, kind `operation`, locator equal to capability, then configured and approved caller arguments as literal boundaries. Provider stdout and stderr pass through and `rig run` preserves its native exit; validation failures return 2 before invocation.

## Steps

- [x] Consume the approved provider ABI from RIG-CORE-002 and capability mapping from RIG-CLI-001, including native output and failure handling.
- [x] Parse and validate `[operation.TOOL.NAME]` sections, required fields, platform filters, trust modes, repeated configured arguments, and repeated caller allow-list values.
- [x] Resolve one declared tool operation and reject unknown identities, unsupported platforms, undeclared capabilities, invalid modes, and caller arguments before provider invocation.
- [x] Implement `rig run TOOL OPERATION [-- ARGUMENT...]` with literal configured and accepted caller arguments, explicit mutation, and preserved native provider outcome.
- [x] Test spaces, empty values, metacharacters, argument order, exact allow-list matching, observation-only operations, mutation operations, validation failures, and an empty provider-call log on rejected input.
- [x] Align help, Bash and Zsh completion, README, `rig(1)`, changelog, configuration and orchestration Specifications, and Bats evidence.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/specs/configuration.md`, `docs/specs/orchestration.md`, and this work record.

## Verify

Use a recording provider to assert exact literal argv and native outcome propagation for observe and mutate operations, plus zero invocation for every rejected case. Then run `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, `/bin/bash -n bin/rig`, and `git diff --check`.

## Dependencies / blocks

RIG-CLI-001 is a genuine build dependency because operations dispatch through declared provider capabilities rather than a separate executable path; RIG-CORE-002 is therefore a transitive dependency. The remaining decision lock is the shared provider contract for output ownership, native exit propagation, and capability names. Existing operation Specifications are otherwise sufficient: do not reopen the accepted literal-argument, explicit-mode, or exact allow-list boundaries. Delivery unblocks RIG-MIG-002 and RIG-MIG-003.

## Delegation

After provider dependencies land, one worker may implement operation parsing and validation while another prepares non-overlapping public documentation and completion changes. The coordinator owns shared dispatch integration, trust-boundary review, exact-argv tests, full verification, roadmap evidence, and the commit.

## Documentation impact

### Decision Records

No new Decision Record is planned because XDR-RIG-001 already owns the operation trust boundary; ADR-RIG-005 must first settle shared provider output and failure semantics.

### Specifications

Mark the operation configuration and orchestration requirements conforming only after parser, dispatch, allow-list, platform, capability, and native-outcome evidence passes.

### Guides

Document declaring and invoking observe and mutate operations, including the exact caller argument allow-list and the absence of arbitrary shell pass-through.

### Roadmap

Record delivery evidence here and unblock the private machine-audit and service-operation migrations only after the generic command and public surfaces land.

## Review

### Delivered

Commit `84f5f62` delivers declared operations from immutable baseline `8807b5579585f1f22b7de832a97d5af68e7181db`; commit `97d98fa` carries the integrated documentation and review alignment. The public command remains generic and does not embed host-specific operations or unrestricted shell execution.

### Summary of changes

Rig now validates declared operation sections and dispatches `rig run TOOL OPERATION [-- ARGUMENT...]` through an explicitly selected custom-provider capability. Modes, platforms, configured arguments, and exact caller allow-lists are enforced before invocation; accepted arguments cross the boundary literally, provider output passes through, and the native exit status is preserved. The integrated follow-up makes the custom-provider restriction, native-exit contract, and explicit `--` separator unambiguous across public surfaces.

### Verification

The exact `84f5f62` snapshot passed ShellCheck, Bash syntax, `mandoc -T lint`, `git diff --check`, and all 84 Bats tests. Focused cases cover exact argv, native status `7`, observe and mutate modes, inert metacharacters, and zero invocation on rejected input. The integrated tree at `97d98fa` passes all 89 Bats tests and the same static gates.

### Outstanding concerns

None. The configured custom executable remains a trusted boundary, while caller input is constrained to exact allow-listed argv values.

### Post-change review

The implementation conforms to the approved provider ABI and operation trust contract and is ready for human acceptance.

### Mini recap

Private machine audits and service actions can now use one bounded generic operation command, unblocking RIG-MIG-002 and RIG-MIG-003 without expanding Rig into host-specific command families.

## Done

Accepted 2026-09-17 by Kris Brown on review packet above.

## Discussion

### Operation identity

`[operation.TOOL.NAME]` names one declared tool and binds it to a declared provider capability. Required fields are `provider`, `capability`, `mode`, and `description`; repeated `platform`, `argument`, and `allow-argument` fields carry literal values.

### Trust modes

The `observe` and `mutate` modes make the trust transition visible. `status` and `doctor` remain observation-only. A mutate operation runs only after the user explicitly names it with `rig run`.

### Caller arguments

The optional `-- ARGUMENT...` tail accepts only exact values declared by repeated `allow-argument` fields. Rig passes configured and accepted caller arguments as literal boundaries without `eval`, shell parsing, or implicit expansion.

### Public surface

Delivery keeps top-level and command help, Bash and Zsh completion, README command inventory, `rig(1)`, the curated `1.0.0 — in progress` changelog, and Bats coverage aligned.
