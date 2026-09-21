---
id: TRD-3a1ab790
title: "Unexpanded $HOME breaks drift and apply"
created_at: 2026-09-21T06:27:26Z
sender: krisb/dotfiles
receiver: knowledgeislands/tools-rig
kind: work
source_ref: "d744be5"
observation: decision
phase: received
decision_status: adopted
received_from_ref: 0b9f4e670346a5ca9501e0c0cb6760d002a4b874
reviewed_at: 2026-09-21T12:18:14Z
rationale: "Home-path normalization is a portable Rig configuration and state concern owned by RIG-CORE-014; resource-local preflight isolation remains separately governed by RIG-CORE-015."
adopted_as: RIG-CORE-014
---

# TRD-3a1ab790: Unexpanded $HOME breaks drift and apply

## Context

Rig 0.2.0 on macOS 27.0.0, reconciling the personal declaration in krisb/dotfiles (`dot_config/rig/conf.d/private_40-macos.toml`).

Declared values that embed `$HOME` are compared against live observed values without expansion, so the literal string `$HOME/Downloads` is matched against `/Users/krisbrown/Downloads` and never agrees. The machine is not drifted; the comparison is.

`rig doctor` reports 8 findings, of which 3 are phantom:

    dock.workstation: drifted (order)
    setting.finder-new-window-target-path: drifted (expected:file://$HOME/ observed:file:///Users/krisbrown/)
    setting.screencapture-location: drifted (expected:$HOME/Downloads observed:/Users/krisbrown/Downloads)

The expected/observed pairs make the cause explicit. The remaining 5 findings are genuine.

More seriously, the same defect fails `rig apply` closed. `rig apply --dry-run` exits 2 after one line and plans nothing at all:

    rig: error: [dock.workstation] Dock item path is missing: $HOME/Downloads

`~/Downloads` exists (mode 700, owner krisbrown). A `kind = "folder"` dock item is existence-checked against the unexpanded literal. Because this aborts the whole run, no unrelated resource can be reconciled either: 2 drifted services, 2 drifted scheduled jobs, and 1 missing scheduled job are all unreachable until the dock item is either fixed upstream or hard-coded to an absolute path locally.

Only the two folder dock items are affected; application items declare fully-qualified paths such as `/Applications/1Password.app` and pass.

## Submission

Expand `$HOME` (and ideally `~`) in declared path-valued settings and dock-item paths before both the existence check and the drift comparison, so a declaration that is portable across machines compares equal to the expanded value the OS reports.

Two distinct call sites are implicated and both need it:

1. The dock adapter's `kind = "folder"` path existence check, which currently exits non-zero and aborts planning.
2. The `macos-defaults` settings comparison, which currently reports drift for any value containing `$HOME`, including the `file://$HOME/` URL form used by `com.apple.finder` `NewWindowTargetPath`.

The URL case suggests expansion should be substring-based over the declared value rather than a whole-string path resolution.

Worth considering alongside this: a missing declared path arguably should be a per-resource finding rather than a fatal error that abandons the entire plan. A single unreachable path currently makes every other resource unreconcilable, which is what turned a cosmetic dock issue into a total apply blocker here.

## Constraints

Filed as observation only. tools-rig owns whether this becomes a roadmap item, how it is scoped, and the fix's shape; no local work is requested or implied.

This is reported from a peer checkout and no change was made to tools-rig. Note that the tools-rig working tree had 20 modified files uncommitted when this was prepared, so another writer was active there.

Receiver-side context: krisb/dotfiles carries DOTFILES-UE-034 (retire Rig operations), which would consume a fix. It also carries DOTFILES-UE-031, a separate and unrelated upstream concern about artifact integrity observation — a cask whose bundle has been emptied still reports `present` because presence derives from `brew list --cask` alone. That one is deliberately not part of this trade and can be sent separately if useful.
