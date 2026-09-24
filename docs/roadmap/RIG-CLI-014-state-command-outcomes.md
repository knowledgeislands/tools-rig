---
id: RIG-CLI-014
area: CLI
title: State command outcomes
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: 565e34b4d04f3988ace186dd2c79ccc6d4b7ad63
created_at: 2026-09-24T12:30:00Z
updated_at: 2026-09-24T12:30:00Z
---

## Goal

Someone who runs a Rig command can see, at the end of its response, what actually happened and which exit status says so — without reading the status number out of the shell, and without inferring a verdict from a table they have to count.

## Context

Rig already exits with a well-chosen status. `0` is success or a healthy verdict, `1` is a valid observation with findings or provider work that failed, `2` is a rejection before work could start, and several commands pass a provider's native status straight through. The statuses are documented in the manual's EXIT STATUS section and summarised in the commands guide.

What is missing is the statement. A `rig status` run ends with a table and a summary line about counts; whether that constitutes healthy is left to the reader. A `rig apply` run that partly failed ends with rows, some of which say `failed`. A command that exits `2` prints `rig: error: ...` and stops, which is clear, but a command that exits `1` after completing independent safe work looks, on screen, much like one that exited `0`.

The result is that the exit status is the only unambiguous verdict, and it is the one thing the terminal does not show you.

## Boundary

This concerns what Rig says at the end of a command and how its statuses are documented. It does not change any exit status, any table, or any JSON payload. It does not introduce a new verbosity system: the outcome line reuses the disclosure rules progress already established.

## Current state

`rig` writes its answer to stdout and everything else to stderr. RIG-STATE-028 makes that a contract for `--format json`: the payload is the only thing on stdout, and progress and native diagnostics stay on stderr. Progress is controlled by `RIG_PROGRESS` with `automatic`, `always` and `never`, where `automatic` means "when stderr is a terminal", and `tests/rig.bats` asserts that `never` leaves stderr empty.

Exit statuses are documented in `man/rig.1` under EXIT STATUS — Rig-owned `0`, `1` and `2`, plus the commands that return a provider's native status and the `129`, `130`, `143` signal statuses for interrupted publication — and in `docs/guides/user/commands.md` under "Read exit statuses". No specification clause states the set as a contract, and neither document says what a command will tell you about its own outcome.

## Decisions

- **The outcome line goes to stderr.** stdout carries the answer. A verdict written to stdout would break RIG-STATE-028's payload purity and would corrupt every table a script already parses.
- **It is controlled like progress, by `RIG_OUTCOME`, defaulting to `automatic`.** A person at a terminal gets the statement they asked for; a script that pipes stderr gets nothing new unless it opts in with `always`. `never` silences it. Reusing the progress vocabulary avoids inventing a second verbosity model for the same question.
- **A rejection is not restated.** A command that exits `2` has already printed `rig: error: ...` naming the cause. Adding a second line after it would say less than the first and read as an artefact of tooling.
- **One line, fixed shape, no colour.** `rig: <command> <result>: status <n>` followed by an optional detail clause. `result` is a small closed vocabulary so it can be read at a glance and grepped: `succeeded`, `healthy`, `unhealthy`, `incomplete`, `failed`, `rejected`.
- **The statuses become a specification clause.** They are a public interface: a person writes `|| exit` against them. A clause in `docs/specs/state.md` states the set, what each means, which commands pass a native status through, and that the set may gain a value but may not repurpose one.

## Steps

- [ ] Add `RIG_OUTCOME` with the same `automatic`, `always`, `never` semantics as `RIG_PROGRESS`, resolved once in the runtime alongside it.
- [ ] Emit one outcome line on stderr as the last thing a command writes, for every command that reaches a terminal state other than a status-2 rejection.
- [ ] Derive `result` from what the command already computed — the health verdict for observation commands, the completed/failed/skipped tallies for operational ones, the native status for pass-through ones — rather than from a second traversal.
- [ ] Carry a detail clause naming the counts or the finding that decided the status, so the line is useful without the table above it.
- [ ] Add `RIG-STATE-029` stating the exit-status contract and the outcome line.
- [ ] Extend `man/rig.1`: an ENVIRONMENT entry for `RIG_OUTCOME` and an EXIT STATUS section that names the pass-through commands and signal statuses as part of the contract rather than as prose around the table.
- [ ] Extend `docs/guides/user/commands.md` so "Read exit statuses" shows the line a person will actually see beside the status it reports.
- [ ] Cover it in `tests/rig.bats`: the line appears under `always`, is absent under `never`, never reaches stdout, never appears after a status-2 rejection, and reports each result value at least once.

## Files touched

- `src/rig/00-runtime.bash` for the `RIG_OUTCOME` resolution and the emitter.
- `src/rig/30-commands.bash` and `src/rig/40-publication-lifecycle.bash` for the terminal call sites.
- `bin/rig` by assembly.
- `docs/specs/state.md`, `man/rig.1`, `docs/guides/user/commands.md`, `CHANGELOG.md`.
- `tests/rig.bats`.

## Verify

- `bats tests/` green, including the existing assertions that `RIG_PROGRESS=never` leaves stderr empty — which now also requires `RIG_OUTCOME=never` to be honoured independently.
- `rig status --format json 2>/dev/null` still emits exactly one line on stdout.
- A run of each of `status`, `doctor`, `apply`, `update`, `run`, `publish` under `RIG_OUTCOME=always` ends with one line naming a result and a status that matches `$?`.
- The complete local gate, and CI green on both runners.

## Dependencies / blocks

Depends on [RIG-DIST-008](RIG-DIST-008-restore-the-verification-gate.md) only in the sense that its gate is what will prove this on both platforms. Nothing blocks it.

## Documentation impact

### Decision Records

None. Writing a verdict to stderr follows the boundary [ADR-RIG-001](../decisions/ADR-RIG-001-shell-only-runtime.md) and RIG-STATE-028 already set; it is an application of that rule, not a new commitment.

### Specifications

`docs/specs/state.md` gains RIG-STATE-029: the exit-status set as a contract, the commands that return a native status, the signal statuses, and the outcome line's stream, control and shape.

### Guides

`docs/guides/user/commands.md` shows the outcome line beside the statuses it reports, and says how to silence or force it.

### Roadmap

None expected.

## Discussion

The temptation here is to make the line clever — colour, a symbol, a summary of everything. The value is in it being boring: same position, same shape, one closed vocabulary, on the stream that already carries everything which is not the answer.

Worth noting for whoever picks this up: the reason a status-2 rejection stays silent is not economy. `rig: error: [tool.alpha] references unknown provider 'absent'` tells you where to go; `rig: apply rejected: status 2` tells you only what you already saw. A tool that repeats itself at the end of every failure trains people to stop reading the end of its output, which is precisely where this work is trying to put something worth reading.
