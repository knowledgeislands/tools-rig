---
id: RIG-CORE-017
title: Declare user skills
area: CORE
theme: orchestration
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T18:02:02Z
updated_at: 2026-09-21T18:02:02Z
---

## Goal

Rig should describe which user-level agent skills belong in a selected setup, why each capability was chosen, where its trusted source lives, which agent runtimes receive it, and whether the native skill manager has materialised the declared intent.

## Context

`npx skills list -g` currently discovers 16 global skills. `caveman` is the only entry with remote source provenance in the Skills CLI's XDG-state lock. Seven KI process skills are local symlinks into `ki-agentic-harness`, while eight Cloudflare skills are physical copies under the Claude and Codex skill roots and are reported by the Skills CLI as local. Rig declares none of this, and chezmoi does not own those global collections.

The result is observable but not reproducible as one personal setup. The native inventory cannot explain why a skill belongs, local entries do not preserve enough source provenance for restoration, and multiple authorities currently materialise different subsets: the Skills CLI, KI bootstrap, agent runtimes, plugins, and occasional runtime-specific local files.

## Boundary

Rig must not copy skill content into its own configuration, become a skill registry, or replace native skill-manager locks and source resolution. Repository-local skills remain repository concerns. Runtime-bundled and plugin-provided skills remain owned by their runtime or plugin manager rather than becoming duplicated global installations.

Skill installation is a trust transition because instruction content changes agent behaviour. Rig must not infer trust from a directory found on disk or silently adopt an unproven local source.

## Discussion

### Declarative capability

A first version should consider one `[skill.ID]` declaration per user-facing capability. It would carry a name, purpose, personal rationale, trusted provider and source identity, user scope, intended agent runtimes, supported platforms, and any explicit dependency such as the selected Node/npm toolchain.

Profiles should select skills independently of tools and machine resources. `rig show` should summarise the resolved set, qualified explanation should retain source and intent, and `rig status` and `rig doctor` should compare declarations with provider-native inventory without evaluating skill content.

### Native authorities

The Agent Skills CLI is a candidate built-in provider for remotely sourced global skills. Its native XDG lock remains provider-owned state; Rig would use fixed, literal CLI operations rather than constructing arbitrary installation commands. A pinned or otherwise deliberate CLI version is needed because invoking unqualified `npx skills` can resolve changing code.

KI-projected skills have a different authority. Their source is the selected `ki-agentic-harness`, and `ki bootstrap` owns compatible user projections. Rig should observe or coordinate that native authority rather than reinstalling the same skill through a second provider. Runtime-specific local skills need an explicit trusted local-source boundary if they are to become managed.

### Lifecycle and drift

Missing declared skills, wrong runtime projections, changed source identity, and absent native provenance should be distinguishable. Applying a profile may materialise missing skills through their declared native authority, but profile deselection should not silently remove agent capabilities. Updates should remain explicit and disclose whether the native manager operates on one skill or the complete global collection.

Unmanaged global skills can be reported locally as informational inventory. Runtime-bundled, plugin-cached, and repository-local skills should not be misclassified as missing user-level declarations.

### Publication boundary

Unlike ports and live machine observations, a skill's public catalogue meaning may be useful on a personal Rig website. The product decision should distinguish optional public metadata such as name, purpose, rationale, and reviewed source from private installation paths, runtime mappings, native lock data, and observed state. Nothing should be disclosed merely because a skill is installed globally.

### Migration questions

The current Cloudflare copies should be reconciled against the canonical `cloudflare/skills` source before adoption. KI symlinks should retain `ki bootstrap` ownership. The runtime-specific `chezmoi-audits` skill and Codex system or plugin skills need classification so the migration does not collapse user-managed, repository-managed, and runtime-managed capabilities into one provider.
