---
id: RIG-CORE-039
area: CORE
title: Observe retired app traces
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-01T04:22:44Z
updated_at: 2026-10-02T01:37:43Z
---

# RIG-CORE-039: Observe retired app traces

## Goal

Rig can report read-only evidence of data and usage traces left by a retired macOS application, so a person can review its retirement without inferring that retained data should be deleted.

## Context

The personal dotfiles roadmap identified a gap while reviewing Actual and Unsloth Studio retirements: Rig reconciles application bundles but does not report retained support files, caches, preferences, or partial last-used evidence. That request was submitted as work trade `TRD-62dc768f` from `krisb/dotfiles` on 2026-09-30. This receiver-owned intake record preserves the requested outcome and safety constraints without requiring an ongoing route to the personal repository.

The user approved delivery on 2026-10-02: explicit retired identities and data locations, opt-in read-only status reporting, uncertainty and ownership distinctions, no cleanup or reinstallation, and complete tests and command documentation. Existing tool artifacts represent expected installed state, so they cannot honestly represent retained retirement evidence without creating false health findings.

## Boundary

Deliver observation only in this repository. Do not delete data, infer ownership from name substrings, treat weak last-used signals as proof of disuse, or take over dotfiles' personal application declarations and retirement decisions. Package-managed stores remain visibly distinct from candidate user-data remnants. No top-level command, provider protocol, runtime dependency, live mutation, package operation, cross-repository edit or release is included. Retained data is informational and never changes doctor health or apply/upgrade plans.

## Current state

The built-in macOS inventory reads application bundles, but there is no retired identity or data-evidence model. Add a separate declaration rather than overloading installation metadata or artifacts. Existing status text/JSON is unchanged unless the new flag is selected. The two terminal-display records are accepted separately; the deferred repair investigation remains outside this work.

## Steps

- [ ] Add validated `[retired-application.ID]` declarations with required `name`, exact `bundle-id` and non-empty `application-paths`; optional `data-paths` and `package-paths` remain literal absolute or documented home-relative paths, with no globbing or shell evaluation. Reject duplicate bundle identities, unsafe paths and installation/profile fields.
- [ ] Add `status --retired` as an additive, configuration-wide informational report, independent of profile selection. Inspect only declared application locations and exact bundle-ID conventional data candidates plus explicitly declared data/package paths. Match bundles through `CFBundleIdentifier`, distinguish missing, inaccessible, mismatched and symbolic-link evidence, and never follow links to inspect arbitrary data.
- [ ] Report optional native last-used metadata only for an exact matched bundle, with source and partial-evidence caveat; absent metadata remains unavailable, never never-used. Keep declared package ownership and inferred candidate attribution explicitly weaker than verified ownership. On non-macOS platforms report unsupported observation without native probes.
- [ ] Cover schema, text/JSON, deterministic ordering, inaccessible and symlink evidence, missing native commands, literal paths, last-used uncertainty, platform isolation, no-mutation and unchanged health/installation/export contracts in isolated tests.
- [ ] Align help, completion output, manual, command/configuration guides, specifications and changelog; assemble the single executable, independently review the integrated result and run the complete local gate.

## Files touched

Authored configuration, observation and command modules; one bounded retired-application observation module; generated `bin/rig`; isolated retired-application tests and any strictly affected contract assertions; help/completion metadata; manual; command/configuration guides; configuration/state/orchestration specifications; changelog; this record. No personal catalogue or package-manager data is edited.

## Verify

Run the complete AGENTS.md gate with Bats stdin from `/dev/null`. Every new test calls `rig_test_isolate` first and uses temporary paths and native-command fakes. Prove exact bundle matching, unavailable versus absent evidence, no links followed, no deletion/install/provider mutation, unchanged existing stdout without the flag, unchanged exit status and doctor findings with retained data, no exposure through export, and Bash 3.2 compatibility. Use bounded native metadata fixtures, never scan or mutate the workstation to exercise a failure.

## Dependencies / blocks

No missing implementation dependency. The user has approved selection into Now and the bounded delivery plan; this replaces the design-only intake boundary. Release follows acceptance and its separate verification/publication gates. No further personal application decision is required because no personal retired declaration is added here.

## Delegation

The runtime worker owns configuration, observation and command integration plus the new module, but not generated `bin/rig`, Git or documentation. A test worker owns the new isolated suite and strictly necessary test-helper containment additions, coordinating public JSON expectations before assertions. A read-only reviewer checks the observation/privacy boundary and integrated changes. The coordinator owns roadmap, documentation, assembly, Git and the full gate. Shared primary checkout, disjoint files; workers use a private assembled payload for focused tests and must not alter shared `bin/rig` during tests. Stop for deletion, automatic ownership inference, a new runtime dependency, a new top-level verb or a public contract outside this scope. Return exact touched paths, checks, unresolved findings and test limitations; no worker may accept, prune, push or release.

## Documentation impact

### Decision Records

Existing inert configuration and native observation boundaries remain authoritative. Explain the separation from active tools in the owning specifications and guide; no new mutation authority or provider protocol decision is introduced.

### Specifications

Specify the additive declaration and opt-in report, private-only projection, exact identity/uncertainty rules, and exclusion from health and mutation.

### Guides

Show a synthetic declaration and `status --retired`, including package-path provenance, partial usage metadata and safe manual review. Align command help, generated completion and manual syntax.

### Roadmap

End this delivery awaiting human review. Mark only the explicitly accepted display records done; leave CORE-030 deferred and release publication separate.

## Discussion

### Observation contract

Exact bundle identity is evidence only for an existing matched application. A conventional data path derived from that identifier is a candidate association, not proof of ownership. Explicit data and package paths preserve the person's authored association without inventing package-manager verification. No content or recursive directory listing is read. Existing bundles with missing or malformed metadata remain uncertain rather than becoming healthy retirement evidence.

### Retained evidence versus desired installation

A retired declaration is deliberately outside tools, profile membership and provider bindings. Presence of retained data is not a defect; it cannot make doctor fail or cause apply to reinstall or remove an application. The status flag opts into potentially private path evidence; normal status and public export do not disclose it. Personal follow-on declarations remain with the dotfiles owner after this interface is accepted.
