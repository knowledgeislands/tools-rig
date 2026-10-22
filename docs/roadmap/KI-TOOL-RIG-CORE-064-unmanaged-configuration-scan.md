---
id: KI-TOOL-RIG-CORE-064
area: CORE
title: Rig manages app configuration
purpose: capability
theme: rig
status: cancelled
resolution: superseded
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T17:11:08Z
updated_at: 2026-10-22T01:29:08Z
---

# Rig Manages App Configuration

## Goal

Rig can manage an application's configuration as well as its installation, declaring both in one place and dividing cleanly with chezmoi's source of truth.

## Context

Kris, 18 October 2026, answering the 17:40 BST recap (CONFIG-UNDER-CONTROL, ways-of-working decisions log, 17:59 BST owner answers), on mgit's learnt output templates in `~/.config/mgit/`:

> Of course, then there's should be tracked in my in my case the tracked in my [chezmoi] folder. So I'm just looking to see what we might have for that. Yeah, currently there isn't any thing in [chezmoi] for .config mgit. I think we do need to have a fairly regular thing where we look to see if we should be bringing more configuration under control. I think I've already mentioned that elsewhere as well as a general thing to do with rig is it'd be nice if it could also manage config for apps.

No existing tools-rig record owns this concern; the earlier mention Kris recalls was not found. On 18 October the chezmoi source's `dot_config` covered `husky`, `ki`, `mise`, `paperclip`, `chezmoi-op`, `rig`, `techne`, `vscode` and `zed`; `~/.config/mgit/` did not exist yet and will be created by `mgit learn`.

## Boundary

- In: a design for Rig declaring and managing an application's configuration alongside its installation, and how that divides with chezmoi's source of truth.
- Out: the recurring scan of configuration not yet under chezmoi, which went to ki.chezmoi as an Activity on 20 October; writing to the chezmoi source or running `chezmoi apply`, which stay with ki.chezmoi and Kris's `chezmoi diff` review; bringing `~/.config/mgit/` itself under chezmoi, which the mgit learn work routes through ki.chezmoi; reading or capturing secrets; any live apply.

## Cancelled

Cancelled on 22 October 2026 under the explicitly named overnight burn-down instruction and Kris's SWEEP-CONVERT decision of 20 October 2026: sweeps become messages, and the recurring unmanaged-configuration scan belongs to the chezmoi repository, not a Rig roadmap record. The successor is a message to the chezmoi work to maintain that recurring scan; no replacement roadmap record is created.

The record had already been narrowed on 20 October to Rig's possible role in managing application configuration alongside installation. That separate design question is preserved in the coordinator's message handoff rather than silently treated as delivered or as part of the recurring scan. No configuration, scheduler, source store or live machine was changed. This cancelled record is retained for independent review and later coordinator-owned pruning.

## Discussion

Origin: the ways-of-working records-fold run of 18 October 2026, under CONFIG-UNDER-CONTROL. Planning questions: how Rig tells configuration worth managing from caches and machine state; whether Rig manages application configuration by rendering through chezmoi or directly, given chezmoi already owns the dotfiles source; and how secrets inside application configuration are excluded. Capture only; adoption, priority and plan belong to this repository.

### Narrowed, 20 October 2026

Kris approved SWEEP-CONVERT a) on 20 October 2026, recorded in Knowledge Islands Principal `+/_WORK/ki.ways-of-working/decisions.md`: "I agree with sweep merge ... should become message records". The recurring scan is a recurring obligation that chezmoi owns, so it went as an Activity line to `ki.chezmoi`'s `messages.md` in Knowledge Islands Principal, and this record keeps only Rig's part, managing an application's configuration. The title changed from "Unmanaged configuration scan"; the file name is kept so existing links hold.
