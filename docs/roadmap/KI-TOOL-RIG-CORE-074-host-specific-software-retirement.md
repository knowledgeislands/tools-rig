---
id: KI-TOOL-RIG-CORE-074
area: CORE
title: Host-specific software retirement
purpose: capability
theme: rig
status: triage
priority: medium
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-24T11:57:59Z
updated_at: 2026-10-24T11:57:59Z
---

# KI-TOOL-RIG-CORE-074: Host-specific Software Retirement

## Goal

Keep a tool's identity and removal intent in the catalogue after it is no longer wanted, so a later discovery on a named host can still be reported for removal. Allow the same tool to remain wanted on another host, while leaving deliberately unselected software alone.

## Context

Kris, 24 October 2026 at 12:45 BST, verbatim:

> One thing that's important for rig is I think we discussed it before is to make sure that it can handle a choice to delete a piece of software as well and so that it stays in deletion list and if it should find that software on one of the systems, it will remove it. Now there's a query there about whether or not it's removed from a particular host or not, but could still be kept for others. So I think the way to deal with deletions is to keep them in the software list with the target being which platforms they've installed on, and then once we're comfortable they've been there for a while, effectively deletions are if we detect that this software is not flagged for this host, then we should consider it needs to be deleted. Something like that.

The existing implementation captures parts of this idea, but not the complete retained-tool, per-host lifecycle. [RIG-CONF-028](../specs/configuration.md#rig-conf-028--explicit-native-software-removal) and [RIG-ORCH-042](../specs/orchestration.md#rig-orch-042--previewed-explicit-native-removal) already provide separate private `remove` declarations and previewed native uninstalls. [RIG-CONF-026](../specs/configuration.md#rig-conf-026--retired-application-declarations) and the [retired application guide](../guides/user/retired-applications.md) preserve separate, read-only macOS trace evidence; they neither uninstall software nor prevent an active declaration from reinstalling it.

Current software removal is selected by profile and platform, and supports Homebrew formulae/casks, mas apps, uv tools, npm globals and mise tools. It requires an explicit removal declaration and attended confirmation. Its validator rejects a native identity still declared by any tool installation anywhere in the catalogue, even if that installation belongs to another profile. Merely adding a second removal profile therefore cannot express keeping the same installation identity on terra while removing it on sol. Current platform names describe operating systems, not individual hosts: both examples are macOS. Profiles select tools; they are not proof of observed installation.

[ADR-KI-TOOL-RIG-008](../decisions/ADR-KI-TOOL-RIG-008-catalogue-scoped-resource-retirement.md) and [RIG-STATE-024](../specs/state.md#rig-state-024--declaration-kind-deselection) already protect against interpreting profile deselection as teardown. Complete reconciliation retires receipted resources whose declarations no longer own them on the platform; it does not uninstall deselected tools. Unmanaged inventory excludes identities recognised anywhere in the catalogue, including unselected placeholders, and is review evidence rather than removal authority.

The current roadmap has adjacent owners, not a duplicate of this outcome: [KI-TOOL-RIG-CORE-072](KI-TOOL-RIG-CORE-072-application-configuration-touch-points.md) owns active-tool touch-point evidence and its later retirement report, explicitly excluding automatic deletion; [KI-TOOL-RIG-CORE-064](KI-TOOL-RIG-CORE-064-unmanaged-configuration-scan.md) owns management of application configuration, excluding the recurring unmanaged-file scan. [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) implements the narrower, receipted firewall-resource retirement contract. None supplies a host-specific software absence intent that survives a retained catalogue entry.

Personal choices remain in chezmoi's `dot_config/rig/conf.d/`. On 24 October, the source lists Safari, Microsoft 365 Copilot Shim, Microsoft Defender Shim, Claude Code URL Handler, MSDisplayManager and Pi with empty profile selections. The helpers and Safari were deliberately recognised without being selected; MSDisplayManager is recognised while its continued hardware use is undecided. Pi is to remain Trial in the assessment model but selected on no machines for now. Its `~/.pi` directory is present on terra. Earlier review notes still describe Pi as laptop-selected; the current parsed source and Kris's later 12:09 decision supersede that snapshot. Absence from a machine selection cannot safely distinguish these cases.

## Boundary

- **In:** design and later implement retained catalogue identity, independent per-host presence intent, safe removal-candidate reporting, optional settling policy, native-adapter boundaries, validation, conflict handling, private evidence and fixture-based verification. Preserve the existing explicit removal command's authority boundary unless separately approved.
- **Out:** this triage capture does not adopt a plan or implement behaviour; it changes no personal catalogue, machine, package, data, scheduler, credentials or public projection. No live removal, remote operation, acceptance or pruning is authorised. Generic service teardown and configuration-content management remain with their existing contracts.

## Discussion

### Translate the requested lifecycle

"Stays in deletion list" means the catalogue remembers the tool and its removal intent even after a successful uninstall; removing the catalogue entry would lose the ability to recognise a later reappearance. "Kept for others" means intent must resolve for the actual host, not just macOS versus Linux. "Not flagged for this host" can identify a discrepancy, but needs an explicit removal disposition before that discrepancy becomes a removal candidate. Detection is observation; native removal remains a separately authorised action.

Recommend three resolved host dispositions: **present** (wanted here), **absent** (explicitly remove here) and **leave alone** (recognised, with no installation or removal authority here). A machine list describes where the tool is wanted, never where it was observed installed. A host omitted from that list defaults to leave alone, unless an explicit absence rule covers it. Assessment such as Trial or Caution, public disclosure, private review history and per-host disposition remain independent. A globally retired tool can have an empty wanted-machine list and retained absence rules for the named hosts; it need not be erased from the catalogue or turned into a radar ring.

Inferring removal from every omission would save a separate removal marker, but a profile edit, a paused trial or an inventory placeholder would then acquire destructive meaning. A settling delay only postpones that mistake; it does not distinguish the intentions. The explicit third disposition is recommended with high confidence because the current catalogue contains directly verified examples of all these different meanings.

This can be represented by one per-host desired-state map, or by a wanted-machine list plus an explicit remove-on list whose complement is leave alone. Exact field names, host identity and profile mapping are design questions, not accepted schema. Either representation must reject contradictory resolved intent on the same host while allowing one native package identity to be present on one host and absent on another. Preserve the current conservative identity and shared-dependency protection until that scoped ownership can be proved; do not merely weaken the global retained-installation guard.

### Concrete readings

These examples are plain-language proposed intent, not TOML accepted by today's parser and not an instruction to change either Mac.

- **Pi now:** assessment Trial; wanted machines none; explicit remove-here disposition on terra and sol, reflecting the current choice to stop using it on both. A native npm installation found in the covered context becomes a removal candidate, even though the tool remains in the catalogue for review. With no explicit remove-here disposition, the same empty machine list means leave alone. `~/.pi` is retained data evidence, not proof of an installed executable and not an uninstall or data-deletion target. Verify all relevant installed Node/npm contexts before claiming Pi is absent; the existing software review found an older Node context that the current one did not expose.
- **Keep on terra, remove on sol:** wanted machines terra; terra resolves present; sol explicitly resolves absent; other hosts resolve leave alone. On terra, Rig observes or installs through the declared route. On sol, it reports a matching installed identity for removal and does not reinstall it; once confirmed absent it keeps the absence rule to catch a reappearance. The common macOS platform does not collapse these two intentions.
- **Recognised helpers and Safari:** empty wanted-machine list; leave alone on both Macs. They remain visible catalogue identities without becoming uninstall candidates. MSDisplayManager likewise stays leave alone until its owner decides whether the hardware and driver are still needed. Recognition alone grants no permission to remove a vendor helper, OS application or its parent package.

### Settling and permission

"Once we're comfortable" needs an owner-chosen policy rather than an inferred amount of time installed. Recommend reporting candidates immediately once explicit absence intent exists, with removal held until an optional owner-set not-before date and the existing attended removal approval. A date passing does not itself grant permission. If a grace period is preferred, planning must define its start event per host, persistence across runs, reset conditions after reselection or intent changes, and how unavailable observations affect it. Kris's wording could also mean retaining the removal entry until confidence is high that all hosts have converged, rather than delaying the first uninstall: those are separate policies. Retaining the entry is recommended so a reappearance remains detectable; any later deletion of that policy is an explicit review decision, not automatic expiry. No default period or unattended standing removal authority is agreed here.

### Adapter and evidence boundaries

Keep software uninstall, managed-resource retirement and user-data cleanup distinct. Delegate supported native uninstalls to the existing manager contract, retaining dependency refusals, exact identity matching, preview, reobservation, operation locks and independent failures. Unsupported, shared, protected, mismatched or uncertain identities remain review-only; their presence never justifies a guessed path deletion, force, zap or new privilege grant. A surviving data directory is reported separately, and deletion of it needs its own explicit decision. Retired trace reporting can reuse the touch-point work without making those paths uninstall targets.

A host reporting absence is healthy for an explicit absent disposition, and a later reappearance is pending removal again. Missing managers, inaccessible locations and ambiguous identities remain unknown or unavailable rather than successful absence. A different profile used for a narrow run must not silently change the durable host policy or expand removal scope. Retired tools and private absence/review evidence stay outside public export under the existing disclosure contract.

### First shaping deliverable

Before adoption or implementation, settle the host/profile identity model and the three dispositions with worked fixtures for Pi, the recognised placeholders and terra-present/sol-absent. Then specify the retained-identity conflict rule, default and optional settling policy, compatibility of existing `remove` and `retired-application` declarations, private observation/reporting and the exact approved removal entry point. Build and verify only against synthetic packages and isolated managers; never reproduce retirement against the working machine. Existing chezmoi alignment and review work continues to own the personal decisions and attended cleanup, rather than being replaced by this portable lifecycle proposal.
