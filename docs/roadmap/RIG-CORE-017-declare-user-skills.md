---
id: RIG-CORE-017
title: Declare user skills
area: CORE
theme: orchestration
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 41e7ecc0dfc017dcd172fa10e885d26c15263d4d
created_at: 2026-09-21T18:02:02Z
updated_at: 2026-09-22T05:08:23Z
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

- [x] Decide whether skills are catalogue capabilities or managed resources, their profile and publication semantics, and the authority classes Rig recognises.
- [x] Define explicit source trust, agent-runtime projection, provenance, update scope, and profile-deselection behaviour.
- [x] Record the product, security, configuration, orchestration, state, query, and publication contracts.
- [x] Implement provider-native observation and bounded materialisation without evaluating skill content or copying provider state into Rig.
- [x] Cover remote, KI-projected, runtime-owned, plugin-owned, local, missing, drifted, and unmanaged cases with isolated tests.
- [x] Align every public CLI and documentation surface and define the later personal-skill migration boundary.

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

## Review

### Delivered

Rig now models user-level agent skills as first-class, profile-selected capabilities with explicit native authority, source, trust, runtime projections, tool dependencies, platform compatibility, and optional reviewed public provenance. Query, state, doctor, unmanaged inventory, apply, bootstrap, update, diagnostics, and publication surfaces understand the model without making Rig a skill registry.

### Summary of changes

- Added the bounded `[skill.ID]` schema and item-centric profile selection for `skills-cli`, `ki`, `local`, `runtime`, and `plugin` authorities.
- Added Skills CLI observation, materialisation, explicit update, and unmanaged inventory using a deliberately installed executable and bounded JSON parsing; KI, runtime, and plugin authorities remain observation-only.
- Added trusted local-source projection with canonical non-symlink source checks, contained runtime roots, last-moment collision checks, and missing-leaf-only symlink creation.
- Extended lifecycle ordering to tools, then skills, then resources; deselection, maintain, and clean never remove or update skills.
- Advanced the public projection to `rig-publication` version 2 with a deterministic skills array and an explicit reviewed allow-list while retaining the previous private-data exclusions.
- Aligned help, completions, manual, README, changelog, user guides, Decision Records, Specifications, and isolated tests. No personal skill roots, native locks, website code, or migration data changed.

### Verification

- `bash -n bin/rig` — passed.
- `shellcheck bin/rig install.sh` — passed.
- `bats tests/` — passed, 214 tests including 9 isolated skill-authority and publication cases.
- `mandoc -T lint man/rig.1` — passed.
- `ki repo audit --skill ki-authoring --repo .`, `ki-decision-records`, `ki-specs`, and `ki-guides` — passed.
- `ki repo audit --repo .` — passed after the final review packet.
- `git diff --check` — passed.

### Outstanding concerns

KI skill inventory is deliberately reported unavailable until KI exposes a stable machine-readable inventory; Rig never parses its human output or invokes KI for skill lifecycle work. Personal inventory reconciliation and declaration remain a separate migration outcome. Publication consumers must adopt format version 2 before using the new skills array.

### Post-change review

The implementation stays inside the locked scope and preserves Bash 3.2, the XDG contract, native provider authority, explicit trust, and non-destructive lifecycle behaviour. The delivery advances one intentional public data contract from version 1 to version 2; it makes no website change and preserves the allow-listed category and tool semantics. No divergence from the approved plan was required.

### Mini recap

User-level skills are now declarative, explainable, observable, selectively materialisable, and privately safe. The remaining work is personal configuration reconciliation after this delivery is accepted.

## Done

Accepted 2026-09-22.

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
