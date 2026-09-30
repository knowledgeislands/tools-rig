---
id: RIG-CLI-017
area: CLI
title: Report what needs attention
theme: cli
horizon: next
status: done
blocks: []
blocked_by: []
baseline_ref: abe812f2c48640bac54d710a990beb9bcf5c5238
created_at: 2026-09-26T13:00:00Z
updated_at: 2026-09-30T00:00:00Z
---

## Goal

Somebody who runs `rig status` on a healthy-but-imperfect workstation learns what needs their attention without reading past everything that does not.

## Context

`rig status` on this workstation's default profile emits 166 lines. Twenty of them are rows in a state other than `present`: seven missing npm tools, seven drifted launchd resources, two missing skills, three unavailable ports, and one unknown external tool. The other 146 lines say that something is fine.

There is no way to ask for less. The command takes `--profile`, `--unmanaged`, and `--format`, and none of those narrow by state. So the reader either scrolls, or pipes the output through a filter they have to write themselves, and the exit status of 1 tells them a problem exists without telling them where.

The summaries do not rescue this, because each one arrives after the section it summarises. `Summary: present=81 missing=7 ...` is on line 106, `Resource summary: selected=44 retire-pending=0 unhealthy=7` near the end, `Port summary: selected=3 unhealthy=3` last of all, and the skill table carries no summary at all. There is no single line anywhere that says how many things need a person.

The same shape costs more than attention. The run took eighty seconds, and because progress is a terminal-aware stderr affordance, a redirected or piped run prints nothing at all until it finishes and then prints everything at once.

## Boundary

This is about which rows and summaries a reader gets and in what order. It is not a change to what Rig observes, to the state vocabulary, to exit statuses, or to the JSON projection's completeness — a filtered text view and a complete machine view can coexist, and the machine view should stay complete.

It does not cover making the tables themselves consistent, which is [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md), nor the separate question of whether `catalogue-only` entries should be counted as unhealthy at all, which is [RIG-CORE-027](RIG-CORE-027-catalogue-only-is-not-unavailable.md).

## Current state

`rig_command_status` in `src/rig/20-orchestration.bash` accepts exactly `--profile NAME`, `--unmanaged`, and `--format text|json`. None of them narrows by state, so there is no code path that shows fewer rows than the profile selects.

The count the reader wants already exists before any output is written. `rig_status_totals` runs first and sets `RIG_STATUS_UNHEALTHY` across tools, skills, resources, stale resources, and ports, and `rig_outcome_note` is already handed `unhealthy=$RIG_STATUS_UNHEALTHY present=$RIG_STATUS_PRESENT`. That total is then spent only on the trailing outcome line on stderr, while stdout opens with `Profile:` and `Platform:` and the full tool table. Printing it first is a reordering, not a new computation.

The per-section summaries are emitted by the section printers in order: the tool summary after the tool table, then `rig_print_skill_status`, `rig_print_resource_status`, and `rig_print_port_status` each printing their own. The skill table carries no summary at all.

Progress explains the silence. `rig_progress_select_renderer` in `src/rig/00-runtime.bash` maps `RIG_PROGRESS=auto` to `bar` only when the context is operational and stderr is a terminal, and to `off` otherwise. `RIG_PROGRESS=lines` and `RIG_PROGRESS=always` already produce the line form; `always` is exactly the non-TTY fallback `auto` declines to use.

## Steps

- [x] Print one verdict line as the first line of `rig status` stdout, naming the count that needs a person from `RIG_STATUS_UNHEALTHY` and the count that does not, before `Profile:` and before any table.
- [x] Add a summary line to the skill table so all four sections summarise themselves consistently.
- [x] Add `--problems` to `rig status`, narrowing every text section to the rows that need attention, and suppressing a section whose filtered row count is zero.
- [x] Leave `--problems` out of the JSON projection's effect: `--format json` keeps emitting every row and every summary, so the machine view stays complete and the two flags compose without argument.
- [x] Spun out. Changing `RIG_PROGRESS=auto` to select `lines` for an operational command whose stderr is not a terminal is now [RIG-CLI-021](RIG-CLI-021-report-progress-when-redirected.md), for the reasons under Discussion.
- [x] Regenerate completions for the new flag and update `man/rig.1` and `docs/guides/user/commands.md`. `README.md` carries no command summary to update.
- [x] Add Bats coverage for the verdict line's position and arithmetic, for `--problems` hiding present rows and empty sections while preserving exit status, and for `--problems --format json` emitting the complete payload. Progress coverage waits on the held step.

## Files touched

- `src/rig/20-orchestration.bash` — `rig_command_status`, its argument parsing, the verdict line, the section printers, and the skill summary.
- `src/rig/00-runtime.bash` — `rig_progress_select_renderer` and the generated Bash and Zsh completion text.
- `bin/rig` — regenerated by `scripts/assemble-rig`.
- `tests/rig.bats` — verdict, filter, and progress assertions.
- `man/rig.1`, `docs/guides/user/commands.md`, `README.md` — the documented status surface.
- `docs/specs/state.md` — the status report contract and the progress affordance.

## Verify

```sh
scripts/assemble-rig --check
bats tests/
shellcheck bin/rig src/rig/*.bash
mandoc -T lint man/rig.1
rig status | head -1
rig status --problems | wc -l
rig status --problems --format json | python3 -m json.tool >/dev/null
rig status >/dev/null 2>&1; echo $?
```

Pass means the first line of stdout names the attention count, `rig status --problems` on this workstation emits far fewer lines than the current 166 while still listing all twenty rows that need a person, `--problems` does not change the exit status, `--problems --format json` emits the complete payload, and the new Bats cases are green.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. Two items reduce its work without gating it: [RIG-CORE-027](RIG-CORE-027-catalogue-only-is-not-unavailable.md) removes thirteen rows from the set `--problems` would otherwise have to reason about, and [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md) makes the sections this filters render through one renderer. Landing either of those first makes this smaller; landing this first costs a small rebase in the section printers.

## Documentation impact

### Decision Records

None. Reordering a report and adding a filter decides nothing about what Rig observes or how it is authorised to act.

### Specifications

`docs/specs/state.md` changes twice: the status report gains a leading verdict line and an optional filtered text view, and the progress affordance's `auto` behaviour changes for a non-terminal stderr. The JSON projection's completeness rule is restated rather than changed, because `--problems` deliberately does not reach it.

### Guides

`docs/guides/user/commands.md`, `man/rig.1`, and the README status summary must all describe `--problems` and the verdict line, and the guide should say plainly that the filter is a text affordance and the JSON payload is always complete.

### Roadmap

No new follow-on work. If making attention-first the default rather than a flag is ever wanted, that is a separate item with a much larger consumer impact, and this item deliberately does not take it.

## Review

### Delivered

The approved boundary was the rows and summaries a `rig status` reader gets and their order, with no change to observation, the state vocabulary, exit statuses, or the JSON projection's completeness. Baseline `abe812f2c48640bac54d710a990beb9bcf5c5238`; delivered in `04d0e55`. `rig status` opens with `Needs attention: N of M entries` naming the sections that hold them; every section, including the skill table, closes with its own summary counters; `rig status --problems` narrows the text sections to the entries that need attention and drops a section the filter empties. The progress step was excluded and is RIG-CLI-021.

### Change Summary

`src/rig/20-orchestration.bash` gained `rig_status_needs_attention`, `rig_print_status_verdict`, the `--problems` flag, and per-section unhealthy counters; `src/rig/00-runtime.bash` gained the completion entries; `docs/specs/state.md` gained RIG-STATE-031 and the per-section summary rule; `man/rig.1`, `docs/guides/user/commands.md`, and `CHANGELOG.md` describe the surface; `tests/rig.bats` gained three cases. One approved deviation: the filter's rule is "state other than `present` and apply result not neutral" rather than the step's "state other than `present`", so sixteen catalogue-only rows that ask nobody for anything stay hidden. The change was committed from a clean worktree because the checkout also carried another session's uncommitted RIG-CORE-031 work in the same files.

### Verification

`scripts/assemble-rig --check`, `shellcheck`, `bash -n`, `scripts/benchmark-rig` (status 5s against an 8s budget), `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1`, `bats tests/` (all green with the three new cases), and `ki repo audit --repo .` PASS, all on 2026-09-28.

### Outstanding concerns

The `RIG_PROGRESS=auto` change that was step 5 is not delivered here; it is captured as [RIG-CLI-021](RIG-CLI-021-report-progress-when-redirected.md). Nothing else is unchecked or failing.

### Post-change review

The goal is met: the first line of stdout answers how much needs a person and where. Scope held to presentation; the machine view is byte-identical with and without `--problems`. Regression risk is low — the counters were already computed for the exit status, and the filter is opt-in. Ready for acceptance.

### Mini recap

Delivered a verdict line, per-section summaries, and an opt-in `--problems` filter for `rig status`; verified by the full local gate; one step spun out as RIG-CLI-021. Possible learning route: the "needs attention" rule in RIG-STATE-031 could inform how RIG-CORE-027 renames the catalogue-only state.

## Done

Accepted 2026-09-30 by Kris Brown on the review packet above.

## Discussion

### A selector, a default, or both

A `--problems` flag is the smallest change and leaves every existing invocation untouched. Making attention-first the default is the larger claim — that the full listing is the special case — and it would change what every existing reader and script sees. The two are not exclusive: the ordering change is cheap and safe on its own, and the filter can follow.

### One verdict line

Four per-section summaries and no overall one means the reader assembles the verdict themselves. A single leading line naming the count that needs a person, before any table, would answer the question most runs are actually asking.

### Progress on a redirected run

Eighty seconds of silence is a property of progress being stderr-and-TTY-only. `RIG_PROGRESS=lines` already exists for this. Whether a long read-only command should default to line progress when its stdout is redirected is worth deciding here rather than leaving to each caller.

Planning settled it in favour of line progress. Precision matters: `auto` already draws a bar whenever stderr is a terminal, so a run that pipes only stdout is unaffected, and the silence belongs to a run that redirects stderr too. For that run, `auto` currently chooses `off` while `always` chooses `lines` — the fallback exists and `auto` simply declines to use it. Progress goes to stderr, which is never part of the report, so a consumer parsing stdout cannot be broken by it, and a consumer that wants nothing still has `RIG_PROGRESS=never`. The cost is stderr output in scripted runs that previously had none, which is why it is called out as a specification change rather than an implementation detail.

### The selector and the default, settled

Planning took the selector and the reordering, and declined to change the default listing. The verdict line and the skill summary are the cheap half and answer the common question on their own; `--problems` is opt-in, so no existing invocation or script sees different rows. Making attention-first the default is the larger claim the record identifies, and it is not needed to fix what was observed.

### What the filter actually hides

The step above said rows "in a state other than `present`", and on this workstation that set includes sixteen catalogue-only tools — entries that are observed by artefact, materialise through no provider, and ask nobody for anything. A filter that showed them would answer the wrong question, so the implemented rule is narrower: an entry needs attention when its state is other than `present` _and_ its apply result is not neutral. That is the same rule `RIG_STATUS_UNHEALTHY` already applied to the exit status and the outcome line, so the verdict, the filter, the exit status, and the machine payload now all agree about what a problem is. It is recorded as `rig_status_needs_attention` and specified as RIG-STATE-031.

[RIG-CORE-027](RIG-CORE-027-catalogue-only-is-not-unavailable.md) remains worth doing and is unaffected either way: it changes what a catalogue-only tool's _state_ is called, while this changes only whether a non-present entry is treated as work.

### Why the progress step is held

Changing `RIG_PROGRESS=auto` to choose `lines` for an operational command with a non-terminal stderr is a live behaviour change for runs nobody is watching, including this machine's `workstation-health` scheduled job, which would begin emitting per-item progress into its report. It is also orthogonal to readability: the verdict line and the filter fix what was observed without it. Bats merges stderr into `$output` and the suite's `setup()` sets no `RIG_PROGRESS=never`, so taking it would perturb many unrelated assertions in the same change.

It was left unchecked rather than quietly dropped, and on 2026-09-30 it was spun out as [RIG-CLI-021](RIG-CLI-021-report-progress-when-redirected.md) so this record could close on what it delivered.
