---
id: KI-TOOL-RIG-CORE-053
area: CORE
title: macOS menu bar declarations
purpose: capability
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T10:30:00Z
updated_at: 2026-10-14T10:30:00Z
---

# macOS Menu Bar Declarations

## Goal

Rig declares what appears in a Mac's menu bar, and in what relative order, once for every machine, with per-machine differences selected by profile. `rig status` and `rig doctor` report where a machine's menu bar differs from the declaration. Rig applies only what it can apply reliably and says plainly which parts it observes but leaves to the owner or a menu-bar manager.

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

Units, boundaries and hand-offs, for owner sanity check before planning:

1. **Setting scope and settle (extends RIG-CONF-017).** Add optional `scope = "current-host"` (`defaults -currentHost`) and optional `settle = "ControlCenter" | "SystemUIServer" | "Dock" | "Finder"`, a fixed allow-list of processes Rig restarts once per apply after writing any setting that names it. Hand-off: the personal configuration declares the values; macOS owns the meaning.
2. **Menu bar layout (`[menu-bar.ID]`, provider `macos-menu-bar`).** One ordered `items` list per layout, modelled on the Dock: each item names a tool (third-party status item, filtered by profile the way KI-TOOL-RIG-CORE-042 filters Dock items) or an Apple module. Rig applies module visibility through unit 1's mechanism. For third-party items Rig observes but does not write: it reads each app's preferred positions, ranks them, and reports `drifted` with the first out-of-order pair, `missing` when a selected app's item is not running, and `unknown` when an autosave name is not found. Correcting order stays a one-off Command-drag by the owner on each machine.
3. **Launch membership.** A status item exists only while its app runs, so the app's tool needs a login-item declaration for the layout to hold after restart. Whether that is a new observe-only `login-item` check or a field on the tool is a planning question; macOS login-item approval stays with the owner.
4. **Personal declarations (chezmoi-owned).** Clock, Siri, hot corners and Control Centre module values, and the menu-bar layout itself, belong in the personal Rig configuration, shared items in `core`, Battery and other laptop-only items in `laptop`, studio-only items in `studio`. Rig ships only the generic kinds.

Out of scope: writing third-party pixel positions; the Controls gallery; Live Activities; installing or configuring Ice or Bartender; anything connection-critical (Wi-Fi, VPN, Tailscale or network settings), which remains observe-only.

## Boundary

- In: unit 1 schema and behaviour; unit 2 declaration, module visibility apply, order observation and drift reporting; unit 3's observation shape; specifications, guides and isolated tests with stubbed `defaults` and `killall`.
- Out: personal values and order (the personal configuration's owner); menu-bar manager adoption; any live apply during delivery.

## Dependencies / blocks

Not blocked. Unit 2's profile filtering should reuse the mechanism KI-TOOL-RIG-CORE-042 delivers rather than invent another.

## Discussion

Origin: Kris Brown's request on 2026-10-14, investigated read-only on terra and sol the same day. Kris's choice between observe-only order (recommended), Rig writing positions with app restarts, or adopting a menu-bar manager as the order lever is pending. Capture only; adoption, priority and plan belong to this repository.
