---
id: RIG-CORE-023
area: CORE
title: Schedule unattended updates
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 27fced00b00fa7ab5adff6e7d7a9cf9a0e5999ff
created_at: 2026-09-23T14:43:03Z
updated_at: 2026-09-25T11:15:00Z
---

## Goal

Let a person schedule Rig's own update run in place of each manager's private auto-update job, so one scheduled pass advances everything the profile declares and reports one truthful outcome, instead of Homebrew updating itself on its own timer while uv, mise, npm, chezmoi, and the Skills CLI go unattended.

## Context

Homebrew's `brew autoupdate` tap installs a launchd agent that runs `brew update` and optionally `brew upgrade` on an interval, can prompt for user credentials mid-run, and posts a notification listing failures. It is useful, and it is also narrow: it covers exactly one of the managers Rig orchestrates. A machine running Rig therefore ends up with one manager on a private schedule and the rest advanced only when someone remembers to type `rig update`.

Rig already owns the pieces this needs. `rig update` dispatches independent per-target operations across every supported provider, and since `RIG-ORCH-024` it reports completed, failed, unavailable, and skipped outcomes per task rather than stopping the run at the first finding. Rig also already models `scheduled-job` resources with the launchd provider, so a person can in principle declare a job whose `program` is `rig update` today.

What is missing is the part that makes such a job trustworthy without a person watching it: an unattended execution mode that cannot block on a credential prompt, a durable place for the run's outcome to land, and a documented recipe that says what to declare and what to retire.

## Boundary

This work concerns how an update run behaves when nobody is watching it, and how its outcome is recorded. It does not change what `rig update` selects, which providers it dispatches to, the per-task outcome vocabulary, or exit status semantics for an interactive run.

Rig must not grow a scheduler. The scheduled job belongs in the person's own configuration as a declared `scheduled-job` resource, materialised by the existing launchd provider — portable behaviour here, personal choices in configuration. Rig must not install, modify, or remove another tool's auto-update agent on the person's behalf, and must not acquire a runtime dependency beyond Bash in order to notify.

## Current state

`rig update` and `rig maintain` share `rig_command_lifecycle`, which plans per-target tasks, dispatches them independently, and reports `completed`, `failed`, `unavailable`, or `skipped` per task with a `Summary:` line and, since RIG-CLI-014, a stated outcome. Every provider invocation inherits Rig's own stdin, so a provider that asks for a password under launchd blocks until the job is killed. Nothing is written anywhere durable: the run's result exists only in whatever captured its output. Rig already models `scheduled-job` resources through the launchd provider, so the job itself needs no new machinery.

## Decisions

- **`--unattended` on `rig update` and `rig maintain`, and nothing else.** No new command, no daemon, no timer. The flag states that nobody is watching, and everything it changes follows from that one fact.
- **An unattended run never prompts.** Every provider invocation takes its stdin from `/dev/null`, so a provider that asks a question fails immediately instead of hanging a launchd job forever. Rig additionally exports `NONINTERACTIVE=1` for the Homebrew adapter, which is Homebrew's own documented way to say the same thing.
- **A task that needs a person reports `unavailable`, not a new state.** From an unattended run's point of view the target genuinely is not available to it, and `unavailable` already means exactly that. The detail clause names the reason, the run returns 1, and the privileged part waits for an interactive `rig update`. Inventing a sixth outcome would make every consumer of the vocabulary handle a case that means what an existing one already means.
- **The run's outcome lands in `${XDG_STATE_HOME:-$HOME/.local/state}/rig/last-update`.** One file, overwritten each unattended run, holding the stated outcome line, the timestamp, and the same tab-separated rows the command printed. It is a public contract so a notification wrapper, a status line, or `rig doctor` can read it without parsing terminal output.
- **Rig does not notify.** A macOS notification means `osascript` or `terminal-notifier`, and Rig's runtime dependency is Bash. The declared job's own wrapper reads `last-update` and notifies however the person wants. This is the boundary that keeps Rig from becoming one more background agent.
- **Rig reports a competing updater as information, never retires it.** `rig doctor` names Homebrew's `brew autoupdate` agent when it observes it, in the same voice it uses for unmanaged listeners. Coexistence is the person's call; Rig states the fact and stops.
- **The scheduled job runs `rig update --unattended`.** `rig maintain` accepts the flag for symmetry but is not what the documented recipe schedules: maintenance is the operation most likely to want a person. The job honours `--profile` exactly as an interactive run does.

## Steps

- [x] Add `--unattended` to `rig update` and `rig maintain`, rejecting it alongside the existing option grammar.
- [x] Give every provider invocation in an unattended run stdin from `/dev/null`, and export `NONINTERACTIVE=1` for the Homebrew adapter.
- [x] Report a task that cannot proceed without a person as `unavailable` with a detail naming the reason, keeping the run's exit status at 1.
- [x] Write `${XDG_STATE_HOME}/rig/last-update` at the end of an unattended run, carrying the outcome line, the timestamp, and the per-task rows.
- [x] Add `RIG-STATE-030` stating the last-run report's location, shape, and stability.
- [x] Report an observed competing auto-update agent as doctor information.
- [x] Document the recipe: a `scheduled-job` resource whose program is `rig update --unattended`, and what to retire once it runs.
- [x] Reproject `man/rig.1`, `rig --help`, shell completion, `README.md`, and `CHANGELOG.md`.
- [x] Cover it in the tests: the flag's grammar, stdin isolation, the `unavailable` report, the written file's shape, and the doctor information.

## Files touched

- `src/rig/00-runtime.bash` for help, completion, and the state path.
- `src/rig/20-orchestration.bash` for the doctor information.
- `src/rig/40-publication-lifecycle.bash` for the lifecycle flag, stdin isolation, and the report.
- `bin/rig` by assembly.
- `docs/specs/state.md`, `docs/specs/orchestration.md`.
- `docs/guides/user/unattended-updates.md`, `docs/guides/user/README.md`, `docs/guides/user/commands.md`, `docs/guides/user/operational-resources.md`.
- `man/rig.1`, `README.md`, `CHANGELOG.md`.
- `tests/rig.bats`, `tests/rig-lifecycle.bats`.

## Verify

- `rig update --unattended` with a provider that reads stdin reports that target as `unavailable` and returns promptly rather than blocking.
- `${XDG_STATE_HOME}/rig/last-update` exists after an unattended run and carries the same outcome and rows the run printed.
- An interactive `rig update` is unchanged: same selection, same dispatch, same vocabulary, same statuses, and no file written.
- `rig doctor` names a competing Homebrew auto-update agent as information without changing its exit status.
- The complete local gate, and CI green on both runners.

## Dependencies / blocks

Nothing blocks it. It builds on RIG-CLI-014's stated outcome, which is what the last-run report records.

## Documentation impact

### Decision Records

None. Declaring the job as a `scheduled-job` resource and leaving notification to its wrapper is an application of [ADR-RIG-001](../decisions/ADR-RIG-001-shell-only-runtime.md) and [ADR-RIG-006](../decisions/ADR-RIG-006-declarative-operational-resources.md), not a new commitment.

### Specifications

`docs/specs/state.md` gains RIG-STATE-030 for the last-run report. `docs/specs/orchestration.md` states the unattended contract: never prompts, reports `unavailable` for work needing a person, and changes nothing else about selection or dispatch.

### Guides

A new `docs/guides/user/unattended-updates.md` carries the recipe and the notification hand-off.

### Roadmap

None expected.

## Review

### Delivered

`rig update` and `rig maintain` accept `--unattended`. No other command does, no new command exists, and nothing schedules anything: the flag states that nobody is watching, and every behaviour it changes follows from that one fact.

Within an unattended run, each provider invocation reads end-of-file rather than the terminal, and the Homebrew adapter is additionally told `NONINTERACTIVE=1`, which is Homebrew's own documented way of saying the same thing. Work that cannot proceed without a person — currently a Mac App Store upgrade, detected from the Homebrew `mas` kind — is reported `unavailable` with detail `interactive-required` before its provider is invoked; the rest of the run completes and the command returns 1, so the gap stays visible rather than being absorbed. Selection, ordering, dispatch, the per-task vocabulary, and the exit statuses are otherwise identical to an interactive run.

A non-dry unattended run replaces `${XDG_STATE_HOME:-$HOME/.local/state}/rig/last-update` atomically. The report is tab-separated, opens with `rig-last-run` and its version, carries `action`, `profile`, `platform`, `finished`, `status`, `result`, `detail`, and `summary`, then the same `TARGET`/`PROVIDER`/`RESULT`/`DETAIL` rows the run printed. It carries no path, locator, argument, credential, or native provider output. Rig does not notify; the guide shows the wrapper that reads the file and does.

`rig doctor` names an observed competing auto-update agent — Homebrew's `brew autoupdate` — as information alone, adding no finding and changing no exit status. A `provider.homebrew` `autoupdate-interval` declaration suppresses it, because that agent is then Rig's own rather than a competing one.

### Change Summary

- `src/rig/00-runtime.bash` — `RIG_UNATTENDED` state, the help tail, and `--unattended` in both bash and zsh completion for `update` and `maintain`.
- `src/rig/40-publication-lifecycle.bash` — the flag's grammar and usage text, `rig_lifecycle_requires_person`, `rig_write_last_run_report`, stdin isolation at the single dispatch site, `NONINTERACTIVE=1` for Homebrew, and row capture for the report. Two fixes landed alongside: the preflight no longer loses its resolved executable when a Homebrew provider declares no manifest, and the needs-a-person predicate keeps the executable it found before reading configuration.
- `src/rig/20-orchestration.bash` — `rig_doctor_competing_autoupdate` and its use in `rig_command_doctor`; the incompatible-tools scan no longer trips `set -u` on a configuration with no tools.
- `bin/rig` — regenerated by `scripts/assemble-rig --write`.
- `docs/specs/state.md` — `RIG-STATE-030`, the last-run report's location, shape, and stability.
- `docs/specs/orchestration.md` — `RIG-ORCH-034`, the unattended execution contract.
- `docs/guides/user/unattended-updates.md` (new), `docs/guides/README.md`, `docs/guides/user/README.md`, `docs/guides/user/commands.md`, `docs/guides/user/operational-resources.md`.
- `man/rig.1`, `CHANGELOG.md`.
- `tests/rig-lifecycle.bats` (five tests, plus `RIG_STATE_HOME` isolation for the whole file), `tests/rig-macos.bats` (one test), `tests/rig.bats` (four completion and synopsis assertions).

### Verification

- `ki repo audit --repo .` — PASS across 16 skills.
- `shellcheck` and `bash -n` over `bin/rig`, `install.sh`, `src/rig/*.bash`, `scripts/assemble-rig`, `scripts/benchmark-rig`, `scripts/smoke-native-providers` — clean.
- `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers` — pass.
- `mandoc -T lint man/rig.1` — clean.
- `bats tests/` — the suite passes. One run reported `representative catalogue stays within the portable query guard` failing while the machine sat at load averages 16.66/22.14/35.75; re-running `tests/rig-performance.bats` on a quiet tree passed all three, which matches that test's own note about contention.
- New tests cover the flag's grammar on `update` and `maintain` and its rejection everywhere else, stdin reaching end-of-file, `NONINTERACTIVE=1` reaching the Homebrew adapter, the `unavailable` report for a `mas` declaration, the written report's shape, the dry run writing nothing, an unsafe report target being left alone, and the doctor information appearing, disappearing when declared, and never printing a `LaunchAgents` path.

### Outstanding concerns

"Needs a person" is currently recognised only for the Homebrew `mas` kind. That is the case this item set out to solve and it is honest about what it detects, but any other provider that demands an interactive credential will fail on end-of-file rather than being reported `unavailable` ahead of time. A post-hoc non-zero exit is not distinguishable from an ordinary failure, so widening this needs another pre-emptive signal per provider, not a cleverer classifier.

`tests/rig-lifecycle.bats` now pins `RIG_STATE_HOME` into a per-test directory. Eight other bats files do not, and an ambient `XDG_STATE_HOME` therefore still reaches them; no current test writes state, but the isolation gap is real and worth closing before one does.

The scheduled job itself is the person's to install. Rig declares the resource kind and `rig apply` materialises it, but nothing in this repository installs a job on this machine — the chezmoi source owns that, as it owns every other host-state decision.

### Post-change review

The lifecycle path picked up two pre-existing bugs while this work was being tested, both from the same cause: `RIG_VALUE` is a single global return channel, so any helper called between a value being produced and being stored silently overwrites it. The preflight lost a Homebrew executable this way, and the new needs-a-person predicate would have lost it again. Both are fixed locally by keeping the value in a named local immediately, which is the right fix for each site, but the pattern will recur. A future item could give the lifecycle path its own return variables rather than sharing the one channel with configuration lookups.

The report is written from `rig_run_lifecycle_tasks` rather than from a general outcome hook, so only lifecycle runs produce one. That is deliberate — `last-update` records a run that changed the machine — but if another command ever needs to record itself, the writer should move rather than be copied.

### Mini recap

One flag, two commands, and a file a wrapper can read. The scheduler stays outside Rig, the notification stays outside Rig, and what Rig owns is the honest report of what one pass actually did.

## Discussion

The value here is not automation for its own sake — it is that a person currently gets a notification about Homebrew and silence about everything else, which reads as "the machine is up to date" when it is not. One scheduled pass reporting one honest outcome across every declared manager is strictly more informative than one manager reporting well and five not reporting at all.

The design risk is scope creep into a scheduler. Rig's manager-of-managers model works because Rig owns selection, ordering, dispatch, and reporting while native tools keep their own execution. A scheduled job is machine state, and machine state is already a declared resource kind with a provider behind it. The moment Rig grows its own timer, daemon, or notification stack, it has stopped being the thing that describes a working setup and started being one more background agent to maintain.

The credential question is the one that decides whether this is worth building. An unattended run that can block on a password is worse than no scheduled run, because it fails silently and invisibly. If the unattended contract cannot honestly guarantee "never prompts, always reports", this should stay unscheduled.
