---
id: KI-TOOL-RIG-CORE-056
area: CORE
title: Menu bar order persistence
purpose: capability
theme: rig
kind: investigate
status: draft
horizon: future
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T20:50:55Z
updated_at: 2026-10-14T20:50:55Z
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

Read-only observation and documentation only. Experiments that change the menu bar run against a throwaway app or a scratch user account, never against the live workstation's own apps, and touch nothing connection-critical (Tailscale, VPN, network or authentication).

## Boundary

- In: a written finding in this record, with evidence, and a recommendation for or against a later declaration record.
- Out: any change to Rig or to KI-TOOL-RIG-CORE-053's report-only scope; personal configuration; menu-bar manager adoption.

## Dependencies / blocks

Not blocked. Worth doing after KI-TOOL-RIG-CORE-053 ships, so its drift report shows what an investigation would need to explain.

## Discussion

Origin: Kris Brown's request on 2026-10-14. Adopted at `future` as a deliberate follow-up investigation; it needs re-scoping before it becomes actionable.
