---
id: RIG-CORE-010
area: CORE
title: Declarative operational resources
theme: orchestration
horizon: now
status: in-progress
blocks: []
blocked_by: []
baseline_ref: 77801a21ff508aff7de1c345afe975ec55620260
created_at: 2026-09-20T11:52:55Z
updated_at: 2026-09-20T13:00:46Z
---

# RIG-CORE-010: Declarative operational resources

## Goal

Rig configuration is the canonical declaration of selected services and scheduled jobs, while providers translate that intent into native manifests and apply it without maintaining a second registry.

## Context

The current personal configuration declares launchcontrol actions in Rig but keeps service identity in `.chezmoidata/service-operations.yaml` and scheduled-job identity in `.chezmoidata/scheduled-jobs.yaml`. The launchcontrol provider calls back into chezmoi at runtime to discover both registries. Rig can invoke operations, but profiles, `show`, `status`, dry-run, and `apply` cannot describe or reconcile the resources those operations affect.

This reverses the intended ownership boundary. Services and jobs are part of a person's selected working setup, so their identity, purpose, profile membership, desired state, and normalised execution or schedule intent belong in Rig. Platform providers retain their native mechanics and observed state.

## Boundary

This item does not move personal service or job declarations into the public repository or make Rig the owner of launchd, systemd, cron, or chezmoi native state. Generic `rig run` provider actions remain an explicit escape hatch rather than the desired-state model.

Implementation must preserve inert parsing and make deferred execution visible before mutation. Catalogue queries must not start, stop, schedule, or invoke a resource. A provider-local YAML file, generated manifest, or native service definition must not become a second declaration authority.

## Current state

Rig schema 1 supports tools, profiles, providers, publications, and imperative provider actions, but no service or scheduled-job declarations. Profiles resolve tools only. Provider actions are absent from `show`, `status`, doctor, dry-run, and apply, and cannot represent expected-versus-observed operational state.

The personal dotfiles repository keeps service metadata in `.chezmoidata/service-operations.yaml`, scheduled execution intent in `.chezmoidata/scheduled-jobs.yaml`, and native launchd plist templates elsewhere. Its launchcontrol provider calls `chezmoi execute-template` at runtime to rediscover those registries. One unrelated existing `workspaces/kit/knowledgeislands/dot_mgit.toml` modification must remain untouched.

## Steps

- [x] Amend the product, configuration, provider-execution, and executable-boundary Decision Records for first-class operational resources and deferred execution; add a focused architecture decision for canonical ownership and application receipts.
- [x] Extend schema 1 with `[service.ID]` and `[scheduled-job.ID]` tables plus `services` and `scheduled-jobs` profile selectors, using only quoted strings and string arrays.
- [x] Validate common identity, purpose, rationale, provider, locator, platform, tool dependency, desired-state, program, environment, path, log, and execution fields; validate service policies and scheduled calendar or interval grammar without shell evaluation.
- [x] Resolve composed-profile resources and their tool dependencies while keeping catalogue queries inert; add resource sections to `show`, qualified resource targets to `explain`, and operational rows to status and doctor.
- [x] Add custom-provider capabilities and literal argv contracts for resource observation, application, retirement, and resource-aware actions; never require a provider to parse TOML or call chezmoi for authoritative data.
- [x] Include selected resources and stale receipt entries in complete preflight, dry-run, application, bootstrap, failure isolation, and progress reporting. Persist only the last successfully managed provider, kind, identity, and locator receipt beneath Rig state so deselection can retire native resources without persisting observed state.
- [x] Cover schema validation, profile composition, tool dependencies, inert queries, literal provider boundaries, observation, complete dry-run, preflight, application, receipt atomicity, retirement, rename transfer, action binding, failure isolation, and XDG state behavior in Bats.
- [x] Align README, user guides, command help, completions, manual, changelog, Specifications, and Decision Records.
- [ ] Migrate the personal Rig fragment to canonical service and scheduled-job declarations, rename the custom provider to `launchd`, and make it render and operate native plists directly from resolved Rig arguments.
- [ ] Remove the two chezmoi YAML registries, native plist templates and stubs, reload hook, runtime chezmoi callbacks, and duplicated launchcontrol discovery while preserving the scheduled wrapper and specialised mcporter restart behavior where still required.
- [ ] Update dotfiles tests, guides, ignore rules, and Decision Records; compare all four native launchd projections and action behavior before and after migration; run `chezmoi diff` without applying it.

## Files touched

- `bin/rig`, `tests/rig.bats`, `README.md`, `CHANGELOG.md`, and `man/rig.1`
- `docs/decisions/`, `docs/specs/`, `docs/guides/`, and this roadmap record
- Chezmoi sources under `dot_config/rig/`, `private_dot_local/private_share/rig/providers/`, `Library/LaunchAgents/`, `.chezmoidata/`, `.chezmoitemplates/`, and the scheduled-job reload hook
- Dotfiles tests, guides, ignore/removal declarations, and Decision Records affected by the ownership change

## Verify

- Run the complete tools-rig gate: `ki repo audit --repo .`, `shellcheck bin/rig install.sh`, `bash -n bin/rig install.sh`, `bats tests/`, and `mandoc -T lint man/rig.1`.
- Inspect rendered manual and generated Bash and Zsh completions; run focused Decision Record, specification, guide, authoring, tools-repository, and roadmap audits.
- In dotfiles, run its complete repository audit, targeted and full Node test suites, ShellCheck on the provider, semantic plist projection comparisons, and `plutil -lint` for every generated plist.
- Run targeted and full `chezmoi diff`; do not run `chezmoi apply` without separate explicit approval.

## Dependencies / blocks

No unresolved product decision or external dependency blocks delivery. Implement tools-rig support before migrating personal declarations. Preserve the unrelated dotfiles modification, existing live services and jobs until source parity is proven, Bash 3.2 compatibility, literal argument boundaries, and provider-native authority. The cross-repository migration requires separate commits and verification in each repository; neither push nor live apply is authorised.

## Documentation impact

### Decision Records

Amend the living product, configuration, provider-execution, and executable-boundary records. Add one focused architecture decision for canonical operational-resource ownership, native provider projection, deferred execution, and reconciliation receipts.

### Specifications

Integrate operational-resource requirements into the existing configuration, orchestration, query, and state Specifications so each accepted behaviour remains with its owning concern. This deliberate consolidation avoids a redundant standalone area; portability and trust-boundary constraints remain expressed through those requirements and the executable-boundary Decision Record.

### Guides

Explain services and scheduled jobs as first-class profile-selected operational resources, distinguish them from tools and ad-hoc provider actions, document deferred-execution trust and application receipts, and keep every public surface aligned. Dotfiles guidance must teach one Rig declaration authority and provider-owned native operation without historical migration narration.

### Roadmap

Keep this record as the canonical tools-rig delivery account. If the dotfiles repository requires its own governed execution record, link it here rather than duplicating product rationale.

## Discussion

### Product model

Schema 1 adds `[service.ID]` and `[scheduled-job.ID]`. Common fields are `name`, `purpose`, `rationale`, `provider`, `locator`, `platforms`, `requires`, `desired-state`, `program`, `environment`, optional `working-directory`, `standard-output`, and `standard-error`. Services add `restart-policy` and `start-policy`; jobs add exactly one of `schedule.calendar` or `schedule.interval`, plus `run-policy` and `priority`. Profile `services` and `scheduled-jobs` arrays select them.

All values remain quoted strings or string arrays. Calendar entries use validated comma-separated `minute|hour|day|weekday|month=DECIMAL` pairs; interval is a positive decimal string. This keeps accepted input valid TOML, the Bash parser bounded, and literal deferred-execution values visible.

Profiles resolve tools and resources. Resource `requires` entries select tool dependencies. `show` gains service and scheduled-job tables; `explain service:ID` and `explain scheduled-job:ID` disclose deferred-execution fields; `status`, doctor, apply, and bootstrap use provider-backed resource work units.

### Provider boundary

Rig passes each resolved declaration to the selected provider as literal `key=value` arguments under versioned `observe-resource`, `apply-resource`, and `retire-resource` verbs. Repeated array fields retain declared order. Providers declare separate `resource-observe`, `resource-apply`, and `resource-retire` capabilities. Resource-aware actions receive one selected qualified resource and its complete resolved declaration before caller arguments. The provider neither parses TOML nor calls chezmoi for authoritative data.

The personal macOS provider is named `launchd`, not `launchcontrol`, because it materialises Apple launchd state rather than the third-party LaunchControl application. It renders native plist data directly from resolved Rig arguments and owns `launchctl` interaction. Chezmoi installs the private Rig fragment and provider executable but does not compose or register native services and jobs.

### Deferred execution trust

A scheduled program or enabled service authorises code to run later, potentially outside an interactive session. All execution fields cross the provider boundary literally. Complete preflight and dry-run expose selected application and stale retirement before mutation. Read-only catalogue commands and observation remain non-executing.

A small atomic receipt beneath `${RIG_STATE_HOME}/resources/` records only the last successfully managed provider, resource kind, ID, and locator. It is reconciliation history, not observed machine state or a second declaration authority. Deselecting a previously managed resource schedules retirement; reuse of the same provider, kind, and locator transfers ownership without destructive retirement.

### Migration

Delivery uses independently reviewable commits in tools-rig and the personal dotfiles repository. Rig lands the accepted resource schema, profile and provider protocol, status and application behavior, tests, manual, completions, and user documentation first. Dotfiles then moves declarations into the private Rig fragment, installs the launchd provider, removes both YAML registries and all plist composition from chezmoi, stops runtime callbacks into chezmoi, and preserves existing live service and job semantics until equivalent tests and `chezmoi diff` prove parity. No live apply occurs in this item.
