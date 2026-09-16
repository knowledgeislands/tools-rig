---
id: RIG-MIG-006
area: MIG
title: Project private catalogue
theme: migration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-16T12:57:39Z
updated_at: 2026-09-16T12:57:39Z
---

# RIG-MIG-006: Project private catalogue

## Goal

The existing private workstation software catalogue renders a valid `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.conf` so `rig diag`, `show`, `list`, and `explain` work with real personal declarations before provider adapters are available.

## Context

The standalone query engine is installed, but the target configuration is missing. The chezmoi source already owns a canonical YAML catalogue of 12 categories and 89 intentionally adopted applications, 86 of which are required. Copying that data into a second hand-maintained file would create competing private authorities.

## Boundary

This item adds one chezmoi template that derives schema-1 categories, catalogue-only tools, and a default profile from `.chezmoidata/software.yaml`. It does not add provider bindings, copy package or path fields into unsupported schema keys, invent role profiles, remove the existing YAML authority, apply chezmoi changes, change live home-directory state, or retire the legacy Rig.

## Current state

`rig diag` reports `/Users/krisbrown/.config/rig/rig.conf` as missing and exits 1. The source catalogue contains 89 tools across 12 categories; three optional records are intentionally excluded from the 86-tool default profile. Its fields have been inventoried against the accepted Rig grammar.

## Steps

- [ ] Add a private chezmoi template for `.config/rig/rig.conf` with deterministic category, tool, and profile order.
- [ ] Map names, categories, and purposes directly; set `platform = macos`; add an explicit transitional rationale without inventing provider state.
- [ ] Normalise digit-leading source IDs to `one-password` and `one-password-cli` while leaving the YAML keys unchanged.
- [ ] Include every catalogue tool and include only required tools in `[profile.default]`.
- [ ] Render into an isolated configuration directory and prove exact counts plus `diag`, `show`, filtered `list`, and `explain` behaviour.
- [ ] Add focused dotfiles regression coverage for the rendered contract.
- [ ] Run `chezmoi diff` for the target and stop before `chezmoi apply`.

## Files touched

In the chezmoi source repository: `dot_config/rig/private_rig.conf.tmpl` and focused tests under `tests/`. In tools-rig: this work record only.

## Verify

Render the template with `chezmoi execute-template` into a temporary Rig configuration, assert 12 categories, 89 tools, and 86 default-profile members, then run `rig diag`, `rig show`, `rig list --category development`, and `rig explain one-password` with `RIG_PLATFORM=macos`. Run the relevant dotfiles tests, `chezmoi diff ~/.config/rig/rig.conf`, tools-rig roadmap audit, and `git diff --check` in both repositories. Do not apply.

## Dependencies / blocks

The delivered schema loader and catalogue queries are sufficient because this slice intentionally emits no provider or binding sections. Full provider-bound declaration migration remains owned by RIG-MIG-004.

## Delegation

One bounded worker may edit the chezmoi template and its focused tests only. The coordinator owns roadmap lifecycle, cross-repository integration, rendered-query verification, `chezmoi diff`, review evidence, and commits. The worker must preserve unrelated dotfiles changes and must not run `chezmoi apply`.

## Documentation impact

### Decision Records

No Decision Record change is expected; the accepted migration boundary already keeps personal declarations in dotfiles and portable behaviour in tools-rig.

### Specifications

No public Specification changes; the rendered file conforms to existing schema and query requirements.

### Guides

No public guide changes in this transitional slice because the private projection is workstation-specific.

### Roadmap

Record the source-of-truth transition and performance observation here without claiming provider migration or legacy retirement.

## Discussion

### Transitional authority

`.chezmoidata/software.yaml` remains the single private authority during this slice. The generated Rig file is a chezmoi target projection, not a second hand-edited catalogue. RIG-MIG-004 will later decide the final provider-aware authority after dependent consumers can migrate.

### Honest field mapping

The source has no rationale field. Every projected tool therefore uses `Intentionally retained in the workstation software catalogue.` as an explicit transitional rationale rather than fabricating a tool-specific preference.

### Profile scope

Only `default` is projected. `minimal`, `developer`, and `knowledge-islands` require deliberate personal selections and remain future private declaration work.
