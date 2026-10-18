---
id: KI-TOOL-RIG-CORE-054
area: CORE
title: Command Line Tools check
purpose: capability
theme: rig
kind: deliver
status: done
blocks: []
blocked_by: []
baseline_ref: 7cbe3407552b21ec395223dad7b6b2aef5c108b7
created_at: 2026-10-14T16:37:00Z
updated_at: 2026-10-18T17:26:05Z
---

# Command Line Tools Check

## Goal

On macOS, `rig doctor` notices when the Command Line Tools are missing or older than the running macOS, and reports that once, as the shared cause, before a person starts an `apply` or `upgrade` that will fail on every Homebrew item for that reason.

## Context

On 14 October 2026 Mac Studio `sol` ran macOS 27 with the Command Line Tools for macOS 26.6. `rig upgrade` reported `planned=0 completed=26 failed=84`: every Homebrew install or upgrade failed, because Homebrew rebuilds `pkgconf` first and refuses to build with Command Line Tools older than the system. Nothing in Rig's output named that cause; it was found by reading native Homebrew output item by item (mac-studio-bootstrap thread, difference D1, recorded in the run report `rig-guide.report.md`). Kris has since installed the Command Line Tools by hand (`pkgutil` now reports 27.0 on macOS 27.0.1).

What Rig does today:

- [Doctor](../../src/rig/22-observation.bash) reports native provider availability (`rig_doctor_native_availability`: `brew`, `uv`, `mise`, `npm`, `chezmoi` present or absent) and one Homebrew housekeeping finding (`rig_doctor_competing_autoupdate`). It does not look at the toolchain Homebrew itself depends on.
- [Doctor health synthesis](../specs/state.md#rig-state-013--doctor-health-synthesis) and [read-only doctor](../specs/state.md#rig-state-014--read-only-doctor) give the place for a read-only environment finding with owner and action fields.

The native evidence is cheap and read-only: `xcode-select -p` for presence, `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables` for the installed version, and `sw_vers -productVersion` for the system. Homebrew's own `brew config` and `brew doctor` report the same mismatch, but are slower and may touch the network.

## Boundary

- In: a read-only macOS doctor finding when the Command Line Tools are absent or their major version is below the running macOS major version, with `owner=environment` (or the owner field the specification settles on) and an action naming the fix (`xcode-select --install` or Software Update); a note in the same output that Homebrew items will fail until it is resolved; the matching `rig apply --dry-run` preflight warning if planning finds it cheap; specification text and isolated tests with stubbed `xcode-select`, `pkgutil` and `sw_vers`.
- Out: installing or updating the Command Line Tools; running `brew doctor`; Xcode.app as an alternative toolchain beyond accepting it as present; Linux toolchains.

## Current state

Delivered locally to Awaiting review on 18 October 2026 by the tools-burndown run, from baseline `7cbe340`, against fixtures only; see Review.

## Steps

- [x] Add `rig_doctor_command_line_tools`, which runs only on macOS when the resolved plan contains a Homebrew-bound tool, through overridable `RIG_XCODE_SELECT`, `RIG_PKGUTIL` and `RIG_SW_VERS`.
- [x] Report one `command-line-tools` tool finding, `missing` or `outdated` by major version, with `owner=environment`, the fix as the action and the note that Homebrew items fail until it is resolved; count it as one environment check.
- [x] Stub the three commands in test isolation so no test reads the host toolchain.
- [x] Add RIG-STATE-047, the manual text, the changelog and the Homebrew authority test; assemble and run the gate.

## Files touched

- [Observation](../../src/rig/22-observation.bash) and the assembled [executable](../../bin/rig).
- [Test isolation](../../tests/helpers/isolate.bash), [Rig tests](../../tests/rig.bats) and [Homebrew authority tests](../../tests/rig-homebrew-authority.bats).
- [State specification](../specs/state.md), [manual](../../man/rig.1) and [changelog](../../CHANGELOG.md).

## Verify

- Stubbed `xcode-select`, `pkgutil` and `sw_vers` with a Homebrew tool selected: no developer directory reports `command-line-tools: missing` with `action=run-xcode-select-install`; Command Line Tools 26.6.0.0.1 on macOS 27.0.1 reports `outdated (installed:26.6.0.0.1;macos:27.0.1;...)` with `action=update-command-line-tools`; both carry `owner=environment` and fail doctor once.
- Current tools with a minor difference (27.0 on 27.0.1), an Xcode.app selection and a plan without Homebrew report nothing; the last runs none of the three commands.
- `bats tests/rig-homebrew-authority.bats </dev/null`, then the full developer gate.

## Dependencies / blocks

Not blocked; blocks nothing. Related to the shared-failure reporting note (R2) in the [mac-studio-bootstrap Project note](../../../ki-principal/Streams/Projects/mac-studio-setup/mac-studio-setup.md), which would collapse 84 identical failures into one; this record catches the cause before the run instead.

## Documentation impact

### Decision Records

None: a bounded extension of the existing doctor and port contracts.

### Specifications

New RIG-STATE-047, Command Line Tools for Homebrew work.

### Guides

The manual and changelog carry the new findings; the user guides describe doctor generically and need no change.

### Roadmap

Planned together with KI-TOOL-RIG-CORE-052, KI-TOOL-RIG-CORE-054 and KI-TOOL-RIG-CORE-055 and delivered in one commit; no acceptance, prune or release has been performed.

## Review

### Delivered

Delivered locally against fixtures only, from baseline `7cbe340`. The host's own Command Line Tools were never read by a test.

### Change Summary

- `rig_doctor_command_line_tools` in `22-observation.bash` reads `xcode-select -p`, the `CLTools_Executables` package version and `sw_vers -productVersion` when Homebrew work is selected on macOS.
- Doctor prepends one `command-line-tools` finding to the tool findings and adds one environment check to the totals when it ran.
- `tests/helpers/isolate.bash` stubs the three commands as current; RIG-STATE-047, the manual and the changelog describe the check.

### Verification

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark within budget, mandoc and diff checks. All 566 Bats tests pass.

Withheld by authority: `scripts/smoke-native-providers` and any live doctor run on `sol` or `terra`.

### Outstanding concerns

- **Provisional plan choices.** Only a major-version lag counts; the finding fails doctor only when Homebrew work is selected; `apply` and `upgrade` do not refuse Homebrew work. Kris to confirm.
- **Deviation, provisional.** The optional `rig apply --dry-run` preflight warning is not delivered; doctor is the one place the cause is named.

### Post-change review

Existing Homebrew doctor tests keep their counts apart from the one added environment check where Homebrew is selected; Linux and non-Homebrew plans are unchanged.

### Mini recap

Doctor now names missing or outdated Command Line Tools once, before a Homebrew apply fails on every item.

## Done

Accepted 2026-10-18 by the ways-of-working rig-lock-review run, after an independent re-check at `3a33d51`: the complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passed, with all 582 Bats tests green and only the existing HOOK-1 and SHELL-FATAL audit warnings. Authority: the ways-of-working decisions log, ACCEPT-AND-PRUNE of 18 October 2026 ("accept every record awaiting acceptance whose verification evidence is recorded"), with RIG-LOCK-FOLLOWUP a) ("an independent review runs before the Rig acceptances"). The provisional choices and the deviation in Outstanding concerns stand as delivered: major-version lag only, failing doctor only when Homebrew work is selected, and no `rig apply --dry-run` warning. Not pruned.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of RIG-RECORDS on 2026-10-14 (decision 70 in the thread's decisions log). Planning questions: whether a minor-version lag (26.6 on 26.7) also counts, or only a major one; whether the finding makes doctor unhealthy or stays informational when no Homebrew tool is selected; whether `apply` and `upgrade` should refuse Homebrew work outright while the finding stands. Capture only; adoption, priority and plan belong to this repository.

Adopted, planned and delivered on 18 October 2026 by the tools-burndown run, under the rig-lane report's RIG-ORDER a) ("plan KI-TOOL-RIG-CORE-055, KI-TOOL-RIG-CORE-052 and KI-TOOL-RIG-CORE-054 to Ready in one ki-plan sitting") and Kris's overnight instruction of 18 October 2026, 04:30 BST, to burn the roadmap down as far as possible and take the recommended course on a judgement call. The record was triage, so its adoption to `deliver` / Now and its plan choices below are provisional, for Kris to confirm at review.

### Independent review

The ways-of-working rig-review run reviewed this record on 18 October 2026, read-only and without having written it, at `92d2d27`, under TOOLS-BLOCKERS in the ways-of-working decisions log. The complete local gate passes there: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark and mandoc; all 572 Bats tests pass. `scripts/smoke-native-providers` was not run. The review does not accept the record; acceptance stays with Kris.

**Verdict: no blocking findings.** Two low.

- **Low: the major-version rule is exact only from macOS 26.** From macOS 26 the Command Line Tools and macOS share their major number, so "installed major below macOS major" is the right test on both Macs today. On macOS 15 and earlier the tools' major ran one ahead (tools 16 on macOS 15), so tools one release behind would pass unnoticed. No machine in the estate runs those releases.
- **Low: Xcode.app skips the check entirely,** including an outdated Xcode, which the Boundary accepts.

Confirmed sound: the check runs only on macOS with Homebrew work selected; it is one finding with `owner=environment`, counted once and added once to the check total; the isolation helper stubs `xcode-select`, `pkgutil` and `sw_vers` as current, so no test reads the runner's toolchain. The missing `apply --dry-run` warning is a recorded, provisional deviation that the Boundary allowed ("if planning finds it cheap").
