---
id: RIG-CORE-040
area: CORE
title: Manage app CLIs
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T09:57:41Z
updated_at: 2026-10-08T09:57:41Z
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
