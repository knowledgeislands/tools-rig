---
id: KI-TOOL-RIG-CORE-049
area: CORE
title: Shared agentic-rig role
purpose: capability
initiative: rig
kind: investigate
status: draft
horizon: hold
hold:
  reason: waiting-for
  condition: vega is rebuilt, so a second agentic-rig host exists
  review: 2026-11-16
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T22:53:48Z
updated_at: 2026-10-14T06:52:07Z
---

# Shared Agentic-Rig Role

## Goal

One `agentic-rig` role profile serves both remote agentic rigs: `vega`, a rebuildable cloud host set up by the Techne harness, and `sol`, Kris's owned Mac Studio configured through chezmoi. Both hosts include the same role from its single published source, with platform variants (Homebrew on macOS), so they carry the same KI toolchain without a second copy of its declaration.

## Context

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted all ten decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md); the plain-language summary is [Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md). Decision 1 makes Rig own the role layer. Decision 3 places the agentic-rig role profile in a recipe-independent `roles/` folder in `ki-techne-harness`. Decision 4 sets the version policy per role: exact pins on rebuildable hosts, newest through Homebrew on workstations, with the role declaring minimums both satisfy.

Rig profiles already compose through `inherits` and `conf.d` fragments. What is not yet shown is whether a profile published by another repository can be included by a person's own configuration (`sol`) and by a Cheztoi-rendered host (`vega`) alike, and how one role carries exact pins on one host and minimums on another.

## Boundary

- In: establishing whether existing composition covers this, and if not, the smallest Rig capability that does; the exact-versus-minimum version policy for one role across hosts; specifications and tests.
- Out: the role's contents and home, which `ki-techne-harness` owns; Kris's own `studio` profile and catalogue, which chezmoi owns; the signed-release install kind, a separate record here.

## Dependencies / blocks

Not blocked. Blocks nothing today; `sol` including the role waits for it. The role's move to `ki-techne-harness`'s `roles/` folder proceeds independently.

## Discussion

Origin: `ki-principal`, state-of-play thread, under Kris Brown's acceptance of the audit decisions. Capture only; adoption, priority and plan belong to this repository. The outcome may be a finding that `conf.d` fragments already suffice, recorded with a worked example.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `investigate / Hold` until 2026-11-16, since its outcome may be a finding that `conf.d` fragments already suffice. vega does not exist, so a role shared across two hosts has only one host today. Adoption grants no planning, implementation or acceptance authority.
