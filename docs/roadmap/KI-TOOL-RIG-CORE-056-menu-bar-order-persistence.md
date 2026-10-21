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
updated_at: 2026-10-21T04:15:28Z
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

On macOS 27, the observed menu-bar windows belong to MenuBarAgent and Window Server (Evidence 1); that MenuBarAgent centrally places status items is inferred from those windows and its binary strings (Evidence 2). Those strings describe persisting positions and tracked applications, migrating preferences to a protected container, and using legacy positions (Evidence 2-5). The terminal was refused access to the named containers (Evidence 4); their contents, other processes' access and MenuBarAgent's authoritative use of them remain inferred or gaps. The public SDK headers examined expose no position or order property (Evidence 9). Keep Rig report-only and recommend against opening a declaration record at present, at moderate confidence: the write, restart and durability behaviour a declaration would require is untested. This recommendation grants no authority to change Rig, preferences or KI-TOOL-RIG-CORE-053.

Each claim below is marked **observed** (a read-only command on `sol` shows it), **inferred** (it follows from observed strings or behaviour but was not exercised), or a **gap** (the permitted archive does not settle it; the needed observation or experiment is named below).

### Evidence

Gathered on `sol`, macOS 27.0.1 (26A434), two 1920 x 1200 displays, on 20 October 2026. The observation commands below are reads; none wrote a preference, started or stopped an application or system agent, or changed an account. The 21 October reconciliation used archived output only, without rerunning workstation observations.

1. **Menu-bar window ownership** (observed snapshot; placement inferred). `ps -axo pid,lstart,comm` shows `/System/Library/CoreServices/MenuBarAgent.app` running since 14 October, beside ControlCenter and SystemUIServer. `CGWindowListCopyWindowInfo` over all windows in layers 20 to 30 lists the menu bar windows as owned by Window Server and MenuBarAgent, one per display, with no separate per-app status-item windows identified in that snapshot. Central placement by MenuBarAgent is inferred; the snapshot does not prove every placement path or give a per-item rank.
2. **MenuBarAgent persists order itself** (observed as strings; behaviour inferred). `strings -n 6 /System/Library/CoreServices/MenuBarAgent.app/Contents/MacOS/MenuBarAgent` contains `MenuBarOrderPersistenceComponent`, `TrailingItemPreferredPositions`, `DistanceFromTrailingEdge`, `MenuBarTrailingSortOrder`, `MenuBarPersistenceID`, `Persisting trailing item positions`, `Handling getPreferredTrailingItemPositions` and `Handling clearPreferredTrailingItemPositions`.
3. **The AppKit keys are a fallback** (observed as strings; behaviour inferred). The same binary logs `Using legacy NSStatusItemHost preferredPosition %{public}f for %{public}s` and `Using legacy control center plist position %{public}f for %{public}s`, and `Migrating preference %{public}s from user preferenes to protected container`.
4. **The protected containers refuse the terminal** (observed for this caller; wider access inferred). `codesign -d --entitlements - --xml` on MenuBarAgent lists `com.apple.MenuBar` and `group.com.apple.controlcenter` under both `com.apple.security.application-groups` and `com.apple.private.security.restricted-application-groups`. `ls -la "$HOME/Library/Group Containers/com.apple.MenuBar"` and `ls -la "$HOME/Library/Containers/com.apple.MenuBarAgent/Data"` both return `Operation not permitted` from the terminal. That establishes a restriction on the terminal only. That other unentitled processes, Rig among them, are refused too is inferred from the restricted-group entitlement; which processes can read or write the containers, what they hold and in what format are gaps.
5. **"Allow in the Menu Bar" is MenuBarAgent's tracked-applications list** (observed as strings; storage inferred). `strings` on `/System/Library/ExtensionKit/Extensions/ControlCenterSettings.appex/Contents/MacOS/ControlCenterSettings` contains `Allow in the Menu Bar`, `TrackedApplications`, `_isAllowed` and `com.apple.MenuBarAgent`; MenuBarAgent contains `Persisting tracked applications`, `Creating status item %{public}s, isAllowed: %{bool,public}d`, `Disallowed application %{public}s`, `allowList` and `DeniedLiveActivityBundleIDs`. That the list is stored in the protected container of item 4 is inferred.
6. **Allow is logged at item creation** (observed snapshot; decision timing inferred). `log show --last 3d` filtered to process `MenuBarAgent` and messages naming legacy, persistence, migration or allow retains two `Creating status item <UUID>, isAllowed: true` lines; no matching legacy-position or persistence lines appear in that filtered snapshot. That does not establish the logging policy or when the allow decision was computed.
7. **Some legacy keys hold implausible values** (observed as a single snapshot; history inferred). `plutil -p` over `~/Library/Preferences/*.plist` finds 25 `NSStatusItem Preferred Position` values in 16 domains. Seven exceed the 1920-point width of either display: 1Password `Item-0` 5728, Apple Script Monitor 6367, Fujitsu domain `com.fujitsu.pfu.SSMenuBar`, autosave `Item-0`, 6116, Google Drive 5843, Caffeine 5725, and Bartender `EItem` 10971 and `RHSItem` 5955; the archived `/Applications/Bartender*` glob found no match, and the process check found Bartender not running; installation elsewhere was not checked. 1Password keeps a second, plausible position (810) under a UUID autosave name. Tailscale and Amphetamine were running, with no status-item key found in the scanned user preference files; container preferences were not covered by that scan. The snapshot shows the values present on 20 October only; it does not show when they were written, what display or app changes came since, or that nothing has rewritten them. That they are stale is inferred.
8. **No order identified in the inspected Control Centre fields** (observed fields; role inferred). `~/Library/Preferences/ByHost/com.apple.controlcenter.<host>.plist` holds per-module integers (`Bluetooth`, `Sound`, `WiFi` and others) alongside metadata such as `LastSelectedDisplayUUID` and `IRServiceToken`; no `NSStatusItem` key was found in the scanned current-host files. The current-host `com.apple.controlcenter.displayablemenuextras` has a `displayablesInfo` data value whose decoded JSON contains an empty `displayableInfos` list, and `com.apple.controlcenter.bentoboxes` has a `boxes` data value containing JSON with `displayablesData`; interpreting that as gallery data is inferred, and its embedded payload was not fully decoded. The user domain's `MenuBarCustomizationState` contains action flags (`MovedControlToBentoBox`, `RemovedControl` and others) and a change date, with no order identified in the decoded object. These observations do not rule out order data in unexamined or embedded fields. ControlCenter's own strings (`Beginning migration of menu bar workflows`, `Failed to register menuBarAgent as a displayables provider client`) suggest it is now a client of MenuBarAgent; that is inferred from the strings, not observed in behaviour.
9. **The examined public headers have no order property** (observed). The macOS 27 Command Line Tools SDK's `NSStatusItem.h` documents `autosaveName` as the "unique name for persisting visibility information", `visible` as "Persisted based on the -autosaveName.", and `behavior` (`RemovalAllowed`, `TerminationOnRemoval`); neither it nor `NSStatusBar.h` offers a position or order property.

Archived source locators: the [original observation transcript](/Users/krisbrown/.claude/projects/-Users-krisbrown-workspaces-knowledge-islands-tools-rig/037d328c-9455-4560-85f0-d7f4ef65cd56.jsonl) has tool-result entries at lines 125 (platform/displays), 129 and 325 (preference keys), 143 and 152 (current-host fields and decoded JSON), 164 (customisation flags), 182 (access refusals), 187 and 192 (agent strings), 200 (retained allow logs), 207 and 215 (headers/processes), 224 and 229 (settings strings/entitlements), and 353 (application/process checks). The [independent review transcript](/Users/krisbrown/.local/state/ki/agents/ways-of-working/wow-accept-rig-056.log:2555) reproduces platform, strings, entitlements, headers, window ownership and preference counts at lines 2555-2779 and 2968-3050. These are archived observations, not a fresh measurement of the machine.

### Answers

1. **Stores, readers and timing.** Order: MenuBarAgent names its own trailing-item positions, a distance from the trailing edge with a sort order (item 2, observed as strings). That they are held after migration in the restricted `com.apple.MenuBar` container, and that they rather than the AppKit keys are the authority for order, are inferred (items 3 and 4). The legacy AppKit keys, `NSStatusItem Preferred Position <autosave>` in each app's domain and in `com.apple.controlcenter` for Apple modules, are inferred from the log wording to be read only as a fallback (item 3). Visibility: the scanned user domains contain `NSStatusItem Visible <autosave>` and `NSStatusItem VisibleCC <autosave>` keys (item 7); the AppKit header documents persistence by autosave name without naming those raw keys (item 9). Allow: MenuBarAgent's tracked-applications list (item 5). The log shows MenuBarAgent, an agent running since 14 October in the snapshot, logging an allow value when an app creates its item (item 6, observed); the decision timing and whether it also reads all three stores and places the item at that moment are inferred. When it reads its persisted positions, and whether AppKit still rewrites the legacy key when the owner Command-drags an item on macOS 27, are gaps.
2. **Durability.** The MenuBarAgent strings suggest trailing-edge distances (item 2); dependence on display width and neighbouring item widths is inferred for both models, rather than demonstrated by a display change. The snapshot shows seven legacy values wider than either display here and keys associated with Bartender, which the archived application glob did not find and the process check did not find running (item 7, observed within those checks). That these values outlived display or app changes without being rewritten is inferred: the snapshot observes no display change, app update or absence of a later rewrite, so it does not demonstrate persistence across those events. A renamed autosave name is inferred to start a new key and leave the old one behind, as 1Password's two entries suggest (observed residue, inferred cause). Whether either store survives a display change, a different main display or an app update, whether MenuBarAgent keys positions per display or per main display, and how its `MenuBarPersistenceID` follows an app update, are gaps.
3. **Writing without quitting.** Unknown; no route was found. The terminal cannot open the container MenuBarAgent's strings point to (item 4, observed), and its restricted-group entitlements suggest that Rig, as an unentitled process, could not either (inferred); which processes can write that store, and in what format, are gaps. Whether a legacy key written while its app runs takes effect, or only once the app recreates its item, is a gap; that such a write could at most seed an item MenuBarAgent has not yet placed follows from the fallback wording (item 3) and is inferred. Whether restarting ControlCenter, SystemUIServer or MenuBarAgent changes order or re-reads legacy keys is a gap: no order was identified in the inspected current-host and Control Centre fields (item 8, observed within that scope) and ControlCenter's strings suggest it now defers to MenuBarAgent (inferred), but no restart was run, by the read-only Method.
4. **A stable interface.** None found. The examined AppKit headers expose autosave name, visibility and removal behaviour, but no position or order property (item 9, observed); this is not an exhaustive survey of every public interface. MenuBarAgent's get and clear position handlers (item 2) are inferred to be a private service, and its binary names private entitlements such as `com.apple.private.menubar.allow` (inferred to guard them). The observed user-domain position keys are legacy offsets, inferred to be a fallback (item 3); their write effects were not tested.
5. **Recommendation.** Keep report-only, and do not open a declaration record. Confidence moderate: it rests on an observed absence and an inferred mechanism, not on a demonstrated impossibility. The examined public headers expose no order property (item 9, observed); the named containers refuse the terminal, while their use as the order store and their access by Rig are inferred (items 3 and 4); the writable keys are inferred to be a fallback and include implausible values in the snapshot (items 3 and 7); and the write, restart and durability behaviour a declaration would rely on is untested. Reconsider only if a supported interface appears, or the owner check routed below shows the legacy key tracks the live bar.

### Consequence for KI-TOOL-RIG-CORE-053

KI-TOOL-RIG-CORE-053 ranks items by the legacy `Preferred Position` keys. If macOS 27 no longer refreshes them when the owner drags an icon, Rig would rank items from stale offsets, and a Command-drag would not clear the drift Rig reports, which is the correction that record's design relies on. Its post-release owner check, a live `rig status` on `sol`, can settle this cheaply: read one item's key with `defaults read DOMAIN "NSStatusItem Preferred Position NAME"`, Command-drag that icon, and read it again. This is routed to the owning work as a message line, not a record.

### Evidence gaps

| Gap | What would close it | Why not here |
| --- | --- | --- |
| Legacy-key refresh | Owner drag and re-read, as above | Attended workstation change |
| Protected-store contents, format and access | Permitted read and entitlement survey | Permission and private format |
| Durability across displays and app updates | Scratch-account changes and re-reads | Workstation changes |
| Live-write or item-recreation effect | Scratch-account key write and observation | Preference write |
| Restart effect on order or legacy reads | Scratch-account agent restarts | System-agent restart |
| Other Apple documentation | Developer documentation and release notes | No network authority |

## Review

### Delivered

A written investigation with nine evidence entries, five answers and six explicit evidence gaps. The original Ready baseline is `ee0bfa387e4360eb1a78a995d889bc362ff4a038`. This reconciliation starts from green local main `3cc18f657a4a56d265b2ef1e6f756551a6172a01` and incorporates only the written failed-review/rework changes from `4efcee6bee1fe2d18916a0a67458fb15a74f85ef` and `3160dcc744c3f78788a5f17090a38a2456a06ba1`, with the coordinator's 21 October evidence corrections. Neither earlier commit is merged or pushed by this run. Status remains `awaiting-review` for a fresh independent review.

### Change Summary

- This investigation record only: integrate the approved uncertainty rework, distinguish Fujitsu's domain from autosave `Item-0`, and distinguish the `displayablesInfo` data key from its decoded `displayableInfos` list.
- Reconcile the remaining wording with archived literals: preserve logging format markers, qualify window-placement and allow-timing inferences, limit application absence to the archived checks, and describe the actual Control Centre fields without claiming unexamined payloads hold no order.
- Retain the failed independent review and its response below. No Rig behaviour, specification, guide, test, preference or CORE-053 lifecycle change.
- The existing RIG-053-LEGACY-ORDER line in the [owning work's messages](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.tools-burndown/messages.md:9) retains Kris's attended post-release check through its archived original. No duplicate follow-up is needed.

### Verification

- Each Finding claim was reconciled with its numbered Evidence entry and archived source, retaining observed snapshots, inferences and gaps. Exact string placeholders, preference counts, oversized values, domain/autosave identity and JSON field names were checked against the archived output.
- The listed observation commands are read-only. This reconciliation collected no live preferences, accessed no protected store, and made no preference, application, process or account change. The owner check above remains an attended follow-up, not a command run here.
- The unchanged-main full audit passed with zero failures and four pre-existing warnings: OWN-1 on `.rumdl.toml`, MATURITY-1 on `.ki.toml`, and ITEM-2 missing size on KI-TOOL-RIG-CORE-047 and KI-TOOL-RIG-CORE-064. Those files remain unchanged. This record has `size: m`.
- Integration requires the focused roadmap audit, full repository audit, complete manual gate in [Develop Rig](../guides/developer/README.md#verify-the-repository), `git diff --check` and hook-backed commit. Exact outcomes and evidence are retained in the [run report](/Users/krisbrown/.local/state/ki/agents/ways-of-working/wow-night-rig-056-f.report.md).
- The committed pre-commit hook now matches the canonical tools hook and runs no Bats suite; Bats remains in the manual gate and CI. The historical hook failure below records the earlier review, not the current baseline.

### Outstanding concerns

- Protected-store contents, format and access by other processes remain gaps. The original terminal refusal was not repeated.
- Whether a Command-drag refreshes legacy keys, their effects after a live write or restart, and durability across display or app changes remain gaps. Kris's attended CORE-053 check remains required; this record does not accept or change CORE-053.
- Evidence covers `sol` only. No developer documentation or release notes were fetched; the header finding is limited to the SDK surface examined.

### Post-change review

The written finding supports a moderate-confidence recommendation to keep report-only while the required write and persistence behaviour remains untested. Archived evidence supports the qualified observations and inferences, without establishing a universal access restriction, an authoritative storage format or impossibility of a later declaration. The recommendation carries no implementation authority. Fresh independent review is still required before acceptance.

### Mini recap

The archived windows and binary strings suggest MenuBarAgent centralises menu-bar placement and persistence. The terminal refusal and examined headers justify a conservative report-only recommendation, with access, storage, timing, writes and durability left uncertain. The existing attended owner check is retained for CORE-053, and neither record is accepted here.

## Discussion

Origin: Kris Brown's request on 2026-10-14. Adopted at `future` as a deliberate follow-up investigation; it needs re-scoping before it becomes actionable.

Gate: promoted from `future` to `now`, re-scoped and planned to Ready on 20 October 2026 under the coordinator's self-serve burndown decision of 22:03 BST in the [ways-of-working decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/decisions.md), which carries Kris's OVERNIGHT-BURNDOWN authority on to work that needs nothing from Kris; a read-only sweep classed this record workable. The re-scope narrows the method to read-only evidence and states every remaining unknown as a gap.

### Independent acceptance review - 20 October 2026

Failed independent review of delivery `45aa494133d2862189be45e2f654e5f0f931c402` against the Review packet and all three Verify requirements. Returned to `in-progress` under Kris's acceptance authority of 20 October 2026, renewed at 22:03 BST; no acceptance or pruning took place.

The read-only recheck on `sol` reproduced the macOS build, process start dates, two 1920 x 1200 displays, window ownership, persistence and legacy-fallback binary strings, restricted-group entitlements, settings strings, two retained allow decisions, 25 preferred-position keys across 16 domains, seven offsets wider than either display, absent current-host status-item keys, Control Centre JSON and the SDK header surface. The consequence message to the owning work is present. The recommendation to remain report-only is reasonable, but the first Verify requirement fails because the following conclusions exceed their evidence.

- **Access boundary (Evidence 4; Answers 1 and 3; Finding opening).** Restricted-group entitlements and a terminal access refusal establish a restriction on that caller. They do not establish that only MenuBarAgent can open or write the store, or exclude other entitled processes. Mark the wider access and authoritative-store conclusions inferred, and retain the exact storage format and write authority as gaps. The protected-container probes were deliberately not repeated because this review's authority forbids touching those containers.
- **Durability (Evidence 7; Answer 2).** A single snapshot of oversized offsets and duplicated autosave names does not observe a display change, application update or absence of intervening rewrites. The snapshot is observed; its history and cause must remain inferred or gaps. Do not treat it as demonstrated persistence across those events.
- **Write and restart behaviour (Answer 3).** Migration and client-related binary strings do not demonstrate whether a live preference write takes effect, requires item recreation, or whether restarting ControlCenter or SystemUIServer affects order. Label those conclusions inferred where supported and otherwise gaps, consistently with the read-only Method. No write, restart, application launch or permission grant is needed to correct these labels.

Reconcile the Finding opening, Answers, recommendation rationale and Review summary with those qualifications, then return the same record for independent review. The existing evidence supports a conservative report-only recommendation without claiming that untested mechanisms are impossible. No new record is required.

The focused roadmap and authoring audits and the record Markdown check report no failures. The full repository audit, run offline against the unchanged primary checkout to avoid linked-worktree registry artefacts, fails the pre-existing `SHELL-HOOK` rule at `.githooks/pre-commit`: the hook runs Bats although the current shared policy assigns the test suite to the manual gate and CI. This is separate from the evidence defects above and blocks integration until the owning work reconciles it. GitHub checks were deliberately unavailable through a temporary failing `gh` stub; no GitHub API call was made.

### Review response - 20 October 2026

Reworked on top of the failed-review commit `4efcee6`, under Kris's roadmap burndown authority renewed at 22:03 BST, and returned to `awaiting-review`. Only wording changed; no evidence was gathered or rerun, and no preference was written, process restarted, application launched or protected container probed.

- **Access boundary.** The Finding opening now says only that the container refused the terminal, and marks as inferred both that it is closed to Rig and other unentitled processes and that MenuBarAgent's store is the authority for order. Evidence 4 is retitled to the terminal's refusal, observed for that caller only, with wider access inferred and readers, writers, contents and format left as gaps. Evidence 5 marks the list's storage location inferred. Answer 1 marks the authoritative store and its location inferred, and Answer 3 no longer says that no other process can write it. The container gap row now names which processes can read or write it.
- **Durability.** Evidence 7 is retitled as a single snapshot, says what the snapshot does not show, and marks staleness inferred. Answer 2 drops "plainly survive" and states that the snapshot does not demonstrate persistence across a display change, an app update or the absence of a later rewrite; survival across those events joins the gaps, and the display gap row widens to cover app updates.
- **Write and restart behaviour.** Answer 3 now opens "Unknown; no route was found" rather than "No". Whether a live legacy-key write takes effect or needs the item recreated, and whether restarting ControlCenter, SystemUIServer or MenuBarAgent changes order, are gaps, each with its own row in the gap table. Evidence 8 marks ControlCenter's client role as inferred from strings.

The report-only recommendation still follows, at moderate rather than high confidence: the public API exposes no position, and nothing found offers a supported write, so the record rests the recommendation on that absence and on the untested behaviour a declaration would need, not on any claim that a declaration is impossible. The Review packet's Delivered, Change Summary, Verification, Post-change review and Mini recap are reconciled with these qualifications. The integration blocker the review raised, the pre-existing `SHELL-HOOK` audit failure, is unchanged and stays with the owning work.

### Evidence reconciliation - 21 October 2026

Under the coordinator's RIG-056-EVIDENCE answer, integrated the written rework from `3160dcc744c3f78788a5f17090a38a2456a06ba1` onto current green main without importing either historical branch. Archived literal output settles the Fujitsu domain/autosave distinction and the `displayablesInfo` wrapper with its nested empty `displayableInfos` list. The claim sweep also narrowed window placement, allow timing, application absence, raw visibility-key attribution and Control Centre payload conclusions to what the archive actually supports. Protected-store and experiment gaps remain. No workstation observation was rerun and no implementation authority was added. The prior failed review and response are preserved above; a fresh independent review must assess this reconciled record.
