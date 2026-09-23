# Expected and observed state — RIG-STATE

This area of the [Rig Specifications](index.md) defines comparison and application beneath [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md), [ADR-RIG-005](../decisions/ADR-RIG-005-provider-execution-contract.md), and the execution boundary in [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Observation

### RIG-STATE-001 — Profile expectation

`rig status [--profile NAME]` MUST report every tool expected by the resolved profile in stable dependency order, using its selected provider observation when bound and catalogue-only state when unbound.

_Conformance:_ conforming

_Verify:_ Bats tests resolve explicit, inherited, required, and catalogue-only tools and compare their ordered status rows.

_Evidence:_ `rig_command_status` consumes the dependency-first operational plan; `tests/rig.bats` covers bound and catalogue-only rows.

### RIG-STATE-002 — Observation vocabulary

Rig MUST classify each expected tool as exactly one of `present`, `missing`, `drifted`, `unavailable`, or `unknown`.

_Conformance:_ conforming

_Verify:_ Bats table tests make a recording provider return every supported observation and reject unrecognised, empty, and multiline results.

_Evidence:_ `rig_command_status` accepts only the five state tokens and maps invalid provider output to `unknown` with `invalid-response` detail.

### RIG-STATE-003 — Provider-owned evidence

Rig MUST derive observed state from the selected provider without creating a competing persistent installation database.

_Conformance:_ conforming

_Verify:_ Bats tests change recording-provider output between invocations and assert `rig status` reflects the current response without a Rig state file.

_Evidence:_ `rig_command_status` invokes the selected provider for each comparison and stores results only in process-local indexed arrays.

### RIG-STATE-004 — Read-only status

`rig status` MUST invoke only built-in observation operations or exact external operations explicitly allowed for observation and MUST NOT invoke mutation.

_Conformance:_ conforming

_Verify:_ Bats recording logs assert status calls only built-in or explicitly allowed external observation; unavailable native commands, missing extension operations, and missing extension executables produce unavailable rows without mutation.

_Evidence:_ `rig_command_status`, `rig_observe_plan`, and `rig_observe_resource_plan` dispatch observation only; `status reports native observation failure without exposing provider exit as command status` and `resource status and dry-run use literal provider records without mutation` prove mutation logs and receipts remain untouched.

### RIG-STATE-008 — Catalogue-only neutrality

`rig status` MUST report a selected catalogue-only tool with provider `-`, state `unavailable`, and detail `catalogue-only` without making that row unhealthy.

_Conformance:_ conforming

_Verify:_ Bats runs a mixed bound and catalogue-only profile and asserts exact row, summary, and exit status.

_Evidence:_ `tests/rig.bats` covers a neutral catalogue-only row in an otherwise healthy status report.

### RIG-STATE-009 — Deterministic status report

`rig status` MUST print `TOOL`, `PROVIDER`, `STATE`, and `DETAIL` columns in stable dependency order followed by fixed-order summary counters. Every human status section MUST use aligned columns, a header rule, and two-space gutters; MUST remain at most 120 characters wide; and MUST mark bounded values with deterministic `...` ellipsis. Path-like unmanaged identities SHOULD preserve useful leading and trailing context when bounded. This human layout MUST NOT be treated as a machine-readable contract.

_Conformance:_ conforming

_Verify:_ Bats compares exact status output for a dependency graph whose lexical order differs from its execution order, exercises every status section, and bounds deliberately long rows to 120 characters with visible ellipsis.

_Evidence:_ `rig_build_plan` provides stable dependency order and `rig_command_status` owns the exact table and summary.

### RIG-STATE-013 — Doctor health synthesis

`rig doctor [--profile NAME]` MUST synthesise configuration validity, effective XDG directory accessibility, profile resolution, provider availability, and selected-tool observations into one compact health result. Missing, drifted, unavailable, and unknown bound tools MUST be findings; catalogue-only and incompatible-platform tools MUST remain informational.

Schema 1 has no optional selected-tool marker, so every selected bound tool is required for doctor health.

_Conformance:_ conforming

_Verify:_ Bats tests compare healthy, mixed-observation, unavailable-provider, catalogue-only, incompatible-platform, and explicit-profile results.

_Evidence:_ `rig_command_doctor` consumes the operational plan and provider observation vocabulary and `tests/rig.bats` covers each treatment.

### RIG-STATE-014 — Read-only doctor

`rig doctor` MUST invoke only built-in observation operations or exact external operations explicitly allowed for providers selected by the resolved profile and MUST NOT invoke apply, repair, publication, or unselected-provider operations.

_Conformance:_ conforming

_Verify:_ Recording-provider Bats tests assert only selected `observe` calls and no invocation when a provider executable is unavailable.

_Evidence:_ `rig_command_doctor` consumes `rig_observe_plan` and `rig_observe_resource_plan` without application dispatch; `doctor gives compact healthy synthesis using observation capabilities only` and `doctor reports unavailable providers without invoking mutation` cover selected observation and unavailable executables.

### RIG-STATE-015 — Doctor output and outcomes

`rig doctor` MUST print either `Rig doctor: healthy` or `Rig doctor: findings`, deterministic owner and action fields for each finding, and fixed-order summary counts. It MUST exit 0 when healthy, 1 when valid checks find health issues, and 2 for syntax, configuration, or resolution failure.

_Conformance:_ conforming

_Verify:_ Bats compares exact healthy and mixed-finding output and covers statuses 0, 1, and 2.

_Evidence:_ Doctor Bats cases assert exact summaries, actionable findings, and failure classes.

## Application

### RIG-STATE-005 — Explicit apply

`rig apply [--profile NAME]` MUST invoke only built-in mutation operations or exact external operations explicitly allowed for bound tools selected by the resolved profile.

_Conformance:_ conforming

_Verify:_ Bats configures selected and unselected recording providers and asserts only selected work receives an apply invocation.

_Evidence:_ `rig_command_apply` traverses only `rig_build_plan` and the selected resource plan; `operational commands honour explicit profiles and ignore unselected providers` and `apply and bootstrap scopes stage tools and resources independently` cover the selection boundary.

### RIG-STATE-006 — Dry-run plan

`rig apply --dry-run` MUST perform full-plan preflight and print planned work in execution order without invoking a provider.

_Conformance:_ conforming

_Verify:_ Bats compares the exact dry-run table and summary and asserts the provider recording log remains absent.

_Evidence:_ `rig_command_apply` calls `rig_preflight_apply` before rendering planned rows and skips invocation when dry-run is selected.

### RIG-STATE-007 — Failed prerequisite

After a work unit fails, `rig apply` MUST report it as `failed`, report transitive dependants as `skipped` with `blocked-by:TOOL`, and continue independent work.

_Conformance:_ conforming

_Verify:_ Bats fails a prerequisite in a mixed dependency graph and asserts the dependant is not invoked while independent work completes.

_Evidence:_ `rig_plan_blocker` identifies failed prerequisite work and `tests/rig.bats` verifies failed, skipped, and completed rows.

### RIG-STATE-010 — Full-plan preflight

`rig apply` MUST validate every selected work unit against the built-in provider registry or the external provider's exact allowed operation and executable before invoking any provider. Configuration, provider capability, executable, platform, retirement, and receipt-boundary failures MUST stop the complete plan before mutation. Rig MUST discover resource-local environmental findings before mutation, record them against their resource rows, prevent those resources from being invoked, and continue independent work.

_Conformance:_ conforming

_Verify:_ Bats places a shared registry, operation, executable, or receipt failure late in the selected plan and asserts every mutation log remains absent; a separate case proves a resource-local path failure produces a failed row while an independent resource completes.

_Evidence:_ `rig_preflight_apply`, `rig_preflight_provider`, `rig_preflight_resource`, and `rig_preflight_resource_receipt` classify the complete plan before dispatch; `tests/rig.bats` proves shared failures prevent every mutation and `tests/rig-macos.bats` proves a Dock-local finding is isolated.

### RIG-STATE-016 — Bootstrap materialisation

`rig bootstrap [--profile NAME] [--dry-run]` MUST run Rig's native bootstrap lifecycle without requiring a bootstrap provider or synthetic setup tools. An explicit profile MUST take precedence; otherwise Rig MUST select `[rig] bootstrap-profile` when declared and fall back to `default-profile` when absent. Rig MUST identify required managers and preflight the complete declarative plan. It MAY defer only the executable readiness of selected built-in mise and npm managers when their fixed Homebrew and mise prerequisites are selected, MUST report and complete those stages in dependency order, and MUST then run the same complete reconciliation model as apply. Dry-run MUST describe every stage without invoking a provider or changing the machine.

_Conformance:_ conforming

_Verify:_ Bats exercises explicit, configured, and fallback profile selection; missing and present manager availability; complete dry-run; failure isolation; and equivalent reconciliation outcomes without bootstrap provider configuration.

_Evidence:_ `rig_command_bootstrap`, `rig_bootstrap_preflight_homebrew_manifest`, and `rig_command_apply` implement the staged native lifecycle; `bootstrap selects its declared profile with explicit and default fallbacks`, `bootstrap and apply execute the same dependency-ordered provider plan`, and the six `tests/rig-bootstrap-manifest.bats` tests cover selection, preflight, dry-run, reconciliation, and failure outcomes.

### RIG-STATE-017 — Bounded comparison identities

Expected-versus-observed reconciliation MUST compare Homebrew formula and cask locators by their terminal token and tool artifacts after expanding only a leading `~/` or `$HOME/`. The same rules MUST govern selected-tool observation and unmanaged inventory comparison. Normalisation MUST NOT rewrite declarations, cross provider namespaces, expand embedded or other variables, or change the locator passed to application.

_Conformance:_ conforming

_Verify:_ Bats tests cover qualified and unqualified Homebrew formula and cask locators, both supported artifact home prefixes, absolute artifacts, unsupported variables, provider namespace separation, and unchanged apply arguments.

_Evidence:_ `rig_normalize_provider_identity` and `rig_normalize_artifact_identity` derive comparison-only values; built-in adapter and unmanaged-inventory Bats cases verify observation and application boundaries.

### RIG-STATE-012 — Direct-download integrity and replacement

A direct-download observation MUST remain local: a missing destination is `missing`; a regular executable whose SHA-256 matches is `present`; a hash or executable-mode mismatch is `drifted`; a symlink or non-regular destination is `unavailable`. Application MUST restrict the initial request and redirects to HTTPS, download to a previously absent sibling temporary path, verify the declared SHA-256, revalidate destination safety immediately before setting executable mode and renaming over the destination, verify the result is a regular file, and remove the temporary path after every handled failure.

_Conformance:_ conforming

_Verify:_ Bats runs status without the downloader, proves dry-run creates nothing, installs a matching payload, rejects a mismatched checksum, verifies no temporary path remains, and rejects a symlink during preflight.

_Evidence:_ `rig_observe_provider`, `rig_preflight_provider`, and `rig_apply_direct_download` implement local observation, full-plan safety checks, verified sibling replacement, and failure cleanup.

### RIG-STATE-011 — Command outcomes

`rig status` and `rig apply` MUST exit 0 for healthy or successful results, 1 for valid unhealthy or failed results, and 2 for syntax, configuration, resolution, or preflight failure.

_Conformance:_ conforming

_Verify:_ Bats covers healthy, catalogue-only, unhealthy observation, native failure, dependency suppression, syntax, and preflight outcomes.

_Evidence:_ Operational command tests assert aggregate status independently from provider-native exit details.

### RIG-STATE-018 — Operational resource state

`rig status` and `rig doctor` MUST observe every selected service and scheduled job through the built-in provider registry or an exact external observation operation and MUST NOT mutate it. Status MUST append deterministic resource identity, kind, provider, state, and detail rows. A non-present selected resource or stale receipt row MUST be unhealthy; stale rows MUST report retirement pending. Doctor MUST turn the same findings into actionable provider-owned diagnostics.

_Conformance:_ conforming

_Verify:_ Bats tests all resource state tokens, protocol failures, stale receipts, healthy and finding outcomes, and provider logs containing only observation verbs.

_Evidence:_ `rig_observe_resource_plan`, `rig_print_resource_status`, and the resource branch of `rig_command_doctor` compare selected and stale resources; `resource status and dry-run use literal provider records without mutation` and `resource apply records managed identities and retires deselected entries` cover observation-only dispatch and retirement-pending state.

### RIG-STATE-019 — Resource application and retirement

`rig apply` MUST preflight every selected tool, setting, Dock layout, service, scheduled job, stale receipt provider, built-in or extension operation, executable, and receipt target before the first mutation. `rig bootstrap` MUST preserve that boundary except for the explicit built-in manager-readiness stages defined by RIG-ORCH-018, and MUST complete a normal apply preflight after those stages. Both commands MUST apply dependency-ordered tools before dependent managed resources, then perform stale resource retirements. A failed tool MUST suppress dependent resources while independent resources continue. A resource-local preflight finding MUST produce a failed row and MUST NOT block independent selected resources. Any selected resource failure MUST prevent stale retirement and receipt replacement. Dry-run MUST invoke no provider, write no state, and print every desired managed-resource record and pending retirement with its planned, failed, or blocked outcome.

_Conformance:_ conforming

_Verify:_ Bats tests shared complete-plan rejection without a mutation log, resource-local preflight isolation, a literal complete dry-run, dependency suppression, independent continuation, native failures, retirement withholding, receipt preservation, resource ordering, and apply/bootstrap parity.

_Evidence:_ `rig_preflight_apply`, `rig_resource_blocker`, `rig_command_apply`, and `rig_command_bootstrap` implement classified preflight, ordered application, and deferred retirement; `tests/rig-macos.bats`, `resource apply preflights every provider before any mutation`, `resource apply failure preserves the previous atomic receipt`, and apply/bootstrap scope and parity tests cover those boundaries.

### RIG-STATE-020 — Reconciliation receipt

After a fully successful resource reconciliation, Rig MUST atomically replace `${RIG_STATE_HOME}/resources/PLATFORM.tsv` with one tab-separated provider, kind, identity, and locator row per selected resource. It MUST NOT persist observations or declaration fields. A later plan MUST treat receipt rows whose provider, kind, and locator are absent from the selected set as stale retirement work. Reusing the same provider, kind, and locator under a new Rig identity MUST transfer ownership without retirement. Malformed or unsafe receipt paths MUST fail before mutation; failed or dry-run applications MUST leave the previous receipt unchanged.

_Conformance:_ conforming

_Verify:_ Bats tests XDG and Rig state overrides, first write, exact content, deselection, deletion, rename transfer, malformed records, unsafe targets, native failure preservation, atomic replacement, and empty successful receipts.

_Evidence:_ receipt helpers read a bounded four-field format, compare locators, preflight the filesystem boundary, write a mode-restricted sibling temporary file, and rename only after success.

### RIG-STATE-021 — Typed machine-resource state

`rig status` and `rig doctor` MUST compare every selected setting and Dock layout with live built-in provider observations and MUST report non-present state as a finding. `rig apply --dry-run` MUST disclose each proposed defaults value and ordered Dock item without mutation. `rig apply` and `rig bootstrap` MUST apply only the selected declarations after full-plan preflight and MUST NOT depend on a workstation provider, provider-owned policy file, or non-Bash runtime.

_Conformance:_ conforming

_Verify:_ Bats uses isolated native-command fakes to cover present and drifted settings, ordered Dock equality, missing required paths, complete dry-run disclosure, successful apply, platform gating, and absence of extension invocations.

_Evidence:_ `rig_setting_observe`, `rig_setting_apply`, `rig_dock_observe`, `rig_dock_apply`, `rig_macos_resource_preflight`, and `rig_print_resource_projection` own typed machine state; `typed macOS resources query and dry-run deterministically`, `typed macOS resources observe and apply through native command fakes`, and `typed macOS schema rejects invalid values before invocation` cover that state boundary.

### RIG-STATE-022 — Lifecycle preflight and preview

`rig update`, `rig maintain`, and `rig capture` MUST provide a non-mutating dry run that reports planned and unsupported work without invoking a provider or writing a manifest. Before a non-dry-run lifecycle mutation, Rig MUST preflight every supported target's executable and required manifest boundary before invoking the first provider. Lifecycle reports MUST be deterministic, MUST keep native diagnostics off the report channel, and MUST report independent completed, failed, unavailable, and skipped outcomes.

_Conformance:_ conforming

_Verify:_ Bats records provider calls and manifest content across dry-run, unavailable executable, unsafe manifest, successful, failed, duplicate, and unsupported lifecycle work.

_Evidence:_ `rig_preflight_lifecycle_task` and `rig_run_lifecycle_tasks` implement complete supported-target preflight, stable tabular reports, dry-run isolation, and independent outcomes; `tests/rig-lifecycle.bats` covers the lifecycle state boundary.

### RIG-STATE-023 — Generated-artifact state

Artifact observation MUST remain read-only and authoritative for `rig status` and `rig doctor`. A macOS application artifact MUST be a real directory with a readable regular `Contents/Info.plist` and at least one entry beneath a real `Contents/MacOS` directory that resolves to a regular executable; otherwise Rig MUST report drift. Profile deselection MUST NOT uninstall a tool or delete its artifacts.

_Conformance:_ conforming

_Verify:_ Bats covers missing, unsafe, structurally damaged, broken-executable, and healthy application artifacts without invoking a generator.

_Evidence:_ `rig_observe_tool_artifacts` implements the state contract; `tests/rig-artifacts.bats` supplies isolated filesystem evidence.

### RIG-STATE-024 — Declaration-kind deselection

A successful complete-profile reconciliation MUST retire previously receipted services and scheduled jobs omitted from the next selection. Profile deselection MUST NOT remove packages, tool artifacts, settings, Dock layouts, ports, or skills without a separate explicit cleanup contract. A view MUST NOT load retirement work or replace a receipt.

_Conformance:_ conforming

_Verify:_ Bats switches complete resource selections and inspects retirement, then observes a view against the same state and confirms no retirement work or receipt mutation.

_Evidence:_ `rig_load_resource_receipt` records only service and scheduled-job retirement while `rig_resolve_operational_plan` excludes views from receipt loading; resource and profile-authority Bats cover both paths.

### RIG-STATE-025 — Exclusive reconciliation target

Before a live receipt-backed apply or bootstrap reads its per-platform receipt, Rig MUST acquire an exclusive lock for that platform and MUST hold it through receipt replacement or failure cleanup. A concurrent invocation MUST fail before provider mutation with active, stale, or unknown owner detail and MUST NOT remove an unverified existing lock.

_Conformance:_ conforming

_Verify:_ Bats supplies live and non-existent owner PIDs, asserts no provider call and retained lock, then completes reconciliation and asserts lock cleanup plus receipt installation.

_Evidence:_ `rig_acquire_reconciliation_lock`, signal traps, `rig_release_reconciliation_lock`, and deferred receipt loading implement the boundary; `tests/rig-profile-authority.bats` covers contention and success.

### RIG-STATE-026 — Private port expected-versus-observed state

For a selected private TCP port, Rig MUST report a required absent listener as `missing`; MUST treat absent on-demand and allocated ports as healthy availability; MUST report a listener with a different bind scope as `drifted`; MUST report positively different ownership as `conflicting`; and MUST report inaccessible ownership or observation as `unknown` or `unavailable` rather than infer absence, drift, or ownership. Allocated occupancy with no positively different owner MUST remain informational. An ownership match MUST rest on the listener's full command line compared against the owner's declaration — a service's or scheduled job's home-expanded `program`, a tool's selected locator without package extras — matched as a complete argument token or path component, with an exact executable-name match as fallback evidence. A listener whose command line cannot be read and whose executable name differs MUST be reported as unverified ownership, never as `conflicting`, and the `conflicting` detail MUST name the listener whose command line positively identified a different process.

_Conformance:_ conforming

_Verify:_ Deterministic Bats command fakes emit no listener, loopback, IPv4 and IPv6 wildcard, matching owner, different owner, missing command, malformed output, and native failure records without opening real sockets.

_Evidence:_ `rig_load_listeners` and `rig_observe_ports` normalise one cached observation; private-port status and doctor tests verify every mode and outcome.

### RIG-STATE-027 — User-level skill expected-versus-observed state

For each selected skill, Rig MUST compare declaration with its fixed native authority and report `present`, `missing`, `drifted`, `unavailable`, or `unknown` without evaluating instruction content. Skills CLI absence, non-zero execution, unsupported version, or malformed bounded JSON MUST report unavailable; KI MUST report inventory unavailable without invocation; local authority MUST distinguish a matching projection, missing leaf, and collision; runtime/plugin ownership MUST remain observation-only. `status --unmanaged` MAY report Skills CLI global identities absent from any matching `source-skill` declaration.

_Conformance:_ conforming

_Verify:_ Isolated Bats fakes cover remote, KI, local, runtime/plugin, missing, drifted, unavailable, malformed, collision, and unmanaged cases without reading real user roots.

_Evidence:_ `rig_observe_skill`, `rig_skills_cli_load_inventory`, `rig_print_unmanaged_skills`, and `tests/rig-skills.bats` implement and verify the contract.
