---
id: RIG-CORE-028
area: CORE
title: Observe Dock folder attributes
theme: orchestration
horizon: next
status: done
blocks: []
blocked_by: []
baseline_ref: 43a73df5b346bc41512911644534bff46596f74c
created_at: 2026-09-27T08:13:24Z
updated_at: 2026-10-01T14:17:58Z
---

## Goal

A Dock folder whose view or display no longer matches its declaration reports as drifted, so a person learns about the difference before the next apply silently overwrites their change.

## Context

`rig_dock_observe` in `src/rig/20-orchestration.bash:850` builds its expected value from `rig_dock_expected_paths` and compares it against the paths `dockutil --list` returns. It reports `drifted` only with `RIG_OBSERVATION_DETAIL=order`, and `present` otherwise. No declared field beyond `path` participates in the comparison.

A `dock-item` may also declare `view` and `display`, and `rig_dock_apply` at `src/rig/20-orchestration.bash:881` does pass both to `dockutil` as `--view` and `--display`. So the two halves of the contract disagree: apply asserts three fields, observe checks one.

The observed consequence on this workstation was a Dock folder set to List by hand against a declaration of `grid`. `rig status` reported the resource `present` throughout, because the path set matched. The next `rig apply` then ran `dockutil --remove all` and re-added the folder as a grid, discarding the change with no prior warning and no drift row. The declaration was corrected instead, but the reporting gap is independent of which value is right: the same silence would hide a declaration that had itself gone stale.

This is the general shape of an unchecked field rather than a Dock quirk. An observation that cannot see a field it applies will report agreement it has not established, and `present` then means "the part I looked at matched" while reading as "the machine matches the declaration".

## Boundary

This is about what the Dock observation compares and what it reports. It does not change how `rig_dock_apply` materialises a Dock, the full-teardown strategy that apply uses, the state vocabulary, or exit statuses. It does not add Dock fields beyond those already declarable, and it does not decide whether any particular workstation should prefer list or grid — that is configuration, not portable behaviour.

Whether other resource adapters share the same partial-comparison shape is worth knowing but is not scoped here.

## Current state

Dock observation compares declared paths and order only. Apply passes declared `view` and `display` to `dockutil`, and `dockutil --list` does not expose those fields.

## Steps

- [x] Preserve dockutil path/order comparison, then read one defaults export of com.apple.dock only when paths agree and folder view/display attributes are explicitly declared.
- [x] Use native plutil typed extraction to inspect persistent-others folder tiles, matching normalized file URLs to declared paths without another parser or runtime dependency.
- [x] Compare declared view and display independently; keep drift precedence of order, then view, then display. Omitted attributes remain unconstrained.
- [x] When no declared mismatch is established, report unknown for unreadable or malformed snapshots, missing or duplicate matching tiles, missing typed fields and unsupported encodings; never infer present from incomplete evidence.
- [x] Cover supported encodings, matching/mismatching attributes, escaped paths, omitted declarations and unavailable evidence with isolated XML/binary plist fixtures. Assert no defaults write, Dock restart or dockutil mutation occurs.
- [x] Run the full repository gate and record the observation contract before the final display batch.

## Files touched

`src/rig/20-orchestration.bash`, generated `bin/rig`, `tests/rig-macos.bats` or a focused test file, and state Specifications if the unavailable-evidence rule changes them.

## Verify

Use fixture plists and explicit defaults/plutil/dockutil stubs on every platform. Assert state/detail for view, display, order, unsupported encodings, duplicate matches, raw paths, escaped file URLs and unavailable evidence. Verify one snapshot at most and no defaults writes, Dock restart or dockutil mutation. Run the entire AGENTS.md gate with Bats stdin redirected from /dev/null; never apply to a live Dock.

## Dependencies / blocks

No build-order dependency. The delivered machine-independent test fixtures can make the macOS cases easier to run on Linux.

## Delegation

One worker owns the macOS observation helper and focused fixtures; an independent reviewer checks typed evidence, URL matching and the no-mutation boundary. The coordinator owns specifications, assembly, shared-source integration and the complete gate. Do not concurrently edit the same source module from another lane.

## Documentation impact

### Decision Records

None expected unless the observation source creates a durable portability decision.

### Specifications

State which declared Dock fields are observed and how unavailable evidence is reported.

### Guides

Update Dock guidance if the source imposes a user-visible limitation.

### Roadmap

Keep any broader partial-comparison audit distinct from this Dock fix.

## Review

### Delivered

Implemented declared Dock folder view/display observation from immutable baseline `43a73df5b346bc41512911644534bff46596f74c` under RIG-BATCH-009. Paths and order retain precedence; omitted attributes remain unconstrained, while incomplete evidence is unknown rather than agreement. The existing Dock apply body is unchanged.

### Change Summary

Added typed native snapshot helpers in `src/rig/20-orchestration.bash`, a command-entry cache reset in `src/rig/90-main.bash`, focused Dock tests and a fixture-only portable plutil helper. Updated existing macOS fixtures, the state specification, operational-resource guide, manual, Unreleased notes and assembled executable. No runtime parser dependency was introduced.

### Verification

All 25 focused Dock/macOS tests passed, including 16 new observation cases. Independent disposable native-plutil checks confirmed XML/binary conversion, typed values and control-character preservation. The full local gate passed: repository audit, ShellCheck, Bash syntax, assembly check, benchmark, six read-only native-provider probes, all 353 Bats tests with stdin from /dev/null, and manual lint.

### Outstanding concerns

None within the approved scope. Existing dockutil path/order normalization is preserved; this item does not redesign unrelated path semantics or the live display.

### Post-change review

A separate worker reviewed native evidence semantics and ran the focused tests. Review found and fixed command-substitution stripping of trailing newlines, with a regression proving malformed paths cannot falsely match. Tests cover one snapshot per command, repeated sourced commands, all encodings, omitted fields, duplicate matches, full-path rather than label matching, proven-mismatch precedence and absent native mutation. The coordinator integrated documentation and the command-entry reset.

### Mini recap

Status and doctor now expose declared Dock attribute drift before apply. The accepted behavior and evidence are retained in RIG-STATE-036 and the operational guide. This item is awaiting human acceptance; live-display work remains separate.

## Done

Accepted 2026-10-01 by Kris on the review packet above.

## Discussion

### Readiness

Prepared for Ready under the user's 2026-10-01 request. Scope, implementation boundary and verification are fixed below; this planning transition does not start implementation or authorise live-machine changes.

### Where the comparison should live

`rig_dock_expected_paths` returns paths because that is what its name promises and what the order check needs. Widening it in place would make the order comparison harder to read. A separate expected-triple builder, or an extra comparison pass keyed by path, both keep the order finding intact. The detail token matters as much as the state: `order` and a new value such as `view` are different findings, and collapsing both into bare `drifted` would lose the distinction that makes the row actionable.

### Locked observation contract

Take at most one read-only defaults-export snapshot per command when explicitly declared folder attributes require it. Respect the native file URL type: raw paths remain raw and file URLs receive exactly one decoding pass. Compare expanded full paths, never labels or basenames. Duplicate matches, malformed field types and unsupported encodings are unavailable evidence, not a guessed match.

Preserve order drift first, then a proven view mismatch, then a proven display mismatch. If no mismatch is proved but a declared attribute cannot be observed, return unknown with an item-qualified detail. Use details such as view:documents and display-unobservable:documents. Omitted attributes impose no expectation. Fixture tests must cover mixed incomplete and mismatching evidence, not only one folder at a time.

### Reading native evidence

Dockutil list output does not expose the folder attributes. The proposed bounded source is a read-only defaults export parsed through macOS-native plutil, not a general parser added to Rig. Upstream dockutil maps view auto/fan/grid/list to 0/1/2/3 and display stack/folder to 0/1. Pin the mappings in fixture-backed adapter tests and report unfamiliar encodings as unknown rather than assuming defaults. Apply remains unchanged.

### Relationship to the catalogue-only work

The delivered catalogue-only status change corrected a neutral row counted as a fault. This is the inverse: a fault counted as agreement. The two changes are independent.
