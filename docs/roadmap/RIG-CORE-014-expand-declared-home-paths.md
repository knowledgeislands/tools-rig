---
id: RIG-CORE-014
area: CORE
title: Expand declared home paths
theme: orchestration
horizon: next
status: done
blocks: []
blocked_by: []
baseline_ref: 25f1cc6f79fd06cb35a905a9449a5e0d3b517395
transferred_from: TRD-3a1ab790
created_at: 2026-09-21T12:06:12Z
updated_at: 2026-09-21T15:21:13Z
---

# RIG-CORE-014: Expand declared home paths

## Goal

Let portable personal declarations use documented home-relative values without producing false drift or making valid local paths impossible to apply.

## Context

Trade `TRD-3a1ab790` reports that macOS settings and Dock resources preserve `$HOME` literally during comparison and preflight. A screen-capture location declared as `$HOME/Downloads` is compared with `/Users/krisbrown/Downloads`, a Finder URL declared as `file://$HOME/` is compared with `file:///Users/krisbrown/`, and a Dock folder declared as `$HOME/Downloads` fails existence checks even though the directory exists. The result is phantom drift and an apply plan that stops before unrelated resources can reconcile.

## Boundary

Keep configuration inert and Bash 3.2-compatible. Do not add general shell interpolation, expand arbitrary environment variables, mutate the stored declaration, or require a personal absolute home path. Preserve native values and URL syntax outside the explicitly supported home forms.

## Current state

Dock paths expand only `~` forms through a launchd-named helper. macOS setting values do not expand home-relative forms during observation or application, and `$HOME` Dock paths therefore fail existence checks before apply. Authored configuration remains inert and query output preserves the literal declaration.

## Steps

- [x] Add one bounded, non-evaluating semantic-value helper for exact `~`, `~/...`, `$HOME`, `$HOME/...`, `file://$HOME`, and `file://$HOME/...` forms.
- [x] Use the same expanded value for string-setting observation and application, and for Dock observation, preflight, and application.
- [x] Preserve embedded variables, other variable names, unsupported tilde forms, and stored/query values literally.
- [x] Add positive and negative Bats coverage, including unset-`HOME` behaviour for recognised forms.
- [x] Align the living configuration decision, specifications, operational-resources guide, manual, and changelog.

## Files touched

- `bin/rig`
- `tests/rig-macos.bats`
- `docs/decisions/ADR-RIG-003-declarative-configuration-grammar.md`
- `docs/specs/configuration.md`
- `docs/specs/state.md`
- `docs/specs/orchestration.md`
- `docs/guides/user/operational-resources.md`
- `man/rig.1`
- `CHANGELOG.md`
- this roadmap record

## Verify

- `bats tests/rig-macos.bats`
- `shellcheck bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`

## Dependencies / blocks

None. The change reuses the existing trusted parser and built-in macOS adapters.

## Documentation impact

### Decision Records

Amend ADR-RIG-003 so its living trust model names the bounded semantic home forms and continues to reject shell evaluation.

### Specifications

Amend configuration, state, and orchestration requirements so authored literals remain inert while supported resource values resolve consistently at runtime.

### Guides

Add consumer examples and limitations to the operational-resources guide.

### Roadmap

Keep this record as the delivery and review authority; no follow-on item is expected unless verification exposes a separate concern.

## Review

### Delivered

From immutable baseline `25f1cc6f79fd06cb35a905a9449a5e0d3b517395`, delivered the approved bounded home-value contract without shell evaluation, general environment expansion, or changes to authored query output.

### Summary of changes

- Added one non-evaluating runtime expansion helper for the accepted whole-value home forms.
- Applied identical semantics to string-setting observation, preflight, and application and to Dock observation, preflight, and application.
- Preserved literal declaration queries and unsupported variable forms.
- Updated the living decision, Specifications, user guides, README, manual, and changelog.

### Verification

- `ki repo audit --repo .` — passed.
- `shellcheck bin/rig install.sh` — passed.
- `bats tests/` — passed, including new paths, file URLs, unsupported embedded variables, Dock paths, and unset-home cases.
- `mandoc -T lint man/rig.1` — passed.

### Outstanding concerns

None within the approved boundary.

### Post-change review

A fresh scope and regression review confirms stored declarations remain inert, launchd retains its existing path semantics, supported resource values resolve consistently, and the CLI surface is unchanged. The item is ready for human acceptance.

### Mini recap

Rig now accepts portable home-relative macOS setting and Dock declarations without phantom drift or impossible preflight, while unsupported text stays literal.

## Done

Accepted 2026-09-21 by Kris Brown on the review packet above.

## Discussion

### Expansion contract

Rig already recognises leading `~/` and `$HOME/` for selected comparison identities. The work must decide which typed setting, Dock, service, and job fields are genuinely path-valued, and whether a bounded `file://$HOME/` form belongs to the same contract without becoming substring-based variable expansion.

### State consistency

Observation, drift reporting, dry-run preflight, and application must use one normalised semantic value. A declaration must not compare one way and validate or apply another way.

### Trade disposition

This record is unadopted intake captured from `TRD-3a1ab790`. Receiving the trade does not select or prioritise the work; adoption and the receiver-local trade linkage require explicit review.
