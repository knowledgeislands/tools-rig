---
id: RIG-CORE-005
area: CORE
title: Normalise identities before comparing
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 6925a79a8a840868ef58fbe93bdcf15a3ed68c74
created_at: 2026-09-17T00:00:00Z
updated_at: 2026-09-18T03:13:01Z
---

# RIG-CORE-005: Normalise identities before comparing

## Goal

Make reconciliation recognise equivalent provider and path identities so a declared tool that is present is not reported missing or unmanaged because the two sources format its identity differently.

## Context

Both directions of reconciliation currently compare declared text with provider-reported text using exact string equality. When the two sides legitimately spell the same identity differently, Rig reports a finding that is purely an artifact of comparison.

Two instances are confirmed against the live 81-tool catalogue:

- A Homebrew cask declared with a tap-qualified locator is reported `missing` while installed. `locator = 1password/tap/1password-cli` and `locator = steipete/tap/codexbar` do not match Homebrew's installed short names `1password-cli` and `codexbar`. Both casks are installed and Rig reports `missing=2`.
- An `artifact` path containing leading `$HOME/` or `~/` does not match the provider-reported absolute path. `bin/rig` compares the literal declared artifact with the reported identity even though other documented path-valued fields receive bounded home expansion.

The path case is currently worked around outside Rig: the chezmoi consumer expands `$HOME` while rendering the catalogue. That workaround exists only because the consumer uses a templating layer, which RIG-CORE-006 is intended to make unnecessary.

## Boundary

This item normalises identity only at provider observation and comparison boundaries. It does not rewrite the authored declaration, add fuzzy matching or aliases between genuinely different identities, alter provider inventory output, or introduce general environment-variable expansion.

## Current state

`rig doctor` and `rig status` consistently report `codexbar` and `one-password-cli` missing against the live catalogue even though Homebrew has installed both casks. `rig status --unmanaged` matches provider inventory against binding locators and tool artifacts literally. The private consumer must pre-expand artifact home paths to avoid false unmanaged findings.

## Steps

- [x] Add bounded comparison helpers that derive an observed identity without mutating the stored declaration or the locator passed to an apply operation.
- [x] For Homebrew formula and cask observation, reduce a tap-qualified locator to its terminal formula or cask token before the installed-state lookup and inventory comparison; retain the complete qualified locator for installation.
- [x] For tool artifacts, expand only leading `~/` and `$HOME/` to the active home directory before comparison with an observed absolute path; leave embedded variables, other variable names, relative paths, and non-path identities literal.
- [x] Apply the same normalisation functions wherever status and unmanaged reconciliation compare those identity classes, avoiding command-specific fixes that can diverge.
- [x] Add Bats coverage for qualified Homebrew formula and cask locators, unqualified locators, both supported home prefixes, explicit absolute artifacts, non-leading variable text, provider namespace separation, and unchanged apply arguments.
- [x] Update the changelog, configuration decision, and configuration, orchestration, and state specifications with the bounded normalisation rules and acquisition-versus-observation distinction.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `CHANGELOG.md`
- `docs/decisions/ADR-RIG-003-declarative-configuration-grammar.md`
- `docs/specs/configuration.md`
- `docs/specs/orchestration.md`
- `docs/specs/state.md`

## Verify

- `bats tests/`
- `shellcheck bin/rig install.sh`
- `bash -n bin/rig install.sh`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`
- Fixture tests prove observation uses short Homebrew identities while apply receives the original qualified locator exactly.
- Fixture tests prove supported home-prefixed artifacts match absolute inventory identities while unsupported or embedded variable syntax stays literal.
- Against the live workstation catalogue, `rig doctor` and `rig status` report `missing=0`, and `rig status --unmanaged` remains correct after the private consumer stops pre-expanding `$HOME`.

## Dependencies / blocks

No build dependency blocks this work. RIG-CORE-006 depends on the same direct-authoring outcome and touches `bin/rig`, `tests/rig.bats`, and `CHANGELOG.md`; serialize their implementation commits, with this identity repair first, rather than treating them as parallel file lanes.

## Documentation impact

### Decision Records

Amend ADR-RIG-003 to allow bounded leading `$HOME/` expansion alongside `~/` for declared path fields while retaining the prohibition on general environment expansion. No new decision record is required.

### Specifications

Specify bounded artifact path normalisation, Homebrew observation identities, preservation of qualified acquisition locators, and consistent status and unmanaged comparisons.

### Guides

No guide change is required because both supported locator and artifact spellings remain valid authored declarations; reference documentation and the changelog are sufficient.

### Roadmap

RIG-CORE-006 can rely on direct artifact paths working without consumer-side expansion after this item lands. It remains independently planned and does not become a formal build-order blocker.

## Review

### Delivered

Delivered the approved comparison-only normalisation boundary from immutable baseline `6925a79a8a840868ef58fbe93bdcf15a3ed68c74`. Homebrew observation and unmanaged reconciliation now recognise tap-qualified formula and cask locators, artifact comparison recognises the two bounded home prefixes, and declaration, export, and apply values remain unchanged. No provider inventory, aliasing, or general interpolation behaviour was added.

### Summary of changes

`bin/rig` now derives provider and artifact comparison identities. `tests/rig.bats` covers qualified and unqualified Homebrew observation, unchanged qualified apply arguments, supported and unsupported artifact spellings, absolute paths, and provider namespaces. The changelog, ADR-RIG-003, and configuration, orchestration, and state specifications record the acquisition-versus-observation distinction.

### Verification

`shellcheck bin/rig install.sh`, `bash -n bin/rig install.sh`, and all 112 Bats tests pass. Focused comparison tests pass. Against the live default profile, `rig status` reports `missing=0`, `rig doctor` reports healthy with zero findings, and `rig status --unmanaged` completes with the expected informational inventory. The repository-wide audit still reports only the nine pre-existing approval-gated GitHub settings findings, and `mandoc -T lint man/rig.1` still reports the pre-existing line-629 style finding; neither file or external setting is in this item's change set.

### Outstanding concerns

The private consumer still pre-expands artifact home paths until RIG-CORE-006 migrates it to direct authoring, so the live unmanaged check validates compatibility rather than removal of that workaround. The known repository audit and manual style findings remain for the batch-level gate.

### Post-change review

The implementation satisfies the item goal and preserves the declared trust and provider boundaries. Regression risk is concentrated in comparison helper reuse and is covered across observation, unmanaged inventory, literal apply arguments, unsupported variables, and provider namespace tests. The item is ready for acceptance review once the batch-level known findings are assessed.

### Mini recap

Rig now compares equivalent identities without changing what the person authored or what providers receive for materialisation. Automated and live checks confirm the two false missing findings are gone. No new durable learning route is proposed beyond the amended decision and specifications.

## Discussion

### One comparison problem

Both cases have the same shape: comparison treats a formatted string as the underlying identity. Fixing them separately at individual call sites would leave another command free to reintroduce the same false finding.

### Preserve declaration authority

Normalisation produces a comparison identity only. `rig show`, `rig explain`, exports, and provider apply operations continue to use the authored declaration. This keeps a tap-qualified Homebrew locator useful for deterministic acquisition while accepting the short token Homebrew reports after installation.

### Bound path expansion

Supporting exactly leading `~/` and `$HOME/` is a documented path-field convenience, not shell interpolation. Rig must not evaluate arbitrary variables, substitutions, quoting, or embedded expressions while loading or comparing inert configuration.
