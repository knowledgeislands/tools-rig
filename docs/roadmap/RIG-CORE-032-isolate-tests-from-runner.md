---
id: RIG-CORE-032
area: CORE
title: Isolate tests from runner
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: abe812f2c48640bac54d710a990beb9bcf5c5238
created_at: 2026-09-28T00:10:42Z
updated_at: 2026-09-28T00:10:42Z
---

## Goal

Make `bats tests/` incapable of reading, writing, or reconciling the machine it runs on. A test that names no override must reach a directory and a launchd domain that belong to the test, never to the person running it.

## Context

Running the suite on this workstation unloaded the whole declared launchd estate, including the local agent-coordination service, three times on 27 and 28 September 2026 — at 23:49, 00:15, and 00:55. Each time the property lists stayed on disk, the declarations stayed in the catalogue, and `${XDG_STATE_HOME}/rig/resources/macos.tsv` was emptied. Each time a reviewed `rig apply --profile services --scope resources` restored all nine resources.

RIG-CORE-031 was raised against the same symptom and diagnosed profile-scoped retirement. That defect was real and is fixed, but it was not the cause here: two of the three teardowns happened while the assembled executable still predated the fix, and the third happened after it, because the fix does not address how the suite reaches the live machine.

A person's shell exports `XDG_CONFIG_HOME` and `XDG_STATE_HOME`. Eleven of the thirteen test files never removed them, so any invocation omitting `RIG_CONFIG_HOME` or `RIG_STATE_HOME` loaded the runner's own catalogue and receipt. The launchd adapter compounds it: `RIG_LAUNCHCTL` defaults to `/bin/launchctl` rather than resolving through `PATH`, and the domain defaults to `gui/<uid>`, so no sandboxed `HOME` or shadowed `PATH` can contain it. A suite invocation with a logging stub in place caught the leak directly: `print gui/501/uk.me.kris.rig.acquire-whatsapp-spool-refresh`, the runner's real domain and a real declared label.

## Boundary

The test harness owns isolation. A test states the overrides its assertion depends on, and the harness guarantees that every override a test omits still resolves inside the test's own tree.

Rig's runtime defaults are correct and unchanged: `/bin/launchctl` in `gui/<uid>` is what a person's own apply must use, and the XDG contract is what makes overrides possible at all. Nothing here weakens the defaults, adds a test-only code path to `bin/rig`, or changes the retirement contract that RIG-CORE-031 settled.

Excluded: any guard inside `bin/rig` that refuses to reconcile when it suspects a test; running the suite in a container or a separate user account; and `scripts/benchmark-rig`, which inherits the real `XDG_STATE_HOME` but only runs read-only commands, so it is a latent rather than an active hazard.

## Current state

`tests/rig.bats` and `tests/rig-projection.bats` open `setup` with `unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME`. The other eleven files do not. Isolation is therefore a convention each test file remembers separately, and each of roughly two hundred invocations restates for itself.

`tests/rig.bats` alone contains 241 invocations that set `RIG_CONFIG_HOME` and only 29 that set `RIG_STATE_HOME`. Nineteen run a non-dry-run `apply` without naming a state home. No invocation outside the launchd tests names `RIG_LAUNCHCTL` or `RIG_LAUNCHD_DOMAIN`, so each falls back to the live domain.

## Steps

- [x] Add `tests/helpers/isolate.bash` defining `rig_test_isolate`, which removes the inherited XDG and `RIG_*` base directories, moves `HOME` into `$BATS_TEST_TMPDIR`, and exports an inert `RIG_LAUNCHCTL` stub with `RIG_LAUNCHD_DOMAIN=gui/rig-test`.
- [x] Call it as the first statement of `setup` in all thirteen test files, and drop the two now-redundant `unset` lines.
- [x] Record the requirement in the repository authoring notes so a new test file inherits it.
- [x] Verify the suite passes and leaves the runner's receipt, launchd domain, and running services untouched.

## Files touched

- `tests/helpers/isolate.bash` — the isolation helper.
- `tests/rig.bats`, `tests/rig-artifacts.bats`, `tests/rig-bootstrap-manifest.bats`, `tests/rig-bootstrap-staging.bats`, `tests/rig-human-config.bats`, `tests/rig-lifecycle.bats`, `tests/rig-macos.bats`, `tests/rig-model-boundaries.bats`, `tests/rig-performance.bats`, `tests/rig-profile-authority.bats`, `tests/rig-projection.bats`, `tests/rig-skills.bats`, `tests/rig-uv-extras.bats` — the `setup` call.
- `AGENTS.md` — the authoring note.
- `docs/roadmap/RIG-CORE-032-isolate-tests-from-runner.md`, `docs/roadmap/_ISSUES.md` — this record and the CORE high-water mark.

## Verify

```sh
shellcheck -s bash tests/helpers/isolate.bash
bats tests/ < /dev/null
```

Snapshot `${XDG_STATE_HOME}/rig/resources/macos.tsv` and `launchctl list` before the run and compare after. Pass means the whole suite green, the receipt byte-identical, every declared resource still loaded in `gui/<uid>`, and the local control plane still answering its health endpoint.

To confirm the leak itself is closed rather than merely quiet, export `RIG_LAUNCHCTL` to a logging stub, run the suite, and assert that no logged call names `gui/<uid>` or a label the runner declares. Before this change that assertion fails on the first observation of a real resource.

## Dependencies / blocks

Nothing blocks this. RIG-CORE-031 shares the symptom and is independent: this item would have prevented all three outages, and that one is still needed because a narrow `rig apply --profile X` on a real machine would retire the resources `X` omits. Neither depends on the other to land.

## Documentation impact

### Decision Records

None. Isolating a test harness from its runner needs no decision recorded: it introduces no contract, reverses none, and closes off no option. ADR-RIG-008 already carries the retirement contract this incident exposed.

### Specifications

None. No specified behaviour changes; `bin/rig` is untouched. The specifications' `_Verify_` clauses continue to name the same tests, which now assert the same things against the test's own tree rather than the runner's.

### Guides

`AGENTS.md` carries the authoring note, next to the existing instruction about redirecting stdin. No user-facing guide, `man/rig.1`, or README text changes, because nothing a person runs behaves differently.

### Roadmap

`scripts/benchmark-rig` inherits the runner's `XDG_STATE_HOME` and needs the same treatment. It is read-only today, so it is noted here rather than raised: the next change to that script should sandbox it.

## Review

### Delivered

The approved boundary in full: one shared helper, called from every test file's `setup`, plus the authoring note that keeps a new file from reintroducing the gap. Rig's runtime defaults are untouched, and no test-only path was added to `bin/rig`.

Immutable baseline `abe812f2c48640bac54d710a990beb9bcf5c5238`. The evidence is the three teardowns at 23:49, 00:15, and 00:55, the emptied receipt each time, and the leaked `print gui/501/uk.me.kris.rig.acquire-whatsapp-spool-refresh` caught by a logging stub.

### Change Summary

`rig_test_isolate` unsets the four XDG base directories and the four `RIG_*` equivalents, points `HOME` at `$BATS_TEST_TMPDIR/isolated-home`, and exports a generated `launchctl` stub that reports every label absent and accepts every mutation, in `gui/rig-test`. Every existing per-invocation override still wins, because `run env VAR=…` sets the variable for that invocation.

Two decisions worth naming. The stub accepts mutations rather than failing, so a forgotten override surfaces as the assertion it belongs to failing rather than as an unrelated provider error. And isolation lives in each file's `setup` rather than in a `setup_suite`, because bats loads a suite file only when given a directory, and a single-file run must be as safe as a whole-suite run.

No approved deviations. Nothing was committed.

### Verification

`shellcheck -s bash tests/helpers/isolate.bash` clean. `bats tests/ < /dev/null` is 250 of 250 passing, up from 249 of 250 before this change — the one prior failure was itself an artefact of the leak.

The runner was checked across that run: the receipt is byte-identical to its pre-run snapshot, all nine declared resources remain loaded in `gui/501`, and the control plane answers `status: ok` with `startupRecovery.phase: ready`. Before the change, the same suite emptied the receipt and unloaded the estate.

### Outstanding concerns

`scripts/benchmark-rig` still inherits the runner's `XDG_STATE_HOME`. It runs only `diag`, `show`, `list`, and `status`, so today it reads the person's receipt without writing it; a future benchmark that applies anything would become the same hazard. Recorded under Documentation impact rather than raised as work.

The working tree also holds unrelated in-flight `rig status --problems` work and the RIG-CORE-031 change, so committing this item requires separating three changes. That is the reviewer's call.

### Post-change review

The goal is met, and it is met structurally: a test cannot reach the runner's catalogue, receipt, or launchd domain by omission, only by naming a real path deliberately. Scope held; `bin/rig` is byte-identical.

Regression risk is in the forced `HOME` and the forced launchd stub, because both change what a test sees when it names no override. Both are covered by the suite passing in full, and the one test that changed state — from failing to passing — did so because it now compares repository files rather than the runner's installed ones.

Ready for acceptance.

### Mini recap

The recurring service outage was the test suite reconciling the live machine, not the retirement defect fixed under RIG-CORE-031. A shared `rig_test_isolate` helper, called from every `setup`, closes it: 250 of 250 passing with the runner's receipt, launchd domain, and services provably untouched.

Learning routes to propose, not to promote: a test harness that relies on each invocation restating its own sandbox will leak at the first omission, so the harness should establish the sandbox and let invocations override it; and a runtime default that bypasses `PATH`, as `/bin/launchctl` does, cannot be contained by the usual test hygiene and needs an explicit override variable, which is the pattern Rig already provides and the tests simply had not used.

## Discussion

### Why the first diagnosis was wrong

RIG-CORE-031 found a genuine defect that produces exactly this symptom, and the symptom recurred after it was fixed. The lesson is that a plausible mechanism matching the evidence is not the same as the mechanism that ran: the timestamps settled it, because the assembled executable carrying the fix was written at 00:35 and two of the three teardowns preceded it.

### Why not guard inside the executable

A check in `bin/rig` that refused to reconcile when it suspected a test would put test awareness in the product, and would still be wrong for the case that matters — a person's own narrow apply. The hazard belongs to the harness, and so does its remedy.
