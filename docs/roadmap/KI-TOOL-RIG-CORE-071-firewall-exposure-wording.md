---
id: KI-TOOL-RIG-CORE-071
area: CORE
title: Firewall exposure wording
purpose: corrective
theme: rig
status: triage
priority: low
size: s
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-23T06:43:00Z
updated_at: 2026-10-23T06:43:00Z
---

# KI-TOOL-RIG-CORE-071: Word Firewall Exposure as a Listener Observation

## Goal

`rig doctor` and `rig status` describe a drifted firewall's listener evidence for what it is: a point-in-time observation that a declared port was listening on all addresses. A reader cannot take the finding as proof that the port is reachable from beyond the tailnet, and cannot take its absence as proof that the firewall has been repaired.

## Context

On 23 October 2026 `terra`'s `firewall.screen-sharing-tailnet` finding read `drifted (anchor-changed,exposed-beyond-tailnet)` in one `rig doctor` run, `drifted (anchor-changed)` in the next, and the longer form again later, with no firewall change in between ([stage3](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3.report.md), [handlers-retry](/Users/krisbrown/.local/state/ki/agents/chezmoi/handlers-retry.report.md), [tower-remove](/Users/krisbrown/.local/state/ki/agents/chezmoi/tower-remove.report.md)). Two later reports took "exposed beyond tailnet" to mean Screen Sharing "may be reachable from beyond the tailnet".

The [stage3-blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3-blind.report.md) and the [firewall-blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/firewall-blind.report.md) found why. The [listener probe](../../src/rig/29-firewall.bash) takes a fresh `netstat -an` snapshot, and the observer appends `exposed-beyond-tailnet` whenever drift reasons exist and that snapshot shows a wildcard listener on a declared port. Screen Sharing's port is socket-activated by launchd, so the listener row can come and go between runs. The probe does not read loaded pf rules (that needs root, under FW-DOCTOR in [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md)), so it cannot show reachability. On `terra` the older anchor was still restricting sources to the tailnet as far as its file shows; only its destination predates `dae10f2`.

## Boundary

- **In:** the detail name or explanatory text for the listener evidence, so it reads as "declared port listening on all addresses" rather than exposure; stating in doctor and `rig explain` that kernel rules are unverified when the evidence is shown; deciding whether a volatile listener observation belongs in the drift reasons at all; specification, guide and Bats alignment.
- **Out:** a privileged doctor (FW-DOCTOR keeps doctor unprivileged); any change to the anchor, the apply path or `terra`'s pending re-apply, which KI-TOOL-RIG-CORE-047 tracks.

## Dependencies / blocks

None. Planning should check [KI-TOOL-RIG-CORE-068](KI-TOOL-RIG-CORE-068-replaced-pf-root-ruleset-bypass.md), which also changes firewall doctor wording, and merge if the two touch the same reasons.

## Discussion

- A rename such as `listening-all-addresses` keeps the evidence and drops the claim. Alternatively, report the listener state as a separate informational field, so the drift reason list changes only when the firewall's own files or daemon change.
