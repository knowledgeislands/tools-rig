---
id: RIG-CORE-010
area: CORE
title: Declarative operational resources
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T11:52:55Z
updated_at: 2026-09-20T11:52:55Z
---

# RIG-CORE-010: Declarative operational resources

## Goal

Rig configuration is the canonical declaration of selected services and scheduled jobs, while providers such as chezmoi translate that intent into native manifests and apply it without maintaining a second registry.

## Context

The current personal configuration declares launchcontrol actions in Rig but keeps service identity in `.chezmoidata/service-operations.yaml` and scheduled-job identity in `.chezmoidata/scheduled-jobs.yaml`. The launchcontrol provider calls back into chezmoi at runtime to discover both registries. Rig can invoke operations, but profiles, `show`, `status`, dry-run, and `apply` cannot describe or reconcile the resources those operations affect.

This reverses the intended ownership boundary. Services and jobs are part of a person's selected working setup, so their identity, purpose, profile membership, desired state, and normalised execution or schedule intent belong in Rig. Chezmoi may still render and load launchd property lists from that declaration, and platform providers retain their native mechanics and observed state.

## Boundary

This intake does not choose the final TOML table names, require one cross-platform scheduler abstraction, move personal service or job declarations into the public repository, or make Rig the owner of launchd, systemd, cron, or chezmoi native state. Generic `rig run` provider actions remain an explicit escape hatch rather than the desired-state model.

Implementation must preserve inert parsing and make deferred execution visible before mutation. Catalogue queries must not start, stop, schedule, or invoke a resource. A provider-local YAML file, generated manifest, or native service definition must not become a second declaration authority.

## Discussion

### Product model

Services and scheduled jobs should share a first-class operational-resource model where that produces a clearer lifecycle, while retaining distinct fields and validation for long-running services and time-triggered jobs. Profiles select these resources directly or through an explicit catalogue relationship. `show` and `explain` describe them; `status` compares desired and observed native state; `apply --dry-run` exposes the complete projection and activation plan before `apply` crosses the provider boundary.

### Provider boundary

Rig should pass each resolved declaration to the selected provider rather than requiring the provider to parse TOML or call chezmoi for authoritative data. A chezmoi source template can parse the canonical Rig fragment directly when it needs to render reviewable native targets, avoiding both a bootstrap dependency on the installed `rig` command and a duplicated `.chezmoidata` mirror.

### Deferred execution trust

A scheduled program or enabled service authorises code to run later, potentially outside an interactive session. Shaping must define literal program arguments, working directories, environment handling, selected-profile membership, activation defaults, dry-run visibility, and safe removal behaviour. Read-only catalogue commands and observation must remain non-executing.

### Migration

Delivery needs coordinated but independently reviewable changes in tools-rig and the personal dotfiles repository. Rig first needs the accepted resource schema, profile and provider protocol, status/apply behaviour, tests, manual, completions where applicable, and user documentation. The dotfiles migration can then move declarations into the private Rig fragment, project launchd files from it, remove both YAML registries, stop runtime callbacks into chezmoi, and preserve existing live services until equivalent tests and `chezmoi diff` prove parity.
