---
id: RIG-CLI-024
area: CLI
title: Simplify intent command surface
theme: cli
horizon: now
status: in-progress
blocks: []
blocked_by: []
baseline_ref: 47e993b452492ea4afd6d69343223669279d02da
created_at: 2026-09-30T21:35:00Z
updated_at: 2026-09-30T21:58:02Z
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

- [x] Remove Homebrew Bundle and autoupdate orchestration, reject retired configuration with migration guidance, and preserve declaration-scoped upgrades without unknown-package deletion.
- [x] Incorporate declared prerequisite staging into apply while preserving complete preflight, explicit dependency closure, targeted scope, dry-run and resource receipts.
- [x] Add non-overwriting init and selective Homebrew capture with read-only discovery, explicit human metadata, global declaration deduplication and reviewable additive TOML proposals.
- [x] Consolidate show/list/explain into show with selected, catalogue and item views; fold diag into doctor verbose; rename update to upgrade; retire bootstrap, run and maintain without aliases.
- [x] Align specifications, decisions, help, completion, manual, guides, examples and test fixtures; document migration without changing chezmoi.
- [ ] Independently review the integrated change, run the full repository gate and commit a complete acceptance packet. Implementation review and Rig checks are complete; final readiness is held by the external Agora audit failure described below.

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

## Review

### Delivered

Implemented the approved ten-command breaking cutover, Rig-owned Homebrew package intent, declared prerequisite staging, safe configuration initialization and reviewed Homebrew adoption. The implementation and this review packet are recorded together against baseline `47e993b452492ea4afd6d69343223669279d02da`; the batch ledger records the resulting delivery commit separately.

### Change Summary

Removed Bundle, autoupdate and catch-all maintenance execution; consolidated informational and diagnostic commands; preserved the internal provider update capability behind public upgrade. Added the authored adoption module while retaining one assembled Bash 3.2 executable. Help, completion, manual, specifications, decisions, guides and isolated fixtures follow the same contract. The [migration guide](../guides/user/migrating-command-surface.md) distinguishes the unreleased checkout from installed releases and identifies host-owned configuration and scheduled commands requiring later migration.

### Verification

Rig verification passed on 2026-09-30: ShellCheck, Bash syntax checks, deterministic assembly check, benchmarks, read-only native-provider smoke, all 311 Bats tests and manual lint. The final Bats and manual-lint recheck returned exit status zero; `RIG_TEST_PYTHON=/opt/homebrew/opt/python@3.14/bin/python3.14` enabled both optional TOML parser assertions, with no skipped tests. Tests ran with stdin redirected from `/dev/null` and isolated host command stubs.

Repository audit passed before implementation and during the aggregate gate, but the final documentation recheck failed with four Agora findings: the unchanged member declaration is now interpreted as an invalid owner declaration, and the linked skill's generated rubric no longer matches its catalogue. Read-only inspection confirmed uncommitted Agora skill, standard and validator changes in the external `ki-agentic-harness` checkout; neither `.ki.toml` nor the linked skill was changed by this delivery. The other twenty selected skill audits pass. The required overall audit is therefore currently failing, not waived.

Benchmark observations were two seconds each for item, selected and whole-catalogue queries against a five-second ceiling, and six seconds for state observation against an eight-second ceiling. Native smoke covered Homebrew, uv, mise, npm, chezmoi and mas without mutation. Focused regressions cover failed preflight cleanup, targeted manager closure, retired configuration and commands, capture deduplication, ambiguous identities, central membership, native inventory failures, exclusive output creation and active-configuration path aliases.

### Outstanding concerns

Formal readiness is blocked by the external Agora governance transition, not by a failing Rig test. Leave this record in-progress and the batch parked until the shared governance owner settles that change and the required repository audit passes. Do not repair another repository, bypass its validator or silently migrate Rig's membership declaration under this CLI authority.

Capture deliberately covers Homebrew formulae installed on request and installed casks only; proposals require manual review and adoption. Central-selection configurations support discovery but reject full proposals with migration guidance rather than mixing membership models. This is a breaking, unreleased cutover: host configuration and scheduled wrappers must be migrated before using it against the workstation. Chezmoi changes, release, human acceptance and pruning remain outside this delivery. The live operational display remains with RIG-CLI-023.

### Post-change review

Workers independently reviewed other implementation lanes. Review found and corrected central-membership proposal handling, operational capture failure exit status, and deferred-provider flags surviving a failed sourced apply preflight. Regression tests cover each finding. The coordinator integrated documentation and assembly, reviewed staged paths and ran the aggregate gate. No live apply or upgrade was used; no workstation configuration or chezmoi source was changed.

### Mini recap

The agreed command and package-authority simplification is implemented and independently reviewed, with reproducible Rig verification and an explicit migration route. The final readiness transition remains parked on the external Agora audit; repeat that gate after its owner resolves the governance transition, then complete the final step and advance to awaiting-review. Unrelated roadmap work remains unchanged. Nothing was pushed, tagged or released.

## Discussion

### Approved command contract

Public commands are `init`, `show [ITEM]`, `status`, `capture [ITEM...]`, `apply`, `upgrade`, `doctor`, `export`, `help`, and `completion`. Bare show describes the selected setup; `--all` browses the catalogue and category filtering remains available. `--profile` is a selector, not a command's purpose. Doctor verbose includes runtime diagnostic evidence. Removed verbs fail with migration advice; no aliases preserve duplicate surface. Internal provider `update` capability is not renamed. Unattended public upgrade reports use `last-upgrade`; no existing state is deleted.

### Adoption and native authority

Init creates minimal valid configuration without discovering or installing software. First capture coverage is Homebrew formulae explicitly installed on request and installed casks. Bare capture discovers; selected capture requires truthful category, purpose and rationale before emitting valid declarations. Proposals go to stdout or a newly created review file outside active configuration, never overwrite authored files, and require deliberate manual adoption. Unknown software and intent absent on this machine remain untouched. ChezMoi templates, credentials and native execution semantics remain native; its migration is a later decision.

### Imperative operations and compatibility

Remove the public generic run command and catch-all maintain. Native tools retain service restarts, logs and provider housekeeping; apply and upgrade never inherit destructive Bundle cleanup. Reject bootstrap-profile and Homebrew manifest/autoupdate configuration with clear migration guidance. Preserve custom provider trust validation and declarative observation/apply contracts without adding a replacement generic runner.
