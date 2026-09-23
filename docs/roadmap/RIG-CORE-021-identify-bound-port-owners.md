---
id: RIG-CORE-021
title: Identify bound port owners
area: CORE
theme: orchestration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 0603938d0c8041b3409193706aaac84d834ae9c1
created_at: 2026-09-22T07:55:00Z
updated_at: 2026-09-23T14:41:06Z
---

## Goal

Make a declared port's owner check identify the process that is actually bound, so a correctly bound interpreted listener stops reporting as `conflicting` and a genuinely misbound port is still caught.

## Context

Listener observation records the executable name that `lsof` reports, and the port check compares that name against the owner's expected command. For anything launched through an interpreter, the reported name is the interpreter rather than the program, so the comparison fails for listeners that are exactly what the declaration says they should be.

Both private ports on the reporting workstation are affected, and both are correctly bound:

- `port:mcporter-http` (tcp/3333) declares `owner = "service:mcporter-http-bridge"`, whose `program` is `~/bin/mcporter-proxy`. The listener is `/opt/homebrew/opt/node/bin/node /Users/…/bin/mcporter-proxy --http 3333`, observed as `node`.
- `port:headroom` (tcp/8787) declares a `tool` owner. The listener is `/Users/…/uv/tools/headroom-ai/bin/python -m headroom.cli --host … --port 8787`, observed as `python`.

Both report `conflicting` with `detail="owner:node;expected:…"`. The consequence is worse than a cosmetic wrong word: a permanent false positive on a healthy machine trains the reader to ignore the one state that is supposed to mean a stranger is on the port, so the check has negative value in its current form.

## Boundary

This work changes how an observed listener is identified and compared, and the detail string that explains a mismatch. It does not change the port declaration schema, the `required` and `on-demand` modes, scope classification, the state vocabulary, exit status, or any other resource kind's observation. It must not weaken the check into passing whenever identification is uncertain.

## Current state

`src/rig/20-orchestration.bash:2341` runs `lsof -nP -iTCP -sTCP:LISTEN -Fpcn`. The `c` field is the executable name; it is stored in `RIG_LISTENER_COMMANDS` alongside the pid already captured in `RIG_LISTENER_PIDS`. The port check at `src/rig/20-orchestration.bash:2494` compares that stored name against `expected_command` by string equality and sets `detail="owner:$observed_command;expected:$expected_command"` on inequality.

The pid is therefore already available at the point of comparison, which is what makes the full command line obtainable without a second enumeration pass.

A repository-side check comparing each listener's full argv against the owner's declared `program` was written in `krisb/dotfiles` and then removed, on the grounds that a general defect in Rig should not acquire a local answer. That workstation therefore reads both `conflicting` findings as known false positives until this lands, which is the cost this work removes.

The approved implementation takes one additional macOS `ps` snapshot after `lsof`, joins full command lines to the already captured PIDs, and never invokes `ps` once per port. Service and scheduled-job ownership matches the home-expanded first `program` value as a complete argv token. Tool ownership matches the selected installation locator after removing package extras, either as a command token or path component. An exact executable-name match remains positive fallback evidence; a different executable name without readable argv is `unknown` rather than `conflicting`. Only a readable command line that positively identifies a different process is `conflicting`.

## Steps

- [x] Capture each listener's full command line alongside its pid during observation, preferring a single additional bounded call over a per-port invocation.
- [x] Resolve the owner's expectation from its declaration — a service's `program`, a tool's locator — rather than from the resource identifier alone.
- [x] Match the expectation against the command line, keeping the executable name as a fallback so an unidentifiable listener is reported rather than excused.
- [x] Distinguish "bound by something else" from "could not identify what is bound" in both state and detail, so an observation failure never reads as a conflict.
- [x] Keep the check working where command-line observation is unavailable or refused, degrading to an explicit unavailable observation rather than a false pass.
- [x] Add fixtures for an interpreted listener matching its declared program, a genuinely foreign occupant, and an unidentifiable listener.
- [x] Align the user command guide, the state Specification, the manual, and the changelog with the revised detail contract.

## Delegation

No delegation is planned. Listener capture, owner resolution, state classification, tests, and documentation are tightly coupled around one observation contract.

## Files touched

- `src/rig/20-orchestration.bash` for listener observation and the port-owner comparison.
- `src/rig/00-runtime.bash` and `src/rig/10-configuration.bash` for the captured argv state and its reset, plus assembled `bin/rig`.
- `tests/` for the interpreted, foreign, and unidentifiable listener fixtures.
- `docs/guides/user/commands.md`, `docs/specs/state.md`, `man/rig.1`, and `CHANGELOG.md` for the revised detail contract.
- This roadmap record and the issue ledger for delivery evidence.

## Verify

- Bats fixtures covering the three listener cases above, including the exact `node`-fronted and `python`-fronted forms that currently fail.
- The complete repository verification gate: assembly drift, `bash -n`, ShellCheck, full Bats, manual lint, documentation lint, benchmarks, native-provider smoke, and `ki repo audit`.
- On a machine with both private ports bound as declared, `rig status` reports neither as `conflicting`, and `rig doctor`'s finding count drops accordingly.

## Dependencies / blocks

No delivery dependency. Sibling to `RIG-CORE-022`: both exist because a local repository had to compensate for an observation Rig makes dishonestly, and together they retire `bin/workstation_surfaces` entirely. Related to `RIG-CLI-010` only in that the revised detail string is human output; do not turn it into a parsing contract.

## Documentation impact

### Decision Records

No new Decision Record expected. Identifying a bound process more accurately is within the accepted observation boundary rather than a change of authority.

### Specifications

The state Specification should say what evidence a port-owner match rests on, and that an unidentifiable listener is its own observation rather than a conflict.

### Guides

Explain what `conflicting` now asserts and what it no longer asserts, so a reader can tell a stranger on the port from an unreadable process.

### Roadmap

Record the delivered evidence here, and note the downstream repository-side check that this work retires.

## Review

### Delivered

A declared port's owner check now identifies the process actually bound, without weakening into a pass whenever identification is uncertain. The port declaration schema, the `required` and `on-demand` modes, scope classification, the state vocabulary, exit status, and every other resource kind's observation are unchanged.

### Summary of changes

- Listener observation takes one additional bounded `ps -axo pid=,command=` snapshot after `lsof` and joins full command lines to the pids already captured, never invoking `ps` per port.
- Service and scheduled-job ownership matches the home-expanded first `program` value as a complete argv token or path component; tool ownership matches the selected locator with package extras removed.
- An exact executable name remains positive fallback evidence where no command line is readable, so an unidentifiable listener is reported rather than excused.
- `conflicting` now requires a readable command line that positively identifies a different process, and names that listener rather than whichever listener the enumeration happened to reach last.
- An unreadable command line whose executable name also differs reports `unknown` with `owner-unavailable`, or stays informational for an `allocated` port.
- `rig_expected_owner_command` is removed; the argv-aware `rig_expected_owner_identity` supersedes it and the old helper had no remaining callers.

### Verification

Evidence:

- `tests/rig.bats` covers the interpreted `node`-fronted service and `python`-fronted tool forms, a genuinely foreign occupant, an unidentifiable listener in both `required` and `allocated` modes, and the `conflicting` detail under both listener orderings.
- The attribution fixture was confirmed to fail against the pre-fix detail expression and to pass after it, so it guards the defect rather than merely describing it.
- Full Bats suite passes with 230 cases; ShellCheck, `bash -n`, `scripts/assemble-rig --check`, `mandoc -T lint`, the performance benchmark, native-provider smoke, and `ki repo audit` all pass.
- On the reporting workstation, `rig status` now reports `port:mcporter-http` as `present` with `owner:mcporter-proxy` and `port:headroom` as `present` with `owner:headroom-ai`; both previously read `conflicting`. Port summary is `selected=2 unhealthy=0`.

### Outstanding concerns

Command-line observation is macOS `ps` only, consistent with the existing macOS-only `lsof` listener observation; other platforms continue to report the observation as unavailable rather than guessing. A listener owned by another user, or one that exits between enumeration and inspection, reports unverified ownership by design.

### Post-change review

The downstream repository-side check in `krisb/dotfiles` that compared listener argv against declared programs is retired by this work; that repository no longer needs to compensate for a dishonest observation, and the two `conflicting` findings it treated as known false positives are gone. The revised detail string remains human output and is not a parsing contract, per `RIG-CLI-010`.

### Mini recap

A correctly bound interpreted listener now reads as healthy, a stranger on the port still reads as `conflicting`, and a process Rig cannot inspect says so instead of pretending to either.

## Discussion

A check that cries wolf on a healthy machine is worse than no check, because its output is indistinguishable from the real finding it exists to surface. That is the reason to treat this as a correctness defect rather than a presentation improvement.

The fallback direction matters. Where the command line cannot be read — a process owned by another user, a platform without the observation, a listener that exits between enumeration and inspection — the honest answer is that the owner is unverified. Reporting such a listener as `conflicting` repeats the present defect in a new place, and reporting it as healthy hides the case the check is for.
