---
id: RIG-CLI-016
area: CLI
title: Apply one resource
theme: cli
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T10:00:00Z
updated_at: 2026-09-26T15:45:00Z
---

## Goal

Somebody who has declared one new thing can materialise that one thing, without asking Rig to reconcile everything else the profile declares at the same time.

## Context

`rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` has no finer selector than `--scope`. Installing a single new scheduled job on this workstation therefore meant running `rig apply --scope resources`, which reconciled all forty-three declared resources.

That was safe only because `rig status` was read first and showed forty-two of the forty-three already `present`, so the one material change was the new agent. Checking beforehand is a procedural habit standing in for a missing selector, and the habit is what fails: the wider the blast radius of a one-line declaration, the more likely somebody applies without looking.

The workaround costs time as well as safety. Reconciling forty-three resources to install one is the slowest way to get there, and a failure anywhere in the pass obscures whether the intended change landed — the first `--scope resources` run reported one failure that a second run did not reproduce, and the failing target was never identified because the output covered everything.

## Boundary

This is a selector for an existing command, not a new command, and not a change to how any provider materialises anything. It does not add partial-profile resolution: the profile still resolves in full, and the selector narrows only what gets dispatched.

## Current state

`rig_command_apply` in `src/rig/20-orchestration.bash` accepts `--profile`, `--scope`, and `--dry-run`, each at most once, and rejects anything else. `--scope` is parsed into a single `scope` variable whose only values are `tools`, `skills`, `resources`, and `all`.

The narrowing mechanism a target selector needs already exists and is the right shape. After `rig_resolve_operational_plan "$profile" defer`, the command narrows by emptying plan arrays: `--scope tools` clears `RIG_SELECTED_SKILLS`, `RIG_RESOURCE_PLAN_SECTIONS`, and the four `RIG_STALE_RESOURCE_*` arrays; `--scope skills` clears `RIG_PLAN_TOOLS`. The profile resolves in full first and the selector removes entries afterwards, which is exactly the contract the Boundary asks for, so a target selector belongs in the same place rather than in resolution.

Two facts constrain where the filter can sit. The reconciliation lock is acquired before narrowing, guarded by `{ [ "$scope" = resources ] || [ "$scope" = all ]; } && rig_reconciliation_needed`, so a target selector that resolves to no resources must not still take the lock. And dependency ordering is computed over the plan, with `RIG_PLAN_DETAILS[$dependency_index] != catalogue-only` consulted at `src/rig/20-orchestration.bash:1047`, so removing an entry that another entry depends on changes what ordering means.

## Steps

- [ ] Add a repeatable `--target ID` option to `rig apply`, accepting the identifiers `rig status` already prints for tools, and the `kind:id` forms for skills, resources, and ports, so the selector's vocabulary is the one the reader already has.
- [ ] Reject an unknown target with status 2 before any dispatch, naming the identifier and the profile, so a typo cannot silently apply nothing and report success.
- [ ] Apply the target filter after full profile resolution, in the same place `--scope` narrows, and make `--target` and `--scope` compose by intersection rather than conflict.
- [ ] Walk the declared dependencies of each selected target and include any prerequisite that is not already `present`, so dispatch never runs a target whose prerequisite is absent.
- [ ] Report every entry included by dependency rather than by request as its own row, so the report says plainly that Rig applied more than was asked for and why.
- [ ] Skip the reconciliation lock and the resource receipt load when the resolved selection contains no resource, so a tool-only `--target` run does not serialise against an unrelated resource apply.
- [ ] Regenerate completions for the new option and update `man/rig.1`, `docs/guides/user/commands.md`, `docs/guides/user/operational-resources.md`, and the README apply summary.
- [ ] Add Bats coverage for a single `--target` dispatching one entry, repeated `--target` dispatching exactly those entries, an unknown target rejected at status 2 with no provider call logged, a target whose prerequisite is missing pulling that prerequisite in and reporting it, `--target` composing with `--scope`, and a tool-only selection taking no reconciliation lock.

## Files touched

- `src/rig/20-orchestration.bash` — `rig_command_apply` argument parsing, the target filter, the dependency closure, the lock guard, and the report rows.
- `src/rig/00-runtime.bash` — generated Bash and Zsh completion text for the new option.
- `bin/rig` — regenerated by `scripts/assemble-rig`.
- `tests/rig.bats` and `tests/rig-lifecycle.bats` — selector, rejection, dependency-closure, and lock assertions.
- `man/rig.1`, `docs/guides/user/commands.md`, `docs/guides/user/operational-resources.md`, `README.md` — the documented apply surface.
- `docs/specs/orchestration.md` — the apply selection contract.

## Verify

```sh
scripts/assemble-rig --check
bats tests/
shellcheck bin/rig src/rig/*.bash
mandoc -T lint man/rig.1
rig apply --target scheduled-job:rig-update --dry-run
rig apply --target no-such-thing --dry-run; echo $?
```

Pass means the new Bats cases are green, a `--dry-run` with one `--target` plans that entry and any not-present prerequisite and nothing else, an unknown target exits 2 with an empty provider-call log, and applying one resource on this workstation dispatches one resource instead of forty-three.

## Dependencies / blocks

Nothing blocks this and it blocks nothing. It shares `rig_command_apply`'s argument parsing with [RIG-CLI-019](RIG-CLI-019-describe-every-option.md), which replaces the seven duplicated usage strings in that function with a generated one; whichever lands second describes `--target` through the option table rather than by editing literals, so landing CLI-019 first is slightly cheaper. It also shares the apply report with [RIG-CLI-018](RIG-CLI-018-one-report-renderer.md), which is where the dependency-included rows would render.

## Documentation impact

### Decision Records

None on the selector itself. The dependency-closure choice — include a missing prerequisite and report it, rather than refuse or ignore it — is a material rule about what `rig apply` may do beyond what was asked, and if it proves contentious it belongs in a decision record rather than in this item's prose. Planning's position is recorded under `Discussion`.

### Specifications

`docs/specs/orchestration.md` changes where it states apply's selection and dispatch contract, because a finer selector exists, because dependency closure can widen the selection, and because the reconciliation lock is no longer taken for every resource-capable invocation.

### Guides

`man/rig.1`, `docs/guides/user/commands.md`, and the README apply summary gain the option. `docs/guides/user/operational-resources.md` matters most: it is where the read-status-first habit is taught, and that habit is what the selector replaces.

### Roadmap

No new follow-on work. The unreproducible single failure the record describes — one failure in a forty-three-resource pass that a second run did not reproduce, with the failing target never identified — becomes diagnosable rather than fixed by this item; if it recurs under a narrow `--target` run it is worth its own record with the evidence that run produces.

## Discussion

### What the selector selects

A target name is the obvious unit, since that is what `rig status` reports and what the outcome lines already name. Whether it accepts several, accepts a glob, or must be exact is open; exact and repeatable is the smaller change.

Planning took exact and repeatable. A glob invites the blast radius the item exists to remove, and it makes the unknown-target rejection impossible to state — a pattern matching nothing is indistinguishable from a pattern matching nothing yet. Repeated exact `--target` options give the same reach for the cases that want several, and every one of them can be checked against the resolved profile before anything is dispatched.

### Interaction with dependency ordering

Rig orders dispatch by declared dependency. Applying one target either ignores that ordering, which can dispatch something whose prerequisite is absent, or honours it and quietly applies more than was asked for. Saying which, and reporting it, matters more than the choice itself.

Planning honoured the ordering, with the quietness removed. A missing prerequisite is pulled in, and every entry included that way is reported as its own row saying so, which turns the objection into a fact the reader can see. Ignoring the ordering would make a narrow apply capable of leaving the machine in a state no full apply could reach, which is a worse failure than doing slightly more than asked. Note the softening: only a prerequisite that is not already `present` is added, so on a healthy machine a one-target run really does dispatch one target.
