---
id: KI-TOOL-RIG-CORE-059
area: CORE
title: Mac App Store provider
purpose: capability
initiative: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: b5011d53957719d19404eeac1721339dc9f6ae38
created_at: 2026-10-15T01:40:07Z
updated_at: 2026-10-15T10:00:00Z
---

# KI-TOOL-RIG-CORE-059: Mac App Store Provider

## Goal

Rig installs, observes, upgrades and removes Mac App Store applications through a built-in `mas` provider of their own, declared as `install.provider = "mas"` with `install.kind = "app"` and a numeric App Store identity as `install.locator`. Every Rig output for these applications names the `mas` provider, never `homebrew`. The former `install.provider = "homebrew"` with `install.kind = "mas"` keeps working as a deprecated alias, which `rig doctor` warns about, so live configurations keep applying until they are migrated.

## Context

App Store applications are declared today under the Homebrew provider with kind `mas`, although Rig never runs `brew` for them: `rig_provider_executable` maps `homebrew:mas` to the `mas` executable (`src/rig/21-provider-state.bash`). The grouping is only a label, but it is what Rig prints, so status, plans, apply history and upgrade reports name `homebrew` for an App Store copy. On 15 October 2026 that confused the Telegram decision on Mac Studio `sol`, where Rig output said "homebrew" for the App Store build ([mas-model run report](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_THREADS/mac-studio-setup/mas-model.report.md)). Kris's point was that Homebrew and the App Store are different managers, "like brew and npm".

## Boundary

- **In:** a built-in provider identity and adapter `mas` with the single kind `app`; numeric-locator validation; observation through `mas list`, installation through `mas install ID`, attended upgrade through `mas upgrade ID` and the unattended `interactive-required` exclusion; native removal through `[remove.ID]` with the existing `sudo -n` rule; `updates = "self"` or `"managed"` and application-source observation; the Homebrew `mas` formula as a deferred executable prerequisite inside one apply, as `mise` already is; the deprecated alias for tools, variants and removals, with a `rig doctor` warning; specifications, guides, manual, changelog and Bats tests.
- **Out:** migrating any personal declaration, which belongs to the chezmoi source and a separate run; App Store sign-in or account handling; `mas` inventory for `rig capture` or `doctor --unmanaged`; resolving App Store identities over the network; carrying apply-history rows recorded under `homebrew` across to `mas`, which [RIG-STATE-035](../specs/state.md) forbids for a replacement provider.

## Current state

- `homebrew:mas` appears as an adapter-and-kind pair in configuration validation, provider invocation, observation, application update policy, application-source detail, software removal and lifecycle upgrade (`src/rig/10-configuration.bash`, `21-provider-state.bash`, `27-software-removal.bash`, `40-publication-lifecycle.bash`).
- The Homebrew adapter's lifecycle exports `NONINTERACTIVE=1` and branches on kind `mas` to call `mas upgrade ID`; an unattended run already reports App Store targets `unavailable` with `interactive-required` (`rig_lifecycle_requires_person`).
- Kris's configuration declares 13 tools with `install.provider = "homebrew"` and `install.kind = "mas"` in chezmoi `dot_config/rig/conf.d/private_10-applications.toml`, and the `mas` executable itself as the Homebrew formula `tool.mas`.

## Steps

- [x] Register `mas` as a built-in provider and adapter; accept kind `app` only; require a numeric locator; reject `[provider.mas]` adapter or capability declarations as for every built-in.
- [x] Rewrite each tool, variant and `[remove.ID]` declaration of provider `homebrew` with kind `mas` to provider `mas` with kind `app` at load, before bindings are synthesised, and record it for `rig doctor`, which lists each one under a Warnings section and counts it in `warn` without changing the verdict.
- [x] Move observe, install, upgrade, removal, update-policy and application-source handling from `homebrew:mas` to `mas:app`, with no Homebrew environment for App Store calls.
- [x] Let an earlier Homebrew formula `mas` in the same plan satisfy the `mas` executable for a tool that requires it.
- [x] Update Bats tests to the new form, and add alias, doctor-warning, output-naming and prerequisite coverage.
- [x] Align the configuration, orchestration and state specifications, the user guides, help, manual and changelog; assemble `bin/rig`; run the complete local gate.

## Files touched

- [Configuration](../../src/rig/10-configuration.bash), [orchestration](../../src/rig/20-orchestration.bash), [provider state](../../src/rig/21-provider-state.bash), [observation](../../src/rig/22-observation.bash), [software removal](../../src/rig/27-software-removal.bash), [lifecycle](../../src/rig/40-publication-lifecycle.bash) and the assembled [executable](../../bin/rig).
- Bats tests under [`tests/`](../../tests/) that declare App Store applications.
- [Configuration](../specs/configuration.md), [orchestration](../specs/orchestration.md) and [state](../specs/state.md) specifications; [getting started](../guides/user/getting-started.md), [commands](../guides/user/commands.md) and [unattended updates](../guides/user/unattended-updates.md) guides; [manual](../../man/rig.1); [changelog](../../CHANGELOG.md).

## Verify

- A tool declared `install.provider = "mas"`, `install.kind = "app"` observes with `mas list`, installs with `mas install ID`, upgrades with `mas upgrade ID`, and appears as provider `mas` in status, plan and history.
- A non-numeric locator, any other kind, and `mas` on a non-macOS platform are rejected before native invocation.
- The old form loads, runs the same `mas` commands, prints `mas` not `homebrew`, and makes `rig doctor` print one warning per declaration while the verdict stays healthy.
- An unattended upgrade reports `mas` targets `unavailable` with `interactive-required` and never invokes `mas`.
- `[remove.ID]` with provider `mas` uses `sudo -n mas uninstall ID`, and the old form still does.
- The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes.

## Dependencies / blocks

Not blocked; blocks nothing. The chezmoi migration of Kris's declarations follows delivery as its own run.

## Documentation impact

### Decision Records

None. The provider follows [ADR-KI-TOOL-RIG-005](../decisions/ADR-KI-TOOL-RIG-005-provider-execution-contract.md) and [XDR-KI-TOOL-RIG-001](../decisions/XDR-KI-TOOL-RIG-001-executable-provider-boundary.md) as written: a fixed built-in identity with reviewed argument construction.

### Specifications

Amend RIG-CONF-012 and RIG-CONF-013 for the `mas` identity, kind `app` and the alias; the orchestration built-in adapter list, provider prerequisite, unattended-upgrade and removal requirements; and the state requirements for application update policy, application source and doctor warnings.

### Guides

Name the App Store provider and its declaration form in [getting started](../guides/user/getting-started.md) and [commands](../guides/user/commands.md), and the migration from the alias.

### Roadmap

Adopted at Now by Kris's MAS-PROVIDER decision; see [Origin and approval](#origin-and-approval).

## Review

### Delivered

Delivered within the approved boundary from baseline `b5011d53957719d19404eeac1721339dc9f6ae38`, using fixtures only. Rig has a built-in `mas` provider with the single kind `app`. A tool, variant or `[remove.ID]` declared as provider `homebrew` with kind `mas` is rewritten to `mas` and `app` at load, before bindings exist, so it runs the same `mas` commands, prints `mas` in every output and appears once under `rig doctor` Warnings with action `declare-provider-mas-kind-app`, counted in `warn` without changing the verdict.

Excluded, as the approval requires: no personal declaration was migrated, no `rig apply` was run, and nothing was accepted, pushed or released.

### Change Summary

- **Configuration** (`10-configuration.bash`): `mas` joins the built-in providers and adapters; `rig_alias_deprecated_mas` rewrites the alias and records each declaration; `mas:app` requires a numeric locator and rejects platform `linux`.
- **Provider state and orchestration** (`20-orchestration.bash`, `21-provider-state.bash`): `mas` capabilities, executable, observe and install arguments, application update policy and source detection move from `homebrew:mas` to `mas:app`; an earlier Homebrew formula `mas` satisfies the executable for a tool that requires it.
- **Upgrade and removal** (`40-publication-lifecycle.bash`, `27-software-removal.bash`): `mas upgrade ID` under the `mas` adapter, without `NONINTERACTIVE`; unattended exclusion keyed to the adapter; removal and its sudo notice keyed to `mas:app`.
- **Doctor** (`22-observation.bash`): a Warnings section in text, a `warnings` array in JSON, and a real `warn` count.
- **Tests**: new `tests/rig-mas-provider.bats` (6 tests); App Store fixtures in `tests/rig.bats`, `tests/rig-lifecycle.bats`, `tests/rig-software-removal.bats` and `tests/rig-application-updates.bats` move to the new form.
- **Documentation**: RIG-CONF-013 and RIG-CONF-028 in [configuration](../specs/configuration.md); RIG-ORCH-018, RIG-ORCH-006, RIG-ORCH-017, RIG-ORCH-024, RIG-ORCH-034 and RIG-ORCH-042 in [orchestration](../specs/orchestration.md); RIG-STATE-015 in [state](../specs/state.md); RIG-CAT-009 in [catalogue](../specs/catalogue.md); the [getting started](../guides/user/getting-started.md) declaration and migration section, [commands](../guides/user/commands.md), the manual and the changelog.

Deviations and interpretations for review:

- **Platform rejection is explicit only.** A `mas` installation is rejected when its own `install.platforms` or variant platforms name `linux`. A tool listing `linux` at tool level is not rejected, because a Linux variant may carry that platform while the top-level `mas` installation serves macOS.
- **Provider arguments.** A `[provider.homebrew]` argument no longer reaches `mas`, which it previously did; App Store calls take no Homebrew argument or environment.
- **History rows.** Apply and upgrade history recorded under `homebrew` stays as recorded, per RIG-STATE-035.
- **No adapter table.** The README adapter table that first grouped `mas` under Homebrew no longer exists; RIG-ORCH-017's command matrix is the current table and is updated.

### Verification

All commands were run locally on 15 October 2026 with stdin closed. No `rig apply` and no live `mas` install, upgrade or uninstall was run.

- `ki repo audit --repo .`: PASS=19, WARN=1, FAIL=0. The warning is the repository's existing lack of a committed `.githooks/pre-commit` gate.
- `shellcheck` and `bash -n` over `bin/rig`, `install.sh`, `src/rig/*.bash` and the three scripts: clean.
- `scripts/assemble-rig --check`: `bin/rig` matches its modules.
- `scripts/benchmark-rig`: every command within budget.
- `scripts/smoke-native-providers`: homebrew, uv, mise, npm, chezmoi and mas PASS.
- `bats tests/`: 550 tests, 0 failures, including the 6 in `tests/rig-mas-provider.bats`.
- `mandoc -T lint man/rig.1` and `git diff --check`: clean.

### Outstanding concerns

- The live configuration on `sol` and `terra` still uses the alias, so `rig doctor` will warn once per App Store declaration until the chezmoi source migrates in its own run.
- The provider is proven against fixtures and the `mas` smoke probe only; the first real `rig status` after this commit is its live check.

For that migration, each App Store declaration in the chezmoi source changes two lines and keeps its locator:

```toml
install.provider = "mas"
install.kind = "app"
install.locator = "747648890"
```

Variants use `variant.ID.install.provider = "mas"` and `variant.ID.install.kind = "app"`; `[remove.ID]` uses `provider = "mas"` and `kind = "app"`. A tool that installs `mas` from Homebrew stays `install.provider = "homebrew"`, `install.kind = "formula"`, `install.locator = "mas"`, and App Store tools MAY add `requires = ["mas"]`.

### Post-change review

The goal is met in code: App Store applications have their own provider, every output names `mas`, and the alias keeps existing configuration working with a visible doctor warning. Scope held to the record's files. Regression risk sits in the load-time rewrite, which touches every tool, variant and removal declaration, and in doctor's new warning count; both are covered by the full suite. Ready for review; acceptance does not depend on a live run.

### Mini recap

Gave the Mac App Store its own built-in `mas` provider, kept the Homebrew alias as a warned deprecation, and aligned specifications, guides, manual and changelog. Proposed learning route: none.

## Discussion

### Origin and approval

The mas-model run on 15 October 2026 recommended against a provider of its own under the state-of-play burn-down rule. Kris chose the alternative the same day, recorded in the mac-studio-bootstrap decisions log as MAS-PROVIDER: "Lets do this now, so its done done." That is an explicit exception to the burn-down rule; it adopts this record at Now and authorises local, fixture-backed delivery to Awaiting review, with the provider named `mas` as the thread proposed. It grants no `rig apply`, no personal-configuration change, no acceptance, no push and no release.

### Naming

`mas` follows the existing built-in convention, which names a provider after the native manager it runs (`homebrew`, `uv`, `mise`, `npm`, `chezmoi`) under [ADR-KI-TOOL-RIG-005](../decisions/ADR-KI-TOOL-RIG-005-provider-execution-contract.md) and [XDR-KI-TOOL-RIG-001](../decisions/XDR-KI-TOOL-RIG-001-executable-provider-boundary.md). The kind is `app`, because `mas` installs only applications and a kind of `mas` under provider `mas` would say nothing.
