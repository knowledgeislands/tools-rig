---
id: RIG-MIG-005
area: MIG
title: Retire chezmoi Rig
theme: migration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-16T11:06:43Z
updated_at: 2026-09-16T23:40:29Z
---

# RIG-MIG-005: Retire chezmoi Rig

## Goal

The standalone Rig becomes the only managed `rig` command after equivalent behaviour, tests, private declarations, and callers have moved safely out of the legacy chezmoi implementation.

## Context

`~/.local/bin/rig` currently resolves to the standalone working installation, while `~/bin/rig` remains managed by chezmoi as a fallback. The dotfiles repository still contains the legacy dispatcher, helper scripts, tests, guides, data, and command references. Removing only the wrapper now would leave live workflows without proven replacements.

## Boundary

This item removes the legacy Rig ownership only after its parity gates pass. It does not delete provider helpers that remain selected by private Rig configuration, discard unrelated dotfiles changes, run `chezmoi apply` without explicit approval, change live GitHub settings, push, or publish a release.

## Current state

The standalone working installation is first on the active path, but chezmoi still manages a fallback `~/bin/rig` and its legacy implementation. The exact source inventory is `bin/executable_rig`, `bin/rig.d/executable_bootstrap`, `bin/rig.d/executable_machine`, `bin/rig.d/executable_services`, the underlying `bin/executable_machine`, and the selected `bin/env/executable_brew`, `executable_bun`, `executable_completions`, `executable_node`, `executable_perms`, `executable_ruby`, `executable_ssh`, `executable_uv`, and `executable_zsh` helpers. Private data remains in `.chezmoidata/software.yaml`, `.chezmoidata/macos.yaml`, `.chezmoidata/scheduled-jobs.yaml`, `.chezmoidata/service-operations.yaml`, and `dot_config/private_homebrew/Brewfile`.

Caller inventory includes `docs/guides/user/bootstrap.md`, `mac-power-tools.md`, `macos-workstation.md`, and `software.md`; `docs/guides/tools/chezmoi.md`, `mcporter.md`, and `rig.md`; `docs/guides/agents/audits.md` and `scheduled-jobs.md`; and `docs/housekeeping/DOTFILES-HK-003-review-workstation-software.md`. Completion ownership is split across the legacy generator in `bin/executable_rig`, regeneration in `bin/env/executable_completions`, and tracked `dot_zsh/completions/_rig`. Test coverage spans `tests/rig.test.mjs`, `tests/env-bootstrap.test.mjs`, `tests/ki-self-skill.test.mjs`, `tests/rig-catalogue.test.mjs`, and `tests/machine-applications.test.mjs`.

## Steps

- [ ] Freeze the source, caller, completion, and test inventory above against the current dotfiles revision and classify every path as remove, rewrite, or retain as a provider helper.
- [ ] Complete a parity matrix for bootstrap install and selected ordering; provider update, cleanup, and backup operations; machine audit and verbose mode; service list, run, restart, status, logs, and follow mode; help, completion, diagnostics, exit status, unknown-name failure, dry-run, and mutation boundaries.
- [ ] Rewrite all callers to standalone bootstrap, status, doctor, apply, `rig run workstation audit`, and `rig run launchcontrol` forms before removing the corresponding legacy surface.
- [ ] Remove only obsolete chezmoi sources and tracked legacy completion after equivalent standalone tests pass; retain every helper still named by private provider or operation configuration.
- [ ] Run focused and full dotfiles tests, regenerate or remove completion through its source workflow, and inspect a targeted `chezmoi diff` that contains no unrelated working-tree changes.
- [ ] Stop for explicit approval before the separate `chezmoi apply`; after approval and application, prove `type -a rig` reports only the intended standalone installation and run final smoke and rollback checks.

## Files touched

Expected scope is exactly the inventoried chezmoi sources, callers, completion, and tests plus the generated private Rig template where retained helper references change. Tools-rig code is changed only if the parity matrix exposes a defect owned by an existing CORE, CLI, or migration item.

## Verify

Before removal, run both implementations side by side against fakes and complete every parity-matrix row. Run the full tools-rig gate and full dotfiles Node suite, inspect `chezmoi status` and targeted `chezmoi diff`, and confirm retained configuration resolves only retained helpers. Do not apply during review. After separate explicit apply approval, run `type -a rig`, standalone help and completion checks, read-only status and doctor, bootstrap dry-run, operation smoke tests, and verify the old target is absent while Git history remains the rollback path.

## Dependencies / blocks

RIG-MIG-001, RIG-MIG-002, RIG-MIG-003, and RIG-CLI-004 must deliver their parity surfaces before removal. RIG-MIG-004 is a transitive prerequisite through those migration items. This is a cross-repository source transition with an explicit review boundary: committing chezmoi sources does not authorise `chezmoi apply`, and application must not be bundled with release, push, or publication work.

## Delegation

Separate workers may audit source retention, caller and completion rewrites, and parity tests against disjoint files. The coordinator owns the immutable inventory revision, unrelated-change preservation, parity-matrix sign-off, targeted `chezmoi diff`, explicit-apply stop, post-apply `type -a rig` proof, and rollback decision.

## Documentation impact

### Decision Records

No new decision record is expected unless retirement changes the accepted private/public authority or rollback boundary.

### Specifications

No new behaviour contract is introduced; any parity defect must be corrected in its owning accepted specification before retirement proceeds.

### Guides

Rewrite every inventoried caller to the standalone command language and remove descriptions of the legacy dispatcher, machine, service, and completion ownership only when their replacement is proven.

### Roadmap

Keep this item draft until all four direct prerequisites and the cross-repository parity matrix are satisfied. Record any newly discovered gap in its existing command, provider, or migration owner rather than broadening retirement scope.

## Discussion

### Cutover gate

Retirement requires standalone tests equivalent to the old bootstrap, machine-audit, and service-operation coverage; migrated command callers and documentation; a side-by-side command inventory; and a reviewed `chezmoi diff` showing the exact source transition.

### Source transition

Changes happen in chezmoi source state. Host-specific declarations remain private, native provider manifests remain authoritative, and helpers are retained whenever the new configuration still references them.

### Rollback

The legacy implementation remains recoverable from dotfiles Git history. Applying the reviewed chezmoi transition is a separately approved action so the user can retain the old executable until the standalone replacement is proven on the target machine.
