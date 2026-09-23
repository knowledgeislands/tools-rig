# Profile and provider orchestration — RIG-ORCH

This area of the [Rig Specifications](index.md) defines profile and provider orchestration beneath the catalogue model in [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md). Provider execution follows [ADR-RIG-005](../decisions/ADR-RIG-005-provider-execution-contract.md) and the trust boundary in [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Profiles

### RIG-ORCH-001 — Configurable default profile

Rig MUST allow a user to name a default profile. In item-owned selection, every selectable declaration that omits `profiles` MUST belong to that configured profile, not to a hard-coded `default` identity or every profile.

_Conformance:_ conforming

_Verify:_ Bats tests create isolated configuration, invoke Rig without an explicit profile, and assert only configured default tools are selected.

_Evidence:_ Catalogue query and operational command tests resolve the configured default without mutating it.

### RIG-ORCH-002 — Explicit profile selection

Rig MUST allow a user to select a non-default configured profile without changing the stored default.

_Conformance:_ conforming

_Verify:_ Bats tests invoke two named profiles against the same isolated configuration and assert their resolved selections remain independent.

_Evidence:_ `rig_resolve_profile` accepts an explicit profile independently of the stored default; command tests cover `--profile` parsing.

### RIG-ORCH-018 — Bootstrap profile precedence

When the selected tool plan uses Homebrew and `[provider.homebrew]` declares `autoupdate-interval`, bootstrap MUST converge Homebrew's native autoupdate job with the bounded declared options before tool reconciliation. Dry-run MUST report the policy without invoking Homebrew. A resources-only bootstrap MUST NOT touch tool-provider policy.

Rig MUST implement bootstrap as a native staged lifecycle over one resolved profile rather than as a provider or synthetic setup tools. `rig bootstrap --profile NAME` MUST select the explicit profile; otherwise bootstrap MUST select `bootstrap-profile` when declared and fall back to `default-profile` when absent. Bootstrap MUST fully preflight configuration, external providers, available built-ins, resources, and the Homebrew manifest before mutation. When a selected Homebrew `mise` tool or mise `node` tool is the declared prerequisite for an unavailable built-in manager, bootstrap MAY defer only that manager's executable check, MUST report the stage, and MUST verify or materialise it before the complete reconciliation pass. No arbitrary or external provider may use deferred readiness.

_Conformance:_ conforming

_Verify:_ Bats selects distinct default and bootstrap profiles, proves explicit precedence and default fallback, records manager availability and bounded Homebrew → mise → npm staging before dependent work, and proves no bootstrap provider or setup-tool declaration is required.

_Evidence:_ `rig_command_bootstrap`, `rig_preflight_apply`, and `rig_bootstrap_preflight_homebrew_manifest` implement native profile selection and complete preflight; `bootstrap selects its declared profile with explicit and default fallbacks` and `bootstrap preflights later providers before manifest mutation` cover precedence, availability, ordering, and failure boundaries.

### RIG-ORCH-007 — Profile composition

Rig MUST allow a profile to inherit other declared profiles explicitly and MUST expand required tool relationships transitively. Resolution MUST fail when a selected tool supports the active platform but one of its required tools does not.

_Conformance:_ conforming

_Verify:_ Bats tests compose nested profiles and required tools, assert one de-duplicated resolved tool set, and reject an active-platform tool with an unavailable required tool.

_Evidence:_ `tests/rig.bats` resolves nested profiles and transitive requirements into one sorted set and rejects incompatible required tools.

### RIG-ORCH-008 — Invalid profile graph

Rig MUST reject unknown profile references, unknown tool references, and profile or required-tool cycles before invoking a provider.

_Conformance:_ conforming

_Verify:_ Bats table tests exercise every invalid graph class and assert status 2 with an empty provider-call log.

_Evidence:_ `rig_validate_cycles` rejects profile and required-tool cycles before resolution; `tests/rig.bats` covers cycles and unknown references.

## Providers

### RIG-ORCH-003 — Native provider authority

Rig MUST delegate observation and state changes to the selected provider rather than maintain a competing package or installation database.

_Conformance:_ conforming

_Verify:_ Bats tests substitute recording providers and assert Rig forwards native kind, locator, and literal arguments without interpreting provider state.

_Evidence:_ Provider observation and application delegate native state while retaining no persistent observed installation database.

### RIG-ORCH-004 — Capability-aware actions

Rig MUST derive a built-in provider's supported operations from its internal registry. For an external provider, Rig MUST report a missing allowed observation as unavailable without invocation and MUST reject a missing allowed mutation during full-plan preflight before mutation. Configuration MUST NOT grant or remove built-in operations.

_Conformance:_ conforming

_Verify:_ Bats tests built-ins with no capability declarations and removes exact external `observe` and `apply` allowances to assert status 1 or preflight status 2 respectively with no extension invocation.

_Evidence:_ `rig_provider_has_capability` derives built-in operations from the registry and reads external allow-lists only after model validation; `tests/rig-model-boundaries.bats` proves configuration cannot grant or remove built-in operations.

### RIG-ORCH-005 — Dependency order

Rig MUST order selected bound-tool work dependency-first, using bytewise tool identity to break ties.

_Conformance:_ conforming

_Verify:_ Bats configures a graph whose dependency order differs from lexical order and asserts the exact invocation sequence.

_Evidence:_ `rig_build_plan` emits a stable dependency-first work plan consumed by status and apply.

### RIG-ORCH-006 — Initial provider classes

Rig MUST provide built-in Homebrew, uv, mise, npm, chezmoi, direct-download, launchd, macOS application inventory, macOS defaults, and semantic Dock integrations without provider declarations. It MUST support providers explicitly declared with `adapter = "custom"` without requiring an unselected extension's executable. A selected custom provider that omits `executable` MUST resolve exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`; an explicit executable MUST take precedence.

_Conformance:_ conforming

_Verify:_ Bats tests exercise every built-in through fakes without provider tables, exercise explicit and exact conventional extension executables, and run unrelated profiles while unselected native and extension executables are absent.

_Evidence:_ `rig_builtin_provider_adapter`, `rig_provider_executable`, `rig_custom_provider_executable`, `rig_launchd_observe_resource`, and `rig_macos_application_inventory` implement the provider classes; `canonical built-in providers are implicit and infer their capabilities`, `custom provider default executable covers every trust-boundary invocation`, and the launchd and typed macOS Bats tests cover each class.

### RIG-ORCH-017 — Built-in native command matrix

Built-in adapters MUST preserve each provider argument and tool `install.argument` as one literal native argument and MUST use the following command matrix, where configured provider arguments precede the native command and installation arguments precede the locator:

- Homebrew `formula`: `brew list --formula --versions OBSERVED_IDENTITY` to observe and `brew install --formula LOCATOR` to apply.
- Homebrew `cask`: `brew list --cask --versions OBSERVED_IDENTITY` to observe and `brew install --cask LOCATOR` to apply.
- Homebrew `mas`: `mas list` with exact numeric identity matching to observe and `mas install LOCATOR` to apply.
- uv `tool`: `uv tool list` with exact package identity matching to observe and `uv tool install LOCATOR` to apply.
- mise `tool`: `mise which LOCATOR` to observe and `mise install LOCATOR` to apply.
- npm `global`: `npm list --global --depth=0 LOCATOR` to observe and `npm install --global LOCATOR` to apply.
- chezmoi `target`: `chezmoi status --path-style=absolute -- LOCATOR` to observe and `chezmoi apply -- LOCATOR` to apply.
- direct-download `executable`: local destination and checksum inspection to observe; `curl --fail --location --proto =https --proto-redir =https --silent --show-error --output TEMP HTTPS_LOCATOR`, SHA-256 verification, executable mode, and sibling rename to apply.

For a Homebrew formula or cask, `OBSERVED_IDENTITY` MUST be the terminal token of a possibly tap-qualified locator and `LOCATOR` MUST remain the complete authored value. An explicit documented provider `executable` override MUST replace the matrix default. Built-in observation and application MUST be available from Rig's provider registry without a capability declaration.

_Conformance:_ conforming

_Verify:_ Bats fake executables record exact native argument boundaries for every built-in kind, including provider and installation arguments containing spaces.

_Evidence:_ `rig_prepare_builtin_invocation`, `rig_observe_provider`, `rig_apply_provider`, and `rig_apply_direct_download` implement the native matrix; `built-in adapters observe dry-run and apply with exact native commands`, Homebrew identity, uv extras, and direct-download Bats tests compare exact invocation boundaries.

### RIG-ORCH-009 — Platform installation selection

Rig MUST select the tool's single declared installation when materialisation is requested on a compatible active platform and MUST reject an incompatible installation. Installation metadata with no `install.platforms` value or value `any` is compatible with every platform; other platform values match exactly.

_Conformance:_ conforming

_Verify:_ Bats tests resolve compatible and `any` tool installations, then assert incompatible installation metadata fails before provider invocation.

_Evidence:_ `tests/rig.bats` covers exact, `any`, incompatible, and catalogue-only installation declarations without invoking providers unexpectedly.

### RIG-ORCH-010 — Literal extension arguments

Rig MUST invoke an external provider as one resolved executable with each configured provider and tool installation argument preserved as a literal argument boundary. Resolution MUST use only the explicit executable or exact `${RIG_DATA_HOME}/providers/PROVIDER-ID` conventional path and MUST NOT search, copy, generate, or recursively discover executables.

_Conformance:_ conforming

_Verify:_ Bats tests record extension arguments containing spaces and shell metacharacters across every invocation surface, exercise explicit and exact conventional executable resolution, and assert no shell interpretation or directory discovery occurs.

_Evidence:_ `rig_custom_provider_executable` resolves one explicit or conventional path and `rig_prepare_provider_invocation` constructs a Bash indexed argument array; Bats verifies paths, spaces, globs, and command syntax remain inert.

### RIG-ORCH-011 — Ordered failure boundary

After a work unit fails, Rig MUST suppress only its transitive dependants, identify a blocking tool when one exists, and continue independent work. A resource-local preflight finding MUST fail only that resource, MUST prevent its invocation, and MUST NOT block an independent tool or resource. Configuration, provider trust, executable availability, platform, and shared state-boundary failures MUST remain fatal before `rig apply` and `rig bootstrap` mutation, because those commands converge a dependency-ordered plan. `rig update` and `rig maintain` dispatch independent per-task operations and instead bound an availability finding to its own task under RIG-ORCH-024.

_Conformance:_ conforming

_Verify:_ Bats fails a prerequisite and a resource-local preflight check, then asserts dependants are skipped, the locally failed resource is not invoked, and independent work completes; shared preflight failures still prevent every mutation.

_Evidence:_ `rig_plan_blocker`, `rig_preflight_apply`, and apply result arrays retain failure detail and bound suppression to the failed branch; `tests/rig.bats` and `tests/rig-macos.bats` cover dependency and resource-local boundaries.

### RIG-ORCH-014 — Versioned extension-provider protocol

For external tool observation and application, Rig MUST invoke the explicitly declared provider as `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER TOOL KIND LOCATOR [INSTALL_ARGUMENT ...]`, with `VERB` exactly `observe` or `apply`. Rig MUST insert `rig-provider-v1`; it MUST NOT accept that marker from user configuration or pass it to a built-in provider. Publication uses the separate fixed `publish` variant specified by RIG-PUB-007.

_Conformance:_ conforming

_Verify:_ Bats records every argument for observation and application and compares the version marker, verb, identities, installation data, and argument order.

_Evidence:_ `rig_prepare_custom_invocation` and `rig_prepare_provider_invocation` implement the extension installation protocol, while recording-provider tests compare its argument boundaries.

### RIG-ORCH-015 — Extension observation response boundary

Rig MUST accept external-provider observation stdout only as one supported state token, mapping invalid output to `unknown` with `invalid-response` and a non-zero exit to `unknown` with `exit:N`.

_Conformance:_ conforming

_Verify:_ Bats exercises every state token, invalid, empty, multiline, and non-zero provider responses.

_Evidence:_ `rig_command_status` parses the isolated protocol channel and retains provider-native failure status as detail.

### RIG-ORCH-016 — Extension application diagnostic boundary

Rig MUST reserve stdout for its deterministic application report and route external-provider application stdout and stderr to Rig's stderr.

_Conformance:_ conforming

_Verify:_ Bats redirects command channels separately and asserts provider diagnostics never contaminate Rig's stdout table and summary.

_Evidence:_ `rig_command_apply` redirects provider stdout to stderr while leaving provider stderr on the same diagnostic channel.

### RIG-ORCH-019 — Provider progress channel

Operational configuration, resolution, planning, preflight, observation, materialisation, lifecycle, publication, export, and cleanup phases MUST report progress on stderr. With terminal stderr, automatic progress MUST rewrite one fixed-width ASCII bar for the active phase and terminate it with one truthful phase summary. Redirected progress forced by `RIG_PROGRESS=always`, and progress explicitly selected by `RIG_PROGRESS=lines`, MUST retain stable line-oriented events. Enumerable work MUST retain its declared denominator, MUST leave the completed count unchanged while an item is running, and MUST advance it exactly once only after that item has succeeded, skipped, or failed; the bar MUST NOT imply elapsed-time completion. Consequential work MUST disclose declaration, manifest, or provider-wide scope before invocation. Failure and interruption MUST terminate an active phase truthfully with completed and outcome counts, including signal-compatible exit status. Rig-authored progress MUST use fixed phase terms and validated public identifiers, MUST NOT expose paths, locators, arguments, environment values, titles, observed details, credentials, or native output, and MUST keep deterministic reports and exported data byte-stable on stdout. The transient line MUST stay within the terminal's width, eliding the item detail rather than wrapping, and each redraw MUST erase the previously drawn line in full so no fragment of a longer line survives beside a shorter one. Native diagnostics MAY interrupt the transient line and the next Rig event MUST redraw it. `RIG_PROGRESS=never` MUST suppress progress, and the default `auto` mode MUST keep declaration-only queries quiet.

_Conformance:_ conforming

_Verify:_ Bats exercises a pseudo-terminal and redirected stdout and stderr separately; proves bar rewriting, width-bounded redraws that leave no residue, durable line events, completed-not-started counts, scope-before-invocation ordering, successful, skipped, failed, and interrupted termination; injects authored payload sentinels; forces and suppresses progress; and proves command reports are unchanged.

_Evidence:_ `rig_progress_start`, `rig_progress_begin`, `rig_progress_result`, `rig_progress_finish`, `rig_progress_fail`, and `rig_progress_interrupted` implement the terminal event contract independently of provider diagnostics; focused progress tests in `tests/rig.bats` cover count truth, privacy, scope, failure, interruption, and forced, automatic, and suppressed modes.

## Declared provider actions

### RIG-ORCH-012 — Explicit action dispatch

`rig run PROVIDER ACTION` MUST resolve either one built-in operation registered by Rig or one action explicitly declared for an external provider, verify that it supports the active platform, and invoke it with literal arguments. It MUST preserve the provider's native outcome and MUST reject invalid input before invocation. Built-in operations MUST NOT require action declarations.

_Conformance:_ conforming

_Verify:_ Bats tests use recording providers to assert exact operation selection, platform and capability validation, invocation boundaries, exit status, and no invocation after validation failure.

_Evidence:_ `rig_command_run_launchd_action` dispatches registered built-in launchd operations while `rig_command_run_action` and `rig_prepare_operation_invocation` dispatch declared external actions; `built-in launchd observes applies and retires declared resources` and `run dispatches declared observe and mutate operations with literal arguments` cover selection, validation, literal arguments, and native outcomes.

### RIG-ORCH-013 — Bounded caller arguments

`rig run PROVIDER ACTION [-- ARGUMENT...]` MUST accept a caller argument only when it exactly matches one `allowed-arguments` array item, unless the external action explicitly declares `argument-policy = "provider"`. Under provider policy Rig MUST pass literal caller arguments to that one declared external provider, which owns domain validation. Rig MUST append accepted caller arguments literally without shell interpretation. An external action with neither policy nor `allowed-arguments` MUST reject all caller arguments.

_Conformance:_ conforming

_Verify:_ Bats tests cover allowed and rejected arguments containing spaces and shell metacharacters, exact-match behaviour, argument order, and an empty provider-call log for rejected input.

_Evidence:_ `rig_operation_allows_argument` performs literal equality checks before dispatch; `rig_command_run` appends accepted caller arguments without evaluation; `tests/rig.bats` covers rejection and literal boundary preservation.

## Operational resources

### RIG-ORCH-020 — Resource profile resolution

Composed profiles MUST select services, scheduled jobs, settings, and Dock layouts in addition to tools. Every managed resource `requires` entry MUST select that tool and its transitive requirements for the active platform. Resource work MUST be ordered deterministically after the dependency-ordered tool plan; an unavailable or failed required tool MUST suppress only its dependent resource.

_Conformance:_ conforming

_Verify:_ Bats tests select resources directly and through composed profiles, assert required tools enter the plan, compare stable resource ordering, and exercise dependent and independent failures.

_Evidence:_ `rig_select_profile`, `rig_select_resource`, `rig_sort_selected_resources`, and `rig_resource_blocker` resolve and order resources after tools; `operational resources resolve through profiles and remain inert in queries`, `apply and bootstrap scopes stage tools and resources independently`, and resource failure tests cover selection and suppression.

### RIG-ORCH-021 — Extension resource protocol

For external resource observation, application, and retirement, Rig MUST invoke `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER RESOURCE-ID RESOURCE-KIND LOCATOR [FIELD=VALUE ...]`. `VERB` MUST be `observe-resource`, `apply-resource`, or `retire-resource`. Selected declarations MUST use ordered literal field records, repeating array keys in declaration order and supplying documented policy defaults. External providers MUST allow the exact corresponding operation. Observation accepts only the standard five state tokens. Built-in providers MUST receive equivalent resolved data through internal calls without `rig-provider-v1`.

_Conformance:_ conforming

_Verify:_ Recording-provider Bats tests assert exact verbs, identities, repeated key order, metacharacter and leading-dash boundaries, default fields, capability rejection, observation tokens, and native failure detail.

_Evidence:_ `rig_append_resource_fields`, `rig_prepare_resource_invocation`, `rig_observe_resource`, `rig_apply_resource`, and `rig_retire_resource` implement the external protocol; `resource status and dry-run use literal provider records without mutation` and `resource apply records managed identities and retires deselected entries` compare its literal records and outcomes.

### RIG-ORCH-022 — Resource-aware actions

An external action declaring `resource-kinds` MUST use provider argument policy and MUST consume its first caller argument as a qualified selected managed resource. Rig MUST reject an unknown kind, identity, foreign-provider resource, or resource not selected by the default profile. The extension invocation MUST append `resource-v1 KIND ID LOCATOR [FIELD=VALUE ...] --` before remaining literal caller arguments. Built-in resource operations MUST resolve the same qualified identity without requiring an action table or extension payload.

_Conformance:_ conforming

_Verify:_ Bats tests cover both kinds, selected and rejected targets, provider ownership, complete literal declaration payloads, caller arguments after the separator, and unchanged ordinary actions.

_Evidence:_ `rig_action_allows_resource_kind` and `rig_command_run_action` validate a qualified selected resource and append its `resource-v1` payload; `resource-aware actions receive selected declaration before caller arguments` and `run dispatches declared observe and mutate operations with literal arguments` cover both dispatch forms.

### RIG-ORCH-023 — Built-in macOS resource adapters

On macOS, Rig MUST observe, apply, and retire launchd services and scheduled jobs through its built-in launchd adapter; MUST observe and apply typed macOS defaults through its built-in settings adapter; MUST observe and apply semantic Dock order through its built-in Dock adapter; and MUST inventory native application bundles through its built-in read-only application source. These integrations MUST require no provider or action declarations and MUST remain unavailable without mutation on other platforms.

_Conformance:_ conforming

_Verify:_ Bats fakes native macOS commands and filesystem surfaces to compare exact observation, dry-run, apply, retirement, inventory, platform-gating, and literal argument behaviour without any external-provider executable or provider table.

_Evidence:_ `rig_launchd_observe_resource`, `rig_launchd_apply_resource`, `rig_launchd_retire_resource`, `rig_setting_observe`, `rig_setting_apply`, `rig_dock_observe`, `rig_dock_apply`, and `rig_macos_application_inventory` implement the four built-in surfaces; the built-in launchd test and all four `tests/rig-macos.bats` tests cover reconciliation and inventory without extension dispatch.

### RIG-ORCH-024 — Explicit provider lifecycle

`rig update` MUST advance selected Homebrew, uv, mise, and npm tools through fixed native operations; `rig maintain` MUST perform at most one fixed maintenance work item for each selected provider among those four; and `rig capture PROVIDER` MUST refresh only a declared Homebrew manifest through its fixed native capture operation. Rig MUST derive these capabilities from its built-in registry, MUST NOT accept configuration-defined lifecycle commands or lifecycle capability grants, and MUST report unsupported selected providers without dispatching them.

A lifecycle preflight finding bounded to one selected task — an unavailable provider or Skills CLI executable, an unreadable declared manifest, or a skill that its authority cannot advance — MUST report that task as `unavailable` with its finding detail, MUST prevent only that task's invocation, and MUST NOT prevent an independent task from running; the run MUST complete every other selected task and MUST return a non-zero status. `rig capture PROVIDER` names one explicit target and MUST keep the same finding fatal.

_Conformance:_ conforming

_Verify:_ Bats selects duplicate and unsupported provider work, compares exact native update, maintenance, and capture invocations, proves an unavailable provider or Skills CLI executable is reported per task while independent work still runs, and proves configuration cannot redirect lifecycle dispatch through an external provider.

_Evidence:_ `rig_lifecycle_supported`, `rig_collect_lifecycle_tasks`, `rig_execute_lifecycle_task`, and `rig_command_capture` implement the fixed lifecycle registry and deduplicated dispatch, while `rig_lifecycle_unavailable` and `rig_run_lifecycle_tasks` bound a preflight finding to its own task; `tests/rig-lifecycle.bats` covers each supported provider, unsupported reporting, per-task unavailability, and Homebrew manifest capture, and `tests/rig-skills.bats` covers an unavailable Skills CLI.

### RIG-ORCH-025 — Artifact lifecycle ownership

Rig MUST treat declared artifacts as observation-only state. `rig apply`, `rig bootstrap`, `rig update`, and `rig maintain` MUST NOT derive or invoke an artifact generator from configuration. Provider lifecycle work MAY create an artifact as a native side effect, but creation, update, and removal remain the native tool's responsibility and are not separate Rig work items.

_Conformance:_ conforming

_Verify:_ Bats proves artifact declarations do not add provider invocations, progress steps, or dry-run work and that unknown artifact lifecycle fields fail closed.

_Evidence:_ `rig_command_apply` and `rig_run_lifecycle_tasks` operate only on provider work; `tests/rig-artifacts.bats` covers observation independently.

### RIG-ORCH-026 — Complete profiles and safe views

Rig MUST resolve item membership through the selected profile and its explicit inheritance closure, then close tool dependencies transitively. A complete profile MUST be eligible for mutation. A view MUST reject `apply`, `bootstrap`, `update`, `maintain`, and selected-resource mutation; MUST NOT inherit a complete profile; and MUST reject a dependency that has not explicitly opted into the view closure.

_Conformance:_ conforming

_Verify:_ Bats compares complete, inherited, and public view selections, then attempts every profile-aware mutating lifecycle and an implicit dependency disclosure.

_Evidence:_ `rig_resolve_profile`, `rig_validate_view_closure`, and the lifecycle command gates implement the distinction; `tests/rig-profile-authority.bats` exercises resolution and rejection.

### RIG-ORCH-027 — Resolved native-target conflicts

Rig MUST reject two selected services or scheduled jobs sharing a provider locator, two selected settings sharing a provider domain and key, or more than one selected Dock layout for the same provider. It MUST permit those alternatives to coexist when no resolved profile selects them together.

_Conformance:_ conforming

_Verify:_ Bats resolves each mutually exclusive alternative successfully and a composed contradictory selection unsuccessfully for every native target class.

_Evidence:_ `rig_resource_native_target` and `rig_validate_selected_native_targets` validate only `RIG_SELECTED_RESOURCE_SECTIONS`; `tests/rig-profile-authority.bats` covers locator, setting, and Dock conflicts.

### RIG-ORCH-028 — Provider operation scope disclosure

Every mutating lifecycle report MUST identify work as declaration-scoped, manifest-scoped, or provider-wide before provider execution. Dry-run and live output MUST use the same scope classification.

_Conformance:_ conforming

_Verify:_ Bats inspects apply, bootstrap, update, maintain, and capture output before and after provider execution.

_Evidence:_ `rig_command_apply`, `rig_command_bootstrap`, `rig_run_lifecycle_tasks`, and `rig_command_capture` emit operation scope before mutation; lifecycle and profile-authority Bats assert the stable report prefixes.

### RIG-ORCH-029 — Deterministic platform variant selection

For a selected tool with `variant.ID.*` declarations, Rig MUST select exactly one variant matching the active platform before installation or artifact observation. A matching variant MUST contribute its installation and artifact data to the existing tool identity; it MUST NOT create another catalogue item. Profile resolution MUST reject zero or multiple matches before provider work. Platform-neutral publication resolution MUST omit all installation and artifact variant data rather than selecting host-private materialisation details.

_Conformance:_ conforming

_Verify:_ Resolve one tool on macOS and Linux, compare selected provider installations and observed artifacts, reject uncovered and overlapping platforms, and inspect public output.

_Evidence:_ `rig_select_tool_variants`, `rig_resolve_profile`, and `rig_observe_tool_artifacts` consume one selected variant; `tests/rig-human-config.bats` covers both platforms and publication isolation.

### RIG-ORCH-030 — Resource dependency order and failure boundary

Rig MUST close selected qualified resource dependencies transitively and order the selected resource plan topologically. When more than one ready resource exists, bytewise section identity MUST provide deterministic order. A failed or skipped resource MUST suppress its transitive resource dependants with a qualified `blocked-by` detail while independent resources continue. Tool requirements MUST remain before the resource graph. A resource dependency MUST NOT grant provider capability or introduce executable configuration.

_Conformance:_ conforming

_Verify:_ Bats selects a cross-kind dependency chain in declaration-independent order, injects a dependency failure, and checks that only transitive dependants are blocked.

_Evidence:_ `rig_select_resource`, `rig_sort_selected_resources`, `rig_resource_blocker`, and `rig_observe_resource_plan` implement closure, order, and propagation; `tests/rig-human-config.bats` covers the graph.

### RIG-ORCH-031 — Read-only macOS listener observation

On macOS, Rig MUST inspect selected private TCP allocations through one cached built-in listener snapshot for each command, MUST aggregate IPv4 and IPv6 records to the least-safe observed scope, and MUST optionally report undeclared listeners through `rig status --unmanaged`. On other platforms or when the native source fails, Rig MUST report observation unavailable. Rig MUST NOT open, reserve, close, kill, or otherwise mutate a socket, and port declarations MUST NOT enter apply plans or reconciliation receipts.

_Conformance:_ conforming

_Verify:_ Bats uses a deterministic `lsof -F` fake, asserts one exact read-only invocation across selected and unmanaged reporting, proves no real sockets are opened, and verifies apply and dry-run omit ports.

_Evidence:_ `rig_load_listeners`, `rig_print_unmanaged_listeners`, and private-port tests implement the bounded built-in source and no-mutation boundary.

### RIG-ORCH-032 — User-level skill authority lifecycle

Rig MUST materialise full apply and bootstrap plans in tools → skills → resources order and MUST expose `skills` as an explicit scope. Skills CLI operations MUST invoke a deliberately installed `skills` executable directly with literal arguments and bounded JSON parsing, never unqualified `npx`; KI MUST NOT be invoked; local authority MUST canonicalise real non-symlink source and runtime roots, enforce component containment, revalidate immediately before mutation, and create only a missing leaf symlink without replacing a collision; runtime and plugin authorities MUST be observation-only. Only `rig update` MAY advance selected Skills CLI skills. Profile deselection, `rig maintain`, and `rig clean` MUST NOT update or remove skills.

_Conformance:_ conforming

_Verify:_ Isolated Bats fakes prove literal CLI arguments, no KI invocation, canonical local containment and collision preservation, tools → skills → resources ordering, explicit update, and absence of removal in apply, bootstrap, update, maintain, and clean.

_Evidence:_ `rig_preflight_skills`, `rig_apply_skill`, `rig_run_skill_apply`, `rig_collect_lifecycle_tasks`, and `tests/rig-skills.bats` implement and verify the lifecycle.

### RIG-ORCH-033 — Equivalent observation snapshots

Within one command, Rig MAY reuse a built-in provider observation only when the executable and every literal native argument are identical. Reuse MUST remain in memory, preserve each item's dependency and artifact evaluation and progress step, MUST NOT apply to custom-provider observations, and MUST NOT persist provider state as a competing authority.

_Conformance:_ conforming

_Verify:_ Bats supplies two uv tools whose exact native observation command is identical, proves one invocation, and verifies independent exact-identity results for both tools.

_Evidence:_ `rig_capture_observation_invocation` keys the command-local snapshot by executable and length-delimited literal arguments; `tests/rig-performance.bats` covers reuse and per-tool interpretation.
