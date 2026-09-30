---
id: RIG-CORE-030
area: CORE
title: Govern tool repair lifecycle
theme: orchestration
horizon: waiting-for
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-27T15:59:32Z
updated_at: 2026-09-30T22:28:16Z
---

## Goal

Make local tool repairs discoverable, verifiable and safe to carry through upgrades without requiring the operator to remember a collection of special scripts. Establish the smallest useful Rig integration while keeping each tool's repair knowledge with its owning component.

## Context

Paperclip onboarding exposed two independent local repairs: historical issue-key aliases and an OpenAI authentication-configuration guard. Both work in the installed application, but the chezmoi source checker assumes every repair has alias evidence, covers only the first repair and has not yet been deployed. A further agent grant-update defect illustrates why a repair inventory cannot assume one verification shape. The consolidated operating evidence is in the dotfiles repository's `docs/guides/tools/paperclip.md`, recorded by commit `29547c81d3b01761b69a1e7d4ac6437c375a1e81`; recheck its dated observations before planning delivery.

Paperclip currently has separate setup, agent-reconciliation and repair-check commands in chezmoi's `bin/`, plus a Rig external provider that translates the agent reconciler's results. Rig supports bounded external-provider observation and application. Declared action metadata does not provide a public command runner; imperative repair commands remain with their native component owner. The gap is a coherent ownership and lifecycle model, not the mere presence of executable files in chezmoi or the lack of another command runner.

Other tools expose related boundaries. The mcporter restart wrapper mixes reusable launchd waiting and retry mechanics with tool-specific transport recovery. The scheduled App Store workaround mixes host policy with the broader need for providers to identify operations requiring a person. These are comparison cases, not proof that all repairs need one implementation.

## Boundary

This item belongs to Rig for the reusable orchestration, observation and provider-contract questions. Paperclip patches, its membership API fix, credentials, company data and repair snapshots remain outside Rig core. Personal selections and repair declarations belong to the host configuration; substantial tool-specific maintenance logic belongs to its tested provider or component. The agentic harness owns portable operating guidance, not a second machine repair catalogue.

Capture does not authorise applying patches, upgrading tools, deploying dotfiles, restarting services, changing grants or editing another repository. It does not commit to a generic patch engine, a new repository or package registry, or bulk migration of every existing wrapper.

## Waiting condition

Waiting for an ownership and integration design investigation, reviewed by Kris with the dotfiles and affected component owners. Return to Next only when that investigation names the owner of repair declarations, implementation, verification and retirement, and demonstrates a concrete gap in Rig's existing provider contract. The user explicitly deferred this item on 2026-09-30; it is excluded from the reliability, display and next 0.x release finishing round.

No investigation has been commissioned or completed by this deferral. The host's existing repair work retains its own owner and remains outside Rig's delivery authority.

## Shaping

Start with a read-only comparison of the existing Paperclip repairs and Rig provider protocol. The first deliverable is an ownership and integration decision with verification examples; implementation across Rig or the dotfiles repository follows only if that decision identifies a concrete gap. The external component's current behaviour and upgrade evidence must be rechecked before promotion to Next.

## Discussion

### Existing capability before new machinery

Assess whether the existing external-provider observe/apply contract can provide the required integration first. A small tested Paperclip maintenance component with thin command entry points is a viable initial shape; chezmoi can continue distributing it while it is host-specific. Moving files from `bin` to another directory alone does not improve verification or ownership.

Add a shared Rig mechanism only where concrete cases expose a common orchestration need. Keep native service and port management with Rig's built-in providers. Tool-specific admission drains, authentication probes, patch application and task recovery remain with the tool's component. Do not conceal native lifecycle operations in arbitrary configuration commands.

### Repair identity and evidence

Each repair needs an identity and reason, an owner, supported upstream versions, applicability evidence, reviewed patch or operation, behaviour-specific verification, recovery information and a retirement condition. Distinguish declared policy, installed payload, running process and observed behaviour; a healthy service does not prove upgrade compatibility, and matching files do not prove the process loaded them.

Whole-file fingerprints must describe the combined installed result when repairs overlap. A changed upstream release requires reviewed adaptation rather than copying an old vendor file over it or refreshing a hash to silence a failure. Retiring a patch should retain the regression check for the behaviour it protected. Instance-specific evidence and secrets stay outside portable source control.

### Operator visibility and authority

Repair health should be separately observable from agent-configuration drift and service availability. Use Rig's existing state and outcome contracts where they fit, and report unavailable evidence honestly rather than treating an unexamined repair as healthy. Read-only inspection must never install a patch or restart a service.

Mutation needs an explicit bounded operation, version checks and verification. Maintenance holds need one owner; an existing hold must not be replaced silently. Preserve the distinction between a drained restart, an explicitly authorised interruption and recovery of the underlying work. Any proposed upgrade gate must state whether it prevents replacement or only detects an already-replaced installation.

### First deliverable and open decisions

The first deliverable should be a reviewed ownership and integration design using the two different Paperclip repairs as concrete cases, with enough verification detail to separate installed checks from live probes and retirement checks. It should identify what existing Rig capabilities already satisfy, what belongs in the Paperclip component, and any actual Rig protocol or lifecycle gap. Establish the follow-on delivery boundaries with the dotfiles owner before implementing them.

Decide whether repair observation needs its own declared target, how upgrade gating composes with native providers, and whether reusable service-recovery primitives merit promotion into Rig. Keep both a provider-only solution and a small shared mechanism available until the evidence distinguishes them.

### Related work

RIG-CORE-024 owns the narrowed unattended-upgrade contract; narrowly targeted application is already delivered. Neither is a build-order dependency for this design, and this item must not duplicate their delivery. DOTFILES-UE-049 owns the host reconciler's absence-versus-invisibility defect, while DOTFILES-UE-051 owns its App Store detection problem. Local Paperclip repair protection remains unfinished host work; capturing this Rig item does not complete or transfer it.
