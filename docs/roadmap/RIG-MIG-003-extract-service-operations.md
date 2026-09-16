---
id: RIG-MIG-003
area: MIG
title: Extract service operations
theme: migration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 1418f7c4ff417151a307604c4762c2196bc8ee8c
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T23:39:56Z
---

# RIG-MIG-003: Extract service operations

## Goal

Rig preserves declared service discovery, run, restart, status, and log operations through a private executable provider without hard-coding one machine's launchd labels into tools-rig.

## Context

The current dotfiles command discovers scheduled jobs and managed services from chezmoi data, depends on `jq` and `launchctl`, and fails closed on unknown names. Its declaration-led safety model is reusable, but its data and platform operations remain private.

## Boundary

This item does not make launchd or `jq` a mandatory Rig dependency, move service declarations into the public repository, or introduce a generic service abstraction.

## Current state

The private `bin/rig.d/executable_services` command discovers scheduled jobs and managed services from chezmoi data, rejects unknown names, and exposes list, run, restart, status, and logs actions. The tracked Zsh completion queries the same declaration-led name set. None of this host-specific launchd behaviour belongs in the public executable.

The migration attaches private operations to tool `launchcontrol`: `list`, `status`, and `logs` use observe mode; `run` and `restart` use mutate mode. Caller-supplied names are allow-listed from private data, and `logs` alone preserves the literal optional `--follow` argument.

## Steps

- [x] Add private `launchcontrol` provider binding and the five declared operations with macOS platform constraints and the required observe or mutate mode.
- [x] Generate repeated allowed name arguments from `.chezmoidata/scheduled-jobs.yaml` and `.chezmoidata/service-operations.yaml` so unknown names still fail before `launchctl` or another helper runs.
- [x] Permit the exact caller argument `--follow` for `logs` only and preserve the existing name-then-follow argument order.
- [x] Rewrite guides and completion consumers to use `rig run launchcontrol OPERATION -- NAME [--follow]` while keeping names derived from the private declarations.
- [x] Add parity tests for discovery, every action, scheduled-job and managed-service routing, unknown-name failure, mode enforcement, literal forwarding, and logs follow behaviour.
- [x] Keep the legacy service command and completion source until RIG-MIG-005 confirms parity.

## Files touched

Expected private scope is `dot_config/rig/private_rig.conf.tmpl`, `.chezmoidata/scheduled-jobs.yaml`, `.chezmoidata/service-operations.yaml`, `bin/rig.d/executable_services`, `dot_zsh/completions/_rig`, service caller guides, and their focused Node tests. Public generic dispatch remains owned by RIG-CLI-005.

## Verify

Render the private configuration and prove its allow-list exactly matches the two private declaration sources without duplicate names. Run legacy and new list, status, logs, run, and restart paths through fakes; assert observe operations cannot mutate, mutate operations dispatch only declared names, `--follow` is accepted only for logs, and invalid input leaves the invocation log empty. Run relevant dotfiles Node suites, tools-rig operation Bats coverage, and `chezmoi diff` without applying it.

## Dependencies / blocks

RIG-MIG-004 supplies private generated operations and RIG-CLI-005 supplies bounded generic dispatch. This item blocks RIG-MIG-005 until command callers, completion, and parity tests no longer need the legacy service surface. Applying the resulting chezmoi target remains a separate explicit approval stop.

## Delegation

One worker may implement generated private operations and render tests while another updates service callers and completion fixtures. The coordinator owns allow-list reconciliation, mutation-boundary review, parity testing, and final `chezmoi diff` review.

## Documentation impact

### Decision Records

No new decision record is expected; this is the accepted private executable-provider pattern, not a public service abstraction.

### Specifications

Generic operation specifications must cover observe and mutate modes, platform checks, repeated allowed arguments, literal argument ordering, and rejection before invocation.

### Guides

Replace `rig services` examples with `rig run launchcontrol` forms and retain clear distinctions among run, restart, status, logs, and follow behaviour.

### Roadmap

Keep generic dispatch in RIG-CLI-005 and legacy retirement in RIG-MIG-005. A public service abstraction requires separate evidence from another backend and is not implied by this migration.

## Review

### Delivered

Dotfiles commit `e1d8b9b` delivers private launch-control operation parity against the generic operation boundary available in public Rig commit `d1d275a`, from immutable baseline `1418f7c4ff417151a307604c4762c2196bc8ee8c`. Launchd, `jq`, service labels, and host paths remain outside public Rig.

### Summary of changes

The private configuration now declares `launchcontrol` list, status, and logs as observe operations and run and restart as mutate operations. Allowed scheduled-job and managed-service names are generated from private declarations, unknown names fail before provider invocation, and only logs accepts the exact optional `--follow` value after the selected name. Provider translation, guides, callers, and tracked completion now use `rig run launchcontrol OPERATION -- NAME [--follow]` while the legacy implementation remains available for final cutover.

### Verification

Public commit `d1d275a` passed all 96 Bats tests and the complete ShellCheck, Bash syntax, manual, repository-audit, and diff-check gate. Dotfiles commit `e1d8b9b` passed all 29 Node tests, including discovery, every service action, scheduled-job and managed-service routing, mode enforcement, unknown-name rejection, literal ordering, logs follow behaviour, and empty invocation logs after invalid input. `chezmoi diff` was reviewed and no `chezmoi apply` was run.

### Outstanding concerns

None. The legacy service command and its source remain intentionally available until RIG-MIG-005 performs the reviewed retirement and applied-machine cutover.

### Post-change review

The migration preserves the declaration-led launch-control safety model through generic private operations without introducing a public service abstraction and is ready for human acceptance.

### Mini recap

Private service discovery and actions now use one bounded Rig operation surface with exact names, modes, and arguments while platform-specific implementation stays in dotfiles.

## Done

Accepted 2026-09-17 by Kris Brown on review packet above.

## Discussion

### Platform boundary

Service operations are expressed as a configured executable provider with platform conditions. A dedicated service abstraction should be introduced only if more than one backend demonstrates a stable shared contract.
