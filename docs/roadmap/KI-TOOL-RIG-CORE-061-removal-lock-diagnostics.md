---
id: KI-TOOL-RIG-CORE-061
area: CORE
title: Removal lock diagnostics
purpose: capability
theme: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: a31a96c1688a1ac2aee226a6a81e4bed90ba00fd
created_at: 2026-10-18T05:32:38Z
updated_at: 2026-10-18T06:07:55Z
---

# KI-TOOL-RIG-CORE-061: Removal lock diagnostics

## Goal

`rig remove --apply` takes the same per-platform operation lock as live `rig apply` and `rig upgrade`, so a removal never runs a native manager alongside them, and `rig doctor` names a held operation or reconciliation lock as active, stale or of unknown owner, with the path a person removes by hand once its owner is gone.

## Context

[KI-TOOL-RIG-CORE-058](/Users/krisbrown/workspaces/knowledge-islands/tools-rig/docs/roadmap/KI-TOOL-RIG-CORE-058-apply-lock-handler-history.md) delivered the operation lock at `$state_home/operation/PLATFORM.lock` under RIG-STATE-025: live apply of any scope and live upgrade acquire it before any provider call, and a concurrent run is refused with status 2. Two gaps sit outside that record's boundary:

- `rig_command_remove_impl` in `src/rig/27-software-removal.bash` invokes Homebrew, uv, npm and mise uninstallers under `--apply` and takes no lock, so a removal can still run beside an apply or an unattended upgrade.
- No diagnostic names a held lock. A stale lock left by a killed process refuses every later apply and upgrade, and a person learns of it only from the refusal message or the unattended report's `operation-lock=stale` detail.

## Boundary

- In: `rig remove --apply` acquiring and releasing the operation lock, with refusal before any native call and its preview and dry-run taking none; a doctor finding for each held operation or reconciliation lock, reporting owner state and the owning command without paths in machine-readable output; specification text in RIG-STATE-025 and the doctor specification; isolated tests against fixture locks.
- Out: removing or breaking a lock automatically; queueing or waiting for a lock; locks for read-only commands; Linux-specific lock semantics beyond the existing per-platform path.

## Current state

At baseline `a31a96c`, `rig_platform_lock_take` in `src/rig/21-provider-state.bash` classifies a held lock's owner inline (`pid=N` alive is active, dead is stale, anything else unknown) and recognises only `apply` and `upgrade` as owning commands. `rig_command_remove_impl` in `src/rig/27-software-removal.bash` runs inside `rig_buffer_mutation_report`'s command substitution, observes every removal through native managers, asks for the typed `remove` confirmation and then calls the native uninstallers, all without a lock. `rig_command_doctor` in `src/rig/22-observation.bash` reports configuration, XDG, tool, removal, resource, port and skill findings and warnings, and never looks at `operation/` or `reconciliation/` beneath the state home.

## Steps

- [x] Extract the owner classification from `rig_platform_lock_take` into `rig_platform_lock_owner LOCK`, setting `RIG_LOCK_CONTENTION` and `RIG_LOCK_CONTENTION_COMMAND`, and recognise `remove` as an owning command. `rig_platform_lock_take` calls it unchanged in behaviour.
- [x] In `rig_command_remove_impl`, under `--apply` only, acquire the operation lock with command `remove` straight after profile resolution and the complete-profile check, before collecting removals, so a held lock refuses with status 2 before any observation or native call. Move the remainder into a helper so the lock is released on every return, with the existing traps covering interruption. Preview and `--dry-run` take no lock.
- [x] Add `rig_doctor_platform_locks` beside the other doctor checks. For the resolved platform it inspects the operation and reconciliation lock paths without creating anything. An absent lock adds nothing. An active owner is a warning (`operation-lock: active (owner-command:apply); owner=rig; action=wait-for-owner`), because a run in progress is normal. A stale or unknown owner is a failure (`action=remove-lock-after-owner-exits`), because it refuses every later live run. A symbolic link or non-directory at the path is an `unsafe` failure. Each held lock counts as one evaluated item; coverage gains `locks`. It runs whether or not configuration loads.
- [x] Report findings under `Lock findings:` in text and `findings.locks` in JSON, with no path in either. Text output alone adds a `Lock recovery:` section naming the exact, shell-quoted command to remove a stale or unknown lock by hand, `rm -r -- PATH`, once no apply, upgrade or removal is running.
- [x] Amend RIG-STATE-025 to include `rig remove --apply`; amend RIG-STATE-015 for the lock findings, warning and text-only recovery path; update the manual's `remove`, `doctor` and FILES text, the command guide and the unattended updates guide, the changelog, and reassemble `bin/rig`.
- [x] Add isolated Bats cases and run the complete local gate.

## Files touched

- `src/rig/21-provider-state.bash`, `src/rig/22-observation.bash`, `src/rig/27-software-removal.bash`, and the assembled `bin/rig`.
- `tests/rig-software-removal.bats`, the new `tests/rig-doctor-locks.bats`, `tests/rig-lifecycle.bats`, and the exact-shape assertions in `tests/diagnostics-tables.bats` and `tests/rig-projection.bats`.
- `docs/specs/state.md`, `man/rig.1`, `docs/guides/user/commands.md`, `docs/guides/user/unattended-updates.md`, `CHANGELOG.md`.

## Verify

Run focused fixtures with stdin closed, then the complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository):

```sh
bats tests/rig-software-removal.bats tests/rig-doctor-locks.bats tests/diagnostics-tables.bats tests/rig-projection.bats </dev/null
```

- A held active, stale or unknown operation lock makes `rig remove --apply` exit 2 with the owner detail, invoke no provider (empty provider log), and leave the lock in place.
- A confirmed removal holds the operation lock while the native uninstaller runs (a provider fixture records that the lock directory exists with `command=remove`), and the lock is gone afterwards, after a refused confirmation, and after a failed native removal.
- Preview and `--dry-run` take no lock: they succeed while a lock is held and create no `operation/` directory.
- An apply or upgrade refused by a lock a removal holds names `owner=remove`.
- Doctor with no lock adds no lock finding and keeps its verdict. An active lock is one warning with an unchanged verdict and exit 0 when otherwise healthy. A stale or unknown operation or reconciliation lock is one failure each, unhealthy, exit 1. An unsafe lock path is a failure. Text names the recovery command with the exact path; JSON carries no state path. Doctor leaves every lock byte-identical and creates no lock directory.
- Doctor reports a stale lock even when configuration fails to load.

## Dependencies / blocks

Follows KI-TOOL-RIG-CORE-058 and assumes its lock design is confirmed at review. Blocks nothing.

## Documentation impact

### Decision Records

None.

### Specifications

RIG-STATE-025 adds live `rig remove --apply` to the operation lock's holders. RIG-STATE-015 adds lock findings, the active-owner warning and the text-only recovery path. RIG-STATE-030's list of owning commands in a refused unattended report gains `remove`.

### Guides

The manual's `remove`, `doctor` and FILES text, the command guide, and the unattended updates guide's stale-lock advice, which can now point to `rig doctor`.

### Roadmap

None beyond this record.

## Review

### Delivered

Delivered locally against fixtures only by the ways-of-working rig-review run on 18 October 2026, from baseline `a31a96c`, under the provisional plan in Discussion. No live `rig remove`, `rig apply` or `rig upgrade` ran, no lock outside a test's temporary state home was read or touched, and nothing was accepted or released.

### Change Summary

- **Owner classification** (`21-provider-state.bash`): `rig_platform_lock_owner` now holds the active, stale and unknown rule that `rig_platform_lock_take` used inline, and recognises `remove` as an owning command; the refusal message is unchanged.
- **Removal** (`27-software-removal.bash`): `rig remove --apply` takes the operation lock with command `remove` straight after profile resolution, before collecting or observing removals, and releases it after the run; the body moved unchanged into `rig_remove_selected`. Preview and `--dry-run` take none.
- **Doctor** (`22-observation.bash`): `rig_doctor_platform_locks` reads the selected platform's operation and reconciliation locks without creating or changing anything. A running owner is a warning with `action=wait-for-owner`; a stale or unknown owner, or a symbolic link or non-directory at the lock path, is a failure under `Lock findings` and `findings.locks`, whether or not configuration loads. Text output alone adds `Lock recovery`, with the exact shell-quoted `rm -r -- PATH`. Each held lock is one item; coverage gains `locks`.
- **Tests:** five cases in the new `tests/rig-doctor-locks.bats`, three removal cases in `tests/rig-software-removal.bats`, one upgrade case in `tests/rig-lifecycle.bats`, and the updated coverage and findings-key assertions in `tests/diagnostics-tables.bats` and `tests/rig-projection.bats`.
- **Documentation:** RIG-STATE-015, RIG-STATE-025 and RIG-STATE-030's owner list; the manual, command guide, unattended updates guide and changelog.

### Verification

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark, the native-provider version smoke (version probes only), mandoc and diff checks. All 581 Bats tests pass. Withheld by authority: any live removal, apply or upgrade, and doctor against the real state home.

Every Verify bullet has a fixture: refusal on active, stale and unknown owners with an empty provider log and a retained lock; a provider fixture recording `profile=default command=remove` in the lock while `brew list` and `brew uninstall` run, and release after success, a refused confirmation and a failed uninstall; preview and dry run with and without a held lock; `owner=remove` in a refused unattended upgrade's report; and the doctor cases, including byte-identical state and a broken configuration.

### Outstanding concerns

- **Provisional choices, for Kris to confirm:** the three planning answers in Discussion (no removal report; stale and unknown fail, active warns; exact `rm -r` command in text only), and `owner=rig` as the finding's owner field.
- **The JSON check is narrower than "no path anywhere".** The test proves the lock finding and recovery command carry no path; when configuration cannot load, doctor's existing information block still prints the state path, as before.
- **A recycled process identifier** can still make a stale owner look active, so doctor would warn rather than fail; this is the existing RIG-STATE-025 rule.
- **The lock is held across the confirmation prompt.** It is taken before observation, so a removal left waiting at `Type remove` blocks an unattended upgrade until it is answered or interrupted; and a removal with nothing to remove still briefly takes, and can be refused by, the lock. Taking it only after confirmation would let the observed state change before the lock, so the plan's order was kept.
- **The installed Rig on both Macs** keeps the old behaviour until a release, which needs Kris.

### Post-change review

The existing lock regressions for apply, upgrade, tool-only targets and signals pass unchanged, so the extraction kept `rig_platform_lock_take`'s behaviour. The lock is taken only after argument parsing, configuration and profile resolution, which invoke no provider, so a syntax error still fails before contention is checked, and an undeclared target is still rejected before any provider call.

### Mini recap

`rig remove --apply` can no longer run beside an apply or upgrade, in either order, and `rig doctor` says when a lock is held, whether its owner is still alive, and, for a dead owner, exactly what to delete.

## Discussion

Origin: the rig-lock run of 18 October 2026, delivering KI-TOOL-RIG-CORE-058's lock half; captured as a provisional follow-up, for Kris to confirm. Planning questions: whether removal's refusal writes any report (it has no unattended mode today); whether doctor's finding is a warning or a failure for a stale lock; and whether doctor offers the exact `rmdir` path or only names the directory. Capture only; adoption, priority and plan belong to this repository.

### Plan decisions

Adopted to deliver at Now and planned to Ready on 18 October 2026 by the ways-of-working rig-review run, provisionally, on Fable's opinion of 18 October, for Kris to confirm (fable-opinion-2: KI-TOOL-RIG-CORE-061 "can be planned provisionally"). The planning questions were answered with the recommended course, each provisional, for Kris to confirm:

- **Removal's refusal writes no report.** `rig remove` has no unattended mode and no report file; the refusal is status 2 with the same owner detail as apply.
- **Stale and unknown fail; active warns.** A stale or unknown lock refuses every later live run, so it makes doctor unhealthy. An active lock means another run is in progress, which is normal, so it warns without changing the verdict.
- **Text gives the exact command, JSON no path.** A lock directory holds an `owner` file, so `rmdir` alone fails; the text output names `rm -r -- PATH` with the exact quoted path. JSON keeps the Boundary's no-path rule; `--verbose` already reports the state path.

The captured `created_at` of 08:00Z lay in the future at planning time, so it was corrected to the capture commit's time, 05:32:38Z.
