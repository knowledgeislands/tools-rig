---
id: KI-TOOL-RIG-CORE-055
area: CORE
title: Interpreter port owner matching
purpose: capability
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T16:37:00Z
updated_at: 2026-10-14T16:37:00Z
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

## Dependencies / blocks

Not blocked; blocks nothing. Headroom is connection-critical for Claude Code on `sol`, so verification stays with fixtures; nothing in delivery touches the running proxy.

## Discussion

Origin: the `sol` bring-up, captured on Kris Brown's approval of RIG-RECORDS on 2026-10-14 (decision 70 in the thread's decisions log). The main planning choice is between inferring the import name (simple, but `headroom-ai` to `headroom` is a convention, not a rule) and letting the port or tool declare the command it expects (explicit, one more field). A false `conflicting` on a connection-critical port invites a person to "fix" a working service, so the record matters more than its size suggests. Capture only; adoption, priority and plan belong to this repository.
