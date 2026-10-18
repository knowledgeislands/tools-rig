---
id: KI-TOOL-RIG-CORE-064
area: CORE
title: Unmanaged configuration scan
purpose: capability
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T17:11:08Z
updated_at: 2026-10-18T17:11:08Z
---

# Unmanaged Configuration Scan

## Goal

A recurring scan reports application and tool configuration on each Mac that is not yet under chezmoi, starting with `~/.config/mgit/`, so Kris can decide what to bring under control; and Rig can manage an application's configuration as well as its installation.

## Context

Kris, 18 October 2026, answering the 17:40 BST recap (CONFIG-UNDER-CONTROL, ways-of-working decisions log, 17:59 BST owner answers), on mgit's learnt output templates in `~/.config/mgit/`:

> Of course, then there's should be tracked in my in my case the tracked in my [chezmoi] folder. So I'm just looking to see what we might have for that. Yeah, currently there isn't any thing in [chezmoi] for .config mgit. I think we do need to have a fairly regular thing where we look to see if we should be bringing more configuration under control. I think I've already mentioned that elsewhere as well as a general thing to do with rig is it'd be nice if it could also manage config for apps.

No existing tools-rig record or ki-principal Activity owns either concern; the earlier mention Kris recalls was not found. On 18 October the chezmoi source's `dot_config` covered `husky`, `ki`, `mise`, `paperclip`, `chezmoi-op`, `rig`, `techne`, `vscode` and `zed`; `~/.config/mgit/` did not exist yet and will be created by `mgit learn`.

## Boundary

- In: a read-only scan of `~/.config/` and other declared configuration locations against the chezmoi source, reporting unmanaged entries with a suggested disposition; a cadence for it, for example through `ki-work-recurring` or Rig doctor; a design for Rig declaring and managing an application's configuration alongside its installation, and how that divides with chezmoi's source of truth.
- Out: writing to the chezmoi source or running `chezmoi apply`, which stay with ki.chezmoi and Kris's `chezmoi diff` review; bringing `~/.config/mgit/` itself under chezmoi, which the mgit learn work routes through ki.chezmoi; reading or capturing secrets; any live apply.

## Dependencies / blocks

None. Blocks nothing.

## Discussion

Origin: the ways-of-working records-fold run of 18 October 2026, under CONFIG-UNDER-CONTROL. Planning questions: whether the recurring scan belongs in Rig, in a ki-principal Activity or in the chezmoi source's own checks, with this record keeping only Rig's part; how the scan tells configuration worth managing from caches and machine state; whether Rig manages application configuration by rendering through chezmoi or directly, given chezmoi already owns the dotfiles source; and how secrets inside application configuration are excluded. Capture only; adoption, priority and plan belong to this repository.
