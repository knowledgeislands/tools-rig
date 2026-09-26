---
id: RIG-CORE-025
area: CORE
title: Isolate state in tests
theme: orchestration
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-25T15:00:00Z
updated_at: 2026-09-26T15:45:00Z
---

## Goal

No test can read or write the machine's real Rig state, whichever test file it lives in.

## Context

Rig now writes a run report beneath `RIG_STATE_HOME`, so the state directory is no longer read-only territory for the suite. `tests/rig-lifecycle.bats` pins `RIG_STATE_HOME` into a per-test directory. Seven of the thirteen bats files never pin it at all — `rig-artifacts`, `rig-bootstrap-staging`, `rig-human-config`, `rig-model-boundaries`, `rig-performance`, `rig-projection`, and `rig-uv-extras` — so an ambient `XDG_STATE_HOME` reaches them, and in the files that do pin it the isolation is per invocation rather than per file.

Nothing fails today because no test in those files writes state. The gap is worth closing before one does, since the first symptom would be a suite that mutates the developer's own machine.

## Boundary

This covers state isolation only. It does not restructure the suite, unify the existing per-invocation `env` calls into a shared helper as a matter of style, or extend to the config, data, and cache homes beyond what the same mechanism gives for free.

## Current state

Counting occurrences of `RIG_STATE_HOME` across the thirteen bats files confirms the record exactly and adds one fact that makes the fix cheap.

Seven files never mention it: `tests/rig-artifacts.bats`, `tests/rig-bootstrap-staging.bats`, `tests/rig-human-config.bats`, `tests/rig-model-boundaries.bats`, `tests/rig-performance.bats`, `tests/rig-projection.bats`, and `tests/rig-uv-extras.bats`. An ambient `XDG_STATE_HOME`, or its absence and therefore the real `~/.local/state`, reaches every test in them.

The six that do mention it pin per invocation rather than per file: `tests/rig.bats` twenty-two times, `tests/rig-bootstrap-manifest.bats` and `tests/rig-macos.bats` twice each, `tests/rig-lifecycle.bats`, `tests/rig-profile-authority.bats`, and `tests/rig-skills.bats` once each. A test in one of those files that omits the prefix is unprotected, and nothing catches the omission.

The fact that makes this cheap: all thirteen files already define `setup()`, and those functions already build per-test scratch directories under `BATS_TEST_TMPDIR` — `tests/rig-artifacts.bats` sets `CONFIG_HOME`, `TEST_HOME`, and `PROVIDER` that way. So a per-file pin has a home in every file that needs one, and no file needs new structure to receive it.

## Steps

- [ ] Export all four XDG overrides — `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME` — into `BATS_TEST_TMPDIR` subdirectories from `setup()` in each of the thirteen files, so isolation is a property of the file rather than of each `run` line.
- [ ] Leave the existing explicit `env` prefixes in place where a test asserts something about a specific path, since a prefix that names the same directory the pin already provides is redundant rather than wrong, and removing them is the stylistic tidy the Boundary excludes.
- [ ] Add one test asserting the pin holds: run a command that writes the run report and assert the file appears beneath `BATS_TEST_TMPDIR` and that the real `${XDG_STATE_HOME:-$HOME/.local/state}/rig` is untouched.
- [ ] Verify by running the suite with a deliberately hostile ambient environment — `XDG_STATE_HOME` pointed at a read-only directory — and confirming every test still passes, which is only possible if nothing reaches it.

## Files touched

- `tests/rig.bats`, `tests/rig-artifacts.bats`, `tests/rig-bootstrap-manifest.bats`, `tests/rig-bootstrap-staging.bats`, `tests/rig-human-config.bats`, `tests/rig-lifecycle.bats`, `tests/rig-macos.bats`, `tests/rig-model-boundaries.bats`, `tests/rig-performance.bats`, `tests/rig-profile-authority.bats`, `tests/rig-projection.bats`, `tests/rig-skills.bats`, `tests/rig-uv-extras.bats` — the `setup()` pin.
- `AGENTS.md` — the authoring note, so a new test file inherits the rule rather than rediscovering it.

No source, manual, or guide changes. This is test hygiene.

## Verify

```sh
bats tests/ </dev/null
mkdir -p "$PWD/.ro-state" && chmod 500 "$PWD/.ro-state"
XDG_STATE_HOME="$PWD/.ro-state" bats tests/ </dev/null
chmod 700 "$PWD/.ro-state" && rm -rf "$PWD/.ro-state"
grep -c RIG_STATE_HOME tests/*.bats
```

Pass means the suite is green both times, and green under a read-only ambient `XDG_STATE_HOME` is the assertion that matters: a test that reached the real state directory could not pass. Note the `</dev/null` in both runs — without it a test that reads a prompt hangs on the terminal.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. It touches only test setup, so it cannot conflict with any of the nine other items beyond ordinary merge proximity in the same files. Landing it early is worth a little because every other item on this roadmap adds tests, and each one added after the pin inherits isolation for free.

## Documentation impact

### Decision Records

None. Test isolation decides nothing about Rig's behaviour or contracts.

### Specifications

None. No behaviour-level contract changes.

### Guides

`AGENTS.md` gains one authoring note beside the existing Bash 3.2 and `</dev/null` notes, stating that a bats file pins the four XDG homes in `setup()`. That is where a test author will look, and without it the gap reopens with the next file.

### Roadmap

No new follow-on work. Extending the same mechanism to further environment isolation is explicitly out of scope and is not a deferred remainder.

## Discussion

### Where the pin belongs

A per-file `setup` that exports all four XDG overrides into `BATS_TEST_TMPDIR` would close it uniformly, but the suite currently prefers explicit `env` prefixes on each `run`, which makes each test readable in isolation. Either is defensible; mixing them silently is what leaves the gap.

Planning took the per-file `setup`, and kept the existing prefixes rather than choosing between the two styles. The reason is that only one of them can actually close the gap: an `env` prefix protects the line it is written on, so a convention of prefixes fails exactly when an author forgets, which is what happened in seven files. A `setup` pin protects a test the author has not thought about yet. The prefixes then become redundant rather than wrong, and the Boundary already says unifying them is not this item's business.

The read-only-`XDG_STATE_HOME` run is the part worth keeping. Without it the change is unfalsifiable: the suite passes today, so a green suite after the pin proves nothing on its own.
