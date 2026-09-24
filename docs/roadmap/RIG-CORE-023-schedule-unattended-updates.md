---
id: RIG-CORE-023
area: CORE
title: Schedule unattended updates
theme: orchestration
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: 27fced00b00fa7ab5adff6e7d7a9cf9a0e5999ff
created_at: 2026-09-23T14:43:03Z
updated_at: 2026-09-24T14:05:00Z
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

- [ ] Add `--unattended` to `rig update` and `rig maintain`, rejecting it alongside the existing option grammar.
- [ ] Give every provider invocation in an unattended run stdin from `/dev/null`, and export `NONINTERACTIVE=1` for the Homebrew adapter.
- [ ] Report a task that cannot proceed without a person as `unavailable` with a detail naming the reason, keeping the run's exit status at 1.
- [ ] Write `${XDG_STATE_HOME}/rig/last-update` at the end of an unattended run, carrying the outcome line, the timestamp, and the per-task rows.
- [ ] Add `RIG-STATE-030` stating the last-run report's location, shape, and stability.
- [ ] Report an observed competing auto-update agent as doctor information.
- [ ] Document the recipe: a `scheduled-job` resource whose program is `rig update --unattended`, and what to retire once it runs.
- [ ] Reproject `man/rig.1`, `rig --help`, shell completion, `README.md`, and `CHANGELOG.md`.
- [ ] Cover it in the tests: the flag's grammar, stdin isolation, the `unavailable` report, the written file's shape, and the doctor information.

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

## Discussion

The value here is not automation for its own sake — it is that a person currently gets a notification about Homebrew and silence about everything else, which reads as "the machine is up to date" when it is not. One scheduled pass reporting one honest outcome across every declared manager is strictly more informative than one manager reporting well and five not reporting at all.

The design risk is scope creep into a scheduler. Rig's manager-of-managers model works because Rig owns selection, ordering, dispatch, and reporting while native tools keep their own execution. A scheduled job is machine state, and machine state is already a declared resource kind with a provider behind it. The moment Rig grows its own timer, daemon, or notification stack, it has stopped being the thing that describes a working setup and started being one more background agent to maintain.

The credential question is the one that decides whether this is worth building. An unattended run that can block on a password is worse than no scheduled run, because it fails silently and invisibly. If the unattended contract cannot honestly guarantee "never prompts, always reports", this should stay unscheduled.
