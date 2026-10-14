---
id: KI-TOOL-RIG-CORE-048
area: CORE
title: Signed-release install kind
purpose: capability
initiative: rig
kind: deliver
status: draft
horizon: hold
hold:
  reason: waiting-for
  condition: vega is rebuilt and the Techne harness's converge-tools-through-Rig work leaves its hold
  review: 2026-11-16
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T22:53:48Z
updated_at: 2026-10-14T06:52:07Z
---

# Signed-Release Install Kind

## Goal

Rig installs a tool shipped as a signed release, such as `ki` or `techne`, through a built-in install kind: it fetches the per-platform archive for an exact or minimum version, verifies the release's checksum manifest against its Ed25519 signature and a declared public key, and installs into the user's home without root. Any role profile or Cheztoi fragment can then declare such tools on macOS or Linux, with no custom provider.

## Context

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted all ten decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md); the plain-language summary is [Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md). Decision 5 places a signed-release install kind in `tools-rig`, replacing a custom provider the Techne harness had planned to ship beside its recipe. Decision 6 makes one KI release contract the canonical artefact for every KI and personal tool (per-platform archives including linux-arm64, a checksum manifest, an Ed25519 signature and an installer with the key embedded), with this kind as one of three thin channels beside the Homebrew tap and the installer.

Today the built-in `direct-download` `executable` kind covers a single binary checked by SHA-256, not a signed `tar.gz` archive, and an owner's payload may not carry a custom provider. `ki` and `techne` already share the archive pattern, which is the condition the audit set for a built-in kind.

## Boundary

- In: the install kind, its configuration fields and validation, signature and checksum verification that never falls back to SHA-256 only, version reporting for `rig status`, specifications and tests.
- Out: changes to any tool's release signing or installer; producing linux-arm64 builds, which each `tools-*` repository owns; bootstrapping Rig itself.

## Dependencies / blocks

Not blocked; `tools-ki` releases already carry a signed manifest. It blocks the Techne harness's plan to converge the agent host's tools through Rig, whose first gate is Rig installing a signed `ki` release.

## Discussion

Origin: `ki-principal`, state-of-play thread, under Kris Brown's acceptance of the audit decisions. Capture only; adoption, priority and plan belong to this repository.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `deliver / Hold` until 2026-11-16. Its only consumer is the Techne harness's plan to converge the agent host's tools through Rig, which is itself held until vega is rebuilt. Adoption grants no planning, implementation or acceptance authority.
