---
id: KI-TOOL-RIG-CORE-055
area: CORE
title: Interpreter port owner matching
purpose: capability
theme: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 7cbe3407552b21ec395223dad7b6b2aef5c108b7
created_at: 2026-10-14T16:37:00Z
updated_at: 2026-10-18T04:15:00Z
---

# Interpreter Port Owner Matching

## Goal

A private port owned by a tool that runs under an interpreter, such as a Python package started as `python -m package`, is recognised as owned by that tool. `rig doctor` stops reporting a working service as `conflicting`, while a listener that really belongs to another process is still reported.

## Context

On 14 October 2026 Mac Studio `sol` reported `port.headroom: conflicting (owner: Python; expected: headroom-ai)` while the Headroom proxy was working and serving Claude Code (mac-studio-bootstrap thread, difference D13 in `rig-guide.report.md`, item 8 in `sol-fix.report.md`).

The personal configuration declares `[port.headroom]` with `owner = "tool:headroom"`, and `[tool.headroom]` installs through `uv` with `install.locator = "headroom-ai[all]"`. A read-only check of the listener on 8787 found the process name `Python` and a readable command line that runs the module through `-m headroom.<module>`; it contains neither `headroom-ai` nor a `/headroom` path component.

What Rig does today:

- [RIG-STATE-026](../specs/state.md#rig-state-026--private-port-expected-versus-observed-state) requires an ownership match on the listener's full command line against the owner's declaration (a tool's selected locator without package extras) as a complete argument token or path component, with an exact executable-name match as fallback.
- [`rig_expected_owner_identity`](../../src/rig/22-observation.bash) turns `headroom-ai[all]` into the identity `headroom-ai`, and `rig_owner_matches_listener` matches it only as a whole token or path component. A Python distribution name (`headroom-ai`) differs from its import name (`headroom`), and a `-m` entry point appears as a dotted module token, so neither form matches. Because the command line was readable and differed, the specification's rule makes it `conflicting` rather than unverified.

## Boundary

- In: recognising interpreter entry points in ownership matching, at least `-m MODULE[.sub]` whose top-level package matches the owner, and deciding how the owner's import name is known (the tool identifier, a distribution-to-import-name rule, or an optional declared `owner-command` or match field); the RIG-STATE-026 amendment; isolated Bats cases with fake listener records for the matching, non-matching and unreadable forms.
- Out: the personal Headroom declaration and its deployment (chezmoi, KB-DOTFILES-UE-090); restarting or reinstalling Headroom; other interpreters beyond what planning chooses to cover (Node `node path/to/cli.js` already matches by path component).

## Current state

Delivered locally to Awaiting review on 18 October 2026 by the tools-burndown run, from baseline `7cbe340`, against fixtures only; see Review.

## Steps

- [x] Have `rig_expected_owner_identity` also return the module names a tool owner may run as: the tool identifier and the locator identity with hyphens replaced by underscores.
- [x] Extend `rig_owner_matches_listener` to accept `-m MODULE` or `-m MODULE.SUB` for those names, after the existing token, path and executable-name checks.
- [x] Amend RIG-STATE-026 and its Verify, the manual and the changelog; add the isolated matching, prefix and non-matching cases; assemble and run the gate.

## Files touched

- [Observation](../../src/rig/22-observation.bash) and the assembled [executable](../../bin/rig).
- [Test isolation](../../tests/helpers/isolate.bash), [Rig tests](../../tests/rig.bats) and [Homebrew authority tests](../../tests/rig-homebrew-authority.bats).
- [State specification](../specs/state.md), [manual](../../man/rig.1) and [changelog](../../CHANGELOG.md).

## Verify

- Fake listener records: `Python ... -m headroom.proxy` on a port owned by `tool:headroom` with locator `headroom-ai[all]` is owned; `-m headroom_ai` matches through the hyphen-to-underscore form; `-m headroomx.cli` and an unrelated `-m` command do not match; an interpreter listener running another module is `conflicting`; an unreadable command line stays unverified, as before.
- `bats tests/rig.bats </dev/null`, then the full developer gate.

## Dependencies / blocks

Not blocked; blocks nothing. Headroom is connection-critical for Claude Code on `sol`, so verification stays with fixtures; nothing in delivery touches the running proxy.

## Documentation impact

### Decision Records

None: a bounded extension of the existing doctor and port contracts.

### Specifications

RIG-STATE-026 amended for interpreter entry points, with its Verify.

### Guides

The manual and changelog carry the new findings; the user guides describe doctor generically and need no change.

### Roadmap

Planned together with KI-TOOL-RIG-CORE-052, KI-TOOL-RIG-CORE-054 and KI-TOOL-RIG-CORE-055 and delivered in one commit; no acceptance, prune or release has been performed.

## Review

### Delivered

Delivered locally against fixtures only, from baseline `7cbe340`. Headroom on `sol` was not touched.

### Change Summary

- `rig_expected_owner_identity` sets `RIG_OWNER_MODULES` for tool owners: the identifier and the locator identity with hyphens as underscores.
- `rig_owner_matches_listener` accepts a whole `-m MODULE` or `-m MODULE.SUB` argument for those modules; a shared prefix such as `headroomx` does not match.
- RIG-STATE-026, the manual's port paragraph and the changelog describe it; `tests/rig.bats` adds the matching and non-matching cases.

### Verification

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark within budget, mandoc and diff checks. All 566 Bats tests pass.

Withheld by authority: `scripts/smoke-native-providers` and any live doctor run on `sol` or `terra`.

### Outstanding concerns

- **Provisional plan choice.** The import name is inferred from the tool identifier or the locator, not declared in a new field. A tool whose import name is neither still reports `conflicting`; a declared match field remains a later option. Kris to confirm.
- The `sol` case resolves only if the personal `[tool.headroom]` identifier stays `headroom`.

### Post-change review

Existing port ownership cases pass unchanged; service owners gain no module matching.

### Mini recap

A tool run as `python -m package` now owns its port when the package is the tool's name, so Headroom stops showing as a conflict.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of RIG-RECORDS on 2026-10-14 (decision 70 in the thread's decisions log). The main planning choice is between inferring the import name (simple, but `headroom-ai` to `headroom` is a convention, not a rule) and letting the port or tool declare the command it expects (explicit, one more field). A false `conflicting` on a connection-critical port invites a person to "fix" a working service, so the record matters more than its size suggests. Capture only; adoption, priority and plan belong to this repository.

Adopted, planned and delivered on 18 October 2026 by the tools-burndown run, under the rig-lane report's RIG-ORDER a) ("plan KI-TOOL-RIG-CORE-055, KI-TOOL-RIG-CORE-052 and KI-TOOL-RIG-CORE-054 to Ready in one ki-plan sitting") and Kris's overnight instruction of 18 October 2026, 04:30 BST, to burn the roadmap down as far as possible and take the recommended course on a judgement call. The record was triage, so its adoption to `deliver` / Now and its plan choices below are provisional, for Kris to confirm at review.

### Independent review

The ways-of-working rig-review run reviewed this record on 18 October 2026, read-only and without having written it, at `92d2d27`, under TOOLS-BLOCKERS in the ways-of-working decisions log. The complete local gate passes there: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark and mandoc; all 572 Bats tests pass. `scripts/smoke-native-providers` was not run. The review does not accept the record; acceptance stays with Kris.

**Verdict: no blocking findings.** Two low.

- **Low: the uv tool path already matched.** An existing test shows a listener under `~/.local/share/uv/tools/headroom-ai/bin/python -m headroom.cli` was already owned through the `/headroom-ai/` path component. The new rule's value is the case the new test pins: a Homebrew or framework Python whose path names no tool. Confirm on `sol` that Headroom's listener is that shape; otherwise the original `conflicting` report had another cause.
- **Low: only `-m MODULE` with a space matches.** `-mMODULE` and `python path/to/module/__main__.py` stay unmatched, and a locator with a version specifier such as `pkg==1.2` yields no useful module name; both are within the provisional inference choice.

Confirmed sound: a module matches only as a whole word or a dotted prefix, so `headroomx` and `-m pip install headroom` are rejected; service and scheduled-job owners gain no module matching; an unreadable command line still reports ownership unverified rather than a conflict.
