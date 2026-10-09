---
id: RIG-CORE-042
area: CORE
title: Profile-filtered Dock items
project: mac-studio-bootstrap
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-09T15:03:37Z
updated_at: 2026-10-09T21:18:32Z
---

# RIG-CORE-042: Profile-Filtered Dock Items

## Goal

One Dock layout declares a single ordered list of items for every machine, and each resolved profile shows only the items it selects, in the same relative order. A machine without an app gets no gap and no preflight failure; a machine with it gets it in its usual place.

## Context

Kris asked for this on 2026-10-09 while splitting his Rig into `core`, `laptop` and `studio` profiles (mac-studio-bootstrap thread, Decision 13, answers 6 and 7): "identical on both except where an app is not on both, but even then the place where it would be is consistent - so one order but items might be machine specific". The consumer is [DOTFILES-UE-075](/Users/krisbrown/.local/share/chezmoi/docs/roadmap/DOTFILES-UE-075-sol-tailscale-daemon-exception.md) in the chezmoi source, which owns the profile split and the personal Dock declaration.

What Rig does today:

- **One Dock per profile.** [RIG-ORCH-027](../specs/orchestration.md) rejects more than one selected Dock layout for the same provider, so a machine profile cannot inherit a shared Dock and add its own items.
- **Items are plain path tables.** [RIG-CONF-018](../specs/configuration.md) gives `[dock-item.ID]` only `kind`, `path` and folder attributes. Items carry no membership, so every listed item is in every profile that selects the layout.
- **Preflight fails on a missing path.** `rig_macos_resource_preflight` fails the whole Dock step when any declared item path is absent, so a shared list naming a studio-only app breaks the laptop's Dock apply, and the reverse.

The workaround without this record is a chezmoi template that renders one Dock layout per machine profile from a master list. It works, but it duplicates membership (an app's tool already says which profiles want it), turns the Dock fragment into a template the catalogue tests must render, and every new machine profile needs a template change.

## Boundary

- **In:** an optional link from a Dock item to the membership that decides whether it shows; filtering a layout's items by the resolved profile while keeping declared order; `rig show`, `rig status`, `rig doctor`, `rig apply --dry-run` and `rig apply` agreeing on the filtered list; validation and specification changes; tests.
- **Out:** choosing the personal Dock order or memberships (DOTFILES-UE-075); filtering by what is installed rather than what is declared, which would make the Dock depend on observed state; removing apps.

## Discussion

- **Proposed shape.** `[dock-item.ID]` MAY declare `tool = "ID"`. The resolved layout includes the item only when the resolved profile selects that tool for the active platform; an item without `tool` (system apps, folders) is always included. This reuses the tool's existing membership, so Kris labels an app once. Validation rejects an unknown tool.
- **Alternative.** Item-owned `profiles` on `[dock-item.ID]`, following [RIG-CONF-020](../specs/configuration.md). More general (it covers items with no tool), but labels the same fact twice and needs a different rule for an omitted array, since "omitted means the default profile" would be wrong for Dock items. Decide whether to offer both, `tool` first.
- **Requires.** Decide whether a linked item's tool should join the layout's `requires` automatically, so apply installs the app before the Dock step, or stay ordering-only.
- **Reporting.** `rig show dock:ID --profile NAME` and the dry run should list the omitted items and why, so a missing icon is explainable without reading the catalogue.
- **Status equality.** Observation compares the live Dock with the filtered list, so the laptop's current 38-item Dock must stay `present` when nothing it selects changes.
- **Specifications touched.** RIG-CONF-018 (item fields), RIG-ORCH-027 (unchanged rule, but note filtering happens before the one-layout check), and RIG-STATE-021 (Dock observation and dry-run disclosure).
