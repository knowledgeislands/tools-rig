---
id: KI-TOOL-RIG-DIST-011
area: DIST
title: Stale vega rig link
purpose: corrective
theme: rig
kind: deliver
status: cancelled
resolution: obsolete
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T09:36:23Z
updated_at: 2026-10-20T04:35:57Z
---

# Stale vega Rig Link

## Goal

`rig` on the Linux host `vega` runs a current Rig: `~/.local/bin/rig` points at a live checkout or is replaced by a release install, and `rig --version` succeeds there.

## Context

As reported on 14 October 2026, `~/.local/bin/rig` on `vega` still points at the retired `~/workspaces/kit/knowledgeislands/tools-rig` path, left over from before repositories moved to `~/workspaces/<group>/<repo>`. The same stale link, and a matching manual-page link, existed on Kris's Mac, where Homebrew's later `PATH` entry masked it; both were removed there the same day. Kris Brown asked on 2026-10-14 for the defect to be recorded and held; nothing on `vega` may change while the Techne Programme Hold stands.

## Boundary

- In: relinking `vega`'s `rig` through the checkout's `install.sh --link`, or a release install, and its manual page; verifying `rig --version` there.
- Out: any other change on `vega`; running `rig apply` there; other hosts.

## Cancelled

Approved by Kris on 20 October 2026 under SWEEP-CONVERT a), recorded in Knowledge Islands Principal `+/_WORK/ki.ways-of-working/decisions.md`: "I agree with sweep merge ... should become message records". This is a one-off machine fix on `vega`, not Rig product work, so under HANDOFF-AS-MESSAGE it is cancelled as obsolete as a record and goes as one line to `ki.agent-host`'s `messages.md` in Knowledge Islands Principal: relink `~/.local/bin/rig` and its manual page with `install.sh --link` or a release install, then check `rig --version`. Nothing on `vega` has changed.

## Discussion

Origin: Kris Brown's request of 2026-10-14 in the state-of-play thread. The per-tool development mode switch, [KI-TOOL-RIG-CLI-026](KI-TOOL-RIG-CLI-026-per-tool-development-mode-switch.md), would let `rig dev release rig` or `rig dev local rig` repair this kind of stale link.
