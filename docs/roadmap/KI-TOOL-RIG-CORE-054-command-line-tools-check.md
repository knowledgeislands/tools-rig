---
id: KI-TOOL-RIG-CORE-054
area: CORE
title: Command Line Tools check
purpose: capability
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T16:37:00Z
updated_at: 2026-10-14T16:37:00Z
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

## Dependencies / blocks

Not blocked; blocks nothing. Related to the shared-failure reporting note (R2) in the [mac-studio-bootstrap Project note](../../../ki-principal/Streams/Projects/mac-studio-bootstrap/mac-studio-bootstrap.md), which would collapse 84 identical failures into one; this record catches the cause before the run instead.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of RIG-RECORDS on 2026-10-14 (decision 70 in the thread's decisions log). Planning questions: whether a minor-version lag (26.6 on 26.7) also counts, or only a major one; whether the finding makes doctor unhealthy or stays informational when no Homebrew tool is selected; whether `apply` and `upgrade` should refuse Homebrew work outright while the finding stands. Capture only; adoption, priority and plan belong to this repository.
