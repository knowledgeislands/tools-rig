---
id: KI-TOOL-RIG-CORE-046
area: CORE
title: Remote access and continuity
initiative: rig
kind: deliver
status: cancelled
resolution: rejected
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T22:14:26Z
updated_at: 2026-10-14T13:27:24Z
---

# KI-TOOL-RIG-CORE-046: Remote Access and Continuity

## Goal

A profile declares whether its machines accept remote screen sessions and who may connect; on macOS it also declares Handoff, Universal Clipboard and Universal Control. `rig doctor` reports a machine whose settings differ from the declaration, `rig apply` sets what the platform allows without the GUI, and Rig shows the manual steps for the rest.

## Context

Kris asked for this on 2026-10-13 in the Mac Studio bootstrap thread (Decision 45): Screen Sharing, Universal Control and Handoff should be managed by Rig, and on other operating systems where possible, screen sharing at least. The person's setup today is two Macs on one tailnet: `terra`, a MacBook on the `laptop` profile, and `sol`, a Mac Studio on the `studio` profile. Screen Sharing is on for sol and off for terra, set by hand in System Settings. How to set everything by hand is in the chezmoi source's macOS workstation guide, in its "Remote access" section.

What makes this worth declaring rather than leaving to the GUI:

- **Exposure.** macOS Screen Sharing listens on every network, not only Tailscale, and has no per-interface setting. Restricting it to the tailnet is split out into [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) (mac-studio-bootstrap Decision 48), which this record does not duplicate.
- **Drift.** Each setting lives in a different System Settings pane, so a machine set up from scratch, or after a reinstall, silently differs from the others.

Related records: [KI-TOOL-RIG-CORE-042](KI-TOOL-RIG-CORE-042-profile-filtered-dock-items.md) (Dock items) is the nearest open per-profile macOS setting. RIG-CORE-045 (default applications) is done and pruned; its last file was [RIG-CORE-045-default-applications.md](https://github.com/knowledgeislands/tools-rig/blob/ea7c3b626a2c0de34fe2c1154dc594806926ee3b/docs/roadmap/RIG-CORE-045-default-applications.md), and the behaviour it delivered is in [Declare default applications](../guides/user/default-applications.md). It is the model for a per-user macOS setting that Rig observes, applies where it can, and reports pending user confirmation where it cannot.

## Boundary

- **In:** per-profile declarations for screen sharing on or off and the users allowed to connect; on macOS, Handoff (which carries Universal Clipboard), Universal Control with its "push through the edge" and "automatically reconnect" options; read-only observation in `rig doctor` and `rig status`; `rig apply` where macOS permits it without the GUI; manual steps shown in doctor and dry-run output where it does not; a Linux equivalent for screen sharing (for example GNOME Remote Desktop or xrdp); specification, guide, help, manual and test alignment.
- **Out:** restricting any listener to the tailnet, on macOS or Linux, which [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) owns; installing or configuring Tailscale itself; SSH server settings and keys; display arrangement for Universal Control; the VNC password option, which Rig should leave off and only report; continuity features on Linux or other systems, which have no equivalent and are reported as unsupported; FileVault and sleep policy.

## Cancelled

Cancelled 2026-10-14 as rejected (parked), approved by Kris Brown in the state-of-play run ('RC-ALL: approve all' to the roadmap census): its trigger was speculative (a further machine or profile) and it was held to 2027. Its Goal, Boundary and the macOS and Linux findings in Discussion are kept as an idea in the mac-studio-bootstrap Project (`ki-principal`, `Streams/Projects/mac-studio-bootstrap/mac-studio-bootstrap.md`); Git history keeps the full record. The firewall slice stays with KI-TOOL-RIG-CORE-047. It leaves no outstanding change.

## Discussion

- **Screen Sharing on macOS.** The service is `com.apple.screensharing`; allowed users are the `com.apple.access_screensharing` group. Enabling it from a script without the GUI is restricted on recent macOS (`launchctl` alone does not suffice and the kickstart tool needs privileges and may be refused without MDM). Check what still works, and fall back to showing the System Settings path: General > Sharing > Screen Sharing, then (i) and "Allow access for: Only these users".
- **Tailnet only.** Moved to [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md). A screen-sharing declaration here should not depend on it; a profile that turns Screen Sharing on can select both.
- **Continuity settings.** Handoff and Universal Control are per-user preferences. Find which `defaults` domains and keys hold them, whether writing them takes effect without logging out, and whether macOS honours a written value at all; if not, observe only and show the manual steps (General > AirDrop & Handoff; Displays > Advanced).
- **Requirements Rig cannot check.** Continuity needs the same Apple Account, Bluetooth and Wi-Fi on, and the machines within about 10 m. Doctor can at most report Bluetooth and Wi-Fi power; decide whether that is useful or noise.
- **Linux.** GNOME Remote Desktop is configured with `grdctl`; xrdp is a system service. Limiting either to `tailscale0` belongs with a later Linux provider for [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md). Decide which one Rig supports first, or whether Linux stays unsupported until a Linux profile exists.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `deliver / Hold` until 2027-01-04. The exposure risk is split into KI-TOOL-RIG-CORE-047; what remains is drift on two Macs already set by hand and documented in the chezmoi guide, and recent macOS mostly blocks setting these from a script. Adoption grants no planning, implementation or acceptance authority.
