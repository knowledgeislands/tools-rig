---
id: KI-TOOL-RIG-CORE-059
area: CORE
title: Mac App Store provider
purpose: capability
initiative: rig
kind: deliver
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: b5011d53957719d19404eeac1721339dc9f6ae38
created_at: 2026-10-15T01:40:07Z
updated_at: 2026-10-15T01:40:07Z
---

# KI-TOOL-RIG-CORE-059: Mac App Store Provider

## Goal

Rig installs, observes, upgrades and removes Mac App Store applications through a built-in `mas` provider of their own, declared as `install.provider = "mas"` with `install.kind = "app"` and a numeric App Store identity as `install.locator`. Every Rig output for these applications names the `mas` provider, never `homebrew`. The former `install.provider = "homebrew"` with `install.kind = "mas"` keeps working as a deprecated alias, which `rig doctor` warns about, so live configurations keep applying until they are migrated.

## Context

App Store applications are declared today under the Homebrew provider with kind `mas`, although Rig never runs `brew` for them: `rig_provider_executable` maps `homebrew:mas` to the `mas` executable (`src/rig/21-provider-state.bash`). The grouping is only a label, but it is what Rig prints, so status, plans, apply history and upgrade reports name `homebrew` for an App Store copy. On 15 October 2026 that confused the Telegram decision on Mac Studio `sol`, where Rig output said "homebrew" for the App Store build ([mas-model run report](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_THREADS/mac-studio-bootstrap/mas-model.report.md)). Kris's point was that Homebrew and the App Store are different managers, "like brew and npm".

## Boundary

- **In:** a built-in provider identity and adapter `mas` with the single kind `app`; numeric-locator validation; observation through `mas list`, installation through `mas install ID`, attended upgrade through `mas upgrade ID` and the unattended `interactive-required` exclusion; native removal through `[remove.ID]` with the existing `sudo -n` rule; `updates = "self"` or `"managed"` and application-source observation; the Homebrew `mas` formula as a deferred executable prerequisite inside one apply, as `mise` already is; the deprecated alias for tools, variants and removals, with a `rig doctor` warning; specifications, guides, manual, changelog and Bats tests.
- **Out:** migrating any personal declaration, which belongs to the chezmoi source and a separate run; App Store sign-in or account handling; `mas` inventory for `rig capture` or `doctor --unmanaged`; resolving App Store identities over the network; carrying apply-history rows recorded under `homebrew` across to `mas`, which [RIG-STATE-035](../specs/state.md) forbids for a replacement provider.

## Current state

- `homebrew:mas` appears as an adapter-and-kind pair in configuration validation, provider invocation, observation, application update policy, application-source detail, software removal and lifecycle upgrade (`src/rig/10-configuration.bash`, `21-provider-state.bash`, `27-software-removal.bash`, `40-publication-lifecycle.bash`).
- The Homebrew adapter's lifecycle exports `NONINTERACTIVE=1` and branches on kind `mas` to call `mas upgrade ID`; an unattended run already reports App Store targets `unavailable` with `interactive-required` (`rig_lifecycle_requires_person`).
- Kris's configuration declares 13 tools with `install.provider = "homebrew"` and `install.kind = "mas"` in chezmoi `dot_config/rig/conf.d/private_10-applications.toml`, and the `mas` executable itself as the Homebrew formula `tool.mas`.

## Steps

- [ ] Register `mas` as a built-in provider and adapter; accept kind `app` only; require a numeric locator; reject `[provider.mas]` adapter or capability declarations as for every built-in.
- [ ] Rewrite each tool, variant and `[remove.ID]` declaration of provider `homebrew` with kind `mas` to provider `mas` with kind `app` at load, before bindings are synthesised, and record it for `rig doctor`, which lists each one under a Warnings section and counts it in `warn` without changing the verdict.
- [ ] Move observe, install, upgrade, removal, update-policy and application-source handling from `homebrew:mas` to `mas:app`, with no Homebrew environment for App Store calls.
- [ ] Let an earlier Homebrew formula `mas` in the same plan satisfy the `mas` executable for a tool that requires it.
- [ ] Update Bats tests to the new form, and add alias, doctor-warning, output-naming and prerequisite coverage.
- [ ] Align the configuration, orchestration and state specifications, the user guides, help, manual and changelog; assemble `bin/rig`; run the complete local gate.

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

## Discussion

### Origin and approval

The mas-model run on 15 October 2026 recommended against a provider of its own under the state-of-play burn-down rule. Kris chose the alternative the same day, recorded in the mac-studio-bootstrap decisions log as MAS-PROVIDER: "Lets do this now, so its done done." That is an explicit exception to the burn-down rule; it adopts this record at Now and authorises local, fixture-backed delivery to Awaiting review, with the provider named `mas` as the thread proposed. It grants no `rig apply`, no personal-configuration change, no acceptance, no push and no release.

### Naming

`mas` follows the existing built-in convention, which names a provider after the native manager it runs (`homebrew`, `uv`, `mise`, `npm`, `chezmoi`) under [ADR-KI-TOOL-RIG-005](../decisions/ADR-KI-TOOL-RIG-005-provider-execution-contract.md) and [XDR-KI-TOOL-RIG-001](../decisions/XDR-KI-TOOL-RIG-001-executable-provider-boundary.md). The kind is `app`, because `mas` installs only applications and a kind of `mas` under provider `mas` would say nothing.
