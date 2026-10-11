---
id: RIG-CORE-045
area: CORE
title: Default applications
initiative: rig
kind: deliver
purpose: capability
component: cli
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 82ef601351989860b2004ad202901fe8d0969763
created_at: 2026-10-11T03:58:00Z
updated_at: 2026-10-11T10:21:31Z
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

## Current state

Kris approved bounded adoption, routine planning and delivery under tools-burndown Decisions 1, 3 and 4. The bootstrap source retains personal application and restart/screen choices. No competing delivery owns this record. Rig currently has no declared handler state; application presence/source helpers are available from RIG-CORE-043.

## Steps

- [x] Add validated `[default-application.ID]` resources for a UTI, file extension or URL scheme, tied to an application tool/bundle identifier and selected through existing profiles.
- [x] Add the fixed macOS Launch Services adapter through the built-in JavaScript bridge, with app-artifact/bundle verification, honest missing/drift/unsupported observations and private declared intent.
- [x] Apply after tool installation, register the declared app before assignment, skip already-correct handlers and verify the effective handler after native success without bypassing macOS confirmation.
- [x] Align specifications, guide, help and manual; verify isolated handler/installation stubs, unsupported platforms and the complete local gate, review the actual diff and prepare the Review packet.

## Files touched

Declaration registry and configuration/profile dispatch; native resource preflight/observation/application and resource description modules; a new default-application module and assembly manifest; assembled executable; inert osascript test isolation and focused handler tests; configuration/state/orchestration specifications, user guides/navigation, help/manual and changelog. Protected Dock implementations and RIG-CORE-042 remain unchanged.

## Verify

Fixtures cover UTI/extension/scheme declarations, owned app absence/damage or bundle mismatch, profile selection and dependency ordering, install-before-handler dispatch, correct-handler no-op, native failure and ineffective/declined assignment, no mutation in doctor/dry-run, private export, conflicting selected declarations and unsupported Linux without native handler calls. Validate the bridge against locally available SDK signatures and literal argument handling without reading or changing live handlers. Run the complete developer-guide gate, hostile-state containment when changing isolation, reference benchmark and rendered manual inspection.

## Dependencies / blocks

RIG-CORE-043's application-artifact helpers are delivered; no acceptance dependency. The adapter uses macOS's existing osascript/plutil rather than acquiring duti or a runtime SDK. No live handler assignment, personal catalogue/profile/Dock change, uninstall or new work record is authorised.

## Documentation impact

### Decision Records

Routine adapter/shape choices and owner authority are recorded here; no separate architectural decision or Initiative note is needed.

### Specifications

Specify private handler declarations, profile/tool prerequisite ordering, native observations, effective-result verification and platform limits.

### Guides

Add a focused handler guide and navigation, and align user commands, getting started, help and manual.

### Roadmap

Retain this identity, immutable baseline and Review packet. Stop at Awaiting review; no acceptance or pruning.

## Review

### Delivered

Delivered the approved private macOS default-application resource from immutable baseline `82ef601351989860b2004ad202901fe8d0969763`. This is generic engine behaviour; no personal handler, catalogue, profile or Dock choice and no live assignment is included.

### Change Summary

Added validated UTI, extension and URL-scheme declarations tied to a catalogue application and selected through existing profiles. The fixed static Launch Services bridge verifies the owned app and bundle identifier, observes honest drift/absence/unknown/unsupported state, runs after installation, skips a correct handler and verifies the effective assignment. Literal native arguments, private offline descriptions and export exclusion retain the existing ownership boundary. Specifications, focused guide, navigation, help, manual and changelog are aligned; inert osascript isolation and eighteen handler fixtures cover the new surface.

### Verification

The complete developer-guide gate passed: repository audit (PASS=19, WARN=1, FAIL=0), ShellCheck, Bash syntax, deterministic assembly, portability benchmark, bounded native version smoke, 513 Bats cases with zero failures, mandoc lint and diff whitespace checks. Two existing optional Python tomllib interoperability cases skipped because no supported interpreter is on the manager-free test PATH; all selected handler cases ran. Eighteen handler fixtures and five declaration-registry checks passed separately. The full suite ran under hostile inherited XDG state and retained only its marker. The two-second reference query benchmark passed (2/2/2 seconds; status 6 seconds within its eight-second budget). Locally available SDK signatures, literal bridge argv, JavaScript compilation and native symbol reflection were checked without calling live handler functions. The rendered manual and actual source/documentation diff were reviewed. Evidence: `/tmp/rig-045-gate.log`, `/tmp/rig-045-focused-final.log`, `/tmp/rig-045-reference-final.log` and `/tmp/rig-045-manual.txt`.

### Outstanding concerns

No required delivery check remains failing. Native macOS consent and effective Launch Services state remain authoritative; an ineffective assignment stays incomplete. Functional native assignment was deliberately tested through isolated stubs, without reading or changing this machine's handlers. Declare a native content type once by UTI or extension, because both can identify the same native type. The pre-existing missing committed-hook audit warning remains; no hook was installed or bypassed.

### Post-change review

Missing, damaged or mismatched apps cannot reach handler query/set operations. Installer failure blocks assignment; healthy catalogue-only ownership can satisfy the prerequisite without inventing an installer. Correct handlers are no-ops; doctor/status and dry-run do not assign/register handlers. Duplicate selected normalised targets fail before native work. Native errors and ineffective results remain failures. Linux reports unsupported state without native calls; export, deselection and retirement do not publish, reset or delete handlers. The actual 22-path delivery was reviewed and protected paths remain untouched.

### Mini recap

Default-application declarations, honest observations and ordered native assignment are delivered for Kris's review. Durable behaviour lives in the existing specifications and user guide; captured scope, routine choices and authority remain here. Personal configuration stays in its source thread. No acceptance, release, pruning or new work record is proposed.

## Discussion

### Approved routine choices

Use private `[default-application.ID]` resources with required name/purpose/rationale, fixed `provider = "macos-handlers"`, application `tool`, `bundle-id`, `kind = "uti" | "extension" | "scheme"`, `value`, macOS platforms and optional profiles. Central profiles use `default-applications`; item membership follows existing conventions. Tool ownership reuses the existing prerequisite machinery. The selected declared application artifact must be healthy and its Info.plist bundle identifier must match before any handler operation; a catalogue-only app may satisfy this through its owned artifact. File types use all roles. Extensions accept one optional leading dot; schemes are lowercase without a colon. Conflicting selected declarations of the same normalised kind/value are rejected; declare a native type once, using its UTI or extension.

The built-in adapter uses static JavaScript through macOS osascript and Launch Services, passing declarations as literal argv. Local SDK signatures and bridge argument handling have been checked without reading or changing live handlers. This avoids a new duti or runtime SDK dependency. Apply follows tool installation, registers the declared app before setting a changed handler, skips a correct assignment and reobserves the effective result. Native error, an ineffective assignment or pending macOS confirmation remains an incomplete outcome; no consent bypass is attempted. Other platforms retain a visible unsupported declaration without native handler calls. These resources do not enter receipts, retirement or public export, and deselection never resets handlers. Protected Dock implementation and RIG-CORE-042 remain untouched.

- **Mechanism.** Not chosen yet. Candidates: `duti`, a small Homebrew tool that sets handlers by bundle identifier and UTI or scheme; Launch Services directly, through a short `swift` script calling `NSWorkspace` or `LSSetDefaultRoleHandlerForContentType` and `LSSetDefaultHandlerForURLScheme`; or reading the current state with `lsregister -dump` or the Launch Services preferences. Weigh a new dependency against a built-in adapter, and check how each behaves when macOS asks the user to confirm a handler change, which it does for some schemes such as `http`.
- **Identity.** Decide whether the declaration keys on UTI, extension or both. Extensions are easier to write; UTIs are what Launch Services stores, and one UTI can cover several extensions.
- **Roles.** Launch Services distinguishes viewer, editor and all roles. Decide whether Rig exposes roles or always sets all.
- **Ordering.** The handler can be set only once its application is installed and registered, so apply runs after installs and may need to register a freshly installed bundle first.
