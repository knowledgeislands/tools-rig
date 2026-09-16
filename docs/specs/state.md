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

`rig status` MUST invoke only an exact declared `observe` capability and MUST NOT invoke an `apply` capability.

_Conformance:_ conforming

_Verify:_ Bats recording logs assert status calls only `observe`; unsupported adapters, capabilities, and executables produce unavailable rows without invocation.

_Evidence:_ `rig_command_status` checks adapter, capability, and executable availability before constructing an observation invocation.

### RIG-STATE-008 — Catalogue-only neutrality

`rig status` MUST report a selected catalogue-only tool with provider `-`, state `unavailable`, and detail `catalogue-only` without making that row unhealthy.

_Conformance:_ conforming

_Verify:_ Bats runs a mixed bound and catalogue-only profile and asserts exact row, summary, and exit status.

_Evidence:_ `tests/rig.bats` covers a neutral catalogue-only row in an otherwise healthy status report.

### RIG-STATE-009 — Deterministic status report

`rig status` MUST print `TOOL`, `PROVIDER`, `STATE`, and `DETAIL` columns in stable dependency order followed by fixed-order summary counters.

_Conformance:_ conforming

_Verify:_ Bats compares exact status output for a dependency graph whose lexical order differs from its execution order.

_Evidence:_ `rig_build_plan` provides stable dependency order and `rig_command_status` owns the exact table and summary.

## Application

### RIG-STATE-005 — Explicit apply

`rig apply [--profile NAME]` MUST invoke the exact `apply` capability only for bound tools selected by the resolved profile.

_Conformance:_ conforming

_Verify:_ Bats configures selected and unselected recording providers and asserts only selected work receives an apply invocation.

_Evidence:_ `rig_command_apply` executes only work produced from the resolved profile and selected bindings.

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

`rig apply` MUST validate every selected bound work unit's adapter, exact `apply` capability, and executable resolution before invoking any provider.

_Conformance:_ conforming

_Verify:_ Bats places a failure late in the selected plan and asserts every provider mutation log remains absent.

_Evidence:_ `rig_preflight_apply` traverses the complete plan before `rig_command_apply` begins its execution loop.

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
