---
id: RIG-CORE-017
title: Declare user skills
area: CORE
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-21T18:02:02Z
updated_at: 2026-09-21T23:43:26Z
---

## Goal

Rig should describe which user-level agent skills belong in a selected setup, why each capability was chosen, where its trusted source lives, which agent runtimes receive it, and whether the native skill manager has materialised the declared intent.

## Context

`npx skills list -g` currently discovers 16 global skills. `caveman` is the only entry with remote source provenance in the Skills CLI's XDG-state lock. Seven KI process skills are local symlinks into `ki-agentic-harness`, while eight Cloudflare skills are physical copies under the Claude and Codex skill roots and are reported by the Skills CLI as local. Rig declares none of this, and chezmoi does not own those global collections.

The result is observable but not reproducible as one personal setup. The native inventory cannot explain why a skill belongs, local entries do not preserve enough source provenance for restoration, and multiple authorities currently materialise different subsets: the Skills CLI, KI bootstrap, agent runtimes, plugins, and occasional runtime-specific local files.

## Boundary

Rig must not copy skill content into its own configuration, become a skill registry, or replace native skill-manager locks and source resolution. Repository-local skills remain repository concerns. Runtime-bundled and plugin-provided skills remain owned by their runtime or plugin manager rather than becoming duplicated global installations.

Skill installation is a trust transition because instruction content changes agent behaviour. Rig must not infer trust from a directory found on disk or silently adopt an unproven local source.

## Current state

The global inventory is split among Skills CLI state, KI symlinks, physical runtime copies, plugins, and runtime-specific local files. Rig has no skill declaration, authority classification, profile selection, query, observation, or lifecycle model. Only one current Skills CLI entry retains remote source provenance in its native lock.

## Steps

- [ ] Decide whether skills are catalogue capabilities or managed resources, their profile and publication semantics, and the authority classes Rig recognises.
- [ ] Define explicit source trust, agent-runtime projection, provenance, update scope, and profile-deselection behaviour.
- [ ] Record the product, security, configuration, orchestration, state, query, and publication contracts.
- [ ] Implement provider-native observation and bounded materialisation without evaluating skill content or copying provider state into Rig.
- [ ] Cover remote, KI-projected, runtime-owned, plugin-owned, local, missing, drifted, and unmanaged cases with isolated tests.
- [ ] Align every public CLI and documentation surface and define the later personal-skill migration boundary.

## Files touched

Expected scope includes `bin/rig`, `tests/`, `docs/decisions/`, `docs/specs/`, `docs/guides/`, `man/rig.1`, `README.md`, and `CHANGELOG.md`. Native locks, harness sources, plugin caches, and personal skill content remain outside this repository.

## Verify

Run the complete repository gate; use isolated agent roots and provider fakes to prove source and projection comparison, literal invocation, explicit trust, non-removal on deselection, and public-data allow-listing. No test may read or change the real user skill roots.

## Dependencies / blocks

No existing delivery record is a build prerequisite. Planning must resolve the catalogue-versus-resource and native-authority decisions before this item can become Ready. Personal source reconciliation follows separately.

## Documentation impact

### Decision Records

Amend the product and trust-boundary decisions to place user-level agent capabilities and their executable-instruction risk deliberately.

### Specifications

Add configuration, query, state, orchestration, portability, lifecycle, and publication requirements with provider-specific evidence.

### Guides

Explain global versus repository-local versus runtime-owned skills, source trust, profile selection, updates, and deliberate public disclosure.

### Roadmap

The personal-skill source cleanup remains part of the separate personal-rig migration outcome.

## Discussion

### Locked declaration model

User-level skills are first-class `[skill.ID]` managed capabilities, separate from executable tools but selected through the same item-centric profile rules. A declaration records name, purpose, rationale, native authority, immutable or reviewable source identity, user scope, intended agent runtimes, supported platforms, and optional public metadata. Rig never stores skill content.

The first authority classes are Skills CLI for explicitly sourced global skills, KI bootstrap for KI projections, runtime or plugin ownership for observation-only bundled skills, and an explicit trusted local source for user-managed projections. Apply may materialise a missing declaration through its fixed native authority; update remains an explicit lifecycle action; deselection never removes a skill. Unqualified changing `npx` execution is forbidden. Publication is opt-in and exposes only reviewed name, purpose, rationale, and source metadata—not paths, runtime mappings, locks, or observed state.

The exploratory observations below are retained as rationale; the declaration model above resolves their open choices for implementation.

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
