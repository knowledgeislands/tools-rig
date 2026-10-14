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
updated_at: 2026-10-14T13:27:24Z
---

# Signed-Release Install Kind

## Goal

Rig installs a tool shipped as a signed release, such as `ki` or `techne`, through a built-in install kind: it fetches the per-platform archive for an exact or minimum version, verifies the release's checksum manifest against its Ed25519 signature and a declared public key, and installs into the user's home without root. Any role profile or Cheztoi fragment can then declare such tools on macOS or Linux, with no custom provider.

## Context

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted all ten decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md); the plain-language summary is [Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md). Decision 5 places a signed-release install kind in `tools-rig`, replacing a custom provider the Techne harness had planned to ship beside its recipe. Decision 6 makes one KI release contract the canonical artefact for every KI and personal tool (per-platform archives including linux-arm64, a checksum manifest, an Ed25519 signature and an installer with the key embedded), with this kind as one of three thin channels beside the Homebrew tap and the installer.

Today the built-in `direct-download` `executable` kind covers a single binary checked by SHA-256, not a signed `tar.gz` archive, and an owner's payload may not carry a custom provider. `ki` and `techne` already share the archive pattern, which is the condition the audit set for a built-in kind.

## Boundary

- In: the install kind, its configuration fields and validation, signature and checksum verification that never falls back to SHA-256 only, version reporting for `rig status`, specifications and tests.
- In: whether one `agentic-rig` role profile, published by the Techne harness, can be included by both remote agentic rigs (`vega` through Cheztoi and `sol` through a person's own configuration), carrying exact pins on one and minimums on the other; if existing `inherits` and `conf.d` composition already covers it, a worked example records that finding. Merged from KI-TOOL-RIG-CORE-049 below.
- Out: changes to any tool's release signing or installer; producing linux-arm64 builds, which each `tools-*` repository owns; bootstrapping Rig itself.

## Dependencies / blocks

Not blocked; `tools-ki` releases already carry a signed manifest. It blocks the Techne harness's plan to converge the agent host's tools through Rig, whose first gate is Rig installing a signed `ki` release.

## Discussion

Origin: `ki-principal`, state-of-play thread, under Kris Brown's acceptance of the audit decisions. Capture only; adoption, priority and plan belong to this repository.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `deliver / Hold` until 2026-11-16. Its only consumer is the Techne harness's plan to converge the agent host's tools through Rig, which is itself held until vega is rebuilt. Adoption grants no planning, implementation or acceptance authority.

### Merged from KI-TOOL-RIG-CORE-049 on 2026-10-14

Kris approved merging KI-TOOL-RIG-CORE-049 (shared agentic-rig role) into this record on 14 October 2026, in the state-of-play run ('RC-ALL: approve all' to the roadmap census): both wait for the same trigger, vega being rebuilt, and the shared role is how a signed install reaches both hosts. Its Goal and Boundary, carried as written:

- **Goal.** One `agentic-rig` role profile serves both remote agentic rigs: `vega`, a rebuildable cloud host set up by the Techne harness, and `sol`, Kris's owned Mac Studio configured through chezmoi. Both hosts include the same role from its single published source, with platform variants (Homebrew on macOS), so they carry the same KI toolchain without a second copy of its declaration.
- **Context.** The Rig and Techne boundary audit makes Rig own the role layer (its Decision 1), places the role profile in a recipe-independent `roles/` folder in `ki-techne-harness` (Decision 3), and sets the version policy per role: exact pins on rebuildable hosts, newest through Homebrew on workstations, with the role declaring minimums both satisfy (Decision 4).
- **In:** establishing whether existing composition covers this, and if not, the smallest Rig capability that does; the exact-versus-minimum version policy for one role across hosts; specifications and tests.
- **Out:** the role's contents and home, which `ki-techne-harness` owns; Kris's own `studio` profile and catalogue, which chezmoi owns.
