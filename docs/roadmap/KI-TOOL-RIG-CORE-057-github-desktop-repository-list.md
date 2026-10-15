---
id: KI-TOOL-RIG-CORE-057
area: CORE
title: GitHub Desktop repository list
purpose: capability
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T23:36:20Z
updated_at: 2026-10-14T23:36:20Z
---

# GitHub Desktop Repository List

## Goal

A Rig step adds every mgit territory checkout to GitHub Desktop, so a new machine's repository list matches its workspaces without a manual reset. The step only adds: it never removes a repository from the list, it waits between opens, and a second run changes nothing.

## Context

On 14 October 2026 Mac Studio `sol`'s GitHub Desktop list held stale paths from an older layout (`~/.homesick`, `~/dev/hnr`, `~/dev/techmedix`, `~/obsidian/vaults`). The gh-desktop run cleared it and added the 56 territory checkouts by hand ([gh-desktop run report](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_THREADS/mac-studio-setup/gh-desktop.report.md)). Its findings shape this record:

- The list lives in GitHub Desktop's IndexedDB database under `~/Library/Application Support/GitHub Desktop`, not in a file, so chezmoi cannot declare it.
- The `github <path>` command-line shim that GitHub Desktop installs (`/opt/homebrew/bin/github` on `sol`) adds and selects a repository, is idempotent for one already listed, and never removes one.
- On the first pass the app silently dropped eight of the 56 opens because an Add Repository dialog was already open; a slower second pass and a third pass added the rest. Opens need a pause between them, and the step must check afterwards which paths were taken.
- `~/workspaces/.mgit.toml` names eight territories (equal-remedy, humans-not-robots, knowledge-islands, legal, personal, sacred-inquiry, techmedix, valle-armonia); each territory's manifest lists its checkouts. That is the source of the list, not the ki registry, which omits the six checkouts without `.ki.toml` and adds the chezmoi source, which belongs to no territory.

The nearest precedent is `ki vscode`, which reconciles VS Code from the ki registry.

## Boundary

- In: a macOS Rig step, run by `rig apply` when GitHub Desktop is selected, that reads `~/workspaces/.mgit.toml` and the eight territory manifests it names, opens each listed checkout present on disk through the `github` shim with a pause between opens, and reports added, already-present and missing paths; idempotence, so a repeat run adds nothing; a dry-run listing; specification text and isolated tests with a stubbed shim and fixture manifests.
- Out: removing or reordering GitHub Desktop entries; editing the app's IndexedDB or Local Storage; GitHub accounts, sign-in or credentials; cloning missing checkouts (mgit owns that); Linux and Windows.

## Dependencies / blocks

Not blocked; blocks nothing. Whether Rig reads mgit manifests directly or asks `mgit` for the list is a planning question; the product boundary keeps a person's paths in configuration, not in `bin/rig`.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of GHD-DECLARE on 2026-10-15 (decision 76 in the mac-studio-bootstrap thread's decisions log): "capture a tools-rig triage record for a Rig step that adds every mgit territory checkout to GitHub Desktop through the github shim (add-only, never removes, pauses between opens)". Planning questions: how Rig confirms an open was taken, given the app reports nothing back (the gh-desktop run read the app's stored data and log); a fixed pause or a check-and-retry loop; whether the step needs GitHub Desktop running, or starts it and leaves it as found; and whether it belongs in the catalogue as a tool action or as a general "register checkouts with an app" hook. Capture only; adoption, priority and plan belong to this repository.
