---
id: RIG-CORE-044
area: CORE
title: Single sudo prompt
initiative: rig
kind: deliver
purpose: capability
component: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-10T16:40:00Z
updated_at: 2026-10-11T09:51:07Z
---

# RIG-CORE-044: Single Sudo Prompt

## Goal

An attended `rig apply` that will need administrator rights asks for the password once, at the start, and the run then completes without stopping at a later native prompt.

## Context

Handoff from the chezmoi source (the dotfiles repository), non-blocking. Kris asked for this on 2026-10-10 (chezmoi thread, Decision 37).

A full attended `rig apply` on the laptop was left running overnight. Hours in, Homebrew's Tailscale cask upgrade stopped at a `sudo` password prompt. Nothing else ran until Kris came back and typed the password, and in the meantime the upgrade had stopped Tailscale, so the laptop was off the tailnet. Several casks, package installers and some macOS settings need administrator rights, and each native tool asks for them at its own point in the run. Leaving an apply to finish unattended therefore only works if nothing in it needs `sudo`.

[RIG-ORCH-034](../specs/orchestration.md#rig-orch-034--unattended-lifecycle-execution) already handles unattended runs by closing native standard input, so a privileged step fails fast instead of waiting. This record is about the attended case, where a person is present at the start but may not stay.

## Boundary

- **In:** working out, during planning, whether a selected task may need administrator rights; asking for the password once before the first task when one may; keeping the `sudo` timestamp fresh until the run ends, and stopping the keepalive on every exit path, interruption included; a plain message when no prompt is needed; tests, spec, guide, help and manual alignment.
- **Out:** storing, caching or passing the password anywhere Rig controls; `sudoers` changes, `NOPASSWD` rules or askpass helpers; unattended runs, which keep the RIG-ORCH-034 contract; Homebrew or App Store sign-in prompts that are not `sudo`.

## Current state

Kris approved bounded adoption, routine planning and delivery under tools-burndown Decisions 1, 3 and 4. The generic feature was handed on from the chezmoi source, which retains personal configuration. No competing delivery owns this record. Native providers currently authenticate independently during attended apply.

## Steps

- [ ] Add explicit attended `apply --sudo` and determine from its scoped plan whether any native work may use the requested grant; dry-run and empty/satisfied selections do not authenticate.
- [ ] Validate the native grant before dispatch, refresh it noninteractively for the owned run and clean up the keeper on normal, failed and interrupted exits without storing a password or invalidating other native grants.
- [ ] Refuse a non-attended or unusable grant before dispatch; stop further tasks after refresh failure while allowing an inflight native operation to settle.
- [ ] Align specification, guide, help and manual; run isolated terminal/stub refusal, refresh, failure and signal fixtures plus the full local gate and prepare the Review packet.

## Files touched

Runtime option/help, apply, reconciliation cleanup and mutation-capture modules; a new sudo-session module and assembly manifest; assembled executable; focused sudo Bats fixtures using the existing inert sudo override and terminal helper; orchestration/state specs, user command guide, manual and changelog.

## Verify

Fixtures assert exactly one initial native validation, only noninteractive refresh calls, no password reads/storage, no mutation after refusal or unusable grant, no authentication for dry-run/no work, no terminal refusal bypass, refresh failure stops subsequent dispatch, normal/early-error/HUP/INT/TERM cleanup and no keeper surviving its owned run. Run the developer guide's complete gate, reference benchmark and rendered manual inspection, then review the actual diff and committed path roster.

## Dependencies / blocks

No required roadmap dependency. RIG-CORE-041 already contains sudo in test isolation. No live privileged command, sudoers/environment change, credential action or machine-specific configuration is authorised. Native App Store sign-in and other non-sudo authentication remain outside scope.

## Documentation impact

### Decision Records

Owner authority and routine bounded choices remain here; no new architectural decision is required.

### Specifications

Specify the opt-in attended grant, owned refresh lifetime, refusal/failure/interrupt outcome and native-policy boundary.

### Guides

Explain `apply --sudo`, native password entry, supported terminal timestamp policy, cleanup and limits; align help/manual.

### Roadmap

Keep this identity, immutable baseline and Review packet. Stop at Awaiting review without acceptance, closure or pruning.

## Discussion

### Approved routine choices

Use explicit `apply --sudo` as the person's declaration that selected native work may need privilege, rather than inventing package metadata inference. Ordinary apply never acquires a grant automatically. Preview and empty or fully satisfied selections explain that no prompt is needed. Actual selected work requires terminal stdin, native `sudo -v` once, and immediate `sudo -n -v` validation before dispatch. An owned background loop refreshes only with `sudo -n -v`, every 30 seconds by default; the bounded `RIG_SUDO_REFRESH_SECONDS` override (1–60 seconds) permits fixtures and shorter native policies. Cleanup stops and waits for the keeper and its sleep child on every catchable exit and does not invalidate native grants with `sudo -k`. The loop also stops if its backend owner disappears. Refresh failure stops further dispatch after the current native task returns; Rig does not forcibly kill an installer. Native terminal timestamp policy remains authoritative; revoked grants, custom timestamp policies and non-sudo authentication cannot be bypassed or promised away. No password is read, stored or supplied by Rig, and no sudoers change is proposed.

- **Mechanism.** The usual pattern is `sudo -v` up front, then a background loop that runs `sudo -n true` every minute or so while the run lasts. The native tools then find a fresh timestamp and do not prompt. Check that this holds for Homebrew's cask installer and `installer`, which call `sudo` themselves, and for macOS's per-terminal `tty_tickets` default, which ties the timestamp to the terminal Rig runs in.
- **When to ask.** Asking on every apply is noisy. Decide whether planning can tell which tasks need privilege (for example from cask artefacts such as `pkg` or `installer` stanzas, or from a declared flag), or whether a simpler `--sudo` option, a profile setting, or "ask whenever any cask or package install is selected" is enough at first.
- **Terminal ownership.** The prompt has to happen before the progress footer takes the terminal under [RIG-ORCH-019](../specs/orchestration.md#rig-orch-019--provider-progress-channel).
- **Failure.** If the password is refused or the keepalive later fails, decide whether the run stops or continues with privileged tasks reported as failed.
- **Security.** The keepalive extends an existing `sudo` grant for the length of a run Kris started, and only in that terminal. Rig never sees the password itself. Record this in the spec so it stays deliberate.
