---
id: RIG-CORE-043
area: CORE
title: Self-updating applications
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-10T15:29:43Z
updated_at: 2026-10-11T01:55:56Z
---

# RIG-CORE-043: Self-Updating Applications

## Goal

Rig leaves alone applications that keep themselves up to date. When such an application is already on the machine, Rig counts it as installed, whatever its version or however it got there. It installs the application only when it is missing and never tries to upgrade it.

Rig also says when an application came from a different source than its declaration names: the App Store, a hand install, or a Homebrew copy that has updated itself out of Homebrew's records. `rig doctor` reports the mismatch and shows the steps to swap the copy for the declared source. Rig never deletes the other copy itself.

## Context

Kris asked for this on 2026-10-10 during the Mac Studio bootstrap (mac-studio-bootstrap thread, Decision 24). On sol, the Mac Studio, `rig apply` failed on the `onedrive` cask. Homebrew refused with "A newer version of OneDrive (26.173.0906) is already installed": OneDrive had updated itself past Homebrew's 26.153 package. The application was present and current, yet Rig reported a failed apply.

Later the same day Kris widened the record (Decision 33). On sol several declared Homebrew casks were already present from another source: App Store copies of Slack, TickTick and WiFi Explorer, and hand-installed copies of Spark Desktop, OneDrive and DaisyDisk. Rig reported each as `missing` and `rig apply` failed on them, with no hint that the application was in fact there. `brew install --cask --adopt` did not help: macOS App Management refused the ownership change on the existing bundles (`Operation not permitted`, or a `sudo chgrp`/`chmod` step that rolled back). The fix that worked was deleting the foreign copy with sudo and rerunning `rig apply`. Kris had to work that out by hand; doctor should have said so. DaisyDisk went the other way: its licence was bought through the App Store, so the declaration moved to the App Store rather than the copy moving to Homebrew.

What Rig does today:

- **Presence comes only from the native manager.** [RIG-ORCH-017](../specs/orchestration.md#rig-orch-017--built-in-native-command-matrix) observes a cask with `brew list --cask --versions` and applies it with `brew install --cask`. [RIG-ORCH-003](../specs/orchestration.md#rig-orch-003--native-provider-authority) leaves the installation state to the provider. An application that Homebrew does not record, because it was installed another way or Homebrew lost track of it after a self-update, is `missing` under [RIG-STATE-002](../specs/state.md#rig-state-002--observation-vocabulary). Apply then sends it to an installer that refuses.
- **Declared artifacts are observation only.** A tool may declare artifacts such as `/Applications/OneDrive.app` ([RIG-CAT-007](../specs/catalogue.md#rig-cat-007--tool-owned-generated-artifacts), [RIG-STATE-023](../specs/state.md#rig-state-023--generated-artifact-state), [RIG-ORCH-025](../specs/orchestration.md#rig-orch-025--artifact-lifecycle-ownership)). Today they do not decide whether the tool itself is installed.
- **Upgrades go to every selected Homebrew tool.** [RIG-ORCH-024](../specs/orchestration.md#rig-orch-024--declaration-scoped-upgrades) runs `brew upgrade --cask LOCATOR` for each selected cask. Homebrew already skips a cask marked `auto_updates` unless `--greedy` is given. Even so, Rig still sends the task, and it fails when Homebrew does not own the installation.
- **Competing auto-update handling is unrelated.** [RIG-ORCH-034](../specs/orchestration.md#rig-orch-034--unattended-lifecycle-execution) has doctor report an undeclared `homebrew-autoupdate` agent as information. That agent advances Homebrew itself. Nothing in Rig describes an application that updates itself.
- **Doctor does not compare versions.** [RIG-STATE-013](../specs/state.md#rig-state-013--doctor-health-synthesis) builds its verdict from the observation vocabulary, so "absence only" already holds for presence. The real gap is that the observation depends on the install source.

## Boundary

- **In:** a per-tool declaration that an application maintains its own version; for such tools, satisfaction by the declared artifact regardless of version or install source; install only when the artifact is missing; `rig upgrade` skipping the tool with a visible per-task outcome; doctor reporting only absence; doctor reporting a tool whose present copy came from a different source than declared (App Store, hand install, or a self-updated Homebrew copy), with the steps to swap it for the declared source; a default from Homebrew's cask `auto_updates` metadata with the declaration as override; spec, guide, help and manual alignment.
- **Out:** formulae, and tools whose versions are pinned or declared (for example `bun` through mise), which keep their declared versions; changing an application's own update settings; adopting or re-registering a foreign installation with Homebrew (`brew install --adopt`), unless planning chooses it; Rig deleting, moving or replacing any application itself, including a foreign copy it reports (it only shows the steps), and any other removal, which belongs to RIG-CORE-041; Kris's own catalogue entries, which belong in the chezmoi source.

## Discussion

### Candidate direction

This is a proposal from capture, not a locked design:

- **Declaration.** A tool field such as `updates = "self"` means the application maintains its own version. It may also be set on a platform variant ([RIG-CAT-008](../specs/catalogue.md#rig-cat-008--one-identity-across-platform-variants)), since self-updating is usually a macOS cask property.
- **Satisfaction.** A self-updating tool counts as `present` when its declared artifact exists, whatever the native manager reports. The tool must then declare an artifact. Whether to reject a self-updating tool with no artifact, or fall back to the manager's own observation, is open.
- **Apply.** Rig installs only when the artifact is missing. A present artifact produces no native call, which avoids the OneDrive refusal entirely.
- **Upgrade.** `rig upgrade` skips the tool with a distinct outcome, such as `skipped` with detail `self-updating`, rather than dropping it silently. That keeps [RIG-STATE-029](../specs/state.md#rig-state-029--exit-status-and-stated-outcome) exit-status semantics and the unattended report under [RIG-STATE-030](../specs/state.md#rig-state-030--unattended-last-run-report) honest.
- **Doctor and status.** Only absence is reported. Detail may note that the artifact was found outside the native manager, so the install source stays visible without failing health.
- **Source mismatch.** For a declared application whose artifact exists but whose native manager does not record it, observation names the source it can see: an App Store receipt (`Contents/_MASReceipt`), a Homebrew Caskroom record for another version, or none (hand-installed). Doctor reports this as a distinct finding rather than `missing`, and its action lists the swap steps for the declared source, for example: quit the app, delete the copy (`sudo rm -rf /Applications/OneDrive.app` when App Management blocks a normal delete), run `rig apply`, sign in again. For a self-updating tool the mismatch is information, not unhealthy; for any other tool it is a finding. Apply skips the tool with that detail instead of calling an installer that will refuse.
- **Default from metadata.** Where Homebrew cask metadata carries `auto_updates true`, it would supply the default and the declaration would override it either way (`updates = "self"` or `updates = "managed"`).

### Spec items affected

- [RIG-CAT-005](../specs/catalogue.md#rig-cat-005--tool-installations) and [RIG-CAT-008](../specs/catalogue.md#rig-cat-008--one-identity-across-platform-variants): the new tool or variant field and its validation.
- [RIG-ORCH-017](../specs/orchestration.md#rig-orch-017--built-in-native-command-matrix) and [RIG-ORCH-003](../specs/orchestration.md#rig-orch-003--native-provider-authority): artifact-based satisfaction as an exception to manager-only observation.
- [RIG-ORCH-024](../specs/orchestration.md#rig-orch-024--declaration-scoped-upgrades) and [RIG-ORCH-034](../specs/orchestration.md#rig-orch-034--unattended-lifecycle-execution): the skip outcome in attended and unattended upgrades.
- [RIG-ORCH-025](../specs/orchestration.md#rig-orch-025--artifact-lifecycle-ownership) and [RIG-STATE-023](../specs/state.md#rig-state-023--generated-artifact-state): artifacts gain a role in tool satisfaction.
- [RIG-STATE-002](../specs/state.md#rig-state-002--observation-vocabulary), [RIG-STATE-013](../specs/state.md#rig-state-013--doctor-health-synthesis) and [RIG-STATE-029](../specs/state.md#rig-state-029--exit-status-and-stated-outcome): observation detail, doctor treatment, and how a skip counts towards the outcome.

### Open questions

- **Metadata cost and determinism.** Reading `auto_updates` needs `brew info --json=v2 --cask`, a further native call per cask on every observation. Options include reading it only during `rig capture` and writing it into the proposal as an explicit declaration, caching it, or requiring the declaration outright. A default that changes when Homebrew metadata changes also makes plans less predictable.
- **Artifact as the authority.** Using an artifact for satisfaction departs from provider-owned evidence ([RIG-STATE-003](../specs/state.md#rig-state-003--provider-owned-evidence)). The departure should stay narrow: only self-updating tools, and only for presence.
- **Mac App Store.** `mas` applications update through the App Store. Whether they are self-updating in this sense, or already covered by the App Store binding's own handling, needs a decision. The reverse case also needs one: a Homebrew cask declared while an App Store copy is present, as with Slack and TickTick on sol.
- **Swap steps and App Management.** The steps doctor shows must work under macOS App Management, which on sol blocked both `brew --adopt` and an ordinary delete. Whether to offer `--adopt` at all, and how to word a step that needs sudo without Rig running it, are open.
- **Detecting the source.** An App Store receipt is cheap to test; telling a hand install from a self-updated Homebrew copy may need the Caskroom record or the bundle's version against the cask's. The check should add no network call.
- **Relationship to removal.** RIG-CORE-041 classifies installed-but-unwanted and drifted items. A self-updating tool installed outside Homebrew should not be counted as drift or as unmanaged software there; the two records should agree on that classification.
