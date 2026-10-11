---
id: RIG-CORE-041
area: CORE
title: Unwanted software removal
initiative: rig
kind: deliver
purpose: capability
component: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-09T06:38:35Z
updated_at: 2026-10-11T09:33:00Z
---

# RIG-CORE-041: Unwanted Software Removal

## Goal

`rig doctor` tells Kris when software is installed that his Rig no longer wants, and keeps three cases apart: (a) items declared for removal that are still present, (b) items installed but not declared or no longer wanted, and (c) declared items that have drifted. Uninstalling stays optional: when Rig removes anything, it does so only when explicitly asked, after a dry run.

## Context

Kris asked for this on 2026-10-09 during the Mac Studio bootstrap (mac-studio-bootstrap thread, Decision 8). Comparing two machines that should carry the same Rig showed software present on one that the declaration no longer selects, and nothing in Rig says so.

What Rig does today:

- **Never uninstalls packages.** Deselection does not retire. [RIG-STATE-024](../specs/state.md) retires only previously receipted services and scheduled jobs the catalogue no longer declares, and forbids removing packages, artefacts, settings, Dock layouts, ports or skills "without a separate explicit cleanup contract". This record would be that contract.
- **Receipt-backed retirement.** [RIG-STATE-020](../specs/state.md) writes `${RIG_STATE_HOME}/resources/PLATFORM.tsv` after a successful reconciliation; RIG-STATE-024 uses it to retire launchd resources removed from the catalogue. No equivalent receipt records which packages Rig installed.
- **Retired applications are observation only.** `[retired-application.ID]` declarations feed `rig status --retired` ([guide](../guides/user/retired-applications.md)). They are not tools or profile members, do not change doctor findings or exit codes, and are not used by apply or upgrade.
- **Unmanaged inventory exists but is opt-in.** `rig status --unmanaged` asks inventory sources about undeclared items: Homebrew formulae installed on request and casks, plus the macOS application baseline ([RIG-STATE-032](../specs/state.md)). [RIG-ORCH-038](../specs/orchestration.md) uses the same inventory for reviewed adoption through `rig capture`. Doctor does not consult it.
- **Doctor has no warning tier in practice.** [The command guide](../guides/user/commands.md) says warnings are currently zero and actionable findings keep failure status, so "installed but unwanted" would either fail doctor or need a real warning level.

chezmoi's [`.chezmoiremove`](https://www.chezmoi.io/reference/special-files/chezmoiremove/) is the model Kris suggested: an explicit, reviewable list of things to remove, acted on only by an apply.

## Boundary

- **In:** the doctor classification of (a), (b) and (c); a declared removal list (a new declaration kind, or an extension of `[retired-application]`); an opt-in removal action with a dry run, per provider, using each native manager's own uninstall; how this relates to the retired-application report and receipt-backed retirement; spec, guide, help and manual alignment.
- **Out:** automatic uninstall on deselection or during `apply` or `upgrade`; deleting retained application data (the retired-application report's "no observation is deletion approval" stays); Kris's own removal list, which belongs in the chezmoi source; the per-machine profile layout (DOTFILES-UE-075 in the chezmoi repository).

## Current state

Kris selected and approved bounded planning and delivery under tools-burndown Decisions 1, 3 and 4. RIG-CORE-043 supplies honest source classification. No competing delivery owns this record; personal removals and RIG-CORE-042 remain protected.

## Steps

- [ ] Add validated private `[remove.ID]` declarations with native identity, platform and optional profile membership; reject conflicts with retained tool installations and unsafe provider arguments.
- [ ] Add default-preview `rig remove`, requiring `--apply` and confirmation of its displayed preview, with fresh observations and independent native outcomes.
- [ ] Add doctor removal findings and opt-in `--unmanaged` information, preserving declared drift and retired-application observation semantics.
- [ ] Align specifications, guide, help and manual; verify isolated native fixtures and the full local gate, then prepare the six-part Review packet.

## Files touched

Configuration, declaration registry, provider inventory, doctor, runtime help and dispatcher modules; a new removal module; assembled executable and assembly manifest; isolated removal tests and sudo containment stub; configuration/state/orchestration specs, user command guide, manual and changelog.

## Verify

Fixture tests prove default preview, refusal/EOF, explicit confirmation, undeclared-target rejection, duplicate/retained identity rejection, profile/platform filtering, no automatic uninstall, native argv and independent failure, honest doctor cases and inventory information. Run the developer guide's complete gate and the suite with hostile inherited XDG state when changing isolation. Review the actual diff and committed path roster.

## Dependencies / blocks

RIG-CORE-043 delivered application classification. No acceptance dependency. No live uninstall, data cleanup, native authentication or personal declaration changes are authorised.

## Documentation impact

### Decision Records

Routine choices and owner authority are recorded here; no separate architectural decision is required.

### Specifications

Specify the private removal declaration, confirmation boundary, native command matrix and three doctor classifications.

### Guides

Explain preview and explicit native removal, inventory opt-in and retained-data boundary; align command help and manual.

### Roadmap

Keep this identity and stop at Awaiting review; do not capture, accept or prune work.

## Discussion

### Approved routine choices

Use separate private `[remove.ID]` declarations as explicit removal authority, without receipt gating. Only selected platform/profile declarations are actionable; retained installation identities anywhere in the catalogue forbid removal. Support native Homebrew formula/cask/App Store, uv, npm and mise uninstall operations; reject custom executables and arbitrary provider arguments. App Store removal uses only an existing noninteractive sudo grant and never acquires one. Preview is the default; `--apply` repeats the selected preview before requiring literal `remove`, and reobserves presence after confirmation. Missing items skip, uncertain evidence refuses, failures remain visible. Native tools retain uninstall semantics; Rig requests no zap or data cleanup. Doctor reports declared pending removals as findings, undeclared-anywhere inventory only under `--unmanaged` as information, and drift through existing observations. Deselection, apply, upgrade and retired-application traces never approve package deletion. No automatic retired declaration is created.


Open questions for planning:

- **Removal list shape.** A separate `[remove.ID]` table, a `remove = true` or `state = "absent"` field on an existing tool, or `[retired-application]` gaining a provider identity. A field on the tool keeps catalogue identity and history in one place; a separate list mirrors `.chezmoiremove` and keeps removed things out of the catalogue and public view.
- **What counts as unwanted.** "Undeclared anywhere in the catalogue" is safe; "declared but not in this machine's profile" matters once per-machine profiles exist (DOTFILES-UE-075) and is the likelier source of noise. Transitive Homebrew dependencies stay out, as `--unmanaged` already excludes them.
- **Doctor severity and cost.** Whether doctor runs the inventory by default (a Homebrew and application scan on every doctor run) or only under a flag; whether case (b) is a warning that does not fail doctor, which needs a real warning tier and a decision about exit status for unattended callers such as the chezmoi `rig-update` job.
- **Uninstall action.** A `rig remove` or `rig apply --remove` that acts only on the declared list, previews with `--dry-run`, refuses anything not declared for removal, and reports per-item native outcomes. Whether removal should be receipt-gated, so Rig only uninstalls what it can show it installed, or trust the explicit declaration.
- **Retirement overlap.** Whether a removed application should automatically gain the retired-application report afterwards, so trace review follows uninstall without a second declaration.
- **A first real list is waiting.** The owner's private configuration repository already holds a decided removal list of about 25 applications and packages across two Macs, from the 2026-10-09 machine comparison. It moves into the removal declaration this record defines once that exists, and stays out of this public repository.
