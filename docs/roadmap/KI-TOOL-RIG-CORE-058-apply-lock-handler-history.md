---
id: KI-TOOL-RIG-CORE-058
area: CORE
title: Apply lock, handler history
purpose: corrective
theme: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 8432f33de6b35be94750f3da6017c33b94ccd7dd
created_at: 2026-10-15T00:53:34Z
updated_at: 2026-10-18T07:30:00Z
---

# Apply Lock, Handler History

## Goal

`rig apply` and `rig upgrade`, including an upgrade started by a scheduled `rig-update` job, take one shared per-platform lock, and either refuses to start while the other holds it. A default-application step records its outcome in the apply history like every other dispatched target, so a failed handler assignment shows in `rig status` and `rig doctor`.

## Context

Two defects, found together in one apply on Mac Studio `sol` on 15 October 2026 ([apply-check run report](/Users/krisbrown/.local/state/ki/agents/mac-studio-bootstrap/apply-check.report.md)):

- **No shared lock.** Kris started `rig apply` at about 01:19 BST while the sol-clt run's `rig upgrade` was running; the upgrade finished at 01:25:11 BST. Both reached Homebrew and mise in the same minutes. The only lock is the resource reconciliation lock (RIG-STATE-025), which `rig_command_apply` in `src/rig/23-application.bash` takes only when the plan has resource work; tool installation runs outside it, and `rig upgrade` (`rig_command_lifecycle`) takes no lock at all. The scheduled `rig-update` job runs the same upgrade at 08:30 unattended, so the overlap can happen without anyone at the keyboard. That night every Homebrew step exited 0, so the overlap caused none of the nine failures, but two native managers running side by side is the risk.
- **Default applications leave no history.** `rig_history_prepare` in `src/rig/25-apply-history.bash` keys tools, skills, services, scheduled jobs, settings and the Dock, not default applications. The SVG handler step (`default-application.svg`, Google Chrome) failed with "handler assignment not effective; native confirmation may be required", most likely because macOS asked for confirmation on screen. It counted in the apply's failed total but wrote no history entry, so the apply-check run could only identify it by elimination from the counts. RIG-STATE-035 already says the ledger covers declared targets that Rig dispatches.

## Boundary

- In: one exclusive per-platform lock that live `rig apply` (every scope, tools included) and live `rig upgrade` (attended and `--unattended`) hold for the whole run; a refusal before any provider call that names the active, stale or unknown owner and its command, matching RIG-STATE-025's owner detail and never removing an unverified lock; how the existing resource reconciliation lock fits into it; recording default-application dispatches in the apply history and projecting their failures in status and doctor; specification amendments to RIG-STATE-025 and RIG-STATE-035; isolated Bats coverage with a held fixture lock and stubbed handler setter.
- Out: queueing or waiting for the lock (refuse only); `rig doctor`, `status`, `show`, dry runs and other read-only commands, which take no lock; changing how the `rig-update` job is scheduled; Homebrew's and mise's own locking; the macOS confirmation prompt itself.

## Current state

The tools-burndown run adopted this record on 18 October 2026 and delivered the history half from baseline `8432f33`, against fixtures only. `rig_history_prepare` now keys default-application and firewall dispatches, which `rig_command_apply` already bracketed but whose history the preparation refused with the warning "apply history unavailable (undeclared-history-target)", and the ledger reader accepts their rows, which it would otherwise have reported as `invalid-history-row`. Including firewall, found by the same check, is provisional, for Kris to confirm. The rig-lock run delivered the lock half on 18 October 2026 from baseline `59e13f2`, against fixture locks only, under RIG-APPLY-LOCK option a), approved provisionally on Fable's opinion, for Kris to confirm. A separate per-platform operation lock, `operation/PLATFORM.lock` beneath the state home, now wraps the unchanged reconciliation lock: live `rig apply` of every scope and target takes it straight after profile resolution, before target selection or any provider call, and live `rig upgrade`, attended or unattended, takes it before collecting tasks. Dry runs take no lock. A held lock refuses with status 2 and the same active, stale or unknown owner detail, never removing it. An unattended upgrade refused this way replaces `last-upgrade` with status 2, result `failed`, detail `operation-lock=STATE owner=COMMAND`, zero counts and no rows. RIG-STATE-025 and RIG-STATE-030 are amended; RIG-ORCH-037 is unchanged, since a tool-only target takes the operation lock but still not the reconciliation lock. No live apply or upgrade was run.

## Steps

- [x] Key default-application and firewall targets in `rig_history_prepare` and accept them in the ledger reader, so their dispatches publish ledger rows and failures reach status and doctor; cover a declined handler assignment, its recovery, and a converged firewall apply in isolated Bats tests; amend the RIG-STATE-035 evidence.
- [x] Settle how one exclusive per-platform lock relates to the reconciliation lock (RIG-STATE-025, RIG-ORCH-037) and how an unattended upgrade refusing on it reports (RIG-STATE-030): a separate operation lock wraps the reconciliation lock, and a refused unattended upgrade records a refused last run and exits 2 (provisional, for Kris to confirm).
- [x] Take the lock for the whole of live `rig apply` and `rig upgrade`, refuse with owner detail before any provider call, amend RIG-STATE-025 and RIG-STATE-030, and cover a held, stale and unknown fixture lock.

## Files touched

- [Apply history](../../src/rig/25-apply-history.bash) and the assembled [executable](../../bin/rig).
- [Default-application tests](../../tests/rig-default-applications.bats) and [firewall tests](../../tests/rig-firewall.bats).
- [State specification](../specs/state.md).
- [Provider state](../../src/rig/21-provider-state.bash), [runtime globals](../../src/rig/00-runtime.bash), [apply](../../src/rig/23-application.bash) and [lifecycle](../../src/rig/40-publication-lifecycle.bash).
- [Profile-authority](../../tests/rig-profile-authority.bats), [lifecycle](../../tests/rig-lifecycle.bats), [command](../../tests/rig.bats) and [sudo-session](../../tests/rig-sudo-session.bats) tests.
- [Manual](../../man/rig.1), [command guide](../guides/user/commands.md), [unattended updates guide](../guides/user/unattended-updates.md) and [changelog](../../CHANGELOG.md).

## Verify

- A declined fixture handler assignment fails the apply without the unavailable-history warning, writes a `default-application:notes` ledger row with a non-zero exit, and `rig doctor --json` reports it with `historical_failure_count` 1; a following successful apply records exit 0 and doctor reports 0.
- A granted firewall apply writes a `firewall:screen-sharing` row with exit 0.
- Against a fixture operation lock owned by a live process, a dead process and no owner, `rig apply` of every scope, a tool-only target and `rig upgrade` exit 2 naming the owner, invoke no provider and leave the lock; dry runs still succeed.
- An unattended upgrade refused by the lock replaces `last-upgrade` with status 2, result `failed`, the `operation-lock=STATE owner=COMMAND` detail and no rows, carrying no owner path or process identifier.
- A live apply's provider runs with both locks held and a live upgrade's with the operation lock held; both are gone afterwards, also after HUP, INT and TERM.
- `bats tests/ </dev/null`, ShellCheck and the assembly check.

## Dependencies / blocks

Not blocked; blocks nothing.

## Documentation impact

### Decision Records

None.

### Specifications

RIG-STATE-035's evidence now names the default-application and firewall coverage; its normative text already required every dispatched declared target. RIG-STATE-025 now requires the operation lock around the reconciliation lock and is retitled "Exclusive operation and reconciliation targets"; RIG-STATE-030 now requires a refused unattended upgrade to replace the report with the refusal.

### Guides

The manual's FILES section names the operation lock and the refused report; the command guide and the unattended updates guide say apply and upgrade refuse each other and how to clear a stale lock.

### Roadmap

None.

## Review

### Delivered

Delivered locally against fixtures only: the history half by the tools-burndown run from baseline `8432f33`, the lock half by the rig-lock run from baseline `59e13f2`. No live `rig apply` or `rig upgrade` ran on either Mac, no lock outside a test's temporary state home was touched, and nothing was accepted or released.

### Change Summary

- **History** (`25-apply-history.bash`): default-application and firewall dispatches are keyed and their ledger rows accepted, so a declined handler assignment reaches status and doctor.
- **Operation lock** (`21-provider-state.bash`): `rig_acquire_operation_lock` takes `operation/PLATFORM.lock` beneath the state home with the same owner line, contention detail and refusal to remove an unverified lock as the reconciliation lock; both now share `rig_platform_lock_take` and `rig_platform_lock_drop`, and one set of traps, `rig_release_platform_locks`, releases the reconciliation lock and then the operation lock on exit or HUP, INT and TERM. The reconciliation lock's messages and path are unchanged.
- **Apply** (`23-application.bash`): a live apply of any scope takes the operation lock straight after profile resolution, before target selection or preflight, and releases it last; the reconciliation lock is still taken only for resource work, inside it.
- **Upgrade** (`40-publication-lifecycle.bash`): a live upgrade takes the operation lock before collecting tasks. An unattended upgrade refused on a held lock writes `last-upgrade` with status 2, result `failed`, detail `operation-lock=STATE owner=COMMAND`, zero counts and no rows; the owner command is reported only as `apply`, `upgrade` or `unknown`, so no path or argument reaches the report.
- **Tests:** two apply cases in `tests/rig-profile-authority.bats`, three upgrade cases in `tests/rig-lifecycle.bats`, a held-lock refusal for a tool-only target in `tests/rig.bats`, and operation-lock release after each signal in `tests/rig-sudo-session.bats`.
- **Documentation:** RIG-STATE-025 and RIG-STATE-030; the manual, command guide, unattended updates guide and changelog.

### Verification

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark, the native-provider version smoke, mandoc and diff checks. All 572 Bats tests pass, including every Verify bullet above.

Withheld by authority: any live apply or upgrade, and observing the 08:30 `rig-update` job against a real lock.

### Outstanding concerns

- **Provisional choices, for Kris to confirm:** the wrapping design itself (RIG-APPLY-LOCK a)), exit status 2 for a refusal, and writing `last-upgrade` only for a lock refusal, not for other status-2 rejections such as invalid configuration.
- **A stale lock blocks every later apply and upgrade** until a person removes it, by design under RIG-STATE-025; the unattended guide says how. Doctor does not yet name a held or stale operation lock.
- **`rig remove`** also invokes native managers and takes no lock; it is outside this record's boundary.
- **The installed Rig on both Macs** keeps the old behaviour until a release, which needs Kris.

### Post-change review

The reconciliation-lock regressions (active and stale owners, tool-only target, success cleanup, signal release) pass unchanged. The operation lock is taken after configuration and profile resolution, which invoke no provider, so a syntax error or invalid configuration still rejects before contention is checked.

### Mini recap

`rig apply` and `rig upgrade` can no longer run at the same time: the second refuses at once and says who holds the lock, and an unattended upgrade that is refused says so in its report.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of APPLY-UPGRADE-LOCK option a) on 2026-10-15 (decision 85 in the mac-studio-bootstrap thread's decisions log): "one unadopted tools-rig triage record (local commit): rig apply and rig upgrade share one lock and refuse to run concurrently, and default-application outcomes are recorded in the apply history". Kris chose one record over two. No open record already owned either half. Planning questions: whether the shared lock replaces the reconciliation lock or wraps it, given a targeted tool-only apply must not take the reconciliation lock today (RIG-ORCH-037); how an unattended upgrade that finds the lock held reports in its last-run report (RIG-STATE-030) and exits; and the history key for a default application (content type or extension, with the owning tool as provider). Capture only; adoption, priority and plan belong to this repository. The tools-burndown run's recommended answer for the lock, provisional, for Kris to confirm: a separate per-platform operation lock that wraps the reconciliation lock rather than replacing it, so RIG-ORCH-037's tool-only apply keeps its present resource behaviour, with an unattended upgrade that finds it held recording a refused last run and exiting non-zero.

The rig-lock run took RIG-APPLY-LOCK option a) on 18 October 2026, provisional on Fable's opinion and for Kris to confirm. Two further choices are also provisional, for Kris to confirm: the refusal exits 2 like the reconciliation lock, as a rejection before work started under RIG-STATE-029, and no other status-2 rejection writes `last-upgrade`. `rig remove` also invokes native managers and takes no lock; it is outside this record's boundary and left for a later record.
