---
id: KI-TOOL-RIG-CORE-070
area: CORE
title: Handler read-back after confirmation
purpose: corrective
theme: rig
kind: deliver
status: awaiting-review
horizon: now
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: 5d2472f5898ef9cc3b5813fbc2780b4171ee49d9
created_at: 2026-10-23T06:43:00Z
updated_at: 2026-10-27T02:55:00Z
---

# KI-TOOL-RIG-CORE-070: Read Back a Default Handler Only After macOS Confirms It

## Goal

An attended `rig apply` of a `default-application` resource that makes macOS ask the person to confirm the new handler records the outcome the person chose. A change the person accepts is recorded as applied on the first run, with no failed-apply record and no second run needed to clear it; a change the person declines, or never answers, is still reported as not effective.

## Context

On 23 October 2026 the chezmoi work applied the `.sh`, `.zsh` and `.toml` handlers on `terra` (Rig at `87fa261`). Each first apply failed with "handler assignment not effective; native confirmation may be required", although macOS had shown a confirmation prompt. About a minute after Kris accepted it, each extension resolved to Zed, and a second, unprompted apply completed (`reconciled:extension:toml`) and cleared the failed-apply records. Evidence: the [handlers-retry](/Users/krisbrown/.local/state/ki/agents/chezmoi/handlers-retry.report.md) and [drift-resolve](/Users/krisbrown/.local/state/ki/agents/chezmoi/drift-resolve.report.md) reports. In the earlier [stage3](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3.report.md) run Kris declined the prompt by mistake, and the same failure wording appeared.

The [stage3-blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3-blind.report.md) located the cause: the adapter accepts the native setter's success and then [reads the handler back](../../src/rig/29-default-applications.bash) at once, so the observation still shows the old handler while the prompt is open. The "native confirmation may be required" wording is a generic suggestion, not detection of a dialog.

This is distinct from [KI-TOOL-RIG-CORE-069](KI-TOOL-RIG-CORE-069-dynamic-type-handler-fallback.md): `.sh` and `.zsh` are declared types (`public.shell-script`, `public.zsh-script`), and the timing affects declared and dynamic types alike.

## Boundary

- **In:** a bounded wait or poll for the effective handler after the setter succeeds, so a confirmation the person answers within the bound is observed; distinct reporting of a timeout, a decline and an ineffective assignment; Bats coverage through the bridge fixture; the default applications guide.
- **Out:** the dynamic-type setter route, which KI-TOOL-RIG-CORE-069 owns; detecting or answering the macOS dialog programmatically; any live handler change during delivery.

## Current state

Grounded at `5d2472f5898ef9cc3b5813fbc2780b4171ee49d9` on 27 October 2026. `rig_default_application_apply` in [29-default-applications.bash](../../src/rig/29-default-applications.bash) called the native setter, reobserved once at the same instant and failed with "handler assignment not effective; native confirmation may be required" whenever the old handler was still observed, so an accepted prompt was recorded as a failed apply until a second run. Nothing distinguished an unanswered prompt, a declined one and an assignment macOS silently refused, and no wait existed for attended or unattended runs.

## Steps

- [x] Add `rig_default_application_confirmed`: after a successful setter whose read-back still shows the previous handler, reobserve until the declared handler appears or a bounded wait is spent; the bound is `RIG_HANDLER_CONFIRMATION_TIMEOUT` seconds when set, else 120 when standard input is a terminal and 0 otherwise, polled every `RIG_HANDLER_CONFIRMATION_INTERVAL` seconds (default 2).
- [x] Report four outcomes distinctly: confirmed, recorded as applied on this run; unattended, failing at once saying nothing waited for the prompt; unanswered, failing once the wait is spent saying the prompt was declined or not answered; ineffective, when the observation detail is anything other than a handler mismatch.
- [x] Extend the osascript bridge fixture with `confirm-after:<n>` (the handler appears on the n-th observation after apply) and `decline` behaviours, and add Bats coverage: an attended apply that records the handler once confirmed with no second apply, a declined or unanswered prompt failing once the budget is spent, and the unattended case.
- [x] Align RIG-ORCH-044, the default applications guide, the man page and the changelog; reassemble `bin/rig`; run the full gate.

## Files touched

- `src/rig/29-default-applications.bash`, `src/rig/00-runtime.bash`, and the assembled `bin/rig`
- `tests/rig-default-applications.bats`
- `docs/specs/orchestration.md` (RIG-ORCH-044), `docs/guides/user/default-applications.md`, `man/rig.1`, `CHANGELOG.md`
- This record.

## Verify

- `bats tests/` passes, including the two new default-application tests and the reworded unattended one.
- `shellcheck` and `bash -n` over the modules and executable, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1`, `git diff --check` and `ki repo audit --repo .` pass.
- An attended `rig apply` of a declared-type handler that raises the macOS prompt, on `terra` or `sol`, records the handler as applied on the run the prompt is accepted; left to Kris, since no live handler change is in scope.

## Dependencies / blocks

None. [KI-TOOL-RIG-CORE-069](KI-TOOL-RIG-CORE-069-dynamic-type-handler-fallback.md) stays separate: the wait sits after the setter call, whichever setter route 069 chooses, so a move to an asynchronous setter would reuse rather than replace it.

## Documentation impact

### Decision Records

None.

### Specifications

RIG-ORCH-044 in `docs/specs/orchestration.md` states the bounded wait, its environment variables and the four outcomes.

### Guides

`docs/guides/user/default-applications.md` tells a reader what happens at the prompt, attended and unattended, and names the two variables; `man/rig.1` carries the same under default applications.

### Roadmap

This record only.

## Review

### Delivered

The Boundary's In clause and nothing more: a bounded poll for the effective handler after the setter succeeds, distinct reporting of an unanswered or declined prompt, an unattended run and an ineffective assignment, Bats coverage through the bridge fixture, and the guide, spec, man page and changelog aligned. The dynamic-type setter route is untouched, no dialog is detected or answered programmatically, and no live handler was changed. Immutable baseline `5d2472f5898ef9cc3b5813fbc2780b4171ee49d9` on `main`.

Adopted from triage to Now and delivered on 27 October 2026 under Kris's "Do the quick wins now" on the ways-of-working [roadmap sweep](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/design/roadmap-sweep.md), bucket C. The Discussion's open bound is settled as 120 seconds attended, read from standard input being a terminal, the convention the sudo session check already uses, and 0 unattended, with `RIG_HANDLER_CONFIRMATION_TIMEOUT` overriding either so a scheduled run can opt in or an interactive one opt out.

### Change Summary

- `src/rig/29-default-applications.bash`: `rig_default_application_confirmed` polls the observation within the budget and sets `RIG_HANDLER_CONFIRMATION` to `confirmed`, `unanswered` or `unattended`, or returns the ineffective detail; `rig_default_application_apply` reports each outcome with its own message, the confirmed case returning success.
- `src/rig/00-runtime.bash`: `RIG_HANDLER_CONFIRMATION` and `RIG_HANDLER_CONFIRMATION_BUDGET` initialised for `set -u`.
- `tests/rig-default-applications.bats`: the fixture's `confirm-after:<n>` and `decline` behaviours; "an attended apply records the handler once macOS confirms it", "a declined or unanswered confirmation fails once the wait budget is spent", and the unattended wording in "native failure and ineffective assignment keep apply incomplete".
- `docs/specs/orchestration.md`, `docs/guides/user/default-applications.md`, `man/rig.1`, `CHANGELOG.md`: the wait, the variables and the outcomes described.
- `bin/rig`: reassembled.

### Verification

- `bats tests/`: 648 tests pass, the two new default-application tests among them.
- `shellcheck` and `bash -n` over `bin/rig`, `install.sh`, every module and the three scripts: pass.
- `scripts/assemble-rig --check`, `scripts/benchmark-rig` (show 2s, show-all 2s, status 3s, all within budget), `scripts/smoke-native-providers` (npm, chezmoi, mas pass), `mandoc -T lint man/rig.1`, `git diff --check`: pass.
- `ki repo audit --repo .`: FAIL=1 WARN=4, the one failure being SHELL-HOOK's reading of the untouched `.githooks/pre-commit` (it takes the hook's `quiet_audit` function as a non-check-only gate), present at baseline and not changed by this record.
- Pre-commit hook (shellcheck, `bash -n`, mandoc lint, staged `ki-repo-tools` audit): ran on the commit.
- Not run: an attended `rig apply` raising the real macOS prompt.

### Outstanding concerns

- A declined prompt and an unanswered one are indistinguishable by observation, since both leave the previous handler in place; the message says so rather than guessing, and the budget is the only bound on a decline.
- Attended is read from standard input being a terminal; a run piped from a terminal session gets no wait unless it sets `RIG_HANDLER_CONFIRMATION_TIMEOUT`.
- The prompt is characterised on `terra` only; `sol` is left to Kris's attended apply.

### Post-change review

Goal met: an accepted prompt is recorded as applied on the run it is accepted, a declined or unanswered one is reported as not effective once the wait is spent, and an unattended run fails promptly with a named reason. Scope held to the In clause. Regression risk is low: a setter that reads back correctly at once takes the same path as before, unattended runs fail as they did with a clearer message, and only an attended run with the old handler still observed waits. Ready for acceptance.

### Mini recap

Delivered the bounded confirmation wait with its distinct outcomes, fixture behaviours, tests and documents; verified by the full gate; outstanding is the decline and no-answer ambiguity and an attended apply on `sol`. Learning route: none proposed.

## Discussion

- The bound needs choosing: long enough for an attended person to read and answer the prompt, short enough that an unattended run does not hang. Unattended applies never get a prompt answered, so they should fail promptly with a named detail.
- Observed on `terra`, macOS 27; the prompt has not been characterised on `sol`.
