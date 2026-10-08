---
id: RIG-CORE-040
area: CORE
title: Manage app CLIs
kind: deliver
purpose: capability
component: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 082154bf8173ac65b3dfcde8397b21cb8c6b3799
created_at: 2026-10-08T09:57:41Z
updated_at: 2026-10-08T13:27:06Z
---

# Manage app CLIs

## Goal

Rig manages the command-line companions of selected applications alongside the applications themselves. A missing or stale app CLI is visible and recoverable through Rig, without requiring an application's settings window.

## Context

Kris requested that Rig manage app CLIs, using CodexBar's Install CLI setting as the concrete case. On 8 October 2026, both `/usr/local/bin/codexbar` and `/opt/homebrew/bin/codexbar` linked to the executable `/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI`. The personal CodexBar declaration selects the Homebrew cask and observes the application plus the former command path.

The locally installed `steipete/tap/codexbar` cask already declares its bundled helper as a Homebrew binary named `codexbar`. Its standalone formula offers a separate CLI distribution; installing that formula alongside the app is unnecessary for this case.

Rig currently observes declared artefacts without creating, repairing or repointing them. [Resolved artefact link evidence](../decisions/ADR-RIG-007-resolved-artifact-link-evidence.md), RIG-CONF-019 and RIG-ORCH-025 explicitly preserve that boundary. Delivery must define how an app CLI becomes managed intent without silently changing the meaning of existing observation-only artefacts.

## Boundary

This item owns portable Rig behaviour, its contract, documentation and isolated verification. CodexBar is the first acceptance case; its personal catalogue and any reviewed chezmoi application remain owned by the chezmoi source repository.

The capability is limited to app-provided command-line companions and their installation evidence. It does not add arbitrary lifecycle hooks or a general-purpose command runner. App credentials, CLI usage and package publication are outside scope.

## Current state

The approved companion capability is implemented and verified. Explicit commands stay inside their application entry, existing artefacts remain observation-only, and missing companions recover through native Homebrew cask repair or bounded link creation. CodexBar source adoption is prepared and healthy under an isolated copy of the full workstation configuration; applying that scoped declaration still requires the source repository's reviewed-diff approval.

## Steps

- [x] Add named tool CLI declarations with source, destination and owner, including platform variants and validation.
- [x] Observe executable sources and expected links, report companion failures through status and doctor, and reconcile after the application installer runs.
- [x] Use native Homebrew cask repair for provider-owned companions; implement missing links for explicitly link-owned companions, preserving conflicts and making previews read-only.
- [x] Extend apply, upgrade and show without changing public export privacy or the meaning of existing artefacts.
- [x] Verify isolated absent, healthy, dangling, wrong-target, conflict, permission, ordering, repeat and failure cases; align specifications, guides, help and manual.
- [x] Run the complete local verification gate and prepare the CodexBar chezmoi source change with its scoped diff and proposed live checks.

## Files touched

Authored modules under `src/rig/`, assembled `bin/rig`, focused Bats fixtures, configuration/state/orchestration specifications, user and developer guides, manual, changelog and this work record. The personal CodexBar declaration belongs to the chezmoi source and is a separately verified commit; its live application waits for the reviewed diff.

## Verify

Run the complete gate in the developer guide: repository audit, ShellCheck, Bash syntax, deterministic assembly, benchmark, native-provider smoke, full Bats suite, mandoc lint and diff checks. Read the rendered manual after layout edits. Exercise native repair and link materialisation only in isolated fixtures; live CodexBar checks are read-only until the scoped chezmoi diff is approved.

## Dependencies / blocks

None. No remote operations, release, push or unconditional full-machine apply is authorised.

## Documentation impact

### Decision Records

No new architectural instrument is needed: the existing provider model remains intact, while explicit managed companions are distinct from observation-only artefacts. Retain the ownership rationale in the contract and this record.

### Specifications

Add explicit CLI fields, installer ownership, read-only previews and collision behaviour to configuration, orchestration and state contracts. Preserve public export privacy.

### Guides

Explain companion declaration, native repair, missing-link creation and conflict recovery; align the manual and pre-1.0 changelog.

### Roadmap

Prepare the review packet here. The personal CodexBar source change is a separate verified commit and requires a reviewed scoped chezmoi diff before application.

## Review

### Delivered

Implemented the approved application CLI boundary without creating another catalogue item, adding an imperative hook or changing observation-only artefacts. The immutable baseline remains in frontmatter. CodexBar's companion declaration is prepared separately in the chezmoi source; no live configuration apply, native cask reinstall, push or release was performed during delivery.

### Change Summary

Added `24-app-clis.bash` and its deterministic assembly registration. Named `cli.ID.*` groups include platform variants, installation-owner validation, destination uniqueness, bounded path expansion, executable/link observation, complete preflight and post-install verification. Existing status, doctor, apply, targeted dependency inclusion, show and upgrade flows consume that capability. Native cask repair retains literal provider arguments and adds no force flag; link creation preserves conflicting paths and cleans up links created by a raced directory or parent replacement.

Aligned configuration, orchestration and state specifications, user guidance, developer module ownership, README, changelog, apply help and rendered manual. Prepared CodexBar's source declaration for its actual Homebrew command path, retaining the app artefact and leaving its legacy compatibility link intact.

### Verification

The complete developer gate passed: repository audit with no failures, ShellCheck, Bash syntax, exact assembly, the two-second reference query benchmark, native-provider smoke checks, all 456 Bats tests, mandoc lint and diff checks. Twenty-two new isolated cases cover native and link ownership, missing/healthy/dangling/non-executable helpers, conflicts, relative links, platform variants, private exports, dry-runs, permissions, installer and postcondition failures, upgrade recovery, targeted prerequisites and filesystem races. The rendered manual was inspected.

The chezmoi repository's complete audit, Node test suite and Markdown gate passed with its pre-existing audit warnings. The initial live doctor and proposed configuration doctor both reported zero findings. The proposed CodexBar show and targeted tools-only preview correctly expose the companion and conditional native repair. Long-running read-only probes that overlapped payload assembly were repeated successfully against an immutable copy; their first interrupted reads are not verification evidence.

### Outstanding concerns

The CodexBar source declaration still awaits explicit permission to apply the reviewed one-file chezmoi diff and run the post-apply read-only health checks. Native cask repair is proven through isolated installer fixtures; a healthy workstation did not require a real reinstall.

Existing governance warnings remain outside this CLI delivery: the repositories have no committed pre-commit gate, and chezmoi's roadmap audit cannot resolve the `ki-arcadia-principal` territory registry handle. They do not produce live Rig health findings. Unknown installed packages and applications remain informational inventory and were not adopted or removed.

### Post-change review

The goal is met for explicitly declared bundled command links. Selection, native ownership and private projection remain coherent; no independent executable database or cleanup policy was introduced. Repeated healthy companion reconciliation adds no CLI repair. A mismatched or occupied path remains a deliberate human conflict-resolution boundary. Bash 3.2 compatibility and the existing runtime dependency boundary passed the required checks. Acceptance can review this delivery while the personal source application retains its separate approval gate.

### Mini recap

Application companions now have explicit intent and verified reconciliation, while ordinary generated artefacts stay read-only. CodexBar is the first prepared adoption and its current command is healthy. Finish its scoped source apply only after approval; retain the behaviour in the accepted contract and user guide rather than duplicating it in Calendar notes.

## Discussion

### Native installer ownership

Prefer reconciliation through the selected application's native installer where it already owns the CLI. For CodexBar, Homebrew's cask binary declaration supplies an existing ownership route. Investigate whether missing companion evidence can cause an appropriate bounded provider repair when the cask itself is present.

A dedicated declarative link adapter may be needed for applications whose installers do not materialise their companions. Decide that extension from actual provider evidence rather than creating a competing link owner for Homebrew-managed applications. Preserve existing observation-only artefacts.

### Companion evidence and repair

Distinguish a healthy expected command from an absent command, a dangling link, a stale or incorrect target, an unavailable app helper and an occupied destination. Determine whether invocation through PATH is part of the contract as well as filesystem health. Expose companion failure in status and doctor even when the application package is installed.

Dry-run must describe the proposed repair without writes. Real reconciliation must establish the application before its companion, preserve unrelated occupied paths, report permission failures honestly and remain idempotent. Provider upgrades must leave companion evidence healthy; deselection must not remove commands without an explicit cleanup contract.

### CodexBar adoption and verification

The first end-to-end case uses the existing app-bundled helper, without installing a duplicate standalone formula. Decide which command destination belongs to the provider; the screenshot's two installed destinations are evidence, not a portable requirement to create both on every machine.

Verify missing, healthy, dangling, wrong-target and conflicting commands in isolated fixtures, including an already installed application, repeated application and dry-run. Prepare the personal CodexBar declaration only after the portable contract is verified, then present its chezmoi diff and proposed verification before any apply.
