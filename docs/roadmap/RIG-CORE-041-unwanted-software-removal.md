---
id: RIG-CORE-041
area: CORE
title: Unwanted software removal
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-09T06:38:35Z
updated_at: 2026-10-11T01:55:56Z
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

## Discussion

Open questions for planning:

- **Removal list shape.** A separate `[remove.ID]` table, a `remove = true` or `state = "absent"` field on an existing tool, or `[retired-application]` gaining a provider identity. A field on the tool keeps catalogue identity and history in one place; a separate list mirrors `.chezmoiremove` and keeps removed things out of the catalogue and public view.
- **What counts as unwanted.** "Undeclared anywhere in the catalogue" is safe; "declared but not in this machine's profile" matters once per-machine profiles exist (DOTFILES-UE-075) and is the likelier source of noise. Transitive Homebrew dependencies stay out, as `--unmanaged` already excludes them.
- **Doctor severity and cost.** Whether doctor runs the inventory by default (a Homebrew and application scan on every doctor run) or only under a flag; whether case (b) is a warning that does not fail doctor, which needs a real warning tier and a decision about exit status for unattended callers such as the chezmoi `rig-update` job.
- **Uninstall action.** A `rig remove` or `rig apply --remove` that acts only on the declared list, previews with `--dry-run`, refuses anything not declared for removal, and reports per-item native outcomes. Whether removal should be receipt-gated, so Rig only uninstalls what it can show it installed, or trust the explicit declaration.
- **Retirement overlap.** Whether a removed application should automatically gain the retired-application report afterwards, so trace review follows uninstall without a second declaration.
