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
updated_at: 2026-10-24T12:29:56Z
---

# KI-TOOL-RIG-CORE-074: Host-specific Software Retirement

## Goal

Keep a tool's identity in the catalogue after it is no longer wanted, so a later discovery on a host where it is not selected is reported as a removal candidate. Allow the same tool to remain selected on another host. Select everything wanted on each host, including system applications and installer-produced helpers whose selection means expected presence without an installation route.

## Context

Kris, 24 October 2026 at 12:45 BST, verbatim:

> One thing that's important for rig is I think we discussed it before is to make sure that it can handle a choice to delete a piece of software as well and so that it stays in deletion list and if it should find that software on one of the systems, it will remove it. Now there's a query there about whether or not it's removed from a particular host or not, but could still be kept for others. So I think the way to deal with deletions is to keep them in the software list with the target being which platforms they've installed on, and then once we're comfortable they've been there for a while, effectively deletions are if we detect that this software is not flagged for this host, then we should consider it needs to be deleted. Something like that.

The existing implementation captures parts of this idea, but not the complete retained-tool, per-host lifecycle. [RIG-CONF-028](../specs/configuration.md#rig-conf-028--explicit-native-software-removal) and [RIG-ORCH-042](../specs/orchestration.md#rig-orch-042--previewed-explicit-native-removal) already provide separate private `remove` declarations and previewed native uninstalls. [RIG-CONF-026](../specs/configuration.md#rig-conf-026--retired-application-declarations) and the [retired application guide](../guides/user/retired-applications.md) preserve separate, read-only macOS trace evidence; they neither uninstall software nor prevent an active declaration from reinstalling it.

Current software removal is selected by profile and platform, and supports Homebrew formulae/casks, mas apps, uv tools, npm globals and mise tools. It requires an explicit removal declaration and attended confirmation. Its validator rejects a native identity still declared by any tool installation anywhere in the catalogue, even if that installation belongs to another profile. Merely adding a second removal profile therefore cannot express keeping the same installation identity on terra while removing it on sol. Current platform names describe operating systems, not individual hosts: both examples are macOS. Profiles select tools; they are not proof of observed installation.

[ADR-KI-TOOL-RIG-008](../decisions/ADR-KI-TOOL-RIG-008-catalogue-scoped-resource-retirement.md) and [RIG-STATE-024](../specs/state.md#rig-state-024--declaration-kind-deselection) already protect against interpreting profile deselection as teardown. Complete reconciliation retires receipted resources whose declarations no longer own them on the platform; it does not uninstall deselected tools. Unmanaged inventory excludes identities recognised anywhere in the catalogue, including unselected placeholders, and is review evidence rather than removal authority.

The current roadmap has adjacent owners, not a duplicate of this outcome: [KI-TOOL-RIG-CORE-072](KI-TOOL-RIG-CORE-072-application-configuration-touch-points.md) owns active-tool touch-point evidence and its later retirement report, explicitly excluding automatic deletion; [KI-TOOL-RIG-CORE-064](KI-TOOL-RIG-CORE-064-unmanaged-configuration-scan.md) owns management of application configuration, excluding the recurring unmanaged-file scan. [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) implements the narrower, receipted firewall-resource retirement contract. None supplies a host-specific software absence intent that survives a retained catalogue entry.

Kris, 24 October 2026 at 12:48 BST, verbatim, answering the concern about recognised but unselected Safari, Microsoft helpers and Pi:

> Well, let's look at those ones, right? So Safari is installed on both hosts, the Microsoft helper is installed on both hosts, and Pi should not be installed on both hosts, so that's likely an issue with the configuration than it is the intent.

Read back: anything wanted on a host is selected for that host, system apps and helper shims included. For these observation-only entries, selection means expected present, with no installation route. Anything present on a host where it is not selected is a removal candidate. The existing unselected examples reveal configuration gaps or unwanted software; they do not establish a third disposition. This clarification supersedes this record's earlier recommendation of a **leave alone** marker and its proposed default for omitted hosts. No case in the inventory below requires that marker.

Personal choices remain in chezmoi's `dot_config/rig/conf.d/`. [KB-DOTFILES-UE-112](/Users/krisbrown/.local/share/chezmoi/docs/roadmap/KB-DOTFILES-UE-112-review-workstation-software.md) records the earlier recognition-only placeholders; its SHIM-APPS snapshot still describes Pi as laptop-selected. The current parsed declarations and Kris's later 12:09 pause decision supersede that Pi snapshot: it remains Trial but no machine selects it. The 12:48 clarification now supplies the intended relationship between selection and removal candidacy. Assessment, current presence and desired host selection remain separate facts.

## Boundary

- **In:** design and later implement retained catalogue identity, host selection as presence intent, safe removal-candidate reporting for unselected installed tools, optional settling policy, native-adapter boundaries, validation, conflict handling, private evidence and fixture-based verification. Preserve the existing explicit removal command's authority boundary unless separately approved.
- **Out:** this triage amendment does not adopt a plan or implement behaviour; it changes no personal catalogue, machine, package, data, scheduler, credentials or public projection. No live removal, remote operation, acceptance or pruning is authorised. Generic service teardown and configuration-content management remain with their existing contracts.

## Discussion

### Translate the requested lifecycle

"Stays in deletion list" means retaining catalogue identity after an uninstall so a reappearance can be recognised. "Kept for others" means resolving selection for the actual host, beyond macOS versus Linux. "Not flagged for this host" means an observed installation is a removal candidate when the host does not select it. No extra removal-intent or leave-alone marker is needed to make that candidate. Detection and candidacy do not authorise execution: native removal remains a separately approved action.

The resolved software intent has two outcomes: **selected here**, meaning expected present, and **unselected here**, meaning a matching installation is a removal candidate if found. An empty wanted-host list makes the tool a candidate wherever found in the covered host estate. Assessment such as Trial or Caution, disclosure and private review history do not override that selection rule. A wanted system app or derived helper must be selected even when it has no install route. Such selection must still observe its own identity and report missing or broken presence honestly.

Exact host identity, field names and profile mapping remain design questions, not accepted schema. Both example machines are macOS. A host-specific model must allow the same native identity to be selected on terra and unselected on sol, without weakening identity or dependency protection. Today's global retained-installation guard and separate explicit removal declarations need deliberate compatibility design. A narrow invocation with another profile must not accidentally redefine the host's durable selection.

### Complete host comparison, 24 October 2026

The local Rig 0.8.0 catalogue on terra contains **199 tools**. Read-only `rig show --all --json`, `rig show --profile laptop --json` and `rig show --profile studio --json` were compared by exact tool identifier. The laptop profile selects 186, leaving **13 unselected on terra**. Resolving studio against that same catalogue selects 183, leaving **16 unselected for sol if the shared configuration is applied**. Their union is **17 tools**: 12 selected by neither host, one studio-only and four laptop-only. Public-view membership does not select a tool on either host. These counts include tools with neither artifacts nor a native install route; hiding those would miss Paperclip and its agent configuration.

Terra selection is verified from the local rendered Rig configuration. Presence below uses read-only checks of declared artifact paths, local Homebrew cask receipt directories and Pi's installed package metadata; it is not a new full live health check. No provider, service or scheduler was changed. A present bundle or receipt does not prove a functioning application. In particular, the previously recorded broken Claude handler was not reclassified as healthy.

**Every sol observation and selection projection is unverified on sol.** No connection to sol was made. Its historical evidence comes from [KB-DOTFILES-UE-086](/Users/krisbrown/.local/share/chezmoi/docs/roadmap/KB-DOTFILES-UE-086-finish-software-alignment.md), [KB-DOTFILES-UE-112](/Users/krisbrown/.local/share/chezmoi/docs/roadmap/KB-DOTFILES-UE-112-review-workstation-software.md), the preceding rig-removal findings retained above and Kris's 12:48 statement. Unknown sol presence is not absence. A projected selection difference is not proof that sol has received the current configuration.

Kris settled these dispositions on 24 October 2026 at 13:27 BST. In the table, **U** means unselected and **S** selected in the pre-decision terra catalogue’s host-profile resolution; the observation columns and counts above remain historical evidence. **Unknown** means presence was not established. The decided column records intended selection, not proof of installation or permission for a general apply. Neither makes observed software a removal candidate; retained data and agent configuration have separate boundaries.

| Tool identifier | terra before | sol, unverified | Decided disposition | Confidence |
| --- | --- | --- | --- | --- |
| `builtin-safari` | U, present | U, owner says present | Both | High |
| `microsoft-365-copilot-shim` | U, present | U, owner says present | Both | High |
| `microsoft-defender-shim` | U, present | U, helper evidence | Both | High |
| `claude-code-url-handler` | U, bundle present | U, unknown | Both | High |
| `google-drive-shortcuts` | U, three present | U, historical presence | Both | High |
| `msdisplaymanager` | U, present | U, unknown | terra; sol undecided | High |
| `chatgpt-current` | U, cask receipt | U, unknown | Both | High |
| `rekordbox` | U, bundle and receipt | U, unknown | Both | High |
| `tigervnc` | U, bundle and receipt | U, unknown | Neither; remove | High |
| `pi-coding-agent` | U, older Node install | U, removal recorded | Neither; keep Trial | High |
| `paperclip` | U, unknown | U, unknown | Neither; retain data | High |
| `paperclip-agents` | U, unknown | U, unknown | Retain settings ‡ | High |
| `davinci-resolve` | U, bundle absent | S, historical presence | sol | High |
| `delta` | S, present | U, unknown | terra | High |
| `orca` | S, bundle and receipt | U, unknown | Both; keep Trial † | High |
| `prime-video` | S, present | U, historical keep if present | Both | High |
| `webex` | S, present | U, unknown | terra | High |

† At 14:00 BST on 24 October 2026 Kris clarified: "orca is in trial on both laptop and studio". This supersedes the earlier host conflict: select Orca on both terra (laptop) and sol (studio), keeping Trial and private trial prose off the public site. The observation columns remain historical; sol’s installation is queued for its local pass, with no sol observation or live change in this pass.

‡ Keep the agent configuration and data unchanged, with reconciliation still unselected; empty selection is not deletion authority. Kris requested a chezmoi roadmap item to study the settings for learnings before deciding their future. The Paperclip program is selected on neither host and its persistent data stays.

TigerVNC is unwanted on every Mac because macOS supplies the replacement VNC client. Kris authorised terra’s native uninstall outright without a backup; sol’s uninstall is queued for its local pass. This decision does not authorise removing Pi, Paperclip or retained data in the current selection pass. Pi’s Trial ring remains independent of empty machine selection. MSDisplayManager stays unselected on sol pending its own decision. No missing selected tool is installed in this pass.

The per-tool reasons below are historical review recommendations, superseded by the decided dispositions above:

- **Safari:** select on both, expected present without an install route. Kris explicitly names its presence on both hosts; its system cryptex symlink is no reason to leave it unselected.
- **Microsoft 365 Copilot Shim:** select on both, expected helper presence without an install route. This is the Office installer helper in the earlier example, covered by Kris's correction; it does not select standalone Copilot.
- **Microsoft Defender Shim:** recommend selecting on both without an install route, as an installer-produced placeholder. Terra presence is verified, but Kris's singular "Microsoft helper" does not independently identify both shim bundles on sol; that is why confidence is lower. Selecting the shim does not select Defender itself.
- **Claude Code URL Handler:** recommend selecting on both without an install route, as a helper of the wanted Claude Code. Terra's bundle exists; the review records an executable link into an absent older cask. Selection must retain that defect, with regeneration owned by Claude Code. The earlier chezmoi test and guide that require it to stay unselected need a later, separately authorised correction if this recommendation is agreed.
- **Google Drive shortcuts:** recommend selecting all three under their existing one tool on both, with no install route. Terra has Docs, Sheets and Slides; the sol keep-installed decision in the alignment record and the later recognition instruction support retaining them. Their derived ownership by Drive does not remove the selection requirement.
- **MSDisplayManager:** provisionally recommend terra only, with low confidence: the local bundle is present and the review records a running display driver, but Kris has not confirmed continued use of its USB adapter. This is an unresolved selection decision, not a third state. If the adapter is no longer wanted, choose neither and treat any installed driver as a candidate; do not uninstall it during this review.
- **ChatGPT current desktop app:** provisionally recommend terra only. Its local Homebrew `chatgpt` receipt and the software review establish a retained packaging watch item alongside ChatGPT Classic, not an owner decision to retire it. Evidence does not establish a sol requirement; extend to both only if Kris wants it there.
- **Rekordbox:** provisionally recommend terra only. Its declared bundle and cask receipt are present, and no reviewed record retires the DJ library tool. That supports asking to select it on terra; sol need and presence remain unverified.
- **TigerVNC:** provisionally recommend terra only. The generic `/Applications/TigerVNC.app` and its cask receipt exist; the version-specific alternative path is absent. Neither this nor overlap with other remote clients establishes a removal decision. There is no reviewed evidence to select it on sol.
- **Pi:** neither, as Kris explicitly directs. Pi 0.84.2 package metadata exists under terra's older Node 24.19.0 installation; the `24.19` path resolves to that same installation, not a second copy. The alignment record carries sol's npm removal. An inactive current shim does not establish absence from older Node contexts. Keep Trial assessment and catalogue identity; `~/.pi` is retained data, not an uninstall target or authority to delete it.
- **Paperclip:** recommend neither, with medium confidence. [KB-DOTFILES-UE-099](/Users/krisbrown/.local/share/chezmoi/docs/roadmap/KB-DOTFILES-UE-099-resource-subject-links-and-service-paths.md) records it as deliberately deselected, stopped and manual. Actual software presence was not probed through a service or provider in this run. If found, report the candidate; service-resource retirement and data cleanup retain their own contracts.
- **Paperclip agent configuration:** recommend neither alongside Paperclip. This is a custom `desired-state` declaration, not a separately installed native application. Its unselected state warrants review of any remaining managed configuration; it does not create a software uninstall target or permission to delete agents. No custom provider was invoked. This is a type boundary the rule can cover, not a need for a leave-alone marker.
- **DaVinci Resolve:** keep sol-only selection, supported by the alignment record's App Store route and studio purpose. Terra's declared app path is absent, so its unselected state has no observed installation to remove. A future matching terra installation would be a candidate.
- **Delta:** keep terra-only selection. It is Zed's agent workspace, not the Git diff pager, and its local app exists. The independent review corrected that identity and confirmed laptop selection. If present unselected on sol, it is a candidate there.
- **Orca:** keep terra-only selection. The current rationale explicitly scopes its trial to the laptop, and the local app and cask receipt exist. Trial assessment alone neither extends it to sol nor exempts an unselected sol installation from candidacy.
- **Prime Video:** recommend both, with medium confidence. Terra's keep decision is already selected. The alignment record's C7a also says to keep it if present on sol, while current selection remains laptop-only. Selecting sol would reconcile that earlier keep instruction with the new rule, but Kris should confirm an ongoing sol requirement before the configuration is changed; its present sol installation is unverified.
- **Webex:** keep terra-only selection. Kris's 24 October keep decision and artifact-only declaration explicitly cover laptop meetings. There is no equivalent sol keep decision in the reviewed evidence; an unselected sol installation is a candidate if found.

For completeness, the three retained `retired-application` identities, **Adobe Photoshop**, **Adobe Lightroom Classic** and **Adobe Creative Cloud**, are not profile-selectable `tool` entries and are outside the 199-tool selection subtraction. Their existing disposition is removal candidates on both, high confidence from the alignment record's explicit owner decision. That record reports terra's applications and traces absent after cleanup; sol's historical installations and outstanding cleanup remain unverified. These observation-only identities preserve evidence and do not execute an uninstall. Other software on the alignment removal list that has no retained catalogue entry is not a recognised-but-unselected catalogue entry and is outside this list.

### Settling and permission

"Once we're comfortable" needs an owner-chosen policy rather than an inferred amount of time installed. Report candidates when an installation is observed without host selection; an optional owner-set not-before date may hold action, alongside the existing attended removal approval. A date passing does not itself grant permission. If a grace period is preferred, planning must define its start event per host, persistence across runs, reset conditions after reselection or intent changes, and how unavailable observations affect it. Retaining the catalogue entry until confidence is high that all hosts have converged is separate from delaying the first uninstall. Retention is recommended so reappearance remains detectable; any later deletion of that identity is an explicit review decision. No default period or unattended standing removal authority is agreed here.

### Adapter and evidence boundaries

Keep software uninstall, managed-resource retirement and user-data cleanup distinct. Delegate supported native uninstalls to the existing manager contract, retaining dependency refusals, exact identity matching, preview, reobservation, operation locks and independent failures. Unsupported, shared, protected, mismatched or uncertain identities can still be candidates when present and unselected, but execution remains blocked or review-only; never invent a deletion path, force, zap or new privilege grant. A surviving data directory is separate evidence whose deletion requires its own decision. A system application can be selected without any materialisation capability; an inability to uninstall it would constrain execution, not introduce another desired-state marker.

A host reporting confirmed absence is healthy for an unselected tool; a later matching installation is a candidate again. Missing managers, inaccessible locations and ambiguous identities remain unknown or unavailable rather than successful absence. Retired tools and private absence/review evidence stay outside public export under the existing disclosure contract.

### First shaping deliverable

Before adoption or implementation, settle host/profile identity and the two resolved selection outcomes with fixtures for Pi, selected observation-only Safari and helpers, and terra-selected/sol-unselected software. Specify the retained-identity conflict rule, optional settling policy, compatibility of existing `remove` and `retired-application` declarations, private observation/reporting and the exact approved removal entry point. Build and verify only against synthetic packages and isolated managers; never reproduce retirement against the working machine. Existing chezmoi alignment and review work owns the personal selection corrections and attended cleanup. The recommendations above are for Kris's review, not catalogue edits made by this amendment.
