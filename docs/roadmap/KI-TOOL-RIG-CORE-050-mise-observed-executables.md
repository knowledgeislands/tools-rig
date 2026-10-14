---
id: KI-TOOL-RIG-CORE-050
area: CORE
title: Mise observed executables
purpose: corrective
initiative: rig
kind: deliver
status: done
blocks: []
blocked_by: []
baseline_ref: d6be83747f504b1aad3f79b9e153f8a4c4e75ca2
created_at: 2026-10-13T23:36:16Z
updated_at: 2026-10-14T08:54:00Z
---

# Mise Observed Executables

## Goal

A mise tool declaration can name the executable, or executables, Rig checks separately from the locator it installs. Tools whose binary name differs from their mise locator, such as `rust` or a `cargo:` backend package, can then be declared in a Rig catalogue, observed by `rig status` and installed by `rig apply`.

## Context

The built-in mise `tool` kind uses its locator for every native operation. [Provider state](../../src/rig/21-provider-state.bash) observes with `mise which LOCATOR` and applies with `mise install LOCATOR`, as the [orchestration specification](../specs/orchestration.md) requires; `rig upgrade` runs `mise upgrade LOCATOR`. `mise which` takes an executable name, so observation succeeds only when the binary is named exactly as the locator.

`rust` installs `rustc` and `cargo` but no `rust` executable, so its observation reports it missing on every run. A `cargo:` backend package, for example `cargo:cargo-nextest` providing `cargo-nextest`, has the same mismatch, as does any tool whose binary carries a different name. The chezmoi workstation therefore pins these tools only in its global mise manifest, outside Rig's catalogue and status.

## Boundary

- In: an optional configuration field naming one or more executables for observation, its validation and default to the locator's tool name, observation reporting when several executables are named, specifications and tests.
- Out: changes to the install, upgrade and removal locator; reading mise's global manifest; any other provider kind.

## Current state

Grounded at `620e0b9` on 14 October 2026.

- [Provider state](../../src/rig/21-provider-state.bash) builds `mise:tool:observe` as `mise which [ARGUMENTS] LOCATOR` and `mise:tool:apply` as `mise install [ARGUMENTS] LOCATOR`. `rig_observe_provider` treats exit 0 as `present`, exit 1 as `missing` and any other exit as `unknown`, through the per-invocation observation cache.
- `mise which` takes an executable name, so a locator that is not itself an executable name is always `missing`: `rust` (provides `rustc` and `cargo`), `cargo:cargo-nextest` (provides `cargo-nextest`), and any versioned locator such as `node@22`.
- [Configuration](../../src/rig/10-configuration.bash) maps `install.*` and `variant.ID.install.*` fields to `install-*` keys, copies them onto the synthesised binding in `rig_synthesise_binding_fields`, rejects `install.*` without `install.provider`, and in `rig_validate_binding_adapter` restricts `install.destination` and `install.checksum` to direct-download. That is the pattern for an adapter-specific optional field.
- `rig upgrade` (`mise upgrade LOCATOR`) and `rig remove` (`mise uninstall LOCATOR`) use the locator and stay unchanged.
- [RIG-ORCH-017](../specs/orchestration.md) fixes `mise which LOCATOR` as the observation command; [RIG-CONF-010 and RIG-CONF-013](../specs/configuration.md) enumerate the permitted `install.*` fields. The `install.*` field list in the [manual](../../man/rig.1) mirrors them.
- `tests/rig-provider-fixtures.bats` already observes a mise tool through `rig_test_provider_response mise 'which sample' …`; that fixture is the test pattern.

## Steps

- [x] Add `install.executables` and `variant.ID.install.executables`, a string array, to the TOML field maps and the tool key allow-lists; copy it to the binding as `observe-executable` (distinct from the provider `executable` key) in `rig_synthesise_binding_fields`; include it in the "requires install.provider" guard.
- [x] In `rig_validate_binding_adapter`, accept `executables` only for `mise:tool`, reject it for every other adapter and kind, and reject an empty element, a tab or newline, a leading `-`, or a `/`.
- [x] Observation: for `mise:tool`, observe each named executable in order with `mise which [ARGUMENTS] EXECUTABLE`. With no `executables`, observe one executable: the locator with a trailing `@VERSION` removed (`rust`, `cargo:cargo-nextest`, `node@22` → `node`), so existing catalogues keep their current command except for a versioned locator. Aggregate: every executable present → `present`; any exit 1 → `missing` with detail `missing-executable:NAME` for the first missing; any other exit → `unknown` with `exit:N`. Apply, upgrade and remove keep the full locator.
- [x] Bats tests in `tests/rig-provider-fixtures.bats`: `rust` with `executables = ["rustc", "cargo"]` is present only when both `which` calls succeed and missing with the first failing name otherwise; `cargo:cargo-nextest` with one executable observes `which cargo-nextest` and applies `install cargo:cargo-nextest`; a versioned locator without the field observes the bare name; the unversioned default command is unchanged. Validation tests in `tests/rig-model-boundaries.bats` reject the field on a non-mise kind, without `install.provider`, and with an unsafe element.
- [x] Update the specification, manual and changelog (below), run `scripts/assemble-rig`, and run the complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository).

## Files touched

- `src/rig/10-configuration.bash`, `src/rig/21-provider-state.bash`, and the regenerated `bin/rig`.
- `tests/rig-provider-fixtures.bats`, `tests/rig-model-boundaries.bats`.
- `docs/specs/orchestration.md`, `docs/specs/configuration.md`, `man/rig.1`, `CHANGELOG.md`.

## Verify

- `bats tests/ </dev/null` passes, including the new fixture and validation tests, with the fixture log showing no undeclared mise call.
- `scripts/assemble-rig` leaves `bin/rig` byte-identical to the committed file after the change.
- The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes.
- No apply runs against the live workstation; observation is proved only through the provider fixture.

## Dependencies / blocks

Not blocked; it blocks nothing. The chezmoi workstation can move `rust` and its `cargo:` tools into its Rig catalogue after a release containing this fix; that move belongs to that repository.

## Documentation impact

### Decision Records

None. The field extends an existing provider contract without a new design choice that needs recorded rationale.

### Specifications

[RIG-ORCH-017](../specs/orchestration.md): mise observation becomes `mise which EXECUTABLE` for each declared executable, defaulting to the locator without its version, with the aggregation rule. [RIG-CONF-010 and RIG-CONF-013](../specs/configuration.md): add `install.executables` as an optional string array valid only for mise `tool`, with its element constraints. Both stay conforming with the new tests as evidence.

### Guides

None beyond the `install.*` field list in `man/rig.1`; no user guide documents per-kind install fields.

### Roadmap

This record only. `CHANGELOG.md` gains one capability line.

## Review

### Delivered

Delivered within the approved boundary from baseline `d6be83747f504b1aad3f79b9e153f8a4c4e75ca2`, using provider fixtures only. A mise `tool` installation, at tool or variant level, now accepts `install.executables`; Rig observes each named executable with `mise which`, and without the field observes the locator with a trailing `@VERSION` removed. Install, upgrade and removal keep the full locator.

Excluded, as planned: no change to install, upgrade or removal commands, no reading of mise's global manifest, no other provider kind, no apply against the live workstation, and no release.

### Change Summary

- **Configuration** (`src/rig/10-configuration.bash`): `install.executables` and `variant.ID.install.executables` map to `install-executable`, copy to the binding as `observe-executable`, join the "install metadata requires install.provider" guard, and are validated in `rig_validate_binding_adapter`: mise `tool` only, no leading `-`, `/`, tab or newline. The TOML reader already refuses an empty array element.
- **Observation** (`src/rig/21-provider-state.bash`, `src/rig/00-runtime.bash`): new `rig_mise_observation_executables` and `rig_observe_mise_tool`; `rig_prepare_builtin_invocation` takes the observed executable for `mise:tool:observe`. Each `mise which` call still goes through the per-invocation observation cache.
- **Tests**: three fixture tests in `tests/rig-provider-fixtures.bats` and one validation test in `tests/rig-model-boundaries.bats`.
- **Documentation**: RIG-ORCH-017, RIG-CONF-010 and RIG-CONF-013, `man/rig.1`, and one `CHANGELOG.md` line. `bin/rig` regenerated.

Interpretations for review:

- **Horizon moved from Next to Now**, as delivery start requires.
- **Scoped package names keep their `@`.** The versionless default removes only a trailing `@VERSION` after a non-empty name that does not end in `:` and a version without `/`, so `npm:@scope/name` is observed unchanged and `npm:@scope/name@1.2` as `npm:@scope/name`.
- **`missing-executable:NAME` only when the field is declared.** The default single observation keeps its existing `missing` with no detail, so the unversioned default output is unchanged.
- **Observation stops at the first non-zero exit**, so a later executable is not called once the outcome is known.

### Verification

All commands ran locally on 14 October 2026 with stdin closed. No live mise call or Rig apply was run against the workstation.

- Complete gate from [Develop Rig](../guides/developer/README.md#verify-the-repository):
  - `ki repo audit --repo .`: no failures; the existing HOOK-1 warning (no committed pre-commit gate) is unrelated.
  - `shellcheck` and `bash -n` on every listed script: clean.
  - `scripts/assemble-rig --check`: current, so `bin/rig` is byte-identical to the assembled modules.
  - `scripts/benchmark-rig`: within budget (show 2 s of 5 s, show-all 2 s of 5 s, status 6 s of 8 s).
  - `scripts/smoke-native-providers`: read-only version probes, 6 of 6 passed.
  - `bats tests/ </dev/null`: 543 of 543 passed, including the four new tests.
  - `mandoc -T lint man/rig.1`: clean.
  - `git diff --check`: clean.
- The cargo-backend fixture asserts that its provider log holds only `which cargo-nextest` and `install cargo:cargo-nextest`, so no undeclared mise call ran; the `rust` fixture asserts `which rust` is never called.

### Outstanding concerns

- The versionless default changes the observed command only for a versioned locator, which was previously always `missing`; no existing correct observation changes.
- A backend whose plain tool name is not an executable, such as `ubi:owner/repo@v1` observed as `ubi:owner/repo`, still needs `install.executables`. That is the field's purpose and is documented.
- The chezmoi workstation needs a Rig release containing this change before its catalogue can declare `rust` and `cargo:` tools. No release was made.

### Post-change review

The goal is met: `rust` with `["rustc", "cargo"]` and `cargo:cargo-nextest` with `["cargo-nextest"]` are observable and installable through Rig, and a versioned locator observes its bare name. Scope held to the planned files plus the runtime global in `00-runtime.bash`. Regression risk is confined to mise observation, which now has its own path; the existing mise fixture test and the full suite pass unchanged. Ready for code review.

### Mini recap

Added `install.executables` for mise tools with validation, per-executable observation with first-failure reporting and a versionless default, fixture and validation tests, and the specification, manual and changelog updates. Proposed learning route: none.

## Done

Accepted 2026-10-14 by Kris Brown on the review packet above (state-of-play decisions log, Decision 170: "RIG050-ACCEPT accept KI-TOOL-RIG-CORE-050").

## Discussion

Origin: the chezmoi source (`krisb/dotfiles`), whose workstation keeps `rust` and `cargo:` tools out of its Rig catalogue for this reason; Kris Brown approved the handoff on 2026-10-14. Capture only; adoption, priority and plan belong to this repository.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `deliver / Next` as a defect fix. The mise `tool` kind reports `rust` and `cargo:` tools missing on every run, so the chezmoi workstation keeps them out of Rig's catalogue. The fix is a small optional field. Adoption grants no planning, implementation or acceptance authority.

### Readiness

On 14 October 2026 Kris approved the plan to Ready and delivery as written, including the versionless default for a versioned locator.
