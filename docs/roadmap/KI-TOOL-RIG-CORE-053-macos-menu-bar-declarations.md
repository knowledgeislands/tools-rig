---
id: KI-TOOL-RIG-CORE-053
area: CORE
title: macOS menu bar declarations
purpose: capability
theme: rig
kind: deliver
status: awaiting-review
horizon: now
size: l
blocks: []
blocked_by: []
baseline_ref: 2054674ff4c58e87b16c3a38d6ee0961489d6960
created_at: 2026-10-14T10:30:00Z
updated_at: 2026-10-20T22:21:02Z
---

# macOS Menu Bar Declarations

## Goal

Rig declares what should appear in a Mac's menu bar, and in what relative order, once for every machine, with per-machine differences selected by profile. `rig status` and `rig doctor` report where a machine's menu bar differs from the declaration. Rig reports menu-bar drift only: it never writes menu-bar visibility or positions, and the owner corrects the order once on each machine by Command-dragging the icons.

## Context

On 14 October 2026 Kris asked that Rig "cover the configuration of the menu bar as well and anything else we can do on the Mac, which should be done consistently", noting that the laptop shows CodexBar, FluidVoice and other items in an order the Mac Studio does not match.

What Rig does today:

- **Typed settings.** [RIG-CONF-017](../specs/configuration.md#rig-conf-017--typed-macos-settings) gives `[setting.ID]` one `macos-defaults` scalar (`domain`, `key`, `value-type`, `value`). Observation runs `defaults read DOMAIN KEY`; apply runs `defaults write`. There is no `-currentHost` scope and no restart of the process that reads the domain, so a Dock, Finder or Control Centre value can be `present` while the running process still shows the old value.
- **Ordered Dock.** [RIG-CONF-018](../specs/configuration.md#rig-conf-018--semantic-dock-declarations) and [RIG-STATE-036](../specs/state.md#rig-state-036--dock-folder-attributes) declare, observe and apply an ordered Dock through `dockutil`, then restart the Dock. [KI-TOOL-RIG-CORE-042](KI-TOOL-RIG-CORE-042-profile-filtered-dock-items.md) adds one ordered list filtered by each profile's selected tools; the same pattern fits menu-bar order.
- **Nothing for the menu bar, hot corners, the clock or login items.** The personal configuration declares 55 settings (keyboard, Finder, Dock, screenshots, trackpad tap) and one Dock layout, all in the `core` profile.

### Read-only inventory, terra (MacBook) versus sol (Mac Studio)

| Area | terra | sol |
| --- | --- | --- |
| Third-party status items running | CodexBar, FluidVoice, Tailscale, 1Password, Amphetamine and others | Tailscale, 1Password, Dropbox, OneDrive, Amphetamine |
| CodexBar, FluidVoice | installed, login items, running | installed, not login items, not running |
| Login items (System Events) | Alfred, Granola, OneDrive, Notion, CodexBar, Amphetamine, FluidVoice, Claude, Warp, BetterDisplay | Dropbox, NordVPN, OneDrive, Notion, Google Drive, Amphetamine, Tailscale, Alfred, Warp, Granola |
| Menu-bar manager | Ice settings left behind, Ice not installed; Bartender settings left behind, not installed | Ice installed, never configured, not running; Bartender settings left behind |
| Control Centre modules in the menu bar (`-currentHost com.apple.controlcenter`) | Battery shown; Siri, Timer, Weather when active; Wi-Fi, Bluetooth, Sound, Spotlight hidden | Sound, Screen Mirroring shown; Bluetooth, Now Playing when active; Focus, Weather hidden |
| Control Centre "Controls" gallery | Show Desktop, Alarms, Lock Screen | Screen recording, screenshots, Calculator, Show Desktop, Print Centre |
| Clock | date shown | date hidden |
| Siri menu | hidden | not set |
| Hot corners | none | bottom right: Quick Note |
| Dock persistent apps | 36 (adds NordVPN, ChatGPT Classic, Zed, Delta, LaunchControl, draw.io, Telegram, RendApp, The Tower) | 28 (adds Lightroom Classic) |
| Keyboard, Finder, trackpad, scroll bars, screenshots | match the declared settings | match the declared settings |

### What the native store can and cannot support

- **Apple module visibility** lives in `defaults -currentHost` integers per module (`Battery`, `Sound`, `WiFi`, `Bluetooth`, `FocusModes`, `NowPlaying`, `ScreenMirroring`, `Display`, `Weather`, `Spotlight`, `Siri` and so on; observed values 2, 8, 18 and 24 encode shown, when active and hidden). Writing them and restarting `ControlCenter` is the established route. The exact value encoding needs confirming on macOS 27 before it is specified.
- **Clock, Siri, hot corners and screenshots** are ordinary per-user defaults (`com.apple.menuextra.clock`, `com.apple.Siri StatusMenuVisible`, `com.apple.dock wvous-*`), so the existing setting kind covers them once it can restart the reading process.
- **Third-party order** is the AppKit `NSStatusItem Preferred Position <autosave name>` value in each app's domain: a pixel offset from the right edge, written by the app when the owner Command-drags an item and read when the app creates the item. Writing it only works while the app is quit, depends on screen width and each item's width, collides with other items, and uses autosave names (`Item-0`, `codexbar-claude`) that an app may change between versions. Rig cannot enforce order reliably this way.
- **Third-party visibility** (`NSStatusItem Visible <autosave name>`) and the macOS 26 "Allow in the Menu Bar" permission are per app; where the latter is stored is not yet known.
- **The Controls gallery** is an opaque JSON blob of per-host UUIDs and binary property-list identities. It cannot be declared portably.
- **Menu-bar managers** (Ice, Bartender) order and hide items by moving their own divider items, so their layout is still positional. Ice keeps its settings in `com.jordanbaird.Ice` defaults, which chezmoi could carry, but that fixes only Ice's behaviour, not each item's section.

## Proposed design

Kris chose report-only on 14 October 2026: Rig reports drift, Kris drags the icons into order once by hand, and Rig enforces nothing. Units, boundaries and hand-offs, for owner sanity check before planning:

1. **Current-host observation (extends RIG-CONF-017).** Add optional `scope = "current-host"` so a setting can be read with `defaults -currentHost`, which the Control Centre module values need. A setting that names this scope inside a menu-bar layout is observed only.
2. **Menu bar layout (`[menu-bar.ID]`, provider `macos-menu-bar`, observe-only).** One ordered `items` list per layout, modelled on the Dock: each item names a tool's status item, filtered by profile the way KI-TOOL-RIG-CORE-042 filters Dock items, or an Apple module. Rig reads module visibility and each app's preferred position, ranks the items, and reports `drifted` with the first out-of-order pair or the first module whose visibility differs, `missing` when a selected app's item is not running, and `unknown` when an autosave name is not found. `rig apply` makes no change for a menu-bar layout and says so.
3. **Launch membership.** A status item exists only while its app runs, so the report flags a selected status-item app that is not a login item. Whether that is a new observe-only `login-item` check or a field on the tool is a planning question; adding or approving login items stays with the owner.
4. **Personal declarations (chezmoi-owned).** The menu-bar layout belongs in the personal Rig configuration: shared items in `core`, Battery and other laptop-only items in `laptop`, studio-only items in `studio`. Clock, Siri and hot-corner values are ordinary per-user defaults that the existing setting kind can already declare there. Rig ships only the generic kinds.

Out of scope: writing menu-bar module visibility or third-party positions; restarting ControlCenter or SystemUIServer; the Controls gallery; Live Activities; installing or configuring Ice or Bartender; anything connection-critical (Wi-Fi, VPN, Tailscale or network settings). Where macOS persists the order, and whether Rig could ever declare it safely, is the separate investigation [KI-TOOL-RIG-CORE-056](KI-TOOL-RIG-CORE-056-menu-bar-order-persistence.md).

## Boundary

- In: unit 1's current-host read; unit 2's declaration, observation and drift reporting; unit 3's observation shape; specifications, guides and isolated tests with stubbed `defaults`.
- Out: any write to a menu-bar value or position; personal values and order (the personal configuration's owner); menu-bar manager adoption; any live apply during delivery.

## Current state

Grounded at `973073e` on 20 October 2026 from source and read-only `defaults read` observation on `sol` (macOS 27.0.1). Nothing was written.

- **No menu-bar kind.** `RIG_DECLARATION_REGISTRY` in [`05-declarations.bash`](../../src/rig/05-declarations.bash) has `dock` (setup) and `dock-item` (component) and nothing for the menu bar. Provider capabilities are a fixed list in `rig_provider_supports` ([`20-orchestration.bash`](../../src/rig/20-orchestration.bash)); every built-in resource provider there has both `resource-observe` and `resource-apply`, so no setup resource is observe-only today.
- **Dock is the template.** `rig_validate_dock` and `rig_validate_dock_item` ([`10-configuration.bash`](../../src/rig/10-configuration.bash)) validate an ordered `items` list of component tables; `rig_dock_resolve_items` filters items by their linked `tool` against the resolved profile and records `profile` or `platform` exclusion reasons (KI-TOOL-RIG-CORE-042, delivered). `rig_setting_observe` reads `defaults read DOMAIN KEY` through `rig_macos_defaults_command`, which the test helper stubs.
- **Visibility is not where the record assumed.** On macOS 27 the `-currentHost com.apple.controlcenter` integers no longer match what is shown: `sol` reads `Sound = 24`, `ScreenMirroring = 24`, `Bluetooth = 8`, `FocusModes = 24`, `NowPlaying = 2`, which does not fit the 14 October inventory's "Sound and Screen Mirroring shown, Focus hidden" under any one encoding. The user domain carries `NSStatusItem VisibleCC <name>` booleans instead, for Apple modules in `com.apple.controlcenter` (`Bluetooth`, `Sound`, `ScreenMirroring`, `WiFi`, `Clock`, `BentoBox-0` all `1`) and for third-party apps in their own domain (CodexBar `VisibleCC codexbar-merged = 0`, OneDrive `VisibleCC Item-0 = 1`). Unit 1's `scope = "current-host"` is therefore not needed for visibility.
- **Order is the same key for both.** `NSStatusItem Preferred Position <name>` exists in `com.apple.controlcenter` for Apple modules (`Bluetooth 396`, `WiFi 460`, `ScreenMirroring 538`, `Sound 325`) and in each app's domain for third-party items (Dropbox `Item-0 736`, OneDrive `Item-1 882`, 1Password `Item-0 5728` beside a UUID-named item at `810`). A larger offset sits further left. Stale autosave names linger, as 1Password's `5728`, wider than any screen, suggests, so an item must name its autosave name rather than take the first key found.
- **Sandboxed apps.** `defaults read io.tailscale.ipn.macos` and `com.if.Amphetamine` return no status-item keys although both items are running; their preferences live in the app container, which a plain domain read does not reach. Such an item would observe as `unknown` unless it declares a container domain.
- **Login items are not readable quietly.** `osascript` asking System Events for login items timed out (`-1712`) on `sol`, because it needs Automation consent; `sfltool dumpbtm` needs root. Neither suits an unattended `rig doctor`, so unit 3 has no safe observation route today.

## Queries

- **PLAN053-MODEL.** Approve the revised model: drop unit 1's `current-host` scope, read visibility from `NSStatusItem VisibleCC` and order from `NSStatusItem Preferred Position` in the user domain, one `[menu-bar-item.ID]` naming its `domain` and `autosave` name? Recommended a), confidence high: the read-only observation on `sol` shows both keys present and coherent for Apple modules and third-party apps, while the `-currentHost` integers do not decode consistently. b) keep unit 1 and confirm the integer encoding first, which needs an attended toggle of each module.
- **PLAN053-LOGIN.** Leave unit 3, launch membership, out of this record? Recommended a), confidence high: neither native route reads login items without Automation consent or root, and an item that is not running already observes as `missing`. b) keep it and accept a consent prompt the first time doctor runs.
- **PLAN053-READY.** Approve this plan to Ready? Recommended a), confidence medium: the kind is observe-only and fully fixture-testable, but it is the first observe-only setup resource and the owner asked to sanity-check its units first. b) keep it in draft.

## Steps

- [x] **Gate.** PLAN053-MODEL, PLAN053-LOGIN and PLAN053-READY answered and this plan adjusted to the answers. Without that, stop.
- [x] **1. Declarations.** Register `menu-bar` (setup) and `menu-bar-item` (component) in `RIG_DECLARATION_REGISTRY`. `[menu-bar.ID]` requires `name`, `purpose`, `rationale`, fixed `provider = "macos-menu-bar"`, macOS-only `platforms` and a non-empty ordered `items` array, and accepts `profiles`, `requires` and `depends-on` as Dock layouts do. `[menu-bar-item.ID]` requires `domain` and `autosave`, and accepts `visible` (bool, default `true`) and a subject `tool`. Profiles gain `menu-bars`. Validation rejects unknown or repeated items, a bad domain or an empty autosave name before any native call.
- [x] **2. Observation.** Add `rig_menu_bar_observe` beside `rig_dock_observe`. It resolves items with the Dock's profile filter (generalise `rig_dock_resolve_items` rather than copy it), reads each item's `NSStatusItem Preferred Position <autosave>` and `NSStatusItem VisibleCC <autosave>` once per domain through `rig_macos_defaults_command`, and reports, in this precedence: `missing` with `menu-bar-item-unplaced:<item>` when a position is absent; `drifted` with `visibility:<item>` for the first item whose visibility differs; `drifted` with `order:<left>-before-<right>` for the first declared pair whose offsets do not strictly decrease; otherwise `present`. A domain that cannot be read gives `unknown` with `domain-unreadable:<domain>`. Hidden items are excluded from the order comparison.
- [x] **3. Observe-only apply.** Register `macos-menu-bar:resource-observe` only. `rig apply` and `rig apply --target menu-bar:ID` make no change, write no `defaults` and run no `killall`, and print `rig: menu-bar.ID: observe-only; reorder by Command-dragging the icons` without failing the run. `rig explain` and `rig show` describe the resource the same way.
- [x] **4. Fixtures.** Add `tests/rig-menu-bar.bats`, isolated with `rig_test_isolate`, whose `defaults` stub serves fixed status-item keys per domain. Cover present, each drift detail, unplaced and unreadable cases, profile and platform exclusion, a hidden item ignored in order, validation failures, and an apply that logs no `defaults write` or `killall`.
- [x] **5. Documents and assembly.** Add the specifications, guide section and manual entries under [Documentation impact](#documentation-impact), a CHANGELOG entry, run `scripts/assemble-rig`, then the gate under [Verify](#verify).

## Files touched

- `src/rig/05-declarations.bash`, `src/rig/10-configuration.bash` — registry, fields, profile reference and validation.
- `src/rig/20-orchestration.bash`, `src/rig/22-observation.bash`, `src/rig/23-application.bash` — capability, shared item resolution, observation and observe-only apply.
- `bin/rig` — regenerated, never edited.
- `tests/rig-menu-bar.bats` — new.
- `docs/specs/configuration.md`, `docs/specs/state.md`, `docs/specs/orchestration.md`, `docs/guides/user/operational-resources.md`, `man/rig.1`, `CHANGELOG.md`.
- This record.

## Verify

- `bats tests/rig-menu-bar.bats </dev/null` passes, and the existing Dock suites (`tests/rig-dock-observation.bats`, `tests/rig-dock-profiles.bats`) still pass after the shared resolution change.
- The complete gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes, including `scripts/assemble-rig --check` and `mandoc -T lint man/rig.1`.
- No test or delivery step writes a `defaults` value or restarts a process; the stub logs prove it. A live `rig status` on `sol` with a declared layout is an owner check after release, not part of delivery.

## Dependencies / blocks

Not blocked. Profile filtering reuses the mechanism [KI-TOOL-RIG-CORE-042](KI-TOOL-RIG-CORE-042-profile-filtered-dock-items.md) delivered. [KI-TOOL-RIG-CORE-056](KI-TOOL-RIG-CORE-056-menu-bar-order-persistence.md) stays a separate investigation; this record does not depend on its finding. The personal layout itself is a later chezmoi step.

## Documentation impact

### Decision Records

None expected. Check [ADR-KI-TOOL-RIG-006](../decisions/ADR-KI-TOOL-RIG-006-declarative-operational-resources.md) during delivery; if it says every setup resource is appliable, amend it in place for observe-only resources rather than adding a record.

### Specifications

A new configuration requirement for menu-bar declarations (next free `RIG-CONF-031`), a new state requirement for menu-bar drift (`RIG-STATE-048`), and an orchestration requirement that apply never writes a menu-bar value (`RIG-ORCH-046`). RIG-CONF-017 is unchanged, since unit 1 is dropped.

### Guides

A menu-bar section in the [operational resources guide](../guides/user/operational-resources.md): declaring items, finding autosave names with `defaults read`, what each detail means, and that the owner reorders by Command-dragging.

### Roadmap

This record only.

## Review

### Delivered

Observe-only macOS menu bar layouts. `[menu-bar.ID]` with provider `macos-menu-bar` names ordered `[menu-bar-item.ID]` icons by preference `domain` and `autosave` name, with optional `visible` and `tool`. Status and doctor report `unknown`, `missing`, visibility drift or order drift from read-only `defaults read DOMAIN` evidence; apply, dry-run and a targeted apply skip the layout as `observe-only` without a native call and without failing the run; show and explain mark it observe-only.

### Change Summary

- `05-declarations.bash`: registry entries `menu-bar` (setup) and `menu-bar-item` (component).
- `10-configuration.bash`: fields, a new `boolean` TOML field type for `visible`, central and item-owned profile selection, `rig_validate_menu_bar` and `rig_validate_menu_bar_item`, and the native-target conflict rule shared with the Dock.
- `20-orchestration.bash`: the `macos-menu-bar:resource-observe` capability, `rig_dock_resolve_items` generalised to either item kind, and `rig_menu_bar_observe` with its value and offset helpers. Observation lives here beside `rig_dock_observe`, not in `22-observation.bash` as the plan guessed.
- `23-application.bash`: `rig_resource_observe_only` and the apply-loop branch that records `skipped observe-only`.
- `30-commands.bash`: status counts, the profile table, show text and JSON, and explain output for menu bar layouts. This file was not in the plan's list.
- `bin/rig` regenerated; `tests/rig-menu-bar.bats` new.
- Documents: RIG-CONF-031 and the RIG-CONF-008 identity list, RIG-STATE-048, RIG-ORCH-046, a guide section and the Getting Started list entry, the manual page, a CHANGELOG entry, and one in-place paragraph in ADR-KI-TOOL-RIG-006 naming observation-only layouts, since its decision describes every layout as reconciled.

### Verification

Run on 20 October 2026 in the delivery worktree at baseline `2054674` plus this change:

- `bats tests/ </dev/null`: 611 of 611 pass, including the 9 tests in `tests/rig-menu-bar.bats` and the unchanged Dock suites `tests/rig-dock-observation.bats` and `tests/rig-dock-profiles.bats` after the shared item resolution change.
- `shellcheck` and `bash -n` over the gate's script list, plus `shellcheck tests/rig-menu-bar.bats`: clean.
- `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1` and `git diff --check`: pass.
- `ki repo audit --repo .`: fails only RUNTIMES-2 in the worktree, as Outstanding concerns explains; on the primary checkout at baseline it fails only the pre-existing SHELL-HOOK check.
- Every menu bar test asserts through the `defaults` fixture log that only `defaults read DOMAIN` ran, and that the `killall` and isolated `defaults` logs are empty. No test or delivery step wrote a preference or restarted a process.

### Outstanding concerns

- The whole-tree `ki repo audit` fails the pre-existing SHELL-HOOK check on `main` because `.githooks/pre-commit` runs Bats. It is outside this record and was left alone because another session changed `.githooks/` in the last day. In the delivery worktree the audit also reports RUNTIMES-2, because the ignored runtime activation directories exist only in the primary checkout.
- During test development one run unset `RIG_DEFAULTS` and reached the real `/usr/bin/defaults read` for two domains on this workstation. Those were reads only and nothing was written; the test now uses the isolation stub.
- A menu bar layout cannot be a `depends-on` target, because nothing can wait for a layout Rig never applies.
- A sandboxed application whose preferences live in its container observes as `unknown` (`domain-unreadable`), as Current state predicted; container domains are not supported.
- The live owner check, `rig status` on `sol` with a declared layout, remains after release, as Verify states.

### Post-change review

The gate decisions are recorded under Discussion. Design choices a reviewer should confirm: an item with no recorded position counts as not shown; an item declared hidden needs no position; a malformed position counts as absent; an unreadable domain outranks every other finding; and observe-only applies only to built-in adapters, so a custom provider without resource apply still fails preflight.

### Mini recap

Rig can now declare a menu bar once and report how each Mac differs, while leaving every icon where the owner put it.

## Discussion

Origin: Kris Brown's request on 2026-10-14, investigated read-only on terra and sol the same day. On 14 October 2026 Kris chose observe-only order over Rig writing positions with app restarts or adopting a menu-bar manager, and the record was trimmed to report-only: the earlier proposal to apply Control Centre module visibility and restart the reading process was dropped with the enforcement options. Capture only; adoption, priority and plan belong to this repository.

Adoption: Kris's OVERNIGHT decision of 20 October 2026 at 00:28 BST ([mac-studio-setup decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.mac-studio-setup/decisions.md)) authorised acting on the [triage review](/Users/krisbrown/.local/state/ki/agents/mac-studio-setup/triage-review.report.md)'s high-confidence recommendations: adopted into Next, confidence high, as a portable, explicitly requested observe-only resource, with current-host reads and status-item ordering still to shape. [KI-TOOL-RIG-CORE-056](KI-TOOL-RIG-CORE-056-menu-bar-order-persistence.md) stays a separate Future investigation; the suggested merge was not taken.

Gate: the coordinator's decision of 2026-10-20 06:53 BST in the [ways-of-working decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/decisions.md), under Kris's OVERNIGHT-BURNDOWN authority of 20 October 2026, directed delivery of this record. PLAN053-MODEL, PLAN053-LOGIN and PLAN053-READY were each taken as their recommended a): the user-domain `NSStatusItem` keys replace unit 1's current-host scope, unit 3 stays out, and the plan is Ready. PLAN053-READY carried medium confidence because this is the first observe-only setup resource; the owner should confirm that shape at review.

Shape sign-off: Kris's sign-off of 20 October 2026 at 23:16 BST in the [ways-of-working decisions log](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/decisions.md), "query sign-offs, first batch", took RIG-053-SHAPE as a): Kris accepts the observe-only shape as delivered. A menu bar layout is declared, status and doctor report its drift, apply skips it with the Command-drag reminder, and Rig never writes a menu bar value and never fails a run over one. This settles the shape PLAN053-READY left for review; it is not acceptance. The record stays Awaiting review until the broken pre-commit test hook is repaired, which the tools burndown owns.
