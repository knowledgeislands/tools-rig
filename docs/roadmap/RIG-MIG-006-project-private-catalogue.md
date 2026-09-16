---
id: RIG-MIG-006
area: MIG
title: Project private catalogue
theme: migration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 40e2eec36299b6c88ab098b7c11768f8095eed95
created_at: 2026-09-16T12:57:39Z
updated_at: 2026-09-16T21:37:27Z
---

# RIG-MIG-006: Project private catalogue

## Goal

The existing private workstation software catalogue renders a valid `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.conf` so `rig diag`, `show`, `list`, and `explain` work with real personal declarations before provider adapters are available.

## Context

The standalone query engine is installed, but the target configuration is missing. The chezmoi source currently owns a canonical YAML catalogue of 12 categories and 88 intentionally adopted applications, 85 of which are required. Copying that data into a second hand-maintained file would create competing private authorities.

## Boundary

This item adds one chezmoi template that derives schema-1 categories, catalogue-only tools, and a default profile from `.chezmoidata/software.yaml`. It does not add provider bindings, copy package or path fields into unsupported schema keys, invent role profiles, remove the existing YAML authority, apply chezmoi changes, change live home-directory state, or retire the legacy Rig.

## Current state

`rig diag` reports `/Users/krisbrown/.config/rig/rig.conf` as missing and exits 1. The source catalogue contains 88 tools across 12 categories; three optional records are intentionally excluded from the 85-tool default profile. Its fields have been inventoried against the accepted Rig grammar.

## Steps

- [x] Add a private chezmoi template for `.config/rig/rig.conf` with deterministic category, tool, and profile order.
- [x] Map names, categories, and purposes directly; set `platform = macos`; add an explicit transitional rationale without inventing provider state.
- [x] Normalise digit-leading source IDs to `one-password` and `one-password-cli` while leaving the YAML keys unchanged.
- [x] Include every catalogue tool and include only required tools in `[profile.default]`.
- [x] Render into an isolated configuration directory and prove exact counts plus `diag`, `show`, filtered `list`, and `explain` behaviour.
- [x] Add focused dotfiles regression coverage for the rendered contract.
- [x] Run `chezmoi diff` for the target and stop before `chezmoi apply`.

## Files touched

In the chezmoi source repository: `.chezmoiignore`, `dot_config/rig/private_rig.conf.tmpl`, and focused tests under `tests/`. In tools-rig: this work record only.

## Verify

Render the template with `chezmoi execute-template` into a temporary Rig configuration, assert exact parity with the current category, application, and required-application counts, then run `rig diag`, `rig show`, `rig list --category development`, and `rig explain one-password` with `RIG_PLATFORM=macos`. Run the relevant dotfiles tests, `chezmoi diff ~/.config/rig/rig.conf`, tools-rig roadmap audit, and `git diff --check` in both repositories. Do not apply.

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

## Review

### Delivered

The private chezmoi projection renders the canonical workstation software catalogue as Rig schema 1 without changing live home-directory state.

### Summary of changes

- Added a private `rig.conf` template derived from `.chezmoidata/software.yaml`.
- Projected 12 categories, 88 tools, and the 85 required tools into `profile.default`.
- Added deterministic parity tests, including the two digit-leading identifier aliases.
- Re-included only the private Rig target beneath the otherwise ignored `.config` tree.

### Verification

- `node --test tests/*.test.mjs`: 23 tests pass.
- `git diff --check`: clean in the dotfiles repository.
- `chezmoi status ~/.config/rig/rig.conf`: reports the expected pending add.
- `chezmoi diff ~/.config/rig/rig.conf`: renders an 843-line mode-0600 target; no apply performed.
- Rendered `rig diag`, `show`, `list --category development`, and `explain one-password` all exit successfully.

### Outstanding concerns

Catalogue queries currently take roughly four to six seconds over this 88-tool projection. RIG-CORE-004 owns the performance follow-up. Provider bindings and legacy retirement remain RIG-MIG-004 work.

### Post-change review

Independent review found the projection functionally clean at the current 12-category, 88-tool, 85-selected-tool state. The only cleanup finding, indentation in the focused test, was corrected and the full dotfiles test suite rerun.

### Mini recap

The private catalogue now has one source of truth and a tested Rig projection ready for explicit chezmoi application. The live `~/.config/rig/rig.conf` remains absent by design until approval.

## Done

Accepted 2026-09-16 by Kris Brown on review packet above.

## Discussion

### Post-review application

At acceptance, the projected `~/.config/rig/rig.conf` exists at mode `0600`, `chezmoi verify` passes, and both `chezmoi status` and `chezmoi diff` are clean. This subsequent application supersedes the review packet's historical pending-add state without changing the reviewed projection boundary.

### Transitional authority

`.chezmoidata/software.yaml` remains the single private authority during this slice. The generated Rig file is a chezmoi target projection, not a second hand-edited catalogue. RIG-MIG-004 will later decide the final provider-aware authority after dependent consumers can migrate.

### Honest field mapping

The source has no rationale field. Every projected tool therefore uses `Intentionally retained in the workstation software catalogue.` as an explicit transitional rationale rather than fabricating a tool-specific preference.

### Profile scope

Only `default` is projected. `minimal`, `developer`, and `knowledge-islands` require deliberate personal selections and remain future private declaration work.
