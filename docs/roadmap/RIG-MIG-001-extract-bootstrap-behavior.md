---
id: RIG-MIG-001
area: MIG
title: Extract bootstrap behavior
theme: migration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 1418f7c4ff417151a307604c4762c2196bc8ee8c
created_at: 2026-09-15T09:54:44Z
updated_at: 2026-09-16T23:37:31Z
---

# RIG-MIG-001: Extract bootstrap behavior

## Goal

Rig provides a small top-level bootstrap command that preserves the useful outcomes of the current dotfiles dispatcher through the private profile and provider model.

## Context

The existing implementation dispatches Homebrew, permissions, Node, Ruby, Zsh, Bun, SSH, uv, and completion components in a fixed order. It supports install, update, cleanup, and backup actions. Portable selection, ordering, failure, and reporting behaviour belongs in Rig; selected programs, native manifests, action policy, and scripts belong to private workstation configuration.

Feature parity concerns outcomes and safety rather than copying every private subsystem or nested command into the permanent public CLI. Portable machine checks move to `doctor` and `status`; macOS audit and launchd service operations remain optional private executable integrations.

## Boundary

This item migrates bootstrap behaviour, compatibility, and cutover only. It does not implement the catalogue resolver or provider engine, expose host-specific machine and service internals as permanent top-level commands, or design personal declarations.

## Current state

The standalone CLI can resolve the private 85-tool default profile but cannot materialise it: it has no provider execution path, `apply`, or `bootstrap` command. The live chezmoi dispatcher still owns four actions (`install`, `update`, `cleanup`, and `backup`) and ordered selection across nine components: Homebrew, permissions, Node, Ruby, Zsh, Bun, SSH, uv, and completions.

Bootstrap is deliberately one entry into the same resolved provider plan as `rig apply`, not a second orchestration engine. Legacy update, cleanup, and backup behaviour maps to explicit provider operations where a provider declares those capabilities.

## Steps

- [x] Define `rig bootstrap [--profile NAME] [--dry-run]` as first materialisation through the same resolver, dependency order, capability checks, dispatch, and reporting used by `rig apply`.
- [x] Map legacy `install` to bootstrap or apply semantics and map supported `update`, `cleanup`, and `backup` outcomes to declared provider operations without exposing the nine legacy component scripts as public commands.
- [x] Extend the private profile and provider declarations only after RIG-MIG-004 supplies provider bindings and the public provider execution contract is usable.
- [x] Add Bats parity coverage for default and selected provider ordering, stale-manifest protection, unsupported capability rejection, provider failure propagation and dependent skipping, and dry-run non-mutation.
- [x] Compare the standalone call plan and outcomes with `bin/rig.d/executable_bootstrap` and `bin/env/executable_*` before changing any legacy source.
- [x] Align top-level help, command help, Bash and Zsh completion, README inventory, `rig(1)`, and the curated v1 changelog.

## Files touched

Expected public scope is `bin/rig`, `tests/rig.bats`, orchestration and state specifications, `README.md`, `man/rig.1`, and `CHANGELOG.md`. Expected private scope is the chezmoi Rig template and focused compatibility tests; legacy `bin/rig.d/executable_bootstrap` and `bin/env/executable_*` remain intact until RIG-MIG-005.

## Verify

Run the complete tools-rig shell, Bats, manual, and repository-audit gates. In an isolated configuration, assert bootstrap and apply produce the same ordered plan, `--dry-run` records no provider mutation, a failed prerequisite skips dependants but not independent providers, unsupported operations fail before invocation, and the managed Brewfile stale-state guard remains effective. Run the dotfiles `tests/rig.test.mjs` and `tests/env-bootstrap.test.mjs` suites against the unchanged legacy path for the side-by-side parity gate.

## Dependencies / blocks

RIG-MIG-004 must provide the private provider-bound profile before bootstrap can execute a meaningful plan. This item blocks RIG-MIG-005 because retirement cannot precede bootstrap parity, and blocks RIG-DIST-001 because the first release promises a usable bootstrap surface. The Homebrew formula itself is a cross-repository release change and remains outside this item.

## Delegation

One worker may implement the command and Bats fixtures while another audits help, completion, manual, README, and changelog alignment. The coordinator owns the private/public boundary, legacy parity comparison, cross-repository checks, and final full-gate review.

## Documentation impact

### Decision Records

No new decision record is expected; implementation follows the accepted catalogue-led manager-of-managers and executable-provider boundaries. Record a new decision only if bootstrap diverges from apply semantics.

### Specifications

Extend orchestration and state requirements to make bootstrap an alias for first materialisation through the apply plan and to define its dry-run and failure behaviour.

### Guides

Update installation and migration guidance with bootstrap usage and provider-operation replacements for update, cleanup, and backup.

### Roadmap

Preserve the dependency links to private declaration migration, legacy retirement, and first release; newly discovered provider-specific parity gaps belong in their existing provider or migration owner.

## Review

### Delivered

Public commit `d1d275a` delivers the standalone bootstrap entry point from immutable baseline `1418f7c4ff417151a307604c4762c2196bc8ee8c`; dotfiles commit `e1d8b9b` delivers the private bootstrap profile, provider translation, and declared maintenance operations. The legacy bootstrap and environment helpers remain intact for the later retirement gate.

### Summary of changes

`rig bootstrap [--profile NAME] [--dry-run]` now selects an explicit profile, the configured bootstrap profile, or the default fallback before delegating to the exact `rig apply` plan. The private projection names its bootstrap profile, preserves the nine-unit install order, keeps the stale-Brewfile guard first, avoids duplicate per-tool Homebrew application and premature `mas` preflight, and exposes update, cleanup, and backup through bounded declared operations. Help, completions, README, manual, changelog, Specifications, guides, and parity tests are aligned.

### Verification

Public commit `d1d275a` passed the complete shell gate with all 96 Bats tests, ShellCheck, Bash syntax, `mandoc -T lint`, repository audit, and diff checking. Dotfiles commit `e1d8b9b` passed all 29 Node tests, including side-by-side bootstrap order, stale-manifest, failure, dry-run, and maintenance-operation parity. `chezmoi diff` was reviewed and no `chezmoi apply` was run.

### Outstanding concerns

None. The post-implementation parity audit findings were corrected before delivery: explicit bootstrap-profile selection, aggregate-versus-per-tool Homebrew duplication, `mas` preflight ordering, stale-manifest protection, fixed setup ordering, and update, cleanup, and backup operation coverage.

### Post-change review

Bootstrap is a small alias into the shared orchestration engine, while private provider declarations retain host-specific manifests and scripts. The delivered public and private revisions satisfy the approved parity boundary and are ready for human acceptance.

### Mini recap

Standalone Rig can now perform the first materialisation of the private working setup and reach retained maintenance outcomes without recreating the legacy subsystem command tree.

## Discussion

### V1 command

`rig bootstrap [--profile NAME] [--dry-run]` is the small permanent top-level command for first materialisation of a resolved rig. It uses provider capabilities and the same dependency plan as apply rather than maintaining a second orchestration engine.

Install, update, cleanup, and backup outcomes remain available only where selected providers declare those capabilities. Any action-shaped compatibility accepted during cutover is documented as transitional rather than expanding every provider into a permanent command hierarchy.

### Compatibility

The existing `rig bootstrap` command remains live through cutover. The standalone command needs equivalent Bats coverage for dispatch order, selected components, stale-manifest protection, unsupported capabilities, dry-run non-mutation, and failure boundaries before the dotfiles source stops owning duplicate behaviour.

The same delivery updates top-level and command-specific help, completion, README command inventory, `rig(1)`, and the curated v1 changelog.
