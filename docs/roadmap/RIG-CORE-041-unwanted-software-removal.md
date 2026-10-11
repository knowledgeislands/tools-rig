---
id: RIG-CORE-041
area: CORE
title: Unwanted software removal
initiative: rig
kind: deliver
purpose: capability
component: cli
status: done
blocks: []
blocked_by: []
baseline_ref: a6946472afd7e8e382613ee8aa0065bc7dd7729f
created_at: 2026-10-09T06:38:35Z
updated_at: 2026-10-11T11:13:09Z
---

# RIG-CORE-041: Unwanted Software Removal

## Goal

`rig doctor` tells Kris when software is installed that his Rig no longer wants, and keeps three cases apart: (a) items declared for removal that are still present, (b) items installed but not declared or no longer wanted, and (c) declared items that have drifted. Uninstalling stays optional: when Rig removes anything, it does so only when explicitly asked, after a dry run.

## Context

Kris asked for this on 2026-10-09 during the Mac Studio bootstrap (mac-studio-bootstrap thread, Decision 8). Comparing two machines that should carry the same Rig showed software present on one that the declaration no longer selects, and nothing in Rig says so.

What Rig does today:

- **Never uninstalls packages.** Deselection does not retire. [RIG-STATE-024](../specs/state.md) retires only previously receipted services and scheduled jobs the catalogue no longer declares, and forbids removing packages, artefacts, settings, Dock layouts, ports or skills "without a separate explicit cleanup contract". This record would be that contract.
- **Receipt-backed retirement.** [RIG-STATE-020](../specs/state.md) writes `${RIG_STATE_HOME}/resources/PLATFORM.tsv` after a successful reconciliation; RIG-STATE-024 uses it to retire launchd resources removed from the catalogue. No equivalent receipt records which packages Rig installed.
- **Retired applications are observation only.** `[retired-application.ID]` declarations feed `rig status --retired` ([guide](../guides/user/retired-applications.md)). They are not tools or profile members, do not change doctor findings or exit codes, and are not used by apply or upgrade.
- **Unmanaged inventory exists but is opt-in.** `rig status --unmanaged` asks inventory sources about undeclared items: Homebrew formulae installed on request and casks, plus the macOS application baseline ([RIG-STATE-032](../specs/state.md)). [RIG-ORCH-038](../specs/orchestration.md) uses the same inventory for reviewed adoption through `rig capture`. Doctor does not consult it.
- **Doctor has no warning tier in practice.** [The command guide](../guides/user/commands.md) says warnings are currently zero and actionable findings keep failure status, so "installed but unwanted" would either fail doctor or need a real warning level.

chezmoi's [`.chezmoiremove`](https://www.chezmoi.io/reference/special-files/chezmoiremove/) is the model Kris suggested: an explicit, reviewable list of things to remove, acted on only by an apply.

## Boundary

- **In:** the doctor classification of (a), (b) and (c); a declared removal list (a new declaration kind, or an extension of `[retired-application]`); an opt-in removal action with a dry run, per provider, using each native manager's own uninstall; how this relates to the retired-application report and receipt-backed retirement; spec, guide, help and manual alignment.
- **Out:** automatic uninstall on deselection or during `apply` or `upgrade`; deleting retained application data (the retired-application report's "no observation is deletion approval" stays); Kris's own removal list, which belongs in the chezmoi source; the per-machine profile layout (DOTFILES-UE-075 in the chezmoi repository).

## Current state

Kris selected and approved bounded planning and delivery under tools-burndown Decisions 1, 3 and 4. RIG-CORE-043 supplies honest source classification. No competing delivery owns this record; personal removals and RIG-CORE-042 remain protected.

## Steps

- [x] Add validated private `[remove.ID]` declarations with native identity, platform and optional profile membership; reject conflicts with retained tool installations and unsafe provider arguments.
- [x] Add default-preview `rig remove`, requiring `--apply` and confirmation of its displayed preview, with fresh observations and independent native outcomes.
- [x] Add doctor removal findings and opt-in `--unmanaged` information, preserving declared drift and retired-application observation semantics.
- [x] Align specifications, guide, help and manual; verify isolated native fixtures and the full local gate, then prepare the six-part Review packet.

## Files touched

Configuration, declaration registry, provider inventory, doctor, runtime help and dispatcher modules; a new removal module; assembled executable and assembly manifest; isolated removal tests and sudo containment stub; configuration/state/orchestration specs, user command guide, manual and changelog.

## Verify

Fixture tests prove default preview, refusal/EOF, explicit confirmation, undeclared-target rejection, duplicate/retained identity rejection, profile/platform filtering, no automatic uninstall, native argv and independent failure, honest doctor cases and inventory information. Run the developer guide's complete gate and the suite with hostile inherited XDG state when changing isolation. Review the actual diff and committed path roster.

## Dependencies / blocks

RIG-CORE-043 delivered application classification. No acceptance dependency. No live uninstall, data cleanup, native authentication or personal declaration changes are authorised.

## Documentation impact

### Decision Records

Routine choices and owner authority are recorded here; no separate architectural decision is required.

### Specifications

Specify the private removal declaration, confirmation boundary, native command matrix and three doctor classifications.

### Guides

Explain preview and explicit native removal, inventory opt-in and retained-data boundary; align command help and manual.

### Roadmap

Keep this identity and stop at Awaiting review; do not capture, accept or prune work.

## Review

### Delivered

Delivered the approved explicit native removal and doctor-classification contract from immutable baseline `a6946472afd7e8e382613ee8aa0065bc7dd7729f`. No personal removal list, live uninstall, retained-data cleanup, Dock/profile delivery or acceptance is included.

The retained-uv review finding is corrected under tools-burndown Decisions 3, 4 and 5, within the existing retained-installation protection requirement. Correction started from immutable published `main` revision `e028775d9cf7393f359b133f4ba4d88cd93353aa` after `rig-deliver.status` ended `DONE`. The original `baseline_ref`, completed Steps and Awaiting review state remain unchanged. No new record, acceptance, closure, release, live provider operation, sudo grant or personal configuration change is included.

### Change Summary

Added private validated `[remove.ID]` declarations and default-preview `rig remove`, with explicit `--apply`, displayed confirmation, fresh native observations and per-item outcomes. Fixed native adapters cover Homebrew formula/cask/App Store, uv, npm and mise. Retained identities, including npm/mise version selectors, and unsafe provider arguments are rejected. Doctor distinguishes pending declared removals, opt-in informational undeclared inventory and existing declared drift. Help/completions, manual, guide, changelog and configuration/state/orchestration specifications describe the same boundary. Sudo calls are contained by an inert test helper override.

The bounded correction changes only `src/rig/27-software-removal.bash`, its generated `bin/rig`, `tests/rig-software-removal.bats` and this record. uv named requirements now yield a conservative distribution identity: versions and extras do not distinguish retained packages, ASCII case is folded, and runs of hyphens, underscores and full stops compare as one hyphen. Paths, URLs, direct references, archive filenames, markers and unsupported or malformed syntax fail closed instead of guessing. Normalisation errors propagate through validation and native removal. Four additional fixtures cover retained requirements before preview/apply/doctor observations, canonical-name and duplicate aliases, ambiguous sources, and a distinct retained-package control. The existing public contract already prohibits removal of retained native identities; no command, schema, help, guide, manual or changelog contract changes are needed.

### Verification

The complete developer-guide gate passed on the final delivery, including repository audit (zero failures and one pre-existing missing committed-hook warning), ShellCheck, Bash syntax, deterministic assembly, benchmark, bounded native version smoke, all 484 Bats cases, mandoc lint and diff whitespace checks. The complete Bats run used hostile inherited XDG state and proved its marker and directory contents remained untouched. Fourteen focused removal fixtures, eight projection cases and six command-surface checks passed independently. ShellCheck was repeated for the final assembled payload and runtime help module after completion alignment. The final two-second reference benchmark passed. The rendered manual and actual source/documentation/test diff were inspected; no protected path changed.

Correction verification at the final authored payload:

- Immutable reviewed `0d6a342077f676bcb9634afb703252453ab2d9e2:bin/rig` and correction-start `e028775d9cf7393f359b133f4ba4d88cd93353aa:bin/rig` both reproduce retained `subject==1.0` versus removal `subject`: `remove --dry-run` exits 0 and plans removal, with exactly one inert `tool list` call. The corrected executable exits 2 for both `remove --dry-run` and confirmed `remove --apply`, reports the retained-binding conflict and makes zero provider calls. Every reproduction uses runtime-owned HOME/config/data/state/cache and a manager-free PATH, without inherited environment.
- `bats tests/rig-software-removal.bats </dev/null`: all 18 removal cases pass. Final full-suite cases cover the additional archive and marker variants. Retained tools deliberately belong to another profile/platform, proving protection is catalogue-wide. New negative cases assert an empty strict provider invocation log; the distinct-package control asserts exact list/list/uninstall argv against an inert stub. The immutable starting executable fails the three new safety cases while passing the distinct-package control.
- `ki repo audit --repo .`: exit 0, PASS=19 WARN=1 FAIL=0. The one pre-existing warning is HOOK-1, missing committed `.githooks/pre-commit`; no hook was installed or bypassed. The final record-inclusive audit has the same outcome.
- Full developer-guide ShellCheck, Bash syntax loop, `scripts/assemble-rig --check`, default `scripts/benchmark-rig`, `mandoc -T lint man/rig.1` and `git diff --check` pass. ShellCheck is repeated on final `bin/rig` and the authored removal module after the archive guard edit.
- `RIG_BENCHMARK_BUDGET_SECONDS=2 scripts/benchmark-rig`: final recheck passes (show-item=2s, show=2s, show-all=2s, status=7s against its 8s observation budget). The initial reference run failed show=3s; the unchanged immutable starting executable independently failed show-item=3s. No timing budget, performance test or unrelated implementation was changed.
- `bats tests/ </dev/null`: all 517 cases ran; initial result was 514 pass, two existing optional tomllib skips and one failure in the portable query timing guard. `bats --filter 'representative catalogue stays' tests/rig-performance.bats </dev/null` subsequently passes the sole failed case. All non-timing cases passed on the full run. The first new focused-test run had an incorrect expectation that doctor configuration findings exit 2; its assertion was corrected to the established unhealthy exit 1, without changing doctor behaviour.
- `scripts/smoke-native-providers` passes all six version-probe branches with strict runtime-owned inert executables accepting only `--version`/`version`. The task forbids live provider operations, so this proves smoke-script plumbing, not real-manager integration. No real manager, sudo or native uninstall was invoked.

The actual source, generated executable and regression diff were reviewed together. `bin/rig` SHA-256 is `bcdfa8a7a51662b7fa10f6395957eabcc963c93e4db3579bd8e6809ea01ad3b8`; authored removal module SHA-256 is `2d7afc20359461545ef74df59dfec5dc553aaa1f916e68a00fcbfd94e41bf727`. Full receipts and comparison output are in the tools-burndown runtime `rig-correct.*.log` files. Exact committed paths and fresh origin ancestry must be inspected before authorised non-force publication; other owners' outgoing commits are excluded.

### Outstanding concerns

No required delivery check remains failing. The existing missing committed-hook warning remains; no hook was installed or bypassed. Native managers retain uninstall semantics and may perform their own hooks; Rig adds no force, zap or application-data deletion. App Store removal requires an existing administrator grant and refuses noninteractive sudo denial. No live uninstall or authentication was exercised.

The retained-uv defect is resolved by isolated evidence. The initial timing failures and their passing focused rechecks are retained above rather than described as a clean first full-suite run. The pre-existing hook warning and two optional tomllib skips remain. Real-manager smoke integration was deliberately not exercised under this task authority. Unsupported uv source forms block removal for the catalogue; this conservative refusal requires no native inspection and cannot imply deletion approval.

### Post-change review

The public surface meets the captured boundary: explicit declarations alone authorise previewed and confirmed native uninstall, absence skips and uncertainty refuses deletion, while independent native failures retain incomplete outcomes. Deselection, ordinary apply/upgrade and retired traces never generate removals. Fresh-observation and retained-version fixtures cover the consequential race and identity boundaries. The actual runtime and documentation diff was reviewed; no protected path changed.

The correction meets the captured protection requirement: a versioned or extra-qualified retained uv distribution cannot be removed through another spelling, including across inactive profile/platform declarations. Ambiguous identities block validation before provider observation or mutation. Existing native removal behaviour for a distinct retained package still works through exact-argv fixtures. Bash 3.2, assembly and the final two-second reference check are verified. No Dock, RIG-CORE-042, provider-observation module, master-owned configuration or personal path was edited. This is review evidence for Kris, not self-acceptance.

### Mini recap

Explicit removal and the three doctor classifications are delivered for Kris's acceptance review. Specifications and the existing user command guide retain the durable contract; personal removal choices stay in their source thread. No new record, automatic retired declaration, closure or pruning is proposed.

The bounded retained-uv correction and its direct regressions are ready for independent review in this same record. No new capability or work record was created; the original immutable baseline and Awaiting review state are retained.

## Done

Accepted 2026-10-11 by Kris Brown on the review packet above.

## Discussion

### Human acceptance

Kris Brown approved this exact completed record under tools-burndown Decision 6 (2026-10-11): "Yeah, if you've done them, I'm happy to accept them, and we can get them pruned as well, and just keep going until you can get as much of this sorted out and done." The rig-close task binds that standing human grant to RIG-CORE-041, RIG-CORE-043, RIG-CORE-044 and RIG-CORE-045, conditional on complete verified delivery. This records Kris's approval against the six-part Review above; it is not agent self-acceptance. Decisions 1, 3 and 4 bound delivery, and Decision 5 still protects master-owned configuration. Pruning remains separately subject to committed Done state and reference/trade preflight.

Acceptance review independently inspected the published correction `d0eda6b26b73f864ca4e7e201be7380eeea545d9` against its immutable parent `e028775d9cf7393f359b133f4ba4d88cd93353aa`. Named requirements, extras, version selectors and ASCII case/separator aliases protect retained uv distributions; ambiguous sources refuse before observation or mutation. All 18 inert removal regressions passed again. The original full-suite timing failure, unchanged-baseline timing reproduction and passing focused/reference reruns remain honestly recorded in Verification; neither budgets nor guards were weakened. The current record, adapter and authoring audits pass, and no captured requirement remains failing.

### Retained uv identity protection

The review finding demonstrated that the original extras-only provider identity helper leaves `subject==1.0` unequal to `subject`, despite uninstall targeting the same retained distribution. Removal now owns its conservative named-requirement identity parsing, rather than changing shared provider observation semantics. Named requirements with ordinary version constraints and optional extras have an explicit identity; Python distribution case/separator equivalence applies before retained and duplicate comparison. Unnamed sources and syntax outside this bounded grammar refuse removal, including when retained in an unselected profile or platform. This is the approved retained-package safeguard, not a new source resolver. Decisions 3, 4 and 5 authorise the correction and publication of only its verified outgoing commit; they do not authorise acceptance, configuration edits or live operations.

### Approved routine choices

Use separate private `[remove.ID]` declarations as explicit removal authority, without receipt gating. Only selected platform/profile declarations are actionable; retained installation identities anywhere in the catalogue forbid removal. Support native Homebrew formula/cask/App Store, uv, npm and mise uninstall operations; reject custom executables and arbitrary provider arguments. App Store removal uses only an existing noninteractive sudo grant and never acquires one. Preview is the default; `--apply` repeats the selected preview before requiring literal `remove`, and reobserves presence after confirmation. Missing items skip, uncertain evidence refuses, failures remain visible. Native tools retain uninstall semantics; Rig requests no zap or data cleanup. Doctor reports declared pending removals as findings, undeclared-anywhere inventory only under `--unmanaged` as information, and drift through existing observations. Deselection, apply, upgrade and retired-application traces never approve package deletion. No automatic retired declaration is created.

Open questions for planning:

- **Removal list shape.** A separate `[remove.ID]` table, a `remove = true` or `state = "absent"` field on an existing tool, or `[retired-application]` gaining a provider identity. A field on the tool keeps catalogue identity and history in one place; a separate list mirrors `.chezmoiremove` and keeps removed things out of the catalogue and public view.
- **What counts as unwanted.** "Undeclared anywhere in the catalogue" is safe; "declared but not in this machine's profile" matters once per-machine profiles exist (DOTFILES-UE-075) and is the likelier source of noise. Transitive Homebrew dependencies stay out, as `--unmanaged` already excludes them.
- **Doctor severity and cost.** Whether doctor runs the inventory by default (a Homebrew and application scan on every doctor run) or only under a flag; whether case (b) is a warning that does not fail doctor, which needs a real warning tier and a decision about exit status for unattended callers such as the chezmoi `rig-update` job.
- **Uninstall action.** A `rig remove` or `rig apply --remove` that acts only on the declared list, previews with `--dry-run`, refuses anything not declared for removal, and reports per-item native outcomes. Whether removal should be receipt-gated, so Rig only uninstalls what it can show it installed, or trust the explicit declaration.
- **Retirement overlap.** Whether a removed application should automatically gain the retired-application report afterwards, so trace review follows uninstall without a second declaration.
- **A first real list is waiting.** The owner's private configuration repository already holds a decided removal list of about 25 applications and packages across two Macs, from the 2026-10-09 machine comparison. It moves into the removal declaration this record defines once that exists, and stays out of this public repository.
