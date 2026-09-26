---
id: RIG-CLI-015
area: CLI
title: Close outcome contract gaps
theme: cli
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-26T15:45:00Z
---

## Goal

Every command ends with an outcome line a reader and a script can both rely on, including the commands that reject their input and the commands that do their work in a subshell.

## Context

Stating an outcome for every command left two gaps behind, both recorded as deliberate at the time.

The result vocabulary emits five values and does not include `rejected`. The decisions listed `rejected` in the vocabulary while also deciding that a status-2 rejection is not restated on an outcome line, and those cannot both hold, so rejection is left to what the `rig: error:` line already says. If a rejection should carry a machine-readable result, that is a change to the error line rather than to the outcome line.

The second gap belonged to `rig clean`, which ran its work in a subshell, so a detail noted inside it could not escape. Its outcome line carried a result derived from the exit status with no detail clause. That command has since been retired, so the gap has no live instance — but the shape that caused it is not forbidden anywhere, and the same would be true of any command that later adopts it.

## Boundary

This does not revisit the five emitted result values for the commands that already report correctly, and it does not reinstate `rig clean` or any part of the retired publication surface in order to close the gap that command carried.

## Current state

Planning found both gaps already closed, by separate events neither of which was recorded here, so the honest remaining work is to lock the contract and retire the stale description rather than to change behaviour.

The rejection gap is settled in code and in the specification. `rig_outcome_report` in `src/rig/00-runtime.bash` returns early on `[ "$status" -ne 2 ] || return 0`, with the reason stated in a comment beside it. `docs/specs/state.md` states the closed vocabulary as `succeeded`, `healthy`, `unhealthy`, `incomplete`, `failed` — five values, with `rejected` absent. The contradiction the record describes no longer exists in either place.

The subshell gap went away with its command. `rig clean` was retired alongside `rig publish`, as `CHANGELOG.md` records under `Unreleased`: the `[publication.ID]` table, the `publish` provider capability, the staging and retention tree, and the 129/130/143 statuses went with them. `main` in `src/rig/90-main.bash` dispatches fourteen commands and `clean` is not among them, and `grep -rn 'rig clean' src tests man` finds nothing outside this record. No surviving command runs its work in a subshell, so no command currently carries a status-derived result with no detail clause.

What remains is that nothing stops either gap reopening. The five-value vocabulary is asserted nowhere in `tests/rig.bats` as a closed set, and the `status -ne 2` early return has a comment but no test.

## Steps

- [ ] Add a Bats case asserting the outcome line's `result` value for every command that emits one falls inside the five-value vocabulary, and that no command emits a sixth value.
- [ ] Add a Bats case asserting a status-2 rejection emits the `rig: error:` line and no outcome line, locking the decision `rig_outcome_report` already implements.
- [ ] Add a Bats case asserting every command whose outcome line can carry a detail clause does carry one, so a future command that loses its detail fails the suite rather than shipping.
- [ ] Confirm `docs/specs/state.md` states the vocabulary as closed and names the status-2 exception, and add the missing statement if either is implicit.

## Files touched

- `tests/rig.bats` — the three outcome-contract assertions.
- `docs/specs/state.md` — only if the closed vocabulary or the status-2 exception is stated implicitly.

No runtime source changes are expected. If the vocabulary test finds a command emitting a value outside the five, that is a defect this item fixes in `src/rig/00-runtime.bash` and `bin/rig` is reassembled.

## Verify

```sh
scripts/assemble-rig --check
bats tests/
grep -rn 'rig clean' src tests man docs/specs docs/guides
grep -n 'rejected' docs/specs/state.md
```

Pass means the three new Bats cases are green, the first `grep` returns nothing, and `docs/specs/state.md` does not list `rejected` among outcome results. A green suite with no source change is the expected outcome and is the evidence that both gaps are closed rather than merely unobserved.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. It is the smallest of the ten and touches only tests and prose, so it can land at any point without rebasing against the output work.

## Documentation impact

### Decision Records

None. The decision not to emit `rejected` is already made and already implemented; this item records that it held rather than revisiting it.

### Specifications

`docs/specs/state.md` changes only if the closed vocabulary or the status-2 exception is currently implicit. The vocabulary itself does not change.

### Guides

None. No behaviour or option changes, so nothing a reader is told needs correcting.

### Roadmap

None. This record's `Context` and `Boundary` were corrected during planning rather than deferred into the step list, so the record is honest at Ready. Had the user not selected this item for promotion, a terminal Triage disposition would have been the alternative reading — the gaps closed without this item doing anything — and the step list is deliberately the small amount of work that makes the closure verifiable instead of assumed.

## Discussion

### Two changes or one

They share a section here because both are gaps in one contract, but they are independent: the rejection question is about the error line's shape, and the subshell question is about how a command returns detail alongside a status. Either can land alone.

### Open questions

Whether any consumer wants rejection to be machine-readable at all. Nothing observed asks for it; the vocabulary listing it was the only pressure, and that has been resolved by not emitting it.

### Why the record went stale

Both halves were closed by work that had no reason to look here. The rejection half was settled by a decision recorded in the specification; the subshell half was closed by retiring `rig publish` and `rig clean`, where removing the command removed the gap as a side effect nobody logged. This is the pattern worth noticing rather than the item: a Triage record describing a defect in a named command survives the deletion of that command, because nothing links the two. Whether that is worth a general check — a record naming a command the CLI no longer dispatches — is a question for the roadmap tooling rather than for Rig.
