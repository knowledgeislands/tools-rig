---
id: TRD-62dc768f
title: "Observe retired application traces"
created_at: 2026-09-30T20:31:41Z
sender: krisb/dotfiles
receiver: knowledgeislands/tools-rig
kind: work
source_ref: "DOTFILES-UE-028"
observation: decision
phase: received
decision_status: superseded
received_from_ref: ae5be36c03f08de5847c58bc753ca21ff48db379
reviewed_at: 2026-10-01T04:45:08Z
rationale: "Re-homed as unadopted Rig roadmap intake RIG-CORE-039; no implementation or priority has been approved."
superseded_by: RIG-CORE-039
---

# TRD-62dc768f: Observe retired application traces

## Context

Rig currently reconciles application bundles but cannot surface user-data remnants left by retirement or last-used evidence for declared apps. Actual and Unsloth Studio retirements exposed retained data, support files, and package-managed caches.

## Submission

Design a read-only macOS observation that matches exact retired identities, reports conventional remnant locations and partial last-used evidence, and distinguishes package-managed stores without proposing deletion.

## Constraints

Do not delete data or infer ownership from name substrings. Report stale use as a review candidate only. Preserve the receiver’s authority over portable Rig schema, adapters, and command language.
