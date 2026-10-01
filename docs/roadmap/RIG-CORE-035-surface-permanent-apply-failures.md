---
id: RIG-CORE-035
area: CORE
title: Surface historical apply failures
theme: orchestration
horizon: next
status: done
blocks: []
blocked_by: []
baseline_ref: 43a73df5b346bc41512911644534bff46596f74c
created_at: 2026-09-30T00:00:00Z
updated_at: 2026-10-01T14:17:58Z
---

## Goal

Make a failed application visible to read-only health checks even when the native manager still reports the tool installed. Keep historical failure evidence distinct from what is observed on the machine now.

## Context

Repeated failed applications previously disappeared into terminal scrollback while status showed tools present and doctor had no findings. Installation receipts do not prove that the last attempted change succeeded. The command cutover preserves this gap: apply has resource reconciliation receipts but no durable per-target outcome history.

The user approved the reliability work and the recommendation to show the last failed attempt immediately, without labelling one failure permanent. This item records failure evidence; [unattended-contract hardening](RIG-CORE-024-widen-needs-person-detection.md) preserves known preflight exclusions. Neither substitutes for the other.

## Boundary

Do not probe mutating provider paths from status or doctor, add a provider capability, introduce an event database, infer a credential problem from an error, or repair personal declarations. Preserve the live observation and existing outcome vocabulary. Display styling follows in the separate live-display item.

## Current state

Apply prints per-target outcomes and an aggregate result, but those rows are not retained. Last-upgrade is a separate unattended lifecycle report, not apply evidence. Targeted apply already requires preservation of unrelated resource receipts; a new failure ledger must likewise avoid losing evidence about targets absent from a narrow run.

## Steps

- [x] Specify one bounded versioned outcome ledger per platform under Rig state, keyed by qualified target and provider/authority. Store only the latest completed outcome, its ordering token, UTC completion time and native exit status; retain successes internally as ordering watermarks and display only failures.
- [x] Reserve a monotonically increasing attempt token under a short state lock immediately before each real dispatch. Publish completed results immediately, replacing a target only with a greater token. A successful result clears its visible failure but retains the watermark. Do not allocate attempts for skipped, rejected or dry-run work.
- [x] Add safe atomic merge/replacement with a short state-write lock so concurrent tool-only applies cannot overwrite unrelated outcomes; define same-target attempt ordering so an older failed attempt cannot replace a later successful result. Refuse unsafe paths and preserve previous valid evidence on failure.
- [x] Show selected unresolved failures as explicitly historical findings in doctor and a separate status section, including problems-only and JSON projections. Preserve current native state and expose recorded time/age; historical health findings contribute to the documented finding exit status.
- [x] Treat missing history as neutral and corrupt or unreadable history as unavailable evidence. Make persistence failures visible separately without rewriting the provider's actual result.
- [x] Cover failure, repeated failure, later success, targeted preservation, provider/platform separation, changed declarations, interrupted runs, unsafe state, concurrent writers and read-only follow-up.
- [x] Align state specifications and guides, run the full gate and prepare the review packet.

## Files touched

The apply and observation modules, a focused authored history helper if factoring warrants it, deterministic assembly, generated executable, isolated state tests, state specification and inspection guides. Do not implement this as duplicated persistence logic in status and doctor.

## Verify

Use recording provider stubs and isolated state homes. Prove live observation remains present while historical failure is visible; a later successful attempt clears only the matching target. Dry runs and read-only checks must not change ledger bytes or invoke mutation. Exercise malformed files, symlinks, failed writes, bounds, changed declarations, clock discrepancy and parallel disjoint-target merges. Force same-target attempts to complete in reverse order and prove a late older failure cannot overwrite a newer successful watermark; interrupt after an earlier completed target and prove its evidence survives. Run the complete AGENTS.md gate with Bats stdin redirected from /dev/null.

## Dependencies / blocks

No build-order dependency. Sequence this before [live display](RIG-CLI-023-design-live-operational-display.md) so presentation consumes settled evidence. The Dock observation fix is independently executable and may share an aggregate verification pass after each item has its own tests and review packet.

## Delegation

One implementation lane owns the shared history contract and apply/observation integration to avoid competing writes to the same state model. A separate reviewer checks data safety, targeted preservation and read-only guarantees. The coordinator owns roadmap state, integration and final verification; no worker live-machine mutations or Git writes.

## Documentation impact

### Decision Records

Explain the distinction between remembered execution evidence and provider-owned current state if a durable authority clarification is needed.

### Specifications

Specify ledger keys, merge/clear rules, privacy, age, interrupted-run behavior and finding exit semantics before implementation. The first unresolved failure is visible; there is no new permanent-failure state.

### Guides

Explain how to inspect a past failed attempt, why an installed tool can also have a historical finding, and why unrelated targeted applications do not clear it.

### Roadmap

No provider materialisability capability or repair framework is included. Retain those as separate concerns only if later evidence justifies them.

## Review

### Delivered

Implemented durable last-completed apply evidence from immutable baseline `43a73df5b346bc41512911644534bff46596f74c` under RIG-BATCH-009. Historical failures remain separate from current machine observations. Newest-started completed attempts win; success watermarks prevent older concurrent failures from resurfacing. No event database, native output capture, automatic repair or permanent-failure classification was introduced.

### Change Summary

Factored persistence and shared projection into `src/rig/25-apply-history.bash`, added dispatch hooks in the application module and health projections in the observation module, and registered the module in deterministic assembly. Added `tests/rig-apply-history.bats` and aligned the state specification, command guide, manual and Unreleased notes. The title now accurately describes historical evidence.

### Verification

The 23 focused history cases cover the original complete run plus deterministic lock-handoff and unresolved-state regressions. The full local gate passed: repository audit, ShellCheck of authored and assembled code, Bash syntax, deterministic assembly, benchmark, six read-only native-provider probes, all 353 Bats tests with stdin from /dev/null, and manual lint. Tests cover every dispatched kind, provider/platform/profile separation, changed declarations, no attempts for rejected or skipped work, parallel disjoint writes, reversed completion, newer in-flight work, interruption, 4 MiB and 4096-row bounds, corruption, permissions, privacy, atomic replacement and byte-preserving reads.

### Outstanding concerns

None within the approved scope. The configured state home's ancestors remain user-selected trusted paths; the owned state/history boundary rejects unsafe or inaccessible paths but does not defend against adversarial same-user replacement of trusted ancestors. A history-write warning does not change the provider's real outcome. Stale foreign locks are not automatically removed.

### Post-change review

Two independent reviewers checked transaction safety and dispatch/projection integration. Review and verification found and fixed hidden-NUL acceptance, EXIT-trap local lifetime, inaccessible directories being mistaken for absent history, and a lock disappearing between failed acquisition and inspection. Each has regression coverage. The legacy no-HOME provider-default fixture now supplies explicit isolated state; a separate regression proves unresolved state is unavailable, not missing history, while explicit state restores healthy read-only behavior. Initial fixture failures were traced to invalid schedule syntax and an already-present dependency correctly not being dispatched; corrected fixtures exercise the intended contracts. Assembled-code lint findings were resolved with quoted literals and narrowly documented annotations for intentional subshell-local copies. No live apply was used.

### Mini recap

An installed target can now truthfully have a separate historical failure finding; later matching success clears it, unrelated work does not, and read-only commands never repair state. RIG-STATE-035 and the inspection guide retain the contract. This item is awaiting human acceptance; presentation and release remain separate records.

## Done

Accepted 2026-10-01 by Kris on the review packet above.

## Discussion

### Readiness

Prepared for Ready under the user's 2026-10-01 request. Scope, implementation boundary and verification are fixed below; this planning transition does not start implementation or authorise live-machine changes.

### Last attempted result, not permanence

Use the latest actual failure and its timestamp, not a consecutive-failure threshold or an event log. Repeated failure updates that evidence; a matching success clears it. The stable title is historical, not a claim that Rig can prove permanence. This keeps the chosen reliability benefit small and understandable.

### Locked evidence and concurrency contract

Use newest-started completed attempt ordering, not wall-clock comparison. An older invocation finishing late cannot overwrite a newer completed success or failure. Native operations remain concurrent; hold the history lock only to allocate a token or atomically merge a result, never while invoking a provider. An interrupted in-flight attempt publishes no outcome; all previously completed and published targets survive. Contention or unsafe/corrupt state must not hang indefinitely or overwrite another owner's lock.

Keep at most one outcome per currently declared target/provider pair, across all profiles, per platform. Prune removed pairs only on a real history write; read-only commands never prune. Successful watermarks are internal concurrency evidence, not a public success log. Apply no age-based expiry. Cap the file at 4 MiB and 4096 rows, reject duplicates and invalid tokens, and preserve the previous file with an explicit warning if a bound or safe publication check fails. Store no locators, arguments, provider output or secrets.

Selected failures appear in a separate historical section and JSON apply_failures array with qualified target, provider/authority, recorded UTC time, read-only age and native exit status. Preserve native rows/counts and add a separate historical count. Historical failures remain visible under problems-only filtering and contribute to health exit status 1; missing history is neutral. Malformed, unreadable or unsafe existing history produces a separate unavailable-history finding and exit 1. Future timestamps expose clock discrepancy rather than a negative age. Failure to write history warns separately and does not change the already-observed provider outcome or mutation exit status.

### Scope and stale evidence

Match history by selected qualified target, provider/authority and platform. Same-provider declaration edits retain the historical finding with a last-recorded-attempt/declaration-may-have-changed label; provider replacement does not inherit its predecessor's failure. Deleted or unselected targets do not contaminate unrelated status. A matching successful real attempt clears the failure; a declaration edit alone is not proof of recovery.

### Interrupted writes and concurrency

Persist completed attempts safely without turning a failed ledger write into a fictional provider failure. Leave previous valid evidence intact when publication cannot complete. Interrupted in-flight operations publish no completed outcome; completed results already published survive. A whole-run report that overwrites unrelated targeted results is not an acceptable shortcut.
