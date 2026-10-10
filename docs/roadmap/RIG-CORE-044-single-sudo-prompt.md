---
id: RIG-CORE-044
area: CORE
title: Single sudo prompt
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-10T16:40:00Z
updated_at: 2026-10-10T16:40:00Z
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

## Discussion

- **Mechanism.** The usual pattern is `sudo -v` up front, then a background loop that runs `sudo -n true` every minute or so while the run lasts. The native tools then find a fresh timestamp and do not prompt. Check that this holds for Homebrew's cask installer and `installer`, which call `sudo` themselves, and for macOS's per-terminal `tty_tickets` default, which ties the timestamp to the terminal Rig runs in.
- **When to ask.** Asking on every apply is noisy. Decide whether planning can tell which tasks need privilege (for example from cask artefacts such as `pkg` or `installer` stanzas, or from a declared flag), or whether a simpler `--sudo` option, a profile setting, or "ask whenever any cask or package install is selected" is enough at first.
- **Terminal ownership.** The prompt has to happen before the progress footer takes the terminal under [RIG-ORCH-019](../specs/orchestration.md#rig-orch-019--provider-progress-channel).
- **Failure.** If the password is refused or the keepalive later fails, decide whether the run stops or continues with privileged tasks reported as failed.
- **Security.** The keepalive extends an existing `sudo` grant for the length of a run Kris started, and only in that terminal. Rig never sees the password itself. Record this in the spec so it stays deliberate.
