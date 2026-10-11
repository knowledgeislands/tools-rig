---
id: RIG-CORE-045
area: CORE
title: Default applications
initiative: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-11T03:58:00Z
updated_at: 2026-10-11T03:58:00Z
---

# RIG-CORE-045: Default Applications

## Goal

Rig declares which application opens each chosen file type and URL scheme, and applies the same choice on every machine in the declared profiles. `rig doctor` reports a machine whose default handler differs from the declaration.

## Context

Kris asked for this on 2026-10-11, in the Mac Studio bootstrap thread. `open` on a Markdown file or path opens it in Obsidian, which Kris is moving off. Kris wants Markdown (`net.daringfireball.markdown`, the `.md` extension) to open in Zed (`dev.zed.Zed`) on both Macs. Rig has no way to declare a default application today, so Kris sets the laptop by hand meanwhile.

The catalogue already declares the applications themselves, and the built-in macOS adapters already own launchd, typed defaults and Dock order under [RIG-ORCH](../specs/orchestration.md). A default handler is a further piece of per-user macOS state of the same kind.

Removing Obsidian is a separate question. It belongs to the undeclared-software decisions in the chezmoi source (DOTFILES-UE-079) and to [RIG-CORE-041](RIG-CORE-041-unwanted-software-removal.md), not to this record.

## Boundary

- **In:** a declaration that maps a content type (UTI), a file extension or a URL scheme to an application bundle identifier, tied to a catalogue tool and filtered by profile like other declarations; observing the current handler; applying the declared one; a doctor finding for drift or for a declared handler whose application is not installed; tests, spec, guide, help and manual alignment.
- **Out:** removing or hiding the application being replaced; per-file overrides set in Finder's Get Info; Linux and other platforms, beyond reporting the declaration as unsupported there.

## Discussion

- **Mechanism.** Not chosen yet. Candidates: `duti`, a small Homebrew tool that sets handlers by bundle identifier and UTI or scheme; Launch Services directly, through a short `swift` script calling `NSWorkspace` or `LSSetDefaultRoleHandlerForContentType` and `LSSetDefaultHandlerForURLScheme`; or reading the current state with `lsregister -dump` or the Launch Services preferences. Weigh a new dependency against a built-in adapter, and check how each behaves when macOS asks the user to confirm a handler change, which it does for some schemes such as `http`.
- **Identity.** Decide whether the declaration keys on UTI, extension or both. Extensions are easier to write; UTIs are what Launch Services stores, and one UTI can cover several extensions.
- **Roles.** Launch Services distinguishes viewer, editor and all roles. Decide whether Rig exposes roles or always sets all.
- **Ordering.** The handler can be set only once its application is installed and registered, so apply runs after installs and may need to register a freshly installed bundle first.
