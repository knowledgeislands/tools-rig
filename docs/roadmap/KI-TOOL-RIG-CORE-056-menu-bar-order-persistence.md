---
id: KI-TOOL-RIG-CORE-056
area: CORE
title: Menu bar order persistence
purpose: capability
theme: rig
kind: investigate
status: ready
horizon: now
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T20:50:55Z
updated_at: 2026-10-20T21:20:00Z
---

# Menu Bar Order Persistence

## Goal

Find where macOS persists the order of menu-bar items across restarts, and decide whether Rig could declare that order safely. The record closes on a written finding, not on a change to Rig.

## Context

[KI-TOOL-RIG-CORE-053](KI-TOOL-RIG-CORE-053-macos-menu-bar-declarations.md) makes Rig report menu-bar drift only, on Kris's choice of 14 October 2026. Kris asked for a follow-up "to investigate this a bit further because surely there must be some configuration somewhere, otherwise, how does the order of the menu bar stay between restarts of a Mac?"

What is already known from the read-only inventory of terra and sol:

- Third-party apps keep an AppKit `NSStatusItem Preferred Position <autosave name>` value in their own defaults domain: a pixel offset from the right edge, written when the owner Command-drags the item and read when the app creates it. Writing it appears to work only while the app is quit, and the value depends on screen width and neighbouring item widths.
- Apple's modules keep `defaults -currentHost` values in the `com.apple.controlcenter` domain, which encode visibility; whether they also encode order is unknown.
- The macOS 26 "Allow in the Menu Bar" permission is stored somewhere not yet identified.

## Questions

1. Which stores hold menu-bar order and visibility on macOS 27, for third-party status items and for Apple modules, and which process reads each one, and when?
2. Does the stored position survive display changes, a different main display, or an app update that renames its autosave name?
3. Can an order be written without quitting each app, and does any write need a restart of ControlCenter or SystemUIServer?
4. Is there a supported or stable interface, rather than pixel offsets, that a declaration could target?
5. Given the answers, should Rig keep report-only, or could a later record declare order safely?

## Method

Read-only observation and documentation only, on `sol`. Re-scoped on 20 October 2026 for unattended delivery: this delivery runs no experiment at all, because a throwaway app or a scratch user account is a change to the workstation that this delivery may not make. Each question that only an experiment can settle is recorded as an evidence gap, naming the experiment that would close it, rather than answered by guess. Nothing connection-critical (Tailscale, VPN, network or authentication) is touched, no preference is written, no process is restarted, and no prompt that asks the owner for consent is triggered on purpose.

## Boundary

- In: a written finding in this record, with evidence and evidence gaps, and a recommendation for or against a later declaration record.
- Out: any change to Rig or to KI-TOOL-RIG-CORE-053's report-only scope; personal configuration; menu-bar manager adoption.

## Current state

Grounded at `c55f2e9` on 20 October 2026. [KI-TOOL-RIG-CORE-053](KI-TOOL-RIG-CORE-053-macos-menu-bar-declarations.md) is awaiting review: it observes order from `NSStatusItem Preferred Position <autosave>` and visibility from `NSStatusItem VisibleCC <autosave>` in the user preference domain, and never writes either. Its Current state already records that on macOS 27 the `-currentHost com.apple.controlcenter` integers no longer decode as visibility, that sandboxed apps keep their keys in a container a plain domain read does not reach, and that stale autosave names linger. Nothing yet says which process reads these keys on macOS 27, or whether they are still the authority for order.

## Steps

- [ ] **1. Inventory the stores.** Read every user and current-host preference file on `sol` that carries an `NSStatusItem` key with `plutil -p`, without `defaults` and without writing, and list the Control Centre and menu-bar containers and their access.
- [ ] **2. Identify the reading process.** From the running processes, the window list, the public AppKit headers, and the strings and entitlements of the system menu-bar binaries, establish which process places status items and where it persists order and the "Allow in the Menu Bar" choice.
- [ ] **3. Write the finding.** Answer each of the five questions under a Finding section, marking each claim observed, inferred or a gap, with the read-only command that reproduces it.
- [ ] **4. Recommend and route.** Recommend for or against a later declaration record, and route any consequence for KI-TOOL-RIG-CORE-053's review as a message line to the owning work, not as a record.

## Files touched

- This record only. A follow-up line in the owning work's `messages.md`, outside this repository, if the finding bears on KI-TOOL-RIG-CORE-053.

## Verify

- Every claim under Finding names an observation that a listed read-only command reproduces, or is marked inferred or a gap.
- No delivery step wrote a preference, launched or restarted an application, or changed an account; the commands listed under Evidence are reads only.
- `ki repo audit --skill ki-work-roadmap --repo .` raises no finding on this record, and `git diff --check` passes.

## Dependencies / blocks

Not blocked. KI-TOOL-RIG-CORE-053 has shipped to awaiting review, so its observation model is the one this investigation tests. This record does not depend on that record's review: the finding informs the observe-only shape question there, and does not wait for its answer.

## Documentation impact

### Decision Records

None. The recommendation is recorded here; a later declaration record, if one is ever opened, owns any decision.

### Specifications

None. Rig's behaviour is out of scope.

### Guides

None. The menu-bar section of the operational resources guide belongs to KI-TOOL-RIG-CORE-053.

### Roadmap

This record only.

## Discussion

Origin: Kris Brown's request on 2026-10-14. Adopted at `future` as a deliberate follow-up investigation; it needs re-scoping before it becomes actionable.

Gate: promoted from `future` to `now`, re-scoped and planned to Ready on 20 October 2026 under the coordinator's self-serve burndown decision of 22:03 BST in the [ways-of-working decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/decisions.md), which carries Kris's OVERNIGHT-BURNDOWN authority on to work that needs nothing from Kris; a read-only sweep classed this record workable. The re-scope narrows the method to read-only evidence and states every remaining unknown as a gap.
