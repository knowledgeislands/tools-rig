---
id: KI-TOOL-RIG-CORE-056
area: CORE
title: Menu bar order persistence
purpose: capability
theme: rig
kind: investigate
status: awaiting-review
horizon: now
size: m
blocks: []
blocked_by: []
baseline_ref: ee0bfa387e4360eb1a78a995d889bc362ff4a038
created_at: 2026-10-14T20:50:55Z
updated_at: 2026-10-20T21:40:00Z
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

- [x] **1. Inventory the stores.** Read every user and current-host preference file on `sol` that carries an `NSStatusItem` key with `plutil -p`, without `defaults` and without writing, and list the Control Centre and menu-bar containers and their access.
- [x] **2. Identify the reading process.** From the running processes, the window list, the public AppKit headers, and the strings and entitlements of the system menu-bar binaries, establish which process places status items and where it persists order and the "Allow in the Menu Bar" choice.
- [x] **3. Write the finding.** Answer each of the five questions under a Finding section, marking each claim observed, inferred or a gap, with the read-only command that reproduces it.
- [x] **4. Recommend and route.** Recommend for or against a later declaration record, and route any consequence for KI-TOOL-RIG-CORE-053's review as a message line to the owning work, not as a record.

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

## Finding

On macOS 27 the menu bar is laid out by one system agent, MenuBarAgent, not by each app. MenuBarAgent keeps its own record of where each status item sits and of which apps are allowed in the menu bar, and it migrates those preferences out of the user preference domain into a restricted container that no other process can open. The AppKit `NSStatusItem Preferred Position <autosave>` keys, which the 14 October inventory took to be the order store and which [KI-TOOL-RIG-CORE-053](KI-TOOL-RIG-CORE-053-macos-menu-bar-declarations.md) now reads, are what MenuBarAgent itself calls legacy: it falls back to them when it has no position of its own. No public interface sets order. Rig should stay report-only, and no declaration record should be opened.

Each claim below is marked **observed** (a read-only command on `sol` shows it), **inferred** (it follows from observed strings or behaviour but was not exercised), or a **gap** (only an experiment this delivery could not run would settle it).

### Evidence

Gathered on `sol`, macOS 27.0.1 (26A434), two 1920 x 1200 displays, on 20 October 2026. Every command is a read; none wrote a preference, started or stopped a process, or changed an account.

1. **MenuBarAgent places the items** (observed). `ps -axo pid,lstart,comm` shows `/System/Library/CoreServices/MenuBarAgent.app` running since 14 October, beside ControlCenter and SystemUIServer. `CGWindowListCopyWindowInfo` over all windows in layers 20 to 30 lists the menu bar windows as owned by Window Server and MenuBarAgent, one per display, and no status-item window owned by any app, so items are no longer per-app windows that a window list could rank.
2. **MenuBarAgent persists order itself** (observed as strings; behaviour inferred). `strings -n 6 /System/Library/CoreServices/MenuBarAgent.app/Contents/MacOS/MenuBarAgent` contains `MenuBarOrderPersistenceComponent`, `TrailingItemPreferredPositions`, `DistanceFromTrailingEdge`, `MenuBarTrailingSortOrder`, `MenuBarPersistenceID`, `Persisting trailing item positions`, `Handling getPreferredTrailingItemPositions` and `Handling clearPreferredTrailingItemPositions`.
3. **The AppKit keys are a fallback** (observed as strings; behaviour inferred). The same binary logs `Using legacy NSStatusItemHost preferredPosition %f for %s` and `Using legacy control center plist position %f for %s`, and `Migrating preference %s from user preferenes to protected container`.
4. **The protected container is closed to other processes** (observed). `codesign -d --entitlements - --xml` on MenuBarAgent lists `com.apple.MenuBar` and `group.com.apple.controlcenter` under both `com.apple.security.application-groups` and `com.apple.private.security.restricted-application-groups`. `ls -la "$HOME/Library/Group Containers/com.apple.MenuBar"` and `ls -la "$HOME/Library/Containers/com.apple.MenuBarAgent/Data"` both return `Operation not permitted` from the terminal. Its contents are a gap.
5. **"Allow in the Menu Bar" is MenuBarAgent's tracked-applications list** (observed as strings; storage inferred). `strings` on `/System/Library/ExtensionKit/Extensions/ControlCenterSettings.appex/Contents/MacOS/ControlCenterSettings` contains `Allow in the Menu Bar`, `TrackedApplications`, `_isAllowed` and `com.apple.MenuBarAgent`; MenuBarAgent contains `Persisting tracked applications`, `Creating status item %s, isAllowed: %d`, `Disallowed application %s`, `allowList` and `DeniedLiveActivityBundleIDs`. Its storage is taken to be the protected container of item 4.
6. **Allow is decided when an item is created** (observed). `log show --last 3d` filtered to process `MenuBarAgent` and messages naming legacy, persistence, migration or allow retains two `Creating status item <UUID>, isAllowed: true` lines; the legacy-position and persistence lines are not kept at the default log level.
7. **The legacy keys are stale** (observed). `plutil -p` over `~/Library/Preferences/*.plist` finds 25 `NSStatusItem Preferred Position` values in 16 domains. Seven exceed the 1920-point width of either display: 1Password `Item-0` 5728, Apple Script Monitor 6367, Fujitsu `SSMenuBar` 6116, Google Drive 5843, Caffeine 5725, and Bartender `EItem` 10971 and `RHSItem` 5955; Bartender is not installed. 1Password keeps a second, plausible position (810) under a UUID autosave name. Tailscale and Amphetamine are running with no status-item key in any user domain.
8. **Current-host and Control Centre stores hold no order** (observed). `~/Library/Preferences/ByHost/com.apple.controlcenter.<host>.plist` holds only per-module integers (`Bluetooth`, `Sound`, `WiFi` and others), and no current-host file carries an `NSStatusItem` key. The current-host `com.apple.controlcenter.displayablemenuextras` holds an empty `displayableInfos` list, and `com.apple.controlcenter.bentoboxes` holds the Controls gallery as JSON. The user domain's `MenuBarCustomizationState` records only what the owner last did (`MovedControlToBentoBox`, `RemovedControl`), not an order. ControlCenter's own strings (`Beginning migration of menu bar workflows`, `Failed to register menuBarAgent as a displayables provider client`) show it is now a client of MenuBarAgent.
9. **The public API has no position** (observed). The macOS 27 Command Line Tools SDK's `NSStatusItem.h` documents `autosaveName` as the "unique name for persisting visibility information", `visible` as "Persisted based on -autosaveName", and `behavior` (`RemovalAllowed`, `TerminationOnRemoval`); neither it nor `NSStatusBar.h` offers a position or order property.

### Answers

1. **Stores, readers and timing.** Order: MenuBarAgent's own trailing-item positions, a distance from the trailing edge with a sort order (item 2), held after migration in the restricted `com.apple.MenuBar` container (items 3 and 4; the location is inferred). The legacy AppKit keys, `NSStatusItem Preferred Position <autosave>` in each app's domain and in `com.apple.controlcenter` for Apple modules, are read only as a fallback (item 3; the fallback condition is inferred from the log wording). Visibility: `NSStatusItem Visible` and `VisibleCC <autosave>` in each domain, as AppKit documents (item 9) and KI-TOOL-RIG-CORE-053 observed. Allow: MenuBarAgent's tracked-applications list (item 5). The reader of all three is MenuBarAgent, a login-long agent, which decides allow and placement when an app creates its item (item 6). When it reads its persisted positions, and whether AppKit still rewrites the legacy key when the owner Command-drags an item on macOS 27, are gaps.
2. **Durability.** Both stores measure a distance from the trailing edge, so a position depends on display width and on the widths of the items beside it (inferred). The legacy keys plainly survive display and app changes without being rewritten: seven values are wider than any display here, and keys from an uninstalled manager remain (item 7). A renamed autosave name starts a new key and leaves the old one behind, as 1Password's two entries suggest (observed residue, inferred cause). Whether MenuBarAgent keys positions per display or per main display, and how its `MenuBarPersistenceID` follows an app update, are gaps.
3. **Writing without quitting.** No. The authoritative store sits in a container only MenuBarAgent's private entitlement opens (item 4), so no other process, Rig included, can write it, with or without quitting an app. Writing a legacy key could at most seed an item MenuBarAgent has never placed, and would still need the app to recreate its item (inferred). Restarting ControlCenter or SystemUIServer no longer bears on order (item 8); whether restarting MenuBarAgent re-reads legacy keys is a gap, deliberately not tested on the live workstation.
4. **A stable interface.** None. AppKit exposes only an autosave name, visibility and removal behaviour (item 9). MenuBarAgent's get and clear position handlers (item 2) are a private service, and its binary names private entitlements such as `com.apple.private.menubar.allow` (inferred to guard them). The only writable surface is the legacy pixel offset, which is now a fallback.
5. **Recommendation.** Keep report-only, and do not open a declaration record. Confidence high: the authority is private and protected, the writable keys are a fallback that already drifts, and enforcement would mean writing a store Apple has moved out of reach.

### Consequence for KI-TOOL-RIG-CORE-053

KI-TOOL-RIG-CORE-053 ranks items by the legacy `Preferred Position` keys. If macOS 27 no longer refreshes them when the owner drags an icon, Rig would rank items from stale offsets, and a Command-drag would not clear the drift Rig reports, which is the correction that record's design relies on. Its post-release owner check, a live `rig status` on `sol`, can settle this cheaply: read one item's key with `defaults read DOMAIN "NSStatusItem Preferred Position NAME"`, Command-drag that icon, and read it again. This is routed to the owning work as a message line, not a record.

### Evidence gaps

| Gap | What would close it | Why not here |
| --- | --- | --- |
| Whether a Command-drag rewrites the legacy key on macOS 27 | The owner drags one icon and re-reads its key, as above | An owner action on the live menu bar |
| What the `com.apple.MenuBar` container holds, and its format | Reading it from a process with Full Disk Access | A permission grant, and a private format Rig should not depend on |
| Per-display and main-display behaviour | Changing the main display, or a scratch account | A change to the workstation |
| Whether restarting MenuBarAgent re-reads legacy keys | Restarting it in a scratch account | Restarting a system agent on the live workstation |
| Apple's own documentation beyond the SDK header | Developer documentation and release notes | This delivery made no network call |

## Review

### Delivered

A read-only investigation of where macOS 27 keeps menu-bar order, visibility and the "Allow in the Menu Bar" choice, written under [Finding](#finding) with nine evidence items, an answer to each of the five questions, a recommendation to stay report-only, and five evidence gaps with what would close each. Baseline `ee0bfa3`, the Ready plan. Excluded, as the boundary set: any change to Rig or to KI-TOOL-RIG-CORE-053, personal configuration, and every experiment that would change the workstation.

### Change Summary

- This record: Finding added, steps ticked, status and baseline set. No source, specification, guide or test changed.
- Outside this repository: one line, RIG-053-LEGACY-ORDER, in the [ki.tools-burndown messages](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/messages.md) at ki-principal `ab08272f`, carrying the consequence for KI-TOOL-RIG-CORE-053's review.
- Material finding: the investigation's premise moved. The 14 October inventory took the AppKit `Preferred Position` keys to be the order store; on macOS 27 they are a fallback behind MenuBarAgent's own protected store.

### Verification

Run on 20 October 2026 in the delivery worktree:

- Every claim under Finding is marked observed, inferred or a gap, and each observed claim names the read-only command that shows it (`ps`, a `CGWindowListCopyWindowInfo` listing, `plutil -p`, `strings`, `codesign -d --entitlements`, `ls -la`, `log show`, and a read of the SDK headers).
- No step wrote a preference, launched, quit or restarted an application or agent, or changed an account. Preferences were read with `plutil -p` from the files, not through `defaults`, and two `ls -la` reads of the protected containers were refused by the system.
- `ki repo audit --skill ki-work-roadmap --repo .`: no finding on this record; the three remaining warnings are the size warnings on KI-TOOL-RIG-CORE-047, KI-TOOL-RIG-CORE-048 and KI-TOOL-RIG-CORE-064.
- `git diff --check` passes. The pre-commit gate, which runs the full Bats suite, passed on the planning commit.

### Outstanding concerns

- The main gap, whether a Command-drag still rewrites the legacy key on macOS 27, decides whether KI-TOOL-RIG-CORE-053's order drift can ever clear; it is routed to that record's review and post-release owner check rather than tested here.
- Reading the protected containers with `ls -la` may have been logged by the system's privacy controls; it was refused and no consent was granted.
- No network call was made, so Apple's developer documentation and release notes were not consulted; the SDK header is the only Apple text cited.
- Evidence is from `sol` only; `terra` was not examined.

### Post-change review

The goal, a written finding and a recommendation, is met within the boundary, and Rig is unchanged, so there is no regression risk to the tool. The finding is stronger than the record expected on question 1 and weaker on questions 2 and 3, where the remaining unknowns need an owner action or a workstation change. Ready for review; the reviewer should weigh whether the inferred parts, the container location and the fallback condition, are enough to close the record.

### Mini recap

macOS 27 now keeps menu-bar order in a system agent's private store, so Rig can only report order, never set it, and KI-TOOL-RIG-CORE-053's order check needs one owner drag to prove it tracks the real bar.

## Discussion

Origin: Kris Brown's request on 2026-10-14. Adopted at `future` as a deliberate follow-up investigation; it needs re-scoping before it becomes actionable.

Gate: promoted from `future` to `now`, re-scoped and planned to Ready on 20 October 2026 under the coordinator's self-serve burndown decision of 22:03 BST in the [ways-of-working decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/decisions.md), which carries Kris's OVERNIGHT-BURNDOWN authority on to work that needs nothing from Kris; a read-only sweep classed this record workable. The re-scope narrows the method to read-only evidence and states every remaining unknown as a gap.
