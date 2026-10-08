# Expected and observed state — RIG-STATE

This area of the [Rig Specifications](index.md) defines comparison and application beneath [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md), [ADR-RIG-005](../decisions/ADR-RIG-005-provider-execution-contract.md), and the execution boundary in [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Observation

### RIG-STATE-001 — Profile expectation

`rig status [--profile NAME]` MUST report every tool expected by the resolved profile in stable dependency order, using its selected provider observation when bound and catalogue-only state when unbound.

_Conformance:_ conforming

_Verify:_ Bats tests resolve explicit, inherited, required, and catalogue-only tools and compare their ordered status rows.

_Evidence:_ `rig_command_status` consumes the dependency-first operational plan; `tests/rig.bats` covers bound and catalogue-only rows.

### RIG-STATE-002 — Observation vocabulary

Rig MUST classify each provider-observed tool as exactly one of `present`, `missing`, `drifted`, `unavailable`, or `unknown`. `rig status` MUST use the separate neutral display state `catalogue-only` for a tool with no selected installation; it is not a provider observation.

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

`rig status` MUST report a selected catalogue-only tool with provider `-`, state `catalogue-only`, and detail `catalogue-only` without making that row unhealthy. The summary MUST count the row only under `catalogue-only`, not `unavailable`; the JSON tool row and summary MUST agree with text.

_Conformance:_ conforming

_Verify:_ Bats runs a mixed bound and catalogue-only profile and asserts exact row, summary, and exit status.

_Evidence:_ `tests/rig.bats` covers a neutral catalogue-only row in an otherwise healthy status report.

### RIG-STATE-009 — Deterministic status report

`rig status` MUST print `TOOL`, `PROVIDER`, `STATE`, and `DETAIL` columns in stable dependency order followed by fixed-order summary counters. Every human section MUST close with its own fixed-order summary counters. Human status sections MUST use aligned columns, a header rule and two-space gutters when columns fit, or labelled stacked entries when they do not. Descriptive values MUST wrap without abbreviation; identity preservation takes precedence over the available width. This human layout MUST NOT be treated as a machine-readable contract.

_Conformance:_ conforming

_Verify:_ Bats compares exact status output for a dependency graph whose lexical order differs from its execution order, exercises every status section, and verifies complete wrapped descriptions, intact identities and terminal-width-aware stacked fallback.

_Evidence:_ `rig_build_plan` provides stable dependency order and `rig_command_status` owns the exact table and summary.

### RIG-STATE-031 — Status attention verdict and filter

`rig status` MUST open its human report with a verdict line stating how many selected entries need attention out of how many entries were compared, naming only the non-empty sections that hold them. An entry needs attention when its state is other than `present` and its apply result is not neutral, so a catalogue-only tool MUST NOT need attention.

`rig status --problems` MUST omit every row that does not need attention, and MUST omit a section left empty by that filter. It MUST NOT change the verdict line, the section summary counters, the exit status, or the `--format json` projection.

_Conformance:_ conforming

_Verify:_ Bats asserts the verdict line's position and arithmetic on a mixed profile, asserts that `--problems` hides present and catalogue-only rows and empty sections while preserving exit status, and asserts that `--problems --format json` still carries the complete payload.

_Evidence:_ `rig_status_totals` derives the per-section attention counts, `rig_status_needs_attention` owns the neutrality rule, and `rig_print_status_verdict` prints the verdict line.

### RIG-STATE-013 — Doctor health synthesis

`rig doctor [--profile NAME]` MUST synthesise configuration validity, effective XDG directory accessibility, profile resolution, provider availability, and selected-tool observations into one compact health result. Missing, drifted, unavailable, and unknown bound tools MUST be findings; catalogue-only and incompatible-platform tools MUST remain informational.

Schema 1 has no optional selected-tool marker, so every selected bound tool is required for doctor health.

_Conformance:_ conforming

_Verify:_ Bats tests compare healthy, mixed-observation, unavailable-provider, catalogue-only, incompatible-platform, and explicit-profile results.

_Evidence:_ `rig_command_doctor` consumes the operational plan and provider observation vocabulary and `tests/rig.bats` covers each treatment.

### RIG-STATE-014 — Read-only doctor

`rig doctor` MUST invoke only built-in observation operations or exact external operations explicitly allowed for providers selected by the resolved profile and MUST NOT invoke apply, repair, or unselected-provider operations.

_Conformance:_ conforming

_Verify:_ Recording-provider Bats tests assert only selected `observe` calls and no invocation when a provider executable is unavailable.

_Evidence:_ `rig_command_doctor` consumes `rig_observe_plan` and `rig_observe_resource_plan` without application dispatch; `doctor gives compact healthy synthesis using observation capabilities only` and `doctor reports unavailable providers without invoking mutation` cover selected observation and unavailable executables.

### RIG-STATE-015 — Doctor output and outcomes

`rig doctor` MUST print `Verdict: healthy` or `Verdict: unhealthy`, deterministic owner and action fields for each finding, and fixed-order summary counts. An unusable configuration MUST become a configuration finding retaining its file, line, reason, and corrective guidance in text and JSON. Doctor MUST still report effective paths, platform, and native provider executable availability without running configuration-dependent observations. It MUST exit 0 when healthy, 1 for findings including configuration load failure, and 2 for syntax or resolution failure. Other operational commands MUST continue to reject unusable configuration with status 2.

_Conformance:_ conforming

_Verify:_ Bats compares exact healthy and mixed-finding output, covers statuses 0, 1, and 2, and checks text and JSON diagnostics for a retired configuration table while status and apply still reject it.

_Evidence:_ Doctor Bats cases and `tests/rig-doctor-config.bats` assert exact summaries, actionable findings, and failure classes.

## Application

### RIG-STATE-005 — Explicit apply

`rig apply [--profile NAME]` MUST invoke only built-in mutation operations or exact external operations explicitly allowed for bound tools selected by the resolved profile.

_Conformance:_ conforming

_Verify:_ Bats configures selected and unselected recording providers and asserts only selected work receives an apply invocation.

_Evidence:_ `rig_command_apply` traverses only `rig_build_plan` and the selected resource plan; `operational commands honour explicit profiles and ignore unselected providers` and `apply scopes stage tools and resources independently` cover the selection boundary.

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

### RIG-STATE-016 — Apply prerequisite staging

Apply MUST include supported selected manager prerequisites in its dependency-ordered plan, disclose them in dry-run and recheck manager availability before dispatch. It MUST preserve the complete preflight and targeted closure boundaries of RIG-ORCH-018 and RIG-ORCH-036 without a separate bootstrap command or configuration profile.

_Conformance:_ conforming

_Verify:_ Exercise selected and unrelated prerequisites, missing managers, dry-run and failures with isolated executables.

_Evidence:_ `rig_preflight_apply` and `tests/rig-bootstrap-staging.bats` cover the unified setup path.

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

_Evidence:_ `rig_observe_resource_plan`, `rig_print_resource_status`, and the resource branch of `rig_command_doctor` compare selected and stale resources; `resource status and dry-run use literal provider records without mutation`, `resource apply records managed identities and retires deleted declarations`, and `profile deselection retires no resource the catalogue still declares` cover observation-only dispatch and retirement-pending state.

### RIG-STATE-019 — Resource application and retirement

`rig apply` MUST preflight every selected tool, setting, Dock layout, service, scheduled job, stale receipt provider, built-in or extension operation, executable, and receipt target before the first mutation. Only the bounded selected manager-readiness exceptions in RIG-ORCH-018 MAY defer an executable check; all other preflight checks MUST remain before mutation. Apply MUST apply dependency-ordered tools before dependent managed resources, then perform stale resource retirements. A failed tool MUST suppress dependent resources while independent resources continue. A resource-local preflight finding MUST produce a failed row and MUST NOT block independent selected resources. Any selected resource failure MUST prevent stale retirement and receipt replacement. Dry-run MUST invoke no provider, write no state, and print every desired managed-resource record and pending retirement with its planned, failed, or blocked outcome.

_Conformance:_ conforming

_Verify:_ Bats tests shared complete-plan rejection without a mutation log, resource-local preflight isolation, a literal complete dry-run, dependency suppression, independent continuation, native failures, retirement withholding, receipt preservation, resource ordering, and apply prerequisite parity.

_Evidence:_ `rig_preflight_apply`, `rig_resource_blocker`, `rig_command_apply` implement classified preflight, ordered application, and deferred retirement; `tests/rig-macos.bats`, `resource apply preflights every provider before any mutation`, `resource apply failure preserves the previous atomic receipt`, and apply prerequisite scope and parity tests cover those boundaries.

### RIG-STATE-020 — Reconciliation receipt

After a fully successful resource reconciliation, Rig MUST atomically replace `${RIG_STATE_HOME}/resources/PLATFORM.tsv` with one tab-separated provider, kind, identity, and locator row per selected resource, followed by every remaining receipt row whose provider, kind, and locator the catalogue still declares for that platform. It MUST NOT persist observations or declaration fields. A later plan MUST treat receipt rows whose provider, kind, and locator are absent from every resource the catalogue declares for that platform as stale retirement work, and MUST NOT treat a declared resource that the current selection omits as stale. Reusing the same provider, kind, and locator under a new Rig identity MUST transfer ownership without retirement. Malformed or unsafe receipt paths MUST fail before mutation; failed or dry-run applications MUST leave the previous receipt unchanged.

_Conformance:_ conforming

_Verify:_ Bats tests XDG and Rig state overrides, first write, exact content, profile deselection, catalogue deletion, retention of a declared row a narrow selection omits, rename transfer, malformed records, unsafe targets, native failure preservation, atomic replacement, and empty successful receipts.

_Evidence:_ receipt helpers read a bounded four-field format, compare each row against the catalogue through `rig_declared_resource_has_locator`, preflight the filesystem boundary, write a mode-restricted sibling temporary file, and rename only after success; [ADR-RIG-008](../decisions/ADR-RIG-008-catalogue-scoped-resource-retirement.md) records why retirement follows the catalogue rather than the selection.

### RIG-STATE-021 — Typed machine-resource state

`rig status` and `rig doctor` MUST compare every selected setting and Dock layout with live built-in provider observations and MUST report non-present state as a finding. `rig apply --dry-run` MUST disclose each proposed defaults value and ordered Dock item without mutation. `rig apply` MUST apply only the selected declarations after full-plan preflight and MUST NOT depend on a workstation provider, provider-owned policy file, or non-Bash runtime.

_Conformance:_ conforming

_Verify:_ Bats uses isolated native-command fakes to cover present and drifted settings, ordered Dock equality, missing required paths, complete dry-run disclosure, successful apply, platform gating, and absence of extension invocations.

_Evidence:_ `rig_setting_observe`, `rig_setting_apply`, `rig_dock_observe`, `rig_dock_apply`, `rig_macos_resource_preflight`, and `rig_print_resource_projection` own typed machine state; `typed macOS resources query and dry-run deterministically`, `typed macOS resources observe and apply through native command fakes`, and `typed macOS schema rejects invalid values before invocation` cover that state boundary.

### RIG-STATE-022 — Upgrade preflight and preview

`rig upgrade --dry-run` MUST report planned and unsupported declaration work without provider invocation or state writes. Before live upgrade dispatch, Rig MUST preflight each supported target, bound an unavailable executable to that target, and continue independent work. Reports MUST be deterministic and separate native diagnostics from stdout. Capture dry-run MAY perform read-only discovery but MUST NOT write a proposal file or active configuration.

_Conformance:_ conforming

_Verify:_ Compare native-call logs and state around upgrade and capture dry-runs, unavailable executables and independent failures.

_Evidence:_ Lifecycle and adoption Bats fixtures cover no-mutation preview, operational findings and report channels.

### RIG-STATE-023 — Generated-artifact state

Artifact observation MUST remain read-only and authoritative for `rig status` and `rig doctor`. A macOS application artifact MUST be a real directory with a readable regular `Contents/Info.plist` and at least one entry beneath a real `Contents/MacOS` directory that resolves to a regular executable; otherwise Rig MUST report drift. Profile deselection MUST NOT uninstall a tool or delete its artifacts.

A declared artifact that is a symbolic link MUST be observed through the target it resolves to. Resolution MUST follow at most 40 leaf links, resolving a relative target against the link's own directory, and MUST NOT be constrained to any root: the declaration is the trusted expectation, and the resolved target supplies the evidence. The resolved target MUST then satisfy every test a directly declared artifact satisfies, so resolution can never report `present` for a target that is absent, damaged, or neither a regular file nor a directory. A link whose resolution exhausts the bound, cycles, or yields no target MUST be `unavailable` with a detail naming failed resolution rather than an unsafe artifact. Where a link was followed, the reported detail MUST carry the resolved target alongside the declared path.

_Conformance:_ conforming

_Verify:_ Bats covers missing, unsafe, structurally damaged, broken-executable, and healthy application artifacts without invoking a generator, and covers a link into a healthy application, a dangling link, a link into a damaged application, a cyclic link, a relative link target, and a link to an unsupported target.

_Evidence:_ `rig_observe_tool_artifacts` and `rig_resolve_artifact_link` implement the state contract; [ADR-RIG-007](../decisions/ADR-RIG-007-resolved-artifact-link-evidence.md) records the evidence boundary; `tests/rig-artifacts.bats` supplies isolated filesystem evidence.

### RIG-STATE-024 — Declaration-kind deselection

A successful complete-profile reconciliation MUST retire previously receipted services and scheduled jobs that the catalogue no longer declares for the platform. Profile deselection MUST NOT retire a service or scheduled job the catalogue still declares, and MUST NOT remove packages, tool artifacts, settings, Dock layouts, ports, or skills without a separate explicit cleanup contract. A view MUST NOT load retirement work or replace a receipt.

_Conformance:_ conforming

_Verify:_ Bats deletes a declaration and inspects its retirement, narrows a profile to nothing and confirms neither retirement nor receipt loss, then observes a view against the same state and confirms no retirement work or receipt mutation.

_Evidence:_ `rig_load_resource_receipt` records only service and scheduled-job retirement and only for rows the catalogue no longer declares, while `rig_resolve_operational_plan` excludes views from receipt loading; resource and profile-authority Bats cover both paths.

### RIG-STATE-025 — Exclusive reconciliation target

Before a live receipt-backed apply reads its per-platform receipt, Rig MUST acquire an exclusive lock for that platform and MUST hold it through receipt replacement or failure cleanup. A concurrent invocation MUST fail before provider mutation with active, stale, or unknown owner detail and MUST NOT remove an unverified existing lock.

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

### RIG-STATE-028 — Machine-readable observation projection

`rig status` and `rig doctor` MUST accept `--format text|json`, defaulting to `text`, and MUST reject any other value with status 2 before observing anything. The `json` rendering MUST project the answer the text rendering reports, from the same observation, so the two cannot disagree about a state, a count, or a verdict.

The payload MUST be a single JSON object on one line on stdout, emitted only after observation has completed, carrying `schema` as an integer, `rig` as the running version, `command`, the resolved `profile` and `platform`, an `observed_at` timestamp, a `healthy` boolean, and a `summary` of the counts the text rendering prints. `rig status` MUST carry `tools`, `skills`, `resources`, and `ports` arrays, each entry naming its identity, its owning provider or authority, its kind where it has one, its state from the vocabulary above, and its detail; `unmanaged` and `unmanaged_problems` MUST be `null` unless `--unmanaged` was requested. `rig doctor` MUST carry its findings grouped by origin and its information. A change that removes or repurposes a field MUST increment `schema`.

No structured field other than a `detail` string, a `findings` entry, or an `information` entry may carry a local path; those three are human-facing text, so a consumer that must not disclose paths can discard exactly those.

Progress and native diagnostics MUST remain on stderr. The exit status MUST NOT vary with the rendering: drift returns 1 in both, and the payload carries `healthy` and the counts so a consumer never has to read the exit status to get the verdict.

_Conformance:_ conforming

_Verify:_ Bats parses the payload with a JSON parser and covers the envelope, both commands, a healthy and a drifted machine, agreement with the text summary and exit status, `--unmanaged`, a rejected format value, quote and backslash escaping, and stdout carrying nothing but the payload.

_Evidence:_ `rig_status_totals`, `rig_json_envelope`, `rig_status_json`, `rig_json_lines`, and `rig_command_doctor` implement the projection; `tests/rig-projection.bats` verifies it.

### RIG-STATE-029 — Exit status and stated outcome

Rig MUST own exactly three statuses of its own. `0` MUST mean a healthy observation or successful operation, `1` MUST mean a valid result carrying findings or an operation that completed independent safe work with failures, and `2` MUST mean a rejection before valid work could start. A release MAY add a status; it MUST NOT repurpose one. A command interrupted by HUP, INT, or TERM MUST return 129, 130, or 143.

A command MUST state its own outcome as the last line it writes to stderr, so a person need not read the status out of the shell. The line MUST have the shape `rig: <command> <result>: status <n>`, optionally followed by a parenthesised detail clause naming the counts or the finding that decided the status. `result` MUST come from the closed vocabulary `succeeded`, `healthy`, `unhealthy`, `incomplete`, `failed`; a release MAY add a value but MUST NOT repurpose one.

The line MUST NOT be written for a status-2 rejection, which `rig: error:` has already named, nor for `help`, `completion`, or `--version`, which report on Rig rather than on a machine. It MUST NOT reach stdout, MUST NOT change an exit status, and MUST NOT carry a path, locator, argument, credential, or native output. `RIG_OUTCOME` MUST control it with `auto`, `always`, and `never`, where `auto` states the outcome when stderr is a terminal; it MUST be independent of `RIG_PROGRESS`, so silencing one does not silence the other.

_Conformance:_ conforming

_Verify:_ Bats asserts the line under `always`, its absence under `never` and after a status-2 rejection, that stdout is unchanged including `--format json`, that it is the last line on stderr, and that each result value appears.

_Evidence:_ `rig_outcome_enabled`, `rig_outcome_note`, `rig_outcome_report`, and `main` implement it; `tests/rig.bats` verifies it.

### RIG-STATE-030 — Unattended last-run report

An unattended `rig upgrade` that dispatches work MUST record its outcome beneath the effective state home as `last-upgrade`, honouring `RIG_STATE_HOME` and then `${XDG_STATE_HOME:-$HOME/.local/state}/rig`. One file MUST hold the most recent unattended run and MUST be replaced atomically, so a reader never observes a partial report. A dry run MUST NOT write it, because no run happened.

The report MUST be UTF-8 tab-separated text. It MUST open with `rig-last-run` and the integer report version, then one `KEY<TAB>VALUE` line each for `action`, `profile`, `platform`, `finished`, `status`, `result`, `detail`, and `summary`, then the `TARGET PROVIDER RESULT DETAIL` header and the same rows the run printed on stdout. `result` and `status` MUST agree with the stated outcome under [RIG-STATE-029](#rig-state-029--exit-status-and-stated-outcome). Rig MAY add a later report version but MUST NOT silently change the meaning of version 1.

The report is a public contract a wrapper reads to notify or report, so it MUST NOT carry a path, locator, argument, credential, or native output, and Rig MUST NOT itself notify. Rig MUST refuse to replace a target that is a symbolic link or a non-regular file, and a report that cannot be written MUST NOT change the run's exit status.

_Conformance:_ conforming

_Verify:_ Bats runs an unattended update, parses the report's keys and rows, compares them with the run's stdout and stated outcome, asserts no file after a dry run, and asserts an unsafe target is left unaltered.

_Evidence:_ `rig_write_last_run_report` and `rig_run_lifecycle_tasks` implement it; `tests/rig-lifecycle.bats` verifies it.

### RIG-STATE-032 — macOS application inventory baseline

On macOS, `rig status --unmanaged` MUST inspect native application bundles alongside every declared inventory provider, not only when no provider is declared. An exact application path observed by both a provider and the built-in scan MUST appear once; unrelated provider identities MUST remain distinct. An unavailable or failed application scan MUST be reported as an inventory problem rather than an observed empty result. The baseline scan MUST NOT run on other platforms.

_Conformance:_ conforming

_Verify:_ Isolated Bats cases exercise zero providers, one unrelated provider, the same canonical app path reported twice, and unavailable and failed scans; a non-macOS case checks the platform boundary.

_Evidence:_ `rig_collect_unmanaged` always includes the macOS application adapter on macOS, and `rig_inventory_provider` deduplicates exact application paths; `tests/rig-application-inventory.bats` covers the observation and problem states.

### RIG-STATE-033 — Shared report and command projection

Every human-readable table MUST use the shared column renderer. It MUST preserve identity columns, wrap descriptive values, use current interactive terminal geometry when available, and use labelled stacked entries when columns cannot fit. Redirected output and unavailable terminal geometry MUST use a deterministic plain 120-column budget independent of ambient `COLUMNS`; when an identity exceeds that budget, preserving it takes precedence. Report spacing MUST NOT be treated as a machine interface.

Human cells MUST show ASCII terminal controls and malformed UTF-8 bytes as visible escapes. Valid UTF-8 code points MUST remain intact and use a conservative two-cell non-ASCII budget; when a terminal cannot contain one wide glyph, preserving that glyph takes precedence. JSON MUST retain original values independently of human rendering.

`rig show`, `rig apply`, and `rig upgrade` MUST accept `--format text|json`, default to text, and reject another format with status 2 before dispatch. JSON MUST be one parseable object on stdout with the common schema, version, command, profile, platform, and observation-time envelope. The selection, declaration, and result values carried in JSON MUST remain complete independently of text wrapping. Mutation projections MUST group unabridged result rows by their named columns and retain the full source report; explanation projections MUST retain the full report alongside labelled fields.

Mutation text reports MUST emit a completed table after its work finishes, so native diagnostics written to stderr cannot divide its rows when a terminal merges the streams. Progress and native diagnostics MUST remain on stderr during execution; buffering stdout MUST NOT change the command's exit status or stated outcome.

_Conformance:_ conforming

_Verify:_ Bats checks a long identifier in show and status, parses JSON from every listed command, checks full JSON values, and exercises a provider that writes to stderr during apply. The complete test gate checks existing command outcomes and report rows.

_Evidence:_ `rig_table_fit_widths`, `rig_render_mutation_report`, `rig_mutation_json`, `rig_show_json`, and the command wrappers implement the contract; `tests/rig.bats` and `tests/rig-projection.bats` cover it.

### RIG-STATE-034 — Homebrew unmanaged inventory

`rig status --unmanaged` MUST discover supported installed Homebrew formulae and casks when the native manager is available, even without a provider table. It MUST exclude identities already declared anywhere in the catalogue and MUST keep formula and cask namespaces distinct. Failed inventory MUST be an explicit problem rather than an empty successful result. Status without `--unmanaged` MUST NOT perform this inventory.

_Conformance:_ conforming

_Verify:_ Isolated Homebrew fixtures assert inventory argv, declared filtering, missing or failing executables and no implicit inventory for ordinary status.

_Evidence:_ `rig_collect_unmanaged`, `rig_homebrew_inventory` and `tests/rig-adoption.bats` cover the built-in source.

### RIG-STATE-035 — Historical apply outcomes

Rig MUST retain a bounded versioned ledger per platform beneath `${RIG_STATE_HOME}/apply-history`, keyed by qualified declared target and provider or skill authority. It MUST store only the latest completed attempt's ordering token, UTC completion time and native exit status, without locators, arguments, output or secrets. Successful results MUST remain internal ordering watermarks, not a public success log. Ports have no apply dispatch; retired resources no longer declared in the catalogue MUST NOT acquire historical rows.

Immediately before an actual selected dispatch, Rig MUST reserve a monotonically increasing token under a short lock. It MUST publish each completed result atomically and replace a matching result only with a greater token. The lock MUST NOT span native work. An older attempt completing late MUST NOT overwrite a newer completed success or failure. Skipped, preflight-rejected, dry-run and interrupted in-flight work MUST NOT publish completed outcomes; already published results MUST survive interruption.

Retention MUST cover currently declared target/provider pairs across all profiles on the platform, with no age-based expiry. Real history writes MAY prune removed pairs; read-only commands MUST NOT prune or repair anything. Same-provider declaration edits MUST preserve explicitly historical evidence with a declaration-change caveat; replacement providers MUST NOT inherit it. The ledger MUST be limited to 4 MiB and 4096 rows, reject duplicate identities or invalid tokens, refuse unsafe paths, and preserve previous valid evidence when publication fails. Lock contention MUST be bounded and MUST NOT remove an unverified existing lock. Persistence failure MUST warn separately without changing the actual provider outcome or apply exit status.

The ledger MUST use canonical LF-terminated records and reject hidden discarded bytes rather than silently normalise damaged evidence. Configured state-home ancestors retain the existing user-selected XDG trust boundary; the state home and owned history subtree MUST reject symlinks, non-directory parents and inaccessible directories. This is not protection against an adversarial same-user replacement of trusted ancestors.

Status and doctor MUST project selected failures separately from current observations, preserving native state vocabulary and counters. Text MUST identify the evidence as historical; JSON MUST include `apply_failures` with qualified target, provider or authority, recorded time, age and native exit status, plus `historical_failure_count` and a nullable `apply_history_unavailable` reason. Historical findings MUST remain visible with `--problems` and contribute health exit status 1. Missing history MUST be neutral; malformed, unreadable or unsafe existing history MUST produce a separate unavailable-history finding and exit 1. Future timestamps MUST report clock discrepancy, never negative age.

_Conformance:_ conforming

_Verify:_ Isolated provider fixtures exercise completed failure and recovery, provider/platform/profile boundaries, independent and reversed concurrent completion, interruption, unsafe and corrupt state, bounds, privacy, clock discrepancy, and byte-preserving read-only and dry-run commands.

_Evidence:_ `src/rig/25-apply-history.bash` owns storage and shared projection; `src/rig/23-application.bash` brackets actual dispatches and `src/rig/22-observation.bash` adds historical health evidence. The 23 cases in `tests/rig-apply-history.bats` cover all dispatched target kinds and the persistence, ordering, filtering, privacy and read-only boundaries; the complete local gate passes with 353 Bats tests.

### RIG-STATE-036 — Dock folder attributes

Dock observation MUST compare declared paths and order before explicitly declared folder `view` and `display` attributes. When paths agree and attribute evidence is needed, Rig MUST read at most one `defaults export com.apple.dock -` snapshot per command and interpret it through native typed `plutil` extraction. Matching MUST use complete normalised paths, never labels, and distinguish raw paths from file URLs with exactly one URL-decoding pass. Binary and XML property lists MUST be supported without a new runtime parser dependency.

Declared view values map to native values `auto=0`, `fan=1`, `grid=2`, `list=3`; display values map to `stack=0`, `folder=1`. Omitted attributes MUST remain unconstrained. Proven differences MUST take precedence in order, then view, then display, with item-qualified details. Missing, ambiguous, duplicate, malformed or unreadable attribute evidence MUST yield `unknown` only when no declared mismatch has been proven. Observation MUST NOT apply a layout, write defaults or restart the Dock.

_Conformance:_ conforming

_Verify:_ Isolated Dock fixtures cover every declared attribute, omitted attributes, raw and encoded paths, binary/XML snapshots, ambiguity, missing tools and data, mismatch precedence, one snapshot per command, sourced command reuse and zero native mutation.

_Evidence:_ `rig_dock_observe_attributes`, typed snapshot helpers in `src/rig/20-orchestration.bash` and the command-entry reset in `src/rig/90-main.bash` implement the comparison. `tests/rig-dock-observation.bats` and `tests/rig-macos.bats` verify the boundary; disposable native-plutil fixtures independently confirm typed extraction and control-character preservation. The Dock apply body is unchanged.

### RIG-STATE-037 — Informational retired application evidence

`rig status --retired` MUST add configuration-wide retired-application evidence in text and JSON without changing active health counts, historical findings or exit status. Profile selection and `--problems` MUST NOT suppress the explicitly requested informational section. Without the flag, Rig MUST NOT probe retired locations or add retired report fields. JSON MUST add `retired_applications` only when requested, including an empty array when none are declared; filesystem paths MUST remain confined to `detail`, preserving the existing redaction contract.

_Conformance:_ conforming

_Verify:_ Compare text/JSON and existing reports without the flag; combine profile and problem filtering; remove redaction fields recursively and assert fixture paths disappear; compare doctor, apply and upgrade results independently of retained evidence.

_Evidence:_ `rig_collect_retired_applications`, `rig_retired_json`, `rig_retired_text` and `tests/rig-retired-applications.bats` verify the opt-in, redactable informational section.

### RIG-STATE-038 — Common diagnostic context

`rig diag` and `rig doctor` MUST report tool, version, proven installation mode (`local`, `release` or `unknown`), runtime-host platform and architecture, runtime version, and configuration presence; default diag MUST omit local paths and configuration values, and `--full` MUST add only executable and effective XDG paths without exposing values or secrets. Runtime-host context MUST remain distinct from selected provider platform.

_Conformance:_ conforming

_Verify:_ Isolated tests compare direct and linked checkout, copied unknown payload and Homebrew receipt provenance, fragment-only configuration, host-versus-target platform, default redaction and explicit full paths.

_Evidence:_ `rig_diagnostic_context`, text/JSON context projections and `tests/diagnostics-tables.bats` cover the shared baseline without executing providers or parsing configuration.

### RIG-STATE-039 — Explicit health coverage and counts

`rig doctor` MUST expose read-only coverage, verdict and pass/warn/fail/skipped counts using declared item checks rather than subprocess counts, MUST skip unavailable dependent selection explicitly, and MUST state that available package updates are not checked. Neutral catalogue-only and incompatible selections MUST NOT become failures. Existing doctor JSON fields MUST retain their meanings alongside additive context, verdict and checks.

_Conformance:_ conforming

_Verify:_ Parse healthy and unusable-configuration JSON, check mixed and incompatible selections, damaged history and multiple historical failures, and assert counts and explicit freshness scope.

_Evidence:_ `rig_command_doctor`, `tests/diagnostics-tables.bats`, `tests/rig.bats` and `tests/rig-apply-history.bats` cover additive health and coverage projections.

### RIG-STATE-040 — Application CLI health

Status and doctor MUST refine a present application's state with the health of its explicitly declared CLI companions, distinguishing a missing command, unavailable executable source, mismatched target, occupied destination and unsafe destination parent. A companion MUST be present only when its expected link resolves to the declared executable source; a relative installer link MAY satisfy that expectation. Reads MUST NOT repair companions or invoke their executables, and structured observations MUST agree with the human health result.

_Conformance:_ conforming

_Verify:_ Bats observes missing, healthy, dangling, non-executable, relative, wrong-target and conflicted companions through status and doctor, and compares the structured missing state without filesystem mutation.

_Evidence:_ `rig_observe_cli`, `rig_observe_tool_clis` and `tests/rig-app-clis.bats` refine existing per-tool observations without creating new catalogue entries.
