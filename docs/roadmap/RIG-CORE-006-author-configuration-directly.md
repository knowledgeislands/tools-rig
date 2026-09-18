---
id: RIG-CORE-006
area: CORE
title: Author configuration directly
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 584a2e9e66e234f5d900c02daa32b7bd28e9c66c
created_at: 2026-09-17T00:00:00Z
updated_at: 2026-09-18T03:25:24Z
---

# RIG-CORE-006: Author configuration directly

## Goal

Let a person author and read Rig's declaration of intent directly in files Rig owns, without requiring a templating layer to remain the source of the loaded configuration.

## Context

Rig currently requires `${RIG_CONFIG_HOME}/rig.conf` and then loads optional `${RIG_CONFIG_HOME}/conf.d/*.conf` fragments. Its first real consumer, the chezmoi source repository, still models the workstation in `.chezmoidata/software.yaml` and renders the loaded configuration from templates. That layering is now a direct cost: checked-in source is not itself the machine's intended rig even though Rig's schema, section model, and fail-closed validation already provide the model.

Fragments solve the physical size problem for the roughly ninety-section private catalogue, but the mandatory root file still prevents a directory of directly authored declarations from being the complete configuration. Provider discovery pushes the same problem outward. Because every custom provider requires an `executable`, consumers must choose and render a path even for private Rig-only providers that could live in a conventional application data directory.

## Boundary

This item covers where Rig reads configuration and how omitted custom-provider executables resolve. It does not change catalogue section meaning, add variables or executable includes, introduce a generation step inside Rig, migrate the private consumer, or apply changes to another repository.

## Current state

Root-file and deterministic bytewise `conf.d/*.conf` loading are already accepted in ADR-RIG-003, implemented by `rig_load_config`, specified by RIG-CONF-001 and RIG-CONF-003, and covered by Bats. The root file remains mandatory and must supply the `[rig]` section. A custom provider still requires an explicit executable command or path; Rig defines no `${RIG_DATA_HOME}/providers` convention. The private consumer migration remains separate repository-owned work.

## Steps

- [x] Amend the configuration decision and specification so `rig.conf` is optional when at least one regular `conf.d/*.conf` fragment exists; retain root-first then bytewise-fragment ordering when the root is present, and fail when no configuration source exists.
- [x] Load and validate fragment-only configuration through the existing parser, requiring exactly one `[rig]` section across all sources and preserving duplicate section, duplicate scalar, unknown field, and reference failures across file boundaries.
- [x] Make `rig diag` describe an absent optional root and the effective fragment count without treating valid fragment-only configuration as missing.
- [x] Define `${RIG_DATA_HOME}/providers/<provider-id>` as the default executable for a custom provider that omits `executable`, while retaining explicit command names and paths unchanged when `executable` is declared.
- [x] Validate and invoke the default provider through the existing custom-provider trust and capability boundary; do not copy, generate, discover recursively, or execute undeclared provider files.
- [x] Add focused Bats coverage for fragment-only loading, mixed root-plus-fragment ordering, no-source failure, cross-file duplicates, default provider resolution, explicit executable override, unavailable default provider, and XDG/Rig data-home overrides.
- [x] Align README, `rig(1)`, changelog, user guidance, relevant Decision Records, and Specifications with the direct-authoring and provider-directory contracts.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `man/rig.1`
- `README.md`
- `CHANGELOG.md`
- `docs/decisions/ADR-RIG-002-xdg-directory-contract.md`
- `docs/decisions/ADR-RIG-003-declarative-configuration-grammar.md`
- `docs/decisions/ADR-RIG-005-provider-execution-contract.md`
- `docs/decisions/XDR-RIG-001-executable-provider-boundary.md`
- `docs/specs/configuration.md`
- `docs/specs/orchestration.md`
- `docs/specs/publishing.md`
- `docs/guides/user/README.md`

## Verify

- `bats tests/`
- `shellcheck bin/rig install.sh`
- `bash -n bin/rig install.sh`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`
- A fragment-only configuration loads identically to an equivalent root-plus-fragment configuration; ordering remains locale-independent and cross-file duplicates fail before provider invocation.
- A custom provider without `executable` resolves only its exact `${RIG_DATA_HOME}/providers/<provider-id>` path, while an explicit executable preserves existing command and path behaviour.

## Dependencies / blocks

This item is independent of RIG-CORE-005, though both should land before the private consumer can drop its templating layer. Both touch `bin/rig`, `tests/rig.bats`, and `CHANGELOG.md`, so implementation should serialize their commits rather than treating them as parallel file lanes.

## Documentation impact

### Decision Records

Amend ADR-RIG-002 and ADR-RIG-003 for the provider data directory and optional root source, and ADR-RIG-005 for omitted-executable resolution. Do not add a new record for consequences already owned by those decisions.

### Specifications

Update configuration loading and provider execution contracts for fragment-only sources, root-plus-fragment ordering, exact validation, the default provider path, and explicit override behaviour.

### Guides

Show how to author split configuration directly, choose a root-plus-fragment or fragment-only layout, place a Rig-only provider, and retain an explicit external executable.

### Roadmap

The private chezmoi consumer migration remains separate follow-up work after this capability lands; do not edit or apply that repository within this item.

## Review

### Delivered

Delivered direct configuration authoring and conventional custom-provider resolution from immutable baseline `584a2e9e66e234f5d900c02daa32b7bd28e9c66c`. A complete declaration may now live entirely in regular `conf.d/*.conf` fragments, while root-plus-fragment loading retains root-first bytewise order. Custom provider and publisher actions resolve one explicit executable or the exact effective data-home `providers/ID` path. No includes, variables, generation, recursive discovery, private-consumer migration, or native-manifest projection was added.

### Summary of changes

`bin/rig` now accepts one or more configuration sources, validates the merged model, reports an absent optional root in `rig diag`, and centralises custom executable resolution across observation, application, operations, inventory, and publication. Bats coverage exercises fragment-only and mixed layouts, no-source and cross-file failures, Rig/XDG data-home precedence, explicit overrides, missing defaults, and every custom trust-boundary invocation. README, the manual, changelog, user guide, three ADRs, the executable-boundary decision, and configuration, orchestration, and publishing specifications now describe the same contract. The XDR and publishing specification additions are a boundary-consistency expansion discovered during implementation.

### Verification

`shellcheck bin/rig install.sh`, `bash -n bin/rig install.sh`, `mandoc -T lint man/rig.1`, and all 116 Bats tests pass. The authoring, decision-record, and specification audits pass. The manual's pre-existing line-length finding was corrected while that file was already in scope. The repository-wide audit remains limited to the nine pre-existing approval-gated GitHub settings findings.

### Outstanding concerns

The private chezmoi consumer has not been migrated; that remains outside this item's boundary. The repository-wide GitHub settings findings require separate explicit authority. No implementation concern remains within the item.

### Post-change review

The implementation meets the direct-authoring goal without introducing another configuration language or weakening the executable trust boundary. Regression risk centres on source discovery and consistent executable resolution; both are covered through every affected command surface and explicit no-source, unavailable, and override cases. The item is ready for acceptance review.

### Mini recap

Rig configuration can now be authored directly as a fragment directory, and private Rig-only providers can live under the data directory without rendered executable paths. All local implementation and documentation checks pass. The private migration remains the established follow-up rather than being folded into this delivery.

## Discussion

### Authoring, not generating

The point is that loaded configuration is authored configuration. Adding includes, variables, or conditionals inside Rig would recreate the templating layer this item is intended to remove, one level down.

### Root and fragment semantics

There is one ordered configuration stream, not competing single-file and directory modes. Parse an existing root first, then regular fragments in bytewise filename order. At least one source must exist, and the merged model must contain exactly one `[rig]` section. Existing validation remains model-wide and fail closed.

### Provider naming

Omitting `executable` on a custom provider means exactly `${RIG_DATA_HOME}/providers/<provider-id>`. It does not search the directory, inspect adjacent files, or add the provider directory to `PATH`. An explicit `executable` continues to support an external command name or path and always overrides the default.

### Manifests stay observations

The consumer's Homebrew Brewfile must not become a generated projection of Rig configuration. Rig states what is wanted; the manifest and live machine state what is there. Generating one side from the other would make comparison vacuous and destroy the ability to notice something installed outside the declaration, which is useful drift.
