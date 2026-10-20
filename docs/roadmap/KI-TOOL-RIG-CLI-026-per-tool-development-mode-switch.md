---
id: KI-TOOL-RIG-CLI-026
area: CLI
title: Per-tool development mode switch
purpose: capability
theme: rig
kind: deliver
status: cancelled
resolution: rejected
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T09:36:23Z
updated_at: 2026-10-20T04:35:57Z
---

# Per-Tool Development Mode Switch

## Goal

`rig dev local <tool>` runs a KI command-line tool from its checkout, and `rig dev release <tool>` returns it to the installed release. `all` in place of a tool name switches every known KI tool. Rig warns when tools that call each other are left in mixed modes, so a checkout of one tool is not silently exercised against a release of another.

## Context

Kris Brown asked for this on 2026-10-14, choosing option (a) in the Techne thread. Each KI tool already has its own local hook: `install.sh --link` points the user's executable directory, by default `~/.local/bin`, at the checkout, and a release returns through the package manager, such as relinking Homebrew. Switching today means finding each checkout and running its installer by hand, and nothing reports which tools are local. On 14 October 2026 the Mac had `ki`, `mgit` and `techne` running locally, `git-almanac` and `rig` running their Homebrew releases behind dangling links into a retired checkout path; meanwhile a Rig cask fix sat on `main` that only a checkout link, not the 0.6.2 release, would pick up.

## Boundary

- In: a `rig dev` command with `local` and `release` verbs, a tool name or `all`, and a read-only report of each tool's current mode; finding checkouts through `ki registry`; calling each tool's own `install.sh --link` for local mode and its release install for release mode; a warning naming tools that call each other in mixed modes; specifications and isolated tests.
- Out: changing any tool's installer, which stays that tool's own hook; building or releasing tools; cloning missing checkouts; managing MCP servers, which run from their checkouts under mcporter.

## Cancelled

Approved by Kris on 20 October 2026 under SWEEP-RIG-026 a), recorded in Knowledge Islands Principal `+/_WORK/ki.ways-of-working/decisions.md`: "we can cancel the development mode switch ... There's already enough command surface". Rejected: each tool's own `install.sh --link` and release install stay the way to switch. The idea is kept as an Idea line on the [Rig theme page](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/Streams/Themes/rig.md) in Knowledge Islands Principal. Nothing was built.

## Discussion

Origin: Kris Brown's request of 2026-10-14 in the state-of-play thread. Where the tool-to-tool call graph that drives the mixed-mode warning is declared, in Rig's catalogue or by each tool, is a planning question. Held with Rig's other holds under the roadmap burn-down rule.
