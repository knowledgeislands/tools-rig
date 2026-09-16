---
id: RIG-CLI-006
area: CLI
title: Replace paths with diagnostics
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-16T12:04:13Z
updated_at: 2026-09-16T12:04:13Z
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

- [ ] Replace public `paths` dispatch, help, and completion with `diag` and command-local help.
- [ ] Report stable runtime, path, and configuration sections using Bash 3.2 only.
- [ ] Validate configuration silently, reporting `valid`, `missing`, or `invalid` without provider invocation.
- [ ] Exit 0 for valid configuration, 1 for missing or invalid configuration, and 2 for invalid command syntax.
- [ ] Add Bats coverage for default and overridden paths, linked invocation, valid, missing, and invalid configuration, provider non-execution, and removed `paths` syntax.
- [ ] Align README, user guide, `rig(1)`, changelog, and portability Specification evidence.

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

## Discussion

### Output contract

Stable labelled sections make output useful to people and support scripts without reproducing a rich diagnostic tree. Configuration validation is summarized; detailed parser errors remain available from catalogue commands.

### Diagnostic boundary

`diag` explains Rig's effective runtime and configuration inputs. `doctor` will later evaluate whether the selected rig and required providers can operate on the machine.
