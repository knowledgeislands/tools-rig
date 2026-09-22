---
id: RIG-MIG-007
title: Curate personal rig
area: MIG
theme: migration
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: 9bb2a753281f94a2e91ff65ca71995a3db787b2e
created_at: 2026-09-21T23:35:16Z
updated_at: 2026-09-22T04:38:19Z
---

## Goal

The live and chezmoi-source personal Rig should exercise the accepted human configuration, profile, private-resource, skill, and publication model with meaningful rationale and no residual competing authority.

## Context

The active configuration and chezmoi source currently match, and former operation surfaces are absent. The default membership is nevertheless expressed as very long central arrays, 87 application rationales repeat essentially the same placeholder, all 35 settings use generic rationale, and no publication is configured for `rig.midnight.ninja`. Global skills have mixed source authority, while stable port intent is undeclared.

## Boundary

Portable schema, lifecycle, observation, and adapter behaviour must land in tools-rig before personal data adopts it. This record does not invent personal rationale, publish private values, apply chezmoi without explicit approval, or make tools-rig authoritative for the dotfiles repository.

## Current state

The live Rig configuration and chezmoi source agree and former operation scripts are absent, but profile membership remains a very long central array, rationale text is mostly generic, profile configuration is not isolated for discovery, no public view or `rig.midnight.ninja` publication is declared, and stable ports and global skills are outside the model.

## Steps

- [x] Reconcile the live configuration and chezmoi source immediately before editing and preserve unrelated dotfiles changes.
- [x] Migrate declaration membership to the accepted implicit-default item model, create a descriptive profile fragment, and remove redundant bootstrap-profile configuration.
- [x] Create an explicit non-appliable public view and publication declaration for `rig.midnight.ninja`, reviewing the allow-list against all private resources and observed state.
- [x] Add stable port and trusted global-skill declarations only after `RIG-CORE-016` and `RIG-CORE-017` land, preserving each native owner's authority.
- [x] Curate purposes and rationales only where the user's intent is known; leave clearly marked reviewable text rather than fabricate preferences.
- [x] Validate the source and rendered configuration, run `chezmoi diff`, and do not run `chezmoi apply` without explicit current approval.

## Files touched

Expected scope is the chezmoi source under `~/.local/share/chezmoi/dot_config/rig/` and its rendered `~/.config/rig/` projection. Portable repository files change only if migration exposes a separately captured defect.

## Verify

Run Rig configuration validation, `show`, `doctor`, `status`, dry-run apply, public export with disclosure assertions, byte comparison of intended rendered files, dotfiles repository checks, and `chezmoi diff`. Report any unapplied source-to-home changes explicitly.

## Dependencies / blocks

Execute after `RIG-CORE-016`, `RIG-CORE-017`, `RIG-CORE-018`, and `RIG-CORE-019` have delivered portable contracts. Website deployment and actual publication remain outside this record.

## Delegation

Portable-to-personal schema mapping and public-projection privacy review may be prepared independently. One coordinator owns the cross-repository edit set, unrelated-change preservation, chezmoi diff, and decision not to apply without current authority.

## Documentation impact

### Decision Records

No tools-rig decision change is expected; personal configuration consumes already accepted contracts.

### Specifications

No new portable requirement is expected; any migration-discovered behavioural defect must be captured separately.

### Guides

Use the resulting personal configuration only as private validation evidence, not as public example data unless explicitly sanitised.

### Roadmap

Any unknown personal rationale remains an explicit user-review follow-up rather than being invented or silently dropped.

## Review

### Delivered

Delivered the approved personal Rig migration from tools-rig baseline `9bb2a753281f94a2e91ff65ca71995a3db787b2e` in dotfiles commit `ed15c68f4fb6b403a6db686a5d55317eced2069e`. The change edits only chezmoi sources and their source-level test; it does not apply home targets, publish the public projection, deploy the website, or push either repository.

### Summary of changes

- Replaced the central default-profile member arrays with item-owned membership: ordinary declarations use implicit default membership, while `chatgpt-current`, `rekordbox`, and `tigervnc` retain explicit `profiles = []` catalogue-only intent.
- Moved complete and public view declarations into discoverable `90-profiles.toml`, removed the redundant `bootstrap-profile`, and added the trusted `midnight-ninja` publisher boundary plus `rig.midnight.ninja` publication.
- Added private loopback port intent for required MCP bridge port 3333 and on-demand Headroom port 8787. Port 1675 remains undeclared because no catalogue owner or stable intent was established.
- Added the npm-managed Skills CLI tool and the one reviewed global skill with known provenance, Caveman. The declaration uses the native `skills` executable contract and never falls back to `npx`.
- Converted generic application and macOS-setting rationales into explicit `Review needed` text. Only the known Rig, profile, publication, port, and skill intent was curated; no personal preference was invented.
- Updated the dotfiles catalogue test for implicit membership, excluded items, ports, skill authority, and the public publication boundary.

### Verification

- `node --test tests/*.test.mjs` in the dotfiles repository: 33 passed, 0 failed.
- `chezmoi cat` byte comparison for all nine rendered Rig files: matched their source content.
- `chezmoi diff`: passed and reported only the seven pending `.config/rig/**` target changes.
- `rig show` for the default and public profiles: passed; the public view contains only `rig` and `skill:caveman`.
- `rig export midnight-ninja`: passed with publication format 2; disclosure checks found no private ports, provider authority, machine paths, native install locators, or observed state.
- `rig apply --profile public --dry-run`: rejected the view as non-appliable, as required.
- `rig status --profile public` and `rig doctor --profile public`: read-only validation completed and reported the expected unavailable Skills CLI executable.
- `rig apply --dry-run`: completed the full plan without mutation and returned 1 because the declared Skills CLI is not installed yet; it planned `tool.skills-cli` and reported `skill.caveman` preflight unavailable.

### Outstanding concerns

- The seven rendered Rig target changes remain unapplied pending explicit review and approval.
- The `skills` executable is not currently installed, so Caveman remains honestly unavailable to Rig until the native manager is materialised.
- The custom `midnight-ninja` publisher executable is intentionally absent; export is available, but publication and website deployment remain outside this item.
- Eighty-six application and thirty-five macOS-setting `Review needed` rationales remain for personal curation.

### Post-change review

The source migration exercises every accepted portable contract without widening Rig into dotfiles authority or leaking private machine state. Implicit default membership preserves the former 99-tool selection, adds the explicitly managed Skills CLI as the hundredth default tool, and retains the three prior catalogue-only tools. The public projection is deliberately narrow and non-appliable. The remaining unavailable native executables and unapplied target diff are visible operational states rather than hidden migration defects. The item is ready for human review.

### Mini recap

Personal configuration now demonstrates human-oriented profiles, private ports, a reviewed user skill, and a safe public data projection. Verification is green at the source and export boundaries; live application, skill installation, publisher delivery, and personal rationale review remain explicit follow-up decisions.

## Discussion

### Locked migration boundary

The migration consumes portable behaviour after it lands. It may edit the dotfiles source and review `chezmoi diff`, but applying rendered changes, publishing the public projection, or deploying the website requires explicit current authority at the point of mutation.

### Configuration migration

Once the portable model is accepted, move profile membership beside each declaration, leaving unqualified items in the default profile and using explicit inheritance for other complete machine profiles. Keep public and minimal views explicit. Separate profile declarations into a discoverable fragment and remove redundant bootstrap selection where fallback is sufficient.

### Meaningful intent

Curate purposes and rationales through human review rather than mechanical rewriting. Add stable ports and user skills only after their native ownership and privacy contracts exist.

### Public projection

Define a deliberate non-appliable public view and publication for `rig.midnight.ninja`. Review its data allow-list independently of installation and ensure private resources, runtime projections, machine paths, and observed state remain excluded.

### Cross-repository authority

The dotfiles repository owns its source edits and `chezmoi diff` review. Any implementation should use a governed trade or explicitly authorised multi-repository delivery rather than silently changing another repository from this record.
