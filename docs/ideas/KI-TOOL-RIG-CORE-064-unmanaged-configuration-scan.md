---
id: KI-TOOL-RIG-CORE-064
area: CORE
title: Rig manages app configuration
purpose: capability
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T17:11:08Z
updated_at: 2026-10-22T01:50:14Z
---

> **Idea, not on the roadmap.** Let Rig manage an application's configuration as well as its installation, dividing cleanly with chezmoi; folded into the application configuration touch points idea. Moved out of `docs/roadmap/` on 27 October 2026 under the roadmap sweep, with its record kept in full here so that it can return when Kris brings it back; it was `KI-TOOL-RIG-CORE-064`.

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

## Dependencies / blocks

None. Blocks nothing.

## Discussion

Origin: the ways-of-working records-fold run of 18 October 2026, under CONFIG-UNDER-CONTROL. Planning questions: how Rig tells configuration worth managing from caches and machine state; whether Rig manages application configuration by rendering through chezmoi or directly, given chezmoi already owns the dotfiles source; and how secrets inside application configuration are excluded. Capture only; adoption, priority and plan belong to this repository.

### Narrowed, 20 October 2026

Kris approved SWEEP-CONVERT a) on 20 October 2026, recorded in Knowledge Islands Principal `+/_WORK/ki.ways-of-working/decisions.md`: "I agree with sweep merge ... should become message records". The recurring scan is a recurring obligation that chezmoi owns, so it went as an Activity line to `ki.chezmoi`'s `messages.md` in Knowledge Islands Principal, and this record keeps only Rig's part, managing an application's configuration. The title changed from "Unmanaged configuration scan"; the file name is kept so existing links hold.
