---
id: KI-TOOL-RIG-CORE-080
area: CORE
title: GitHub SSH key check
priority: medium
size: s
assignee: owner
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-11-24T12:02:30Z
updated_at: 2026-11-24T12:02:30Z
---

# KI-TOOL-RIG-CORE-080: GitHub SSH key check

## Goal

Rig tells a person when their GitHub SSH key cannot be used without an agent, because its passphrase is not in the macOS Keychain, and names the `ssh-add --apple-use-keychain` fix.

## Context

Kris asked on 27 October 2026 (KEY-REMINDER) for a resource or `rig doctor` check that runs `env -u SSH_AUTH_SOCK ssh -T -o BatchMode=yes git@github.com` and reports a missing Keychain passphrase with the `ssh-add --apple-use-keychain` fix (RIG-SSH-CHECK). The chezmoi guides carry the manual step meanwhile. Rig has no SSH-identity check today. Kris agreed the capture on 24 November 2026: ki.tools's change 11, 4.2, in the Cairn store, `work/ki/ki.tools/11-rig-lane.change.md` (RIG-INTAKE), and the [rig-intake report](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/setup/rig-intake.report.md). Original line: [the Mac Studio setup messages](https://github.com/krisb/ki-cairn-store/blob/b759e7b4506da8df0c4ca680f577bae82f7cfe57/work-legacy/batch-01-initial/personal/personal.reg.rig-sol/folded/ki.prj.mac-studio-setup/messages.md), 28 October.

## Boundary

- **In:** a resource or doctor check, its finding and fix text, specification and tests that never reach the network.
- **Out:** creating, loading or storing keys; SSH configuration, which chezmoi owns.

## Discussion

Planning must settle whether `rig doctor` may make a network call, or whether the check belongs to an explicit resource or flag instead. Captured as triage for Kris to adopt or cancel.
