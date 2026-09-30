---
id: RIG-CLI-024
area: CLI
title: Simplify intent command surface
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-30T21:35:00Z
updated_at: 2026-09-30T21:35:00Z
---

## Goal

Give Rig one clear command surface for describing, observing and managing a working setup, with Rig configuration owning package intent and no competing Brewfile authority. Make first-time configuration and selective adoption understandable and safe.

## Context

The user approved the proposed command contract, breaking cutover, native-tool ownership of imperative operations and housekeeping, additive reviewed capture, delegated delivery, and verified local commits. Homebrew remains an executor like uv; chezmoi retains its native source authority and any changes to the user's chezmoi repository are explicitly deferred.

## Boundary

Deliver only this CLI and package-authority cutover. Do not change the live workstation, another repository, credentials, releases, tags or remote refs. Do not add runtime dependencies or alter chezmoi source ownership. The separately shaped live display remains with [RIG-CLI-023](RIG-CLI-023-design-live-operational-display.md); unresolved repair, persistence and Dock work are excluded. Human acceptance and pruning follow delivery.

## Current state

Fifteen public verbs overlap. Bootstrap calls apply after manager prerequisites; capture dumps a Brewfile rather than editing Rig intent; package inventory does not cover Homebrew. Bundle cleanup can remove software outside Rig declarations. Authored Bash modules and isolated provider fixtures support a coordinated breaking cutover.

## Steps

- [ ] Remove Homebrew Bundle and autoupdate orchestration, reject retired configuration with migration guidance, and preserve declaration-scoped upgrades without unknown-package deletion.
- [ ] Incorporate declared prerequisite staging into apply while preserving complete preflight, explicit dependency closure, targeted scope, dry-run and resource receipts.
- [ ] Add non-overwriting init and selective Homebrew capture with read-only discovery, explicit human metadata, global declaration deduplication and reviewable additive TOML proposals.
- [ ] Consolidate show/list/explain into show with selected, catalogue and item views; fold diag into doctor verbose; rename update to upgrade; retire bootstrap, run and maintain without aliases.
- [ ] Align specifications, decisions, help, completion, manual, guides, examples and test fixtures; document migration without changing chezmoi.
- [ ] Independently review the integrated change, run the full repository gate and commit a complete acceptance packet.

## Files touched

Authored modules under `src/rig/`, new adoption module, generated `bin/rig`, assembly and benchmark scripts, isolated tests and fixtures, `AGENTS.md`, `README.md`, `CHANGELOG.md`, `man/rig.1`, relevant `docs/specs/`, `docs/decisions/`, `docs/guides/`, this record and the batch ledger. Existing unrelated roadmap records remain unchanged.

## Verify

Run `ki repo audit --repo .`; ShellCheck and Bash syntax checks over the executable, installer, authored modules and scripts; assembly drift check; standalone benchmark; native-provider read-only smoke; `bats tests/ </dev/null`; and `mandoc -T lint man/rig.1`. Focused fixtures must prove command inventory agreement, unknown command rejection, safe init/capture paths, no Bundle invocation, selected prerequisites, target scope, report compatibility decisions and zero provider mutation by discovery.

## Dependencies / blocks

No external or build-order dependency. Keep one canonical delivery item because the command grammar, provider staging and schema change form one cutover and cannot honestly be released as independent interfaces. Execute bounded internal phases and integrate before the aggregate gate. Exclude release and chezmoi migration.

## Delegation

The coordinator owns authority, shared Git writes, documentation, assembly, ancillary test integration and the final gate. GPT-6.1 Sol owns lifecycle/prerequisite modules 21, 23 and 40 plus bootstrap/lifecycle tests; a separate GPT-6.1 Sol worker owns modules 00, 22, 30 and 90 plus public CLI/doctor tests. Astra owns schema module 10, inventory capability in module 20, the new adoption module and adoption tests. Workers use the primary checkout with disjoint ownership, no commits, no live mutation and no full benchmark runs. After integration, an idle worker reviews changes outside its own lane. Stop only on material scope or safety decisions not covered here.

## Documentation impact

### Decision Records

Update living catalogue, provider and execution decisions to distinguish Rig package-selection authority from provider execution and chezmoi source authority.

### Specifications

Record the reduced command grammar, explicit breaking migration, adoption contract, prerequisite staging and declaration-scoped upgrade behavior. Preserve requirement identities and deprecate withdrawn contracts.

### Guides

Update setup, configuration, command reference, providers and unattended examples. Add one actionable migration route, including deferred host-owned scheduled commands and configuration changes.

### Roadmap

This record owns the approved cutover. The existing display and unresolved product-design records remain separate; no release, acceptance or prune is inferred.

## Discussion

### Approved command contract

Public commands are `init`, `show [ITEM]`, `status`, `capture [ITEM...]`, `apply`, `upgrade`, `doctor`, `export`, `help`, and `completion`. Bare show describes the selected setup; `--all` browses the catalogue and category filtering remains available. `--profile` is a selector, not a command's purpose. Doctor verbose includes runtime diagnostic evidence. Removed verbs fail with migration advice; no aliases preserve duplicate surface. Internal provider `update` capability is not renamed. Unattended public upgrade reports use `last-upgrade`; no existing state is deleted.

### Adoption and native authority

Init creates minimal valid configuration without discovering or installing software. First capture coverage is Homebrew formulae explicitly installed on request and installed casks. Bare capture discovers; selected capture requires truthful category, purpose and rationale before emitting valid declarations. Proposals go to stdout or a newly created review file outside active configuration, never overwrite authored files, and require deliberate manual adoption. Unknown software and intent absent on this machine remain untouched. ChezMoi templates, credentials and native execution semantics remain native; its migration is a later decision.

### Imperative operations and compatibility

Remove the public generic run command and catch-all maintain. Native tools retain service restarts, logs and provider housekeeping; apply and upgrade never inherit destructive Bundle cleanup. Reject bootstrap-profile and Homebrew manifest/autoupdate configuration with clear migration guidance. Preserve custom provider trust validation and declarative observation/apply contracts without adding a replacement generic runner.
