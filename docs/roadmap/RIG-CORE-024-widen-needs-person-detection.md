---
id: RIG-CORE-024
area: CORE
title: Widen needs-person detection
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

An unattended run says ahead of time that a piece of work needs a person, whatever provider that work belongs to, instead of discovering it as an ordinary failure afterwards.

## Context

`rig update --unattended` reports work that cannot proceed without a person as `unavailable` before invoking it. That pre-emptive check currently recognises exactly one case: a Homebrew store-app target. Any other provider that demands an interactive credential instead reads end-of-file and fails, and a post-hoc non-zero exit is indistinguishable from an ordinary failure.

The narrowest instance of the gap is already observed. A `mas` entry inside a Homebrew manifest is invisible to the check, because a manifest dispatches as one task carrying one representative binding: `brew bundle` calls `mas upgrade`, `mas` calls `sudo` to replace a root-owned bundle, and the whole manifest task fails on one stale App Store app while every other Homebrew result is masked. This workstation's chezmoi source works around it in its own scheduled wrapper by setting `HOMEBREW_BUNDLE_MAS_SKIP` from `mas outdated`.

That workaround now runs daily and holds: the scheduled run on 2026-09-26 completed sixteen targets with none failed and none unavailable, exit 0. The gap is therefore masked rather than closed, and masked on one machine only — any other machine following the same guide meets the original failure, where one stale App Store app fails the whole Homebrew manifest task and hides every other Homebrew result.

## Boundary

This is not a cleverer classifier of non-zero exits after the fact. It does not teach Rig `mas` internals, or any other provider's internals, to serve one machine's quirk, and it does not touch the machine's own wrapper — that belongs to the chezmoi source.

## Current state

The whole check is one predicate, and its narrowness is deliberate and documented in place.

`rig_lifecycle_requires_person` in `src/rig/40-publication-lifecycle.bash:632` returns false for an empty or `skill.*` binding, returns false for any provider that declares a native manifest — with the comment explaining that a manifest task carries one representative binding for many declarations — reads the binding's `kind`, and reduces to `[ "$kind" = mas ]`. That single comparison is the entire recognised set.

Its one caller is `rig_command_lifecycle`, at line 719: when `RIG_UNATTENDED` is 1 and the predicate holds, the entry's executable is set to `-`, `RIG_LIFECYCLE_DETAILS[$index]` becomes `interactive-required`, progress records `skipped`, and the later reporting loop turns that detail into an `unavailable` row and sets `exit_code=1`. So the honest-signal path is complete and correct; only its input is narrow.

The manifest exclusion is what hides the observed case. `rig_lifecycle_manifest` returning true short-circuits the predicate before `kind` is ever read, so a `mas` entry inside a Homebrew manifest is invisible by construction rather than by oversight.

Everything else fails ordinarily. `rig_execute_lifecycle_task` runs with `</dev/null` when unattended, with the comment stating the intent — a provider that asks a question reads end-of-file and fails rather than hanging — and that failure becomes a `failed` row indistinguishable from any other.

No provider declares anything about interactivity. There is no configuration field, no provider-protocol action, and no adapter capability through which a provider could say that work it is about to dispatch needs a person.

## Steps

- [ ] Add a provider-protocol action through which a provider may declare, before dispatch, the entries of an upcoming task that need a credential an unattended run cannot supply, returning nothing when it has none to declare.
- [ ] Define the absence of that action as "declares nothing", so every existing provider keeps working unchanged and no provider is required to implement it.
- [ ] Call the new action during lifecycle preflight for an unattended run, and merge what it returns with `rig_lifecycle_requires_person`'s existing answer rather than replacing it.
- [ ] Keep the `[ "$kind" = mas ]` case as the built-in Homebrew adapter's own declaration, so the behaviour observed today does not regress if a provider declares nothing.
- [ ] For a manifest task whose declaration covers some entries but not all, report one `unavailable` row per declared entry and still dispatch the manifest task, so the remaining entries are not masked by the declared ones.
- [ ] Make exclusion the provider's job, not Rig's: the unattended dispatch tells the provider it is unattended, and the provider excludes the entries it itself declared. Rig never names `mas`, never constructs an exclusion list, and never reads a manifest.
- [ ] Add Bats coverage with a fake provider implementing the new action: assert an unattended run reports the declared entries as `unavailable` with `interactive-required` before invoking anything, that a provider not implementing the action behaves exactly as today, that an interactive run ignores the declaration entirely, and that a manifest task's mixed case follows the stated rule.
- [ ] Update `docs/specs/orchestration.md`, the provider-boundary decision record, `man/rig.1`, and `docs/guides/user/unattended-updates.md` for the widened protocol.

## Files touched

- `src/rig/40-publication-lifecycle.bash` — `rig_lifecycle_requires_person`, `rig_preflight_lifecycle_task`, and the unattended branch of `rig_command_lifecycle`.
- `src/rig/20-orchestration.bash` — the provider-protocol action vocabulary and dispatch.
- `bin/rig` — regenerated by `scripts/assemble-rig`.
- `tests/rig-lifecycle.bats` — the fake-provider declaration cases.
- `docs/specs/orchestration.md`, `docs/decisions/XDR-RIG-001-executable-provider-boundary.md` — the provider contract.
- `man/rig.1`, `docs/guides/user/unattended-updates.md` — the documented unattended behaviour.

## Verify

```sh
scripts/assemble-rig --check
bats tests/
scripts/smoke-native-providers
shellcheck bin/rig src/rig/*.bash
mandoc -T lint man/rig.1
```

Pass means the new Bats cases are green, `scripts/smoke-native-providers` still passes with no provider implementing the new action, and this workstation's scheduled `rig update --unattended` run still completes with none failed — the point of the work is that the same outcome no longer depends on the machine's own `HOMEBREW_BUNDLE_MAS_SKIP` wrapper, so a second machine following the same guide reaches it too.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. It is independent of the output work and of [RIG-CLI-016](RIG-CLI-016-apply-one-resource.md), touching lifecycle preflight rather than apply. It has a cross-repository consequence rather than a dependency: once the signal is honest, this workstation's chezmoi source can retire its `HOMEBREW_BUNDLE_MAS_SKIP` wrapper, which that repository owns and which this item must not change.

## Documentation impact

### Decision Records

`docs/decisions/XDR-RIG-001-executable-provider-boundary.md` changes, because the provider protocol gains an action and the boundary's shape is what that record owns. The change is additive and optional, and the record should say so plainly: a provider that does not answer is not in breach.

### Specifications

`docs/specs/orchestration.md` changes for the new action, for when it is called, and for the manifest mixed-case rule. The `--unattended` contract's existing promise — that the flag changes neither target selection, dependency order, dispatch, the per-task outcome vocabulary, nor exit statuses — must be re-read against this work, because moving an entry from `failed` to `unavailable` changes which row a reader sees even though both exit 1.

### Guides

`docs/guides/user/unattended-updates.md` carries the scheduled-job recipe and must say what a declared interactive entry now looks like in the report. `man/rig.1` needs the same for `--unattended`.

### Roadmap

No new follow-on work in this repository. The dotfiles source has a consequential item — retiring the `HOMEBREW_BUNDLE_MAS_SKIP` wrapper once this lands — which belongs to that repository's roadmap and is mentioned here only so the connection is not lost.

## Discussion

### Why not a cleverer classifier

A failure that has already happened carries no reliable evidence that a person was what it wanted. Widening the honest signal means each provider declaring, before dispatch, which of its work needs a credential a scheduled run cannot supply.

### Where the signal has to come from

A manifest is opaque to Rig by design, so either the provider gains a way to report the interactive entries it is about to hand to its own tooling, or a manifest task keeps reporting one outcome for many entries. The second is defensible; it just has to be stated rather than assumed.

Planning took the first, with the exclusion left on the provider's side of the boundary. The provider declares its interactive entries and then excludes them itself when told the run is unattended; Rig reports each declared entry as `unavailable` and dispatches the rest of the manifest as one task. That keeps the opacity intact — Rig never names `mas`, builds an exclusion list, or reads a manifest — while the reader still gets one row per thing that needs them.

The second option was rejected on the evidence rather than on principle. One stale App Store app masking every other Homebrew result is the observed failure, and reporting one outcome for many entries preserves exactly that masking. It would be honest about the limitation and useless against the problem.

This is also what the machine's own wrapper already proves works: `HOMEBREW_BUNDLE_MAS_SKIP` computed from `mas outdated` is the provider-side exclusion, written by hand on one machine. The work is to move that capability behind the protocol so every machine gets it, not to reinvent it.
