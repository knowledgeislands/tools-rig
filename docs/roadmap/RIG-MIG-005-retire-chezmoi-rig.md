---
id: RIG-MIG-005
area: MIG
title: Retire chezmoi Rig
theme: migration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: d9175e86084ba88d9022f1c29b23eac9cbad0f7a
created_at: 2026-09-16T11:06:43Z
updated_at: 2026-09-18T02:34:25Z
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

- [x] Freeze the source, caller, completion, and test inventory above against the current dotfiles revision and classify every path as remove, rewrite, or retain as a provider helper.
- [x] Complete a parity matrix for bootstrap install and selected ordering; provider update, cleanup, and backup operations; machine audit and verbose mode; service list, run, restart, status, logs, and follow mode; help, completion, diagnostics, exit status, unknown-name failure, dry-run, and mutation boundaries.
- [x] Rewrite all callers to standalone bootstrap, status, doctor, apply, `rig run workstation audit`, and `rig run launchcontrol` forms before removing the corresponding legacy surface.
- [x] Remove only obsolete chezmoi sources and legacy completion ownership after equivalent standalone tests pass; retain the standalone-generated tracked completion and every helper still named by private provider or operation configuration.
- [x] Run focused and full dotfiles tests, regenerate or remove completion through its source workflow, and inspect a targeted `chezmoi diff` that contains no unrelated working-tree changes.
- [x] Stop at the reviewed, unapplied chezmoi diff and record separate explicit approval as the gate for application, post-apply `type -a rig` proof, final smoke checks, and rollback decision.

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

This item reached Awaiting review only after all four direct prerequisites and the cross-repository parity matrix were satisfied. Record any newly discovered gap in its existing command, provider, or migration owner rather than broadening retirement scope.

## Review

### Delivered

Dotfiles commit `d59f856` delivers the reviewed legacy-source retirement from tools-rig baseline `d9175e86084ba88d9022f1c29b23eac9cbad0f7a`. It builds on private declaration commit `d2971c2`, dotfiles parity commit `e1d8b9b`, and public bootstrap and operation support in `d1d275a`. Dotfiles adoption commit `5eb788a` then records the approved cutover to the Knowledge Islands tap release.

### Summary of changes

The dotfiles source no longer owns `bin/executable_rig` or the legacy bootstrap, machine, and service dispatchers under `bin/rig.d/`. Bootstrap maintenance and launch-control behaviour now live in their retained private provider shims, while the workstation provider continues to delegate to the retained root machine helper. `.chezmoiremove` declares the four target removals; private catalogue data, native manifests, environment helpers, provider shims, and the standalone-generated tracked `_rig` completion remain authoritative. The reviewed target transition deletes `~/bin/rig` and `~/bin/rig.d/{bootstrap,machine,services}`, adds the three provider shims, and updates private `rig.conf`, `_rig`, and `bin/machine`.

### Verification

Dotfiles commit `d59f856` passed all 22 Node tests plus ShellCheck, Bash syntax, Markdown, completion-identity, and diff checks. The tools-rig gate passed all 96 Bats tests, ShellCheck, Bash syntax, and `mandoc -T lint`; the repository audit retained only the known live GitHub-settings findings outside this item's authority. Post-cutover verification confirms `~/.local/bin/rig` is the standalone development link, `/opt/homebrew/bin/rig` is the v0.1.0 package installation, all four legacy targets are absent and no longer managed by chezmoi, and Rig help, Bash and Zsh completion, bootstrap dry-run, workstation audit, and launch-control list operations succeed. Live `doctor` and `status` complete against the private catalogue and consistently report 71 present, two missing, and 12 catalogue-only tools.

### Outstanding concerns

The live private catalogue reports `codexbar` and `one-password-cli` missing because tap-qualified declared identities do not yet normalise to Homebrew's short installed identities. `RIG-CORE-005` owns that comparison defect; it does not indicate legacy Rig remains installed or managed.

### Post-change review

The applied transition removes only the legacy command facade and dispatchers. Private declarations, provider/native authority, fail-fast bootstrap ordering, operation allow-lists, mutation boundaries, and host-specific helpers remain intact. Both active `rig` resolutions now execute the standalone Knowledge Islands implementation rather than the retired chezmoi dispatcher.

### Mini recap

Standalone Rig has complete private parity, the obsolete chezmoi sources are retired, and the live legacy executable and dispatchers are absent. Deleted sources remain recoverable from pre-retirement dotfiles commit `e1d8b9b`, providing the documented rollback point.

## Done

Accepted 2026-09-18 by Kris Brown on the review packet above.

## Discussion

### Cutover gate

Retirement requires standalone tests equivalent to the old bootstrap, machine-audit, and service-operation coverage; migrated command callers and documentation; a side-by-side command inventory; and a reviewed `chezmoi diff` showing the exact source transition.

### Source transition

Changes happen in chezmoi source state. Host-specific declarations remain private, native provider manifests remain authoritative, and helpers are retained whenever the new configuration still references them.

### Rollback

The legacy implementation remains recoverable from dotfiles Git history. Applying the reviewed chezmoi transition is a separately approved action so the user can retain the old executable until the standalone replacement is proven on the target machine.
