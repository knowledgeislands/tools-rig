---
id: KI-TOOL-RIG-CORE-042
area: CORE
title: Profile-filtered Dock items
theme: rig
kind: deliver
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 30fbebf9929cbb1be500a2023ea463b8ec5a01ca
created_at: 2026-10-09T15:03:37Z
updated_at: 2026-10-18T04:10:00Z
---

# KI-TOOL-RIG-CORE-042: Profile-Filtered Dock Items

## Goal

One Dock layout declares a single ordered list of items for every machine, and each resolved profile shows only the items it selects, in the same relative order. An app excluded by the resolved profile leaves no gap or missing-path preflight failure; a selected app keeps its relative place and remains an observable error if its path is missing.

## Context

Kris asked for this on 2026-10-09 while splitting his Rig into `core`, `laptop` and `studio` profiles (mac-studio-bootstrap thread, Decision 13, answers 6 and 7): "identical on both except where an app is not on both, but even then the place where it would be is consistent - so one order but items might be machine specific". The consumer is [KB-DOTFILES-UE-075](https://github.com/krisb/dotfiles/blob/4817b1947e10e047413288464280061a141de7ab/docs/roadmap/KB-DOTFILES-UE-075-sol-tailscale-daemon-exception.md) in the chezmoi source, which owns the profile split and the personal Dock declaration.

What Rig does today:

- **One Dock per profile.** [RIG-ORCH-027](../specs/orchestration.md) rejects more than one selected Dock layout for the same provider, so a machine profile cannot inherit a shared Dock and add its own items.
- **Items are plain path tables.** [RIG-CONF-018](../specs/configuration.md) gives `[dock-item.ID]` only `kind`, `path` and folder attributes. Items carry no membership, so every listed item is in every profile that selects the layout.
- **Preflight fails on a missing path.** `rig_macos_resource_preflight` fails the whole Dock step when any declared item path is absent, so a shared list naming a studio-only app breaks the laptop's Dock apply, and the reverse.

On 14 October 2026 Kris found that Mac Studio `sol` has no Zed on its Dock. A read-only check (`sol-dock-zed` run in the mac-studio-bootstrap thread) found Zed installed and selected by `core`, but the personal `[dock.workstation]` layout selected only by `laptop`, a deliberate choice of 9 October while this record was unbuilt. Rig therefore leaves `sol`'s hand-made Dock alone and reports nothing wrong, and `rig apply` on `sol` cannot add Zed. Kris then set the ordering rule for the shared Dock: "same order as the laptop, filtered by what each profile selects". That rule is exactly this record's model: the laptop's declared `items` order is the one list, and each machine's resolved profile filters it.

The workaround without this record is a chezmoi template that renders one Dock layout per machine profile from a master list. It works, but it duplicates membership (an app's tool already says which profiles want it), turns the Dock fragment into a template the catalogue tests must render, and every new machine profile needs a template change.

## Boundary

- **In:** an optional link from a Dock item to the membership that decides whether it shows; filtering a layout's items by the resolved profile while keeping declared order; `rig show`, `rig status`, `rig doctor`, `rig apply --dry-run` and `rig apply` agreeing on the filtered list; validation and specification changes; tests.
- **Out:** choosing the personal Dock order or memberships (KB-DOTFILES-UE-075); filtering by what is installed rather than what is declared, which would make the Dock depend on observed state; removing apps.

## Current state

Delivered locally to Awaiting review on 18 October 2026 by the tools-burndown run, from baseline `30fbebf`, against fixtures only; see Review. The planning-time source inspection at `bbe1d86` that grounded this plan is superseded by the delivered code. The acceptance check on `sol` has not run.

## Steps

- [x] After Kris approves this plan, re-read authority and source, establish the immutable implementation baseline through `ki-implement`, and retain the agreed boundary. Stop for review if source drift changes the dependency or preflight assumptions below.
- [x] Extend scalar field recognition, TOML mapping and `rig_validate_dock_item` for optional `tool = "ID"`; require a valid existing tool identifier even on an excluded or unused item. Keep kind/path and folder validation unchanged, and keep item-owned `profiles` unsupported.
- [x] Add one shared Dock-item resolution/projection helper over the completed profile/platform tool selection. Walk declared `items` in source order; include unlinked items and linked items whose tool is selected, including tools selected transitively. Retain excluded IDs and reasons separately. Do not mutate authored items, select tools from links, or use filesystem/provider state for membership. Reset per-command state and protect saved values from `RIG_VALUE` clobbering.
- [x] Route expected paths, folder-attribute observation, preflight, native add order and dry-run resource fields through that same included-item projection. An empty included list is valid: comparison expects an empty Dock, preflight checks no blank path, and fixture apply removes all items with no add calls. Preserve the one-selected-layout-per-provider conflict rule even when a layout filters to empty.
- [x] Add profile-aware `rig show dock:ID --profile NAME` in text and JSON, using the default resolved profile when the Dock target has no profile option. Display declared positions, compact included positions, linked tool and exclusion reasons; an unselected target layout is explained as unselected without entering execution. Preserve other target-option restrictions. Share the item selection/exclusion details with resolved-profile show, status, doctor and apply/dry-run reports, while retaining their existing envelopes and state/exit semantics.
- [x] Preserve selected missing-path failure before any Dock mutation, with `dock-item-path-missing` identifying the item/path in apply and dry-run. Status/doctor must expose missing selected path evidence as unhealthy rather than imply agreement from an icon alone. Excluded missing paths and folder attributes cause no health failure. Keep explicit `requires`/`depends-on` blocking and existing tool-before-resource sequencing; do not add implicit tool prerequisites.
- [x] Add isolated public-command Bats coverage with shared catalogue/native fixtures and exact invocation assertions for the verification cases below; retain existing Dock path, URL, order, folder-attribute and snapshot regressions.
- [x] Align the existing specifications, operational/profile/command guides, command-local help, manual and active changelog; assemble `bin/rig` from authored modules, then run the permitted offline developer gate and assemble an honest implementation review packet. Native-provider smoke and live apply remain outside this plan's execution authority.

## Files touched

This preparation changes only this canonical roadmap record. Expected later delivery scope:

- [Runtime help and command metadata](../../src/rig/00-runtime.bash), [configuration](../../src/rig/10-configuration.bash), [Dock orchestration](../../src/rig/20-orchestration.bash), [observation reports](../../src/rig/22-observation.bash), [apply projection](../../src/rig/23-application.bash), [show/explain](../../src/rig/30-commands.bash), and assembled [executable](../../bin/rig). Keep the authored version unchanged unless separately required; add no runtime dependency.
- New `tests/rig-dock-profiles.bats`; existing [macOS tests](../../tests/rig-macos.bats), [Dock observation tests](../../tests/rig-dock-observation.bats), [profile-authority tests](../../tests/rig-profile-authority.bats), and [command-surface tests](../../tests/rig-cli-surface.bats) for affected regressions. Reuse [test isolation](../../tests/helpers/isolate.bash) without changing its containment contract.
- [Configuration](../specs/configuration.md), [orchestration](../specs/orchestration.md) and [state](../specs/state.md) specifications; [operational resources](../guides/user/operational-resources.md), [profiles](../guides/user/profiles.md) and [commands](../guides/user/commands.md) guides; [README command overview](../../README.md), [manual](../../man/rig.1) and [changelog](../../CHANGELOG.md) where affected.

## Verify

These are planned delivery checks, not results of this planning unit. Each Bats `setup` starts with `rig_test_isolate`; use only test-owned HOME/XDG/Rig roots, applications and state, exact native/provider fakes, and the inert launchd domain. Assert native logs as well as output so a real preference write cannot masquerade as a contained result.

- **Membership and order:** declare `items = ["system", "shared", "laptop-only", "studio-only", "downloads"]`. Leave `system` and `downloads` unlinked; link the other items to tools with matching IDs. Select `shared` in `core`, with `laptop` and `studio` inheriting `core` and selecting their respective extra tool. For both central profiles and item-owned tool membership, assert laptop includes `[system, shared, laptop-only, downloads]` and excludes `studio-only`; studio includes `[system, shared, studio-only, downloads]` and excludes `laptop-only`. Both use compact positions 1–4 and retain declared positions for explanation; transitive selected tools qualify in a separate fixture. Changing catalogue tool sorting never reorders Dock items, and legacy items without links preserve their complete original list.
- **Platform and validation:** a Linux-only linked tool is excluded from a macOS Dock with a platform reason; a supported tool absent from the resolved selection gets a profile-selection reason. Selecting a macOS Dock on Linux still follows existing resource-platform refusal. Unknown, empty, malformed or non-string links fail validation before any native invocation, even if the item would be excluded. `dock-item.profiles` remains rejected.
- **Command parity:** invoke show (target/default/explicit profile and resolved profile, text/JSON), status (text/JSON), doctor, dry-run and fake apply on the same fixture. Assert identical included IDs/order and excluded IDs/reasons across reports; native add calls match included expanded paths exactly. Read-only commands and dry-run log no defaults write/delete, dockutil add/remove or killall call.
- **Observation and failure:** an exact filtered Dock is `present`; genuine order or included folder-attribute drift is unhealthy, and excluded folder attributes are never queried. A selected missing app remains included, produces visible missing-path failure in dry-run/apply and unhealthy status/doctor evidence, and performs no Dock mutation. A missing excluded app succeeds. An all-excluded layout observes/applies the empty sequence without checking an empty path. Two selected layouts still conflict before native invocation.
- **Dependency regression:** links never expand membership or prerequisites; all-scope fake apply retains tools-before-Dock order, while resources-only apply never installs linked tools. Explicit requirements still select transitive tools and suppress dependent Dock mutation on failure. A catalogue-only linked tool with an existing path is included without an implicit blocker. Initial missing-path preflight remains an error even if a selected tool's fake install could later create the app; this plan does not move preflight.

Run focused fixtures with stdin closed:

```sh
bats tests/rig-dock-profiles.bats tests/rig-macos.bats tests/rig-dock-observation.bats tests/rig-profile-authority.bats tests/rig-cli-surface.bats </dev/null
```

Then use [Develop Rig's single complete command list](../guides/developer/README.md#verify-the-repository): full repository audit, ShellCheck, Bash syntax, assembly drift, fixture benchmark, complete isolated Bats suite, mandoc and diff checks. Use the two-second benchmark budget for resolution/query changes and inspect rendered manual changes. Every `ki` call in this run uses the authorised config-restoring wrapper. Do not run native-provider smoke, live macOS apply, sol or SSH operations under this grant; report that withheld gate explicitly rather than claiming a complete operational check. No planning audit or existing regression run proves the unimplemented feature.

### Acceptance check on sol

Kris asked on 14 October 2026 that this record, not a manual Dock change, be what puts Zed on `sol`'s Dock: "use it to verify rather than manual change". This check is therefore part of acceptance, after fixture-backed delivery reaches Awaiting review. It is not part of `ki-implement`'s authority, which still excludes any live apply, and it needs three things outside this repository:

1. **The personal declaration.** The chezmoi source's `dot_config/rig/conf.d/private_40-macos.toml` moves `[dock.workstation]` from `profiles = ["laptop"]` to `core`, keeps the laptop's current `items` order, and links each machine-specific item to its tool with `tool = "ID"`. On 14 October 2026 the resolved selections were: Zed, NordVPN, ChatGPT, LaunchControl, draw.io and Telegram in both `laptop` and `studio`; Delta, RendApp and The Tower in `laptop` only; Adobe Lightroom Classic in `studio` only and absent from the laptop's list.
2. **An owner decision on placement** of any studio-only app with no laptop position, such as Lightroom Classic, which `sol`'s hand-made Dock carries today.
3. **Kris's approval of the live run** on `sol`: `rig apply` with the Dock in scope is a live macOS change, and Kris, or an agent Kris authorises for that run, performs it.

The check, on `sol` with the default `studio` profile:

- Before the apply, `rig show dock:workstation` lists the filtered items with Zed included, and `rig doctor` reports the Dock layout as drifted rather than saying nothing.
- `rig apply` (or the Dock resource alone, if the command offers that scope) changes the Dock and reports success, with no manual Dock edit before or after.
- Afterwards `defaults read com.apple.dock persistent-apps` or `dockutil --list` shows Zed in its laptop-relative place, between Claude and Visual Studio Code, with Delta, RendApp and The Tower absent; `rig status` and `rig doctor` report the Dock `present`.
- On `terra`, `rig doctor` still reports the laptop Dock `present` with its full list, so the shared layout did not change the laptop.

If any step fails, the record returns to `in-progress` through `ki-accept`'s failed-review route; nobody fixes `sol`'s Dock by hand to pass it.

## Dependencies / blocks

The existing `blocks: []` and `blocked_by: []` remain unchanged. Local portable implementation has no dependency on the Studio restart, personal catalogue/order edits or the chezmoi consumer. The acceptance check on `sol` does depend on the chezmoi declaration change and on Kris's approval of the live apply, as that section states. Decision 15 satisfies the named Hold release condition; owner approval of this concrete plan is the remaining readiness gate. The published principal/mac-studio checkpoints still describe the earlier Hold and are owner-owned; this unit records the later exact approval here and does not mutate either checkpoint.

## Documentation impact

### Decision Records

No new Decision Record is proposed: this is a bounded extension of existing profile and resource contracts. Keep the reviewed linkage/prerequisite rationale here until accepted behaviour is carried by the existing specifications; a wider dependency/preflight redesign would require renewed owner review.

### Specifications

Extend RIG-CONF-018 with tool-link validation, RIG-STATE-021 with filtered projection and missing-selected-path diagnostics, and the existing Dock observation contract RIG-STATE-036 with filtered paths/attributes. Preserve RIG-ORCH-027's layout-level conflict rule; document filtering after final tool selection, not as a way to merge layouts or bypass conflicts. Keep RIG-ORCH-020's explicit tool prerequisites and RIG-ORCH-030's resource sequencing unchanged. Preserve existing requirement IDs and truthful conformance/evidence; do not claim proposed behaviour already conforms.

### Guides

Explain the optional tool link, inherited/platform membership, stable relative order, omitted-item reasons, profile-aware Dock show and selected missing-path error in existing user guides. Align help, manual, emitted completion metadata and changelog where the show option combination/output changes. Use synthetic examples; personal configuration stays with its owner.

### Roadmap

Kris approved the plan on 12 October 2026, so the record became Ready at Next; Kris prioritised it on 14 October 2026, so it became Ready at Now. Delivered to Awaiting review on 18 October 2026; no acceptance, prune or release has been performed. The personal declaration change the acceptance check needs belongs to the chezmoi source; its earlier owner, KB-DOTFILES-UE-075, is no longer an open record there, so that change needs a chezmoi record of its own before acceptance.

## Review

### Delivered

Delivered locally against fixtures only, from baseline `30fbebf`. No native-provider smoke, live `rig apply`, `sol` or SSH operation ran, and nothing was accepted or released.

### Change Summary

- **Configuration** (`10-configuration.bash`): `[dock-item.ID]` accepts an optional string `tool`, validated as an existing tool even when the item would be excluded. Item `profiles` stays rejected.
- **Resolution** (`20-orchestration.bash`): `rig_dock_resolve_items` walks a layout's `items` in declared order over the completed tool selection. Unlinked items are always included; a linked item is included only when its tool is selected, otherwise excluded with reason `profile` or `platform`. It never selects tools or adds prerequisites.
- **One projection everywhere:** expected paths, folder-attribute observation, preflight, `dockutil` add order, dry-run resource fields (`item=` and `excluded-item=ID (reason)`), and the resolved-profile `show` table (`4 of 5`) and JSON (`items`, `excluded_items`) all use it. An all-excluded layout applies an empty Dock.
- **Observation:** an included item whose path does not exist makes the layout `drifted` with `dock-item-path-missing:ITEM` before order is compared, so status and doctor no longer imply agreement. An excluded item's path and attributes are never checked.
- **Show** (`30-commands.bash`): `rig show dock:ID [--profile NAME]` accepts `--profile` for a Dock target only and adds `dock-profile`, `dock-platform`, `dock-selected`, and per item `tool`, compact `position` or `excluded`. Without `--profile` it uses the default profile when the layout supports the platform.
- **Tests:** new `tests/rig-dock-profiles.bats`, 11 cases, covering every Verify bullet that fixtures can reach.
- **Documentation:** RIG-CONF-018, RIG-STATE-021 and RIG-STATE-036; operational-resources, profiles and commands guides; manual; changelog.

### Verification

The complete local gate in [Develop Rig](../guides/developer/README.md#verify-the-repository) passes: audit (the existing HOOK-1 warning only), ShellCheck, Bash syntax, assembly drift, the fixture benchmark within budget, mandoc and diff checks. All 563 Bats tests pass. The focused command in Verify passes.

Withheld by authority: `scripts/smoke-native-providers`, any live apply, and the acceptance check on `sol`.

### Outstanding concerns

- **Deviation, provisional.** The plan asks status and doctor to show missing selected-path evidence. Delivered as an observation detail naming the item, before the order comparison, for linked and unlinked included items alike; there is no separate per-item evidence list in status JSON.
- **Doctor and status envelopes** carry the filtered result through the existing observation state and detail; they do not list included and excluded items. `show dock:ID` and dry-run do.
- **Acceptance on `sol`** needs the chezmoi declaration change, which now needs a chezmoi record of its own (see Roadmap), Kris's placement decision for studio-only apps, and Kris's approval of the live run.

### Post-change review

Existing Dock regressions (paths, URLs, order, folder attributes, snapshots, the contiguous `show` item lines) pass unchanged. Targeted apply narrows the plan but filters against the whole resolved profile, so a targeted Dock keeps every selected app.

### Mini recap

One Dock layout can now serve laptop and studio: each machine shows only the apps its profile selects, in the shared order.

## Discussion

### Proposed contract for owner review

Recommend optional `tool = "ID"` on a Dock item, with membership determined by the final resolved profile/platform tool set and order determined only by the layout's declared `items`. Unlinked system apps/folders remain included. Do not add item-owned profiles: they duplicate app membership and introduce omitted-array policy without a demonstrated need. The link does not infer an application path from tool installation metadata.

Exclusion reporting names the item, linked tool and either unsupported platform or absence from resolved profile selection, with platform exclusion taking precedence. Preserve original declared positions for explanation and compact included positions for execution. Filesystem observations affect health and preflight only; they never decide inclusion.

### Prerequisites and first-run behaviour

Recommend **filter/order-only linkage, with no automatic prerequisites**. Current resources already run after the tool phase. Turning every linked tool into `requires` would defeat profile exclusion by selecting the whole shared list; even conditional implicit dependencies add blocking semantics to catalogue-only applications. Owners who need installation/failure dependencies can continue declaring explicit layout `requires`, understanding that those tools become selected on every profile selecting that layout. Linking alone does not promise a successful install-before-Dock first run because current resource preflight runs before installation. A selected missing path must stay an observable error, and changing that preflight order is out of this bounded plan.

### Approval boundary

Kris should approve the tool-link-only schema, final-selection membership, filter/order-only dependency choice and the verification contract above before this record becomes Ready. That later approval permits local fixture-backed delivery, not personal Dock/order/configuration changes or live provider/host operations. If automatic conditional prerequisites or item-owned profiles are preferred, revise this draft before implementation.

### Adoption and hold approval

Kris approved adoption in tools-burndown Decision 11 (12 October 2026): "I approve your recommendation, I can review it further later". That approval adopted the record as Deliver / draft on Hold, pending explicit local-planning release through Rig mac-studio-bootstrap. Adoption itself granted no planning, implementation, acceptance or release authority.

Kris explicitly released this record from Hold in tools-burndown Decision 15 (12 October 2026): "lets get this done, no need to park it". Under `ki-next`, the destination is Deliver / draft Next, with the hold mapping removed and existing classification and dependencies preserved. This supersedes the Decision 11 planning hold only: prepare a reviewable canonical local plan under `ki-plan`, then obtain explicit plan approval before Ready or implementation. It grants no personal Dock/configuration change, macOS apply, sol operation, acceptance, pruning, or release.

### Plan approval

On 12 October 2026 Kris approved this plan as written (state-of-play thread, Decision 147): the tool-link-only schema, final-selection membership, the filter/order-only dependency choice and the verification contract above. The record moves to `ready` at Next. The approval permits local, fixture-backed delivery through `ki-implement` only; it grants no personal Dock, order or configuration change, no macOS apply, no `sol` or other live host operation, and no acceptance, pruning or release.

### Promotion and owner rule

On 14 October 2026 Kris answered two queries from the mac-studio-bootstrap thread (decision 70 in its decisions log): "SOL-DOCK-ZED - prioritise KI-TOOL-RIG-CORE-042, use it to verify rather than manual change" and "SOL-DOCK-EXTRAS - same order as the laptop, filtered by what each profile selects". Under `ki-next` the record moves from Next to Now with its Ready status, plan and approvals unchanged. The ordering rule confirms the approved contract rather than changing it, and the acceptance check on `sol` adds a post-delivery verification step outside `ki-implement`'s fixture-only grant, so no replan is needed. These answers add no authority beyond the existing Ready approval: no personal configuration change and no live apply.
