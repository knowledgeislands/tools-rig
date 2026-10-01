---
id: RIG-CLI-025
area: CLI
title: Quiet terminal phase completion
theme: cli
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 5f4aad112a2ece87bee915b3bb72e9d246bf0c0b
created_at: 2026-10-01T21:48:03Z
updated_at: 2026-10-01T22:10:55Z
---

## Goal

Routine configuration work disappears cleanly from the interactive display rather than leaving verbose success summaries and growing blank gaps. Failures, interruption, native diagnostics and noninteractive logs remain visible and truthful.

## Context

Acceptance use of the adaptive footer exposed four configuration phase summaries before a retired Brewfile binding error. The user approved both a source-owned chezmoi migration and a Rig presentation refinement, with delegation. The footer's end helper currently prints a durable summary for every phase; each new phase also reserves two more rows. An isolated screen-model check showed that suppressing summaries alone still accumulates blank space.

## Boundary

Refine the existing adaptive footer, not the public command surface or provider protocol. Preserve Bash 3.2, stdout bytes, exit status, plain/redirected progress and native terminal ownership. No cursor-position queries, child PTY, new dependency, native-output filtering, unsafe erasure or removal of protective native partial-line separators. ChezMoi changes belong to that repository's existing formula migration record; no live apply, publication, release, acceptance or pruning belongs here.

## Current state

The existing display implementation is committed and awaiting human review in the [live display record](RIG-CLI-023-design-live-operational-display.md). Its code is available, so acceptance is not a build dependency. This is a separately approved refinement, not silent acceptance or reopening of that delivery. The complete current baseline gate passed with 375 Bats tests before implementation.

## Steps

- [x] Suppress durable summaries only for complete, failure-free phases that still qualify for the interactive footer; keep failures, interruption, incomplete counts, failed-item outcomes and line/fallback summaries.
- [x] Introduce an explicitly scoped owned configuration group around the four configuration phases, reusing one footer reservation. Guarantee cleanup and original status on every loader return; do not leak grouping into later resolution, native work or report output.
- [x] Add isolated terminal regressions for successful skips, adverse outcomes, consecutive-phase fixed spacing, early errors, zero work, display-mode changes and resize/fallback. Retain native partial-line, signal, privacy and stdout-equivalence coverage.
- [x] Align the guide, manual, specification and changelog; regenerate the single executable once worker edits are complete.
- [x] Review terminal ownership independently and run the complete local gate, retaining acceptance evidence and a canonical review packet.

## Files touched

`src/rig/00-runtime.bash`, `src/rig/10-configuration.bash`, `tests/rig-progress.bats`, `tests/helpers/tty-progress.py`, affected assertions in `tests/rig.bats` and `tests/rig-output-contract.bats`, generated `bin/rig`, `docs/specs/orchestration.md`, `docs/guides/user/commands.md`, `man/rig.1`, `CHANGELOG.md` and this record. No provider execution changes or new flags are expected.

## Verify

Run the complete AGENTS.md gate with Bats stdin redirected from `/dev/null` and the existing test-only Python override when needed. Compare one versus several successful configuration phases in the bounded screen fixture to prove spacing does not grow per phase. Preserve a diagnostic sentinel, full terminal margins, signal-compatible status and exact line-mode summaries. The ten-command output-contract suite must remain green. Use only isolated fake-provider fixtures, never a live apply.

## Dependencies / blocks

The adaptive renderer exists. ChezMoi migration can proceed independently with a stable copy of the executable and its own reviewed source/apply boundary. Release remains separate. User approval in the current conversation covers both corrections and delegation; no additional runtime design is implied.

## Delegation

The renderer worker owns the two authored modules, terminal helper and progress tests plus affected existing Bats assertions, including terminal-outcome assertions in the all-command output-contract suite. The coordinator owns documentation, roadmap, assembly, Git and the aggregate gate. A read-only independent reviewer checks cleanup, grouping, counters, mode transitions, native boundaries and the final diff. Shared primary checkout, disjoint path ownership and no worker Git writes. Do not regenerate the shared executable while another test run is reading it; use a private payload for focused tests. Return touched paths, exact checks, findings and limitations. Stop for unsafe native cursor assumptions, external dependencies or a broader rendering contract. The coordinator integrates only after the worker freezes its candidate.

## Documentation impact

### Decision Records

No new provider or terminal authority decision: retain the established native handoff boundary.

### Specifications

Refine RIG-ORCH-019 to distinguish transient successful terminal phases from durable adverse outcomes and unchanged plain logs.

### Guides

Explain the quieter terminal completion policy and unchanged explicit line mode; preserve the documented conservative native and resize limits.

### Roadmap

Leave the original display record awaiting acceptance and the release record unexecuted. This follow-up ends at its own awaiting-review boundary.

## Review

### Delivered

Quiet terminal completion and bounded configuration-phase spacing, delivered in `53684b2da0f4c4661994b52ff0998860301fc88f` from immutable baseline `5f4aad112a2ece87bee915b3bb72e9d246bf0c0b`. The approved presentation boundary held: no command, flag, provider, runtime dependency, live apply, release or acceptance change. The renderer worker's frozen candidate was independently reviewed before integration.

### Change Summary

`rig_progress_end` suppresses permanent summaries only for complete, failure-free phases that remain eligible for the footer. The configuration loader scopes a shared reservation to its four owned phases and cleans up on every return. Adverse outcomes, explicit line mode, native ownership and final command outcomes remain intact. The assembled executable, guide, manual, orchestration specification and changelog are aligned; help syntax and completion generation require no portable change because the public command surface is unchanged.

Nine additional progress regressions cover grouping, fixed spacing, errors, skips, mode changes and terminal fallback. Existing all-command tests now verify final visible outcome placement with the bounded screen model and require the exact outcome bytes at the raw stream tail; stdout, status and native-byte checks remain unchanged.

### Verification

The complete local gate passed across the final candidate checks: `ki repo audit --repo .` (20 skills); the AGENTS.md `shellcheck` and `bash -n` target lists; `scripts/assemble-rig --check`; `scripts/benchmark-rig`; `scripts/smoke-native-providers`; `RIG_TEST_PYTHON=/opt/homebrew/opt/python@3.14/bin/python3.14 bats tests/ </dev/null` (384 passed); and `mandoc -T lint man/rig.1`. Targeted `rumdl check` and `git diff --check` also passed. The focused suites passed all 23 progress tests and seven output-contract groups.

The first integrated run found four obsolete raw-line assertions, corrected with independently reviewed visible-screen and trailing-byte checks. A subsequent aggregate gate stopped at the unchanged eight-second observation budget during heavy host load; an isolated retry also missed it. No budget or runtime code was changed. After the functional suite completed, sequential baseline and candidate benchmarks both measured status at six seconds. This supports host contention rather than a regression; timing remains host-sensitive. Final functional evidence is `/tmp/rig-migration.xGuPBG/rig-final-tests.log`, the successful timing comparison is `rig-benchmark-comparison.log` beside it, and earlier failed runs remain retained rather than overwritten.

### Outstanding concerns

No remaining implementation or verification blocker. Human visual acceptance remains outstanding. The conservative initial separation row and resize/native-output limits are intentional; the fixture is a bounded terminal model, not proof for every terminal emulator.

The coordinated ChezMoi source migration is separately committed and awaiting review under `DOTFILES-UE-036`. Its exact six-target diff still needs explicit application approval; the live retired-manifest error is not claimed fixed here. No packages or services were changed.

### Post-change review

The delivered change meets the goal without retaining cursor ownership across native writers or hiding failures. Independent review covered cleanup, counters, signal handling, mode changes, grouping and the strengthened final-outcome assertions, with no remaining findings. Exact stdout and exit-status checks passed across all ten public commands. The original display item and this follow-up remain separate acceptance decisions; neither was self-accepted or pruned.

### Mini recap

Routine successful terminal phases are transient, configuration phases share one bounded reservation, and errors and plain logs remain durable. Implementation, documentation and verification are complete and ready for acceptance. No new durable guidance is proposed beyond the updated owning specification and guide. Live ChezMoi application, other roadmap work and release remain outside this delivery.

## Discussion

### Quiet success, durable failure

Successful footer state is transient; repeating it as a permanent log defeats the compact display. A phase containing failures, an incomplete denominator or interruption must remain legible after cleanup. Plain output is a log rather than a frame, so its existing events and summaries remain unchanged. Re-evaluate terminal eligibility at phase end so a lost or resized terminal does not silently lose its summary.

### Bounded row ownership

The configuration loader is a proven contiguous block of Rig-owned work with no native terminal writer. Reuse a single reservation only inside this explicit group, and close it on every return. Do not generalise deferred cleanup to arbitrary phases. One conservative initial separation may remain; the requirement is to remove repeated phase-by-phase gaps without guessing the cursor position or erasing opaque native diagnostics.

### Rendered outcome assertions

The first integrated run exposed an old test assumption: a durable success summary had supplied a newline before the final outcome, so the raw terminal transcript's last line began with that outcome. Quiet completion instead restores column one through terminal controls. Verify the final visible row with the existing bounded screen model and retain raw trailing-outcome ordering, exact stdout, native-byte and status checks. Do not reintroduce blank lines merely to satisfy a byte-line assertion that no longer describes terminal presentation.
