---
id: RIG-CORE-006
area: CORE
title: Author configuration directly
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-17T00:00:00Z
updated_at: 2026-09-18T02:36:43Z
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

- [ ] Amend the configuration decision and specification so `rig.conf` is optional when at least one regular `conf.d/*.conf` fragment exists; retain root-first then bytewise-fragment ordering when the root is present, and fail when no configuration source exists.
- [ ] Load and validate fragment-only configuration through the existing parser, requiring exactly one `[rig]` section across all sources and preserving duplicate section, duplicate scalar, unknown field, and reference failures across file boundaries.
- [ ] Make `rig diag` describe an absent optional root and the effective fragment count without treating valid fragment-only configuration as missing.
- [ ] Define `${RIG_DATA_HOME}/providers/<provider-id>` as the default executable for a custom provider that omits `executable`, while retaining explicit command names and paths unchanged when `executable` is declared.
- [ ] Validate and invoke the default provider through the existing custom-provider trust and capability boundary; do not copy, generate, discover recursively, or execute undeclared provider files.
- [ ] Add focused Bats coverage for fragment-only loading, mixed root-plus-fragment ordering, no-source failure, cross-file duplicates, default provider resolution, explicit executable override, unavailable default provider, and XDG/Rig data-home overrides.
- [ ] Align README, `rig(1)`, changelog, user guidance, relevant Decision Records, and Specifications with the direct-authoring and provider-directory contracts.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `man/rig.1`
- `README.md`
- `CHANGELOG.md`
- `docs/decisions/ADR-RIG-002-xdg-directory-contract.md`
- `docs/decisions/ADR-RIG-003-declarative-configuration-grammar.md`
- `docs/decisions/ADR-RIG-005-provider-execution-contract.md`
- `docs/specs/configuration.md`
- `docs/specs/orchestration.md`
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

## Discussion

### Authoring, not generating

The point is that loaded configuration is authored configuration. Adding includes, variables, or conditionals inside Rig would recreate the templating layer this item is intended to remove, one level down.

### Root and fragment semantics

There is one ordered configuration stream, not competing single-file and directory modes. Parse an existing root first, then regular fragments in bytewise filename order. At least one source must exist, and the merged model must contain exactly one `[rig]` section. Existing validation remains model-wide and fail closed.

### Provider naming

Omitting `executable` on a custom provider means exactly `${RIG_DATA_HOME}/providers/<provider-id>`. It does not search the directory, inspect adjacent files, or add the provider directory to `PATH`. An explicit `executable` continues to support an external command name or path and always overrides the default.

### Manifests stay observations

The consumer's Homebrew Brewfile must not become a generated projection of Rig configuration. Rig states what is wanted; the manifest and live machine state what is there. Generating one side from the other would make comparison vacuous and destroy the ability to notice something installed outside the declaration, which is useful drift.
