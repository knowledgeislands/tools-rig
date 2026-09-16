---
id: RIG-CLI-006
area: CLI
title: Replace paths with diagnostics
theme: cli
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 5ac6ab7be9dfa23c3b518d0ab7a9a2a2122ee50f
created_at: 2026-09-16T12:04:13Z
updated_at: 2026-09-16T12:16:33Z
---

# RIG-CLI-006: Replace paths with diagnostics

## Goal

`rig diag` replaces the narrow `rig paths` command with one compact, non-mutating troubleshooting snapshot of Rig's runtime, paths, and configuration.

## Context

Paths are useful only as part of the wider answer to “which Rig am I running and which configuration does it see?”. Rig already has a separate planned `doctor` command for selected-profile and provider health, so diagnostics should explain Rig's own effective environment without becoming a second health engine.

## Boundary

This item removes `rig paths` from the pre-v1 public surface and adds `rig diag`. Diagnostics report only runtime identity, active platform, executable, Bash version, effective XDG paths, root configuration, fragment count, configuration validity, schema, and default profile. They do not invoke providers, inspect selected-tool presence, mutate state, access the network, or expose provider commands, arguments, or catalogue contents.

## Current state

`rig paths` prints four effective directories and exits successfully without reading configuration. Help, completion, README, the user guide, manual, changelog, Bats, and RIG-PORT-002 evidence name that command. No consolidated diagnostic command exists.

## Steps

- [x] Replace public `paths` dispatch, help, and completion with `diag` and command-local help.
- [x] Report stable runtime, path, and configuration sections using Bash 3.2 only.
- [x] Validate configuration silently, reporting `valid`, `missing`, or `invalid` without provider invocation.
- [x] Exit 0 for valid configuration, 1 for missing or invalid configuration, and 2 for invalid command syntax.
- [x] Add Bats coverage for default and overridden paths, linked invocation, valid, missing, and invalid configuration, provider non-execution, and removed `paths` syntax.
- [x] Align README, user guide, `rig(1)`, changelog, and portability Specification evidence.

## Files touched

`bin/rig`, `tests/rig.bats`, `README.md`, `docs/guides/user/README.md`, `man/rig.1`, `CHANGELOG.md`, `docs/specs/portability.md`, and this work record.

## Verify

Run focused diagnostic Bats cases, then `shellcheck bin/rig install.sh`, `/bin/bash -n bin/rig install.sh`, `bats tests/`, `mandoc -T lint man/rig.1`, the `ki-specs`, `ki-guides`, `ki-authoring`, `ki-work-roadmap`, and `ki-repo-tools` audits, the complete `ki repo audit --repo .`, and `git diff --check`.

## Dependencies / blocks

The command is independently ready and has no delivery dependency. It replaces a pre-v1 scaffold command before the first release rather than preserving a compatibility alias.

## Delegation

One bounded worker may edit `bin/rig` and `tests/rig.bats`. The coordinator owns documentation, Specification evidence, roadmap lifecycle, integration review, verification, and commits. Both lanes preserve Bash 3.2, XDG overrides, literal configuration parsing, and provider non-execution.

## Documentation impact

### Decision Records

No Decision Record change is expected; the accepted XDG, catalogue, and trust boundaries already own the behaviour.

### Specifications

Replace the command-specific portability requirement and evidence without changing the underlying XDG directory contract.

### Guides

Replace the path-inspection procedure with the broader diagnostic procedure and explain its boundary from doctor.

### Roadmap

Record delivery evidence here; no existing item is closed or reprioritised by this replacement.

## Review

### Delivered

Against immutable baseline `5ac6ab7be9dfa23c3b518d0ab7a9a2a2122ee50f`, `rig diag` now replaces `rig paths` across the executable and public documentation. It reports only the approved runtime, path, and configuration snapshot; provider execution, installed-tool checks, mutation, network access, and doctor behaviour remain excluded.

### Summary of changes

`bin/rig` now prints stable Runtime, Paths, and Configuration sections, preserves the invoked executable path including a symlink, counts loaded configuration fragments, silently classifies configuration as valid, missing, or invalid, and emits schema and default profile only for valid configuration. Help and completion expose `diag` and no longer expose `paths`. Bats grew to 40 cases, while README, the user guide, `rig(1)`, changelog, and portability Specification now describe the same contract.

### Verification

`shellcheck bin/rig install.sh`, `/bin/bash -n bin/rig install.sh`, all 40 Bats tests, `mandoc -T lint man/rig.1`, and `git diff --check` pass. The `ki-specs`, `ki-guides`, `ki-authoring`, `ki-work-roadmap`, and `ki-repo-tools` focused audits pass. The complete `ki repo audit --repo .` remains 14 of 15 skills passing because of the same ten pre-existing, out-of-scope live GitHub settings findings; changing those settings is not authorised.

### Outstanding concerns

No implementation concern remains. If `HOME` is absent and a required XDG or Rig-specific path is also unset, diagnostics retain the established path-contract failure and cannot print a complete snapshot. The unrelated live GitHub settings differences remain outside this work.

### Post-change review

Independent read-only review found no defect and confirmed Bash 3.2 and `set -u` behaviour, XDG precedence, status semantics, silent validation, provider non-execution, linked and `PATH` invocation reporting, fragment-loader parity, help and completion alignment, and removal of `paths`. The approved boundary held and the item is ready for human acceptance.

### Mini recap

Rig now has one useful local troubleshooting command instead of a path-only command, while doctor remains reserved for selected-profile and provider health. All scoped checks pass and no compatibility alias was retained in the pre-v1 surface.

## Discussion

### Output contract

Stable labelled sections make output useful to people and support scripts without reproducing a rich diagnostic tree. Configuration validation is summarized; detailed parser errors remain available from catalogue commands.

### Diagnostic boundary

`diag` explains Rig's effective runtime and configuration inputs. `doctor` will later evaluate whether the selected rig and required providers can operate on the machine.
