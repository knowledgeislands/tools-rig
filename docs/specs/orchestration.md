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

### RIG-ORCH-018 — Declared apply prerequisites

Apply MUST preflight the selected plan before mutation and MAY defer only a missing built-in manager with a selected, explicitly required supported prerequisite. Homebrew itself MUST already be available. A declared Homebrew mise prerequisite and a declared mise node prerequisite MAY make later mise and npm work available; Rig MUST recheck availability before dependent dispatch and MUST NOT suppress unrelated preflight failures. Targeted apply MUST NOT expand to unrelated manager declarations. Rig MUST NOT read a Brewfile or manage Homebrew autoupdate policy.

_Conformance:_ conforming

_Verify:_ Isolated Bats fixtures exercise successful, invalid and dry-run behavior without changing the live workstation.

_Evidence:_ `rig_apply_provider_prerequisite`, `rig_preflight_apply` and `tests/rig-bootstrap-staging.bats` cover selected closure, staging, rechecks and failures.

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

After a work unit fails, Rig MUST suppress only its transitive dependants, identify a blocking tool when one exists, and continue independent work. A resource-local preflight finding MUST fail only that resource, MUST prevent its invocation, and MUST NOT block an independent tool or resource. Configuration, provider trust, executable availability, platform, and shared state-boundary failures MUST remain fatal before `rig apply` mutation, because those commands converge a dependency-ordered plan. `rig upgrade` dispatch independent per-task operations and instead bound an availability finding to its own task under RIG-ORCH-024.

_Conformance:_ conforming

_Verify:_ Bats fails a prerequisite and a resource-local preflight check, then asserts dependants are skipped, the locally failed resource is not invoked, and independent work completes; shared preflight failures still prevent every mutation.

_Evidence:_ `rig_plan_blocker`, `rig_preflight_apply`, and apply result arrays retain failure detail and bound suppression to the failed branch; `tests/rig.bats` and `tests/rig-macos.bats` cover dependency and resource-local boundaries.

### RIG-ORCH-014 — Versioned extension-provider protocol

For external tool observation and application, Rig MUST invoke the explicitly declared provider as `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER TOOL KIND LOCATOR [INSTALL_ARGUMENT ...]`, with `VERB` exactly `observe` or `apply`. Rig MUST insert `rig-provider-v1`; it MUST NOT accept that marker from user configuration or pass it to a built-in provider.

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

Operational configuration, resolution, planning, preflight, observation, materialisation, lifecycle and export phases MUST report progress on stderr. On supported terminal stderr with usable geometry of at least eight rows and sixty columns, automatic progress MUST use a width-bounded two-line bottom footer for Rig-owned phases and single native-capable items, containing command, resolved selection (or pending selection), phase, completed/total work, qualified target and phase-local outcome counts. Multi-item native-capable phases MUST use line events to avoid repeatedly reserving footer rows in scrollback. The footer MUST remain present only while Rig owns the terminal; before a native-capable item, including observation or preflight, Rig MUST clear its owned rows, restore full scrolling margins and a safe cursor position, and disclose the item and consequential scope in a durable header. The native invocation MUST retain its stdin, direct diagnostic output and exit semantics; Rig MUST NOT mediate or redraw over that execution. The footer MAY return only after the semantic item returns. Native output lacking a final newline MAY be followed by a separating newline without inspecting or altering the native stream.

Redirected stderr, unsupported or dumb terminals, unavailable geometry and insufficient dimensions MUST use stable line-oriented events. Explicit `RIG_PROGRESS=lines` MUST retain those events, `always` MAY enable declaration-query progress, `never` MUST suppress Rig-authored progress, and automatic declaration-only queries MUST remain quiet. Geometry MUST be re-evaluated at safe rendering boundaries, without asynchronous native-time redraw, alternate-screen use, cursor hiding, terminal-mode changes or additional runtime dependencies. Where resize or reflow makes old footer coordinates uncertain, Rig MUST restore margins without erasing uncertain content and MAY leave prior footer text in scrollback. Configuration-group exit, ungrouped phase completion, failure and handled HUP/INT/TERM MUST restore terminal ownership, including in buffered-report subprocesses; uncatchable termination is outside that guarantee.

Complete, failure-free phases that remain in footer mode MUST finish without a durable success summary. Failed, interrupted, incomplete and failed-item phases MUST retain truthful summaries, as MUST phases using line output or falling back to it. Consecutive owned configuration phases MUST share one footer reservation rather than accumulate per-phase blank rows. This grouping MUST end on every configuration-loader return and MUST NOT retain terminal ownership across native work or final reports.

Enumerable work MUST retain its declared denominator, leave completed counts unchanged while running, and advance exactly once after success, skip or failure. Counts MUST NOT imply elapsed-time completion. Failure and interruption MUST produce truthful phase counts and preserve signal-compatible exit status. Rig-authored labels MUST use fixed phase terms and validated public identifiers, never arbitrary paths, locators, arguments, environment payloads, titles, observed details, credentials or native output. Reports and exported data MUST remain byte-stable independently of display mode.

_Conformance:_ conforming

_Verify:_ Isolated Bats and PTY fixtures compare stdout and stderr separately; prove bottom anchoring, width bounds, resize and fallback, native handoff including ANSI and no-final-newline diagnostics, nested suspension, counts, privacy, scope, terminal restoration, interruption and unchanged text/JSON reports across the public commands. Configuration-group fixtures compare one versus several phases for fixed spacing, quiet successful completion and cleanup on errors, mode changes and group return.

_Evidence:_ `rig_progress_footer_render`, `rig_progress_suspend`, `rig_progress_resume` and `rig_progress_cleanup` implement bounded terminal ownership; native-capable phases yield by default, with explicit owned configuration/resolution phases. `rig_progress_end` keeps successful footer completion transient, while the scoped `rig_load_config` wrapper reuses one reservation and guarantees cleanup. Isolated terminal tests in `tests/rig-progress.bats` and output-contract groups in `tests/rig-output-contract.bats` cover the interactive and report-producing commands, including a controlling-terminal prompt and unchanged native failure status. The fixture-only screen model is bounded evidence, not universal terminal emulation.

## Declared provider actions

### RIG-ORCH-012 — ~~Explicit action dispatch~~ (deprecated)

The public generic action runner is withdrawn. Native tools own imperative operations; retained internal helpers and validated action metadata do not create a supported CLI entry point.

### RIG-ORCH-013 — ~~Bounded caller arguments~~ (deprecated)

The public generic action runner is withdrawn. Native tools own imperative operations; retained internal helpers and validated action metadata do not create a supported CLI entry point.

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

_Evidence:_ `rig_append_resource_fields`, `rig_prepare_resource_invocation`, `rig_observe_resource`, `rig_apply_resource`, and `rig_retire_resource` implement the external protocol; `resource status and dry-run use literal provider records without mutation` and `resource apply records managed identities and retires deleted declarations` compare its literal records and outcomes.

### RIG-ORCH-022 — ~~Resource-aware actions~~ (deprecated)

The public generic action runner is withdrawn. Native tools own imperative operations; retained internal helpers and validated action metadata do not create a supported CLI entry point.

### RIG-ORCH-023 — Built-in macOS resource adapters

On macOS, Rig MUST observe, apply, and retire launchd services and scheduled jobs through its built-in launchd adapter; MUST observe and apply typed macOS defaults through its built-in settings adapter; MUST observe and apply semantic Dock order through its built-in Dock adapter; and MUST inventory native application bundles through its built-in read-only application source. These integrations MUST require no provider or action declarations and MUST remain unavailable without mutation on other platforms. Every rendered property list MUST open with a comment naming Rig and the declaration it was rendered from, and a resource MAY declare `associated-applications` whose bundle identifiers Rig renders as `AssociatedBundleIdentifiers` for the platform to present as it chooses. Replacing a loaded resource MUST NOT leave it unloaded: Rig MUST observe that the native domain has released the resource before it loads the replacement, and MUST report a wait that exceeds its bound as a resource failure rather than loading over a resource that is still terminating.

_Conformance:_ conforming

_Verify:_ Bats fakes native macOS commands and filesystem surfaces to compare exact observation, dry-run, apply, retirement, inventory, platform-gating, and literal argument behaviour without any external-provider executable or provider table.

_Evidence:_ `rig_launchd_observe_resource`, `rig_launchd_apply_resource`, `rig_launchd_retire_resource`, `rig_setting_observe`, `rig_setting_apply`, `rig_dock_observe`, `rig_dock_apply`, and `rig_macos_application_inventory` implement the four built-in surfaces; `rig_launchd_render_plist` emits the ownership comment and the associated bundle identifiers; `rig_launchd_unload` waits for the domain to release a label before `rig_launchd_apply_resource` bootstraps its replacement; the built-in launchd test and all four `tests/rig-macos.bats` tests cover reconciliation and inventory without extension dispatch.

### RIG-ORCH-024 — Declaration-scoped upgrades

`rig upgrade` MUST advance selected Homebrew, uv, mise and npm tools and supported Skills CLI skills through fixed native operations. It MUST NOT invoke Homebrew Bundle or provider-wide maintenance. Unavailable executables and unsupported operations MUST remain visible per task, while independent work continues. Native dependencies MAY change as part of a declared provider operation; Rig MUST NOT remove unknown packages or dispatch a second package list.

_Conformance:_ conforming

_Verify:_ Isolated Bats fixtures exercise successful, invalid and dry-run behavior without changing the live workstation.

_Evidence:_ `rig_collect_lifecycle_tasks`, `rig_execute_lifecycle_task`, `tests/rig-lifecycle.bats` and `tests/rig-skills.bats` cover declaration-scoped dispatch.

### RIG-ORCH-025 — Artifact lifecycle ownership

Rig MUST treat declared artifacts as observation-only state. `rig apply` and `rig upgrade` MUST NOT derive or invoke an artifact generator from configuration. Provider lifecycle work MAY create an artifact as a native side effect, but creation, update, and removal remain the native tool's responsibility and are not separate Rig work items.

_Conformance:_ conforming

_Verify:_ Bats proves artifact declarations do not add provider invocations, progress steps, or dry-run work and that unknown artifact lifecycle fields fail closed.

_Evidence:_ `rig_command_apply` and `rig_run_lifecycle_tasks` operate only on provider work; `tests/rig-artifacts.bats` covers observation independently.

### RIG-ORCH-026 — Complete profiles and safe views

Rig MUST resolve item membership through the selected profile and its explicit inheritance closure, then close tool dependencies transitively. A complete profile MUST be eligible for mutation. A view MUST reject `apply`, `upgrade`, and capture proposals; MUST NOT inherit a complete profile; and MUST reject a dependency that has not explicitly opted into the view closure.

_Conformance:_ conforming

_Verify:_ Bats compares complete, inherited, and public view selections, then attempts every profile-aware mutating lifecycle and an implicit dependency disclosure.

_Evidence:_ `rig_resolve_profile`, `rig_validate_view_closure`, and the lifecycle command gates implement the distinction; `tests/rig-profile-authority.bats` exercises resolution and rejection.

### RIG-ORCH-027 — Resolved native-target conflicts

Rig MUST reject two selected services or scheduled jobs sharing a provider locator, two selected settings sharing a provider domain and key, or more than one selected Dock layout for the same provider. It MUST permit those alternatives to coexist when no resolved profile selects them together.

_Conformance:_ conforming

_Verify:_ Bats resolves each mutually exclusive alternative successfully and a composed contradictory selection unsuccessfully for every native target class.

_Evidence:_ `rig_resource_native_target` and `rig_validate_selected_native_targets` validate only `RIG_SELECTED_RESOURCE_SECTIONS`; `tests/rig-profile-authority.bats` covers locator, setting, and Dock conflicts.

### RIG-ORCH-028 — Operation scope disclosure

Every mutating lifecycle report MUST identify its declaration scope before provider execution. Dry-run and live output MUST use the same classification. Capture MUST identify its output as a proposal rather than applied configuration.

_Conformance:_ conforming

_Verify:_ Isolated Bats fixtures exercise successful, invalid and dry-run behavior without changing the live workstation.

_Evidence:_ `rig_command_apply`, `rig_run_lifecycle_tasks` and `rig_command_capture` implement the scope boundary; lifecycle, adoption and profile-authority tests exercise it.

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

Rig MUST materialise full apply plans in tools → skills → resources order and MUST expose `skills` as an explicit scope. Skills CLI operations MUST invoke a deliberately installed `skills` executable directly with literal arguments and bounded JSON parsing, never unqualified `npx`; KI MUST NOT be invoked; local authority MUST canonicalise real non-symlink source and runtime roots, enforce component containment, revalidate immediately before mutation, and create only a missing leaf symlink without replacing a collision; runtime and plugin authorities MUST be observation-only. Only `rig upgrade` MAY advance selected Skills CLI skills. Profile deselection MUST NOT update or remove skills.

_Conformance:_ conforming

_Verify:_ Isolated Bats fakes prove literal CLI arguments, no KI invocation, canonical local containment and collision preservation, tools → skills → resources ordering, explicit update, and absence of removal in apply and upgrade.

_Evidence:_ `rig_preflight_skills`, `rig_apply_skill`, `rig_run_skill_apply`, `rig_collect_lifecycle_tasks`, and `tests/rig-skills.bats` implement and verify the lifecycle.

### RIG-ORCH-033 — Equivalent observation snapshots

Within one command, Rig MAY reuse a built-in provider observation only when the executable and every literal native argument are identical. Reuse MUST remain in memory, preserve each item's dependency and artifact evaluation and progress step, MUST NOT apply to custom-provider observations, and MUST NOT persist provider state as a competing authority.

_Conformance:_ conforming

_Verify:_ Bats supplies two uv tools whose exact native observation command is identical, proves one invocation, and verifies independent exact-identity results for both tools.

_Evidence:_ `rig_capture_observation_invocation` keys the command-local snapshot by executable and length-delimited literal arguments; `tests/rig-performance.bats` covers reuse and per-tool interpretation.

### RIG-ORCH-034 — Unattended lifecycle execution

`rig upgrade` MUST accept `--unattended`, and no other command may. The flag MUST preserve target selection, dependency order, the per-task outcome vocabulary and aggregate exit-status semantics.

Every native upgrade invocation in an unattended run MUST take its standard input from `/dev/null`, and Rig MUST export `NONINTERACTIVE=1` for the Homebrew adapter. Selected Mac App Store bindings MUST be reported `unavailable` with detail `interactive-required` before native invocation. Other native failures MUST retain the `failed` outcome and native exit detail, while independent targets continue; an unavailable or failed task MUST produce aggregate status 1. Mixed Homebrew App Store, cask and formula tasks MUST retain separate results in the unattended report rather than sharing a manifest outcome.

Standard-input EOF does not prevent a native program from using a controlling terminal, graphical authentication or an independent credential helper. The flag does not impose a timeout or supervise native processes, and Rig does not infer that an ordinary failure requires credentials.

Rig MUST NOT schedule the run, notify anyone about it, or acquire a runtime dependency in order to do either. A person schedules it by declaring a `scheduled-job` resource whose program is `rig upgrade --unattended`, and a wrapper reads the report under [RIG-STATE-030](state.md#rig-state-030--unattended-last-run-report). Rig MUST report an observed competing auto-update agent it did not declare as doctor information only, and MUST NOT install, modify, or remove it.

_Conformance:_ conforming

_Verify:_ Isolated Bats asserts the flag's grammar, native stdin EOF despite supplied caller input, Homebrew's noninteractive flag, and separate persisted results for an excluded App Store target, failed cask and successful formula. Interactive and dry-run cases prove App Store dispatch remains available and previews preserve state. Doctor tests assert the information line leaves exit status unchanged.

_Evidence:_ `rig_command_lifecycle`, `rig_lifecycle_requires_person`, `rig_run_lifecycle_tasks`, `rig_execute_lifecycle_task` and `rig_doctor_competing_autoupdate` implement the bounded contract; mixed Homebrew, interactive, dry-run and stdin fixtures in `tests/rig-lifecycle.bats` verify independent execution and persisted rows, while `tests/rig.bats` covers doctor information.

### RIG-ORCH-035 — Exact apply targets

`rig apply` MUST accept repeatable exact `--target ID` selectors for entries in its resolved complete profile and MUST reject an unknown selector with exit status 2 before provider dispatch. A selector and `--scope` MUST compose by intersection. A `port:ID` selector MUST select its declared owner for reconciliation within the owner's scope; the port itself remains observational and MUST NOT be materialised.

_Conformance:_ conforming

_Verify:_ Bats selects one and several tools, rejects a typo with an empty provider log, intersects a resource target with tools scope, and selects a private port's owner without port mutation.

_Evidence:_ `rig_apply_select_targets` filters the fully resolved plan; `tests/rig.bats` covers exact selection, unknown rejection, scope intersection, and the port boundary.

### RIG-ORCH-036 — Target prerequisite closure

A targeted apply MUST include each transitive declared prerequisite that is not observed `present`, preserve dependency-first dispatch, and identify requested and dependency-included entries separately in its report. An already-present prerequisite MUST NOT be dispatched merely because its dependant was selected. If `--scope` excludes a missing prerequisite, Rig MUST reject the target before dispatch rather than apply it without that prerequisite.

_Conformance:_ conforming

_Verify:_ Bats supplies present and missing tool and resource prerequisites, asserts dispatch order and target/dependency rows, checks that present prerequisites are absent from the targeted plan, and rejects a resource-only target with a missing tool prerequisite before invocation.

_Evidence:_ `rig_apply_mark_dependencies` observes and closes tool and resource requirements; targeted tool and resource tests in `tests/rig.bats` verify the resulting rows and calls.

### RIG-ORCH-037 — Narrow reconciliation state boundary

A targeted apply MUST NOT retire unselected stale resources or record un-applied declarations as reconciled. It MUST NOT acquire the resource reconciliation lock when its filtered plan contains no resource work.

_Conformance:_ conforming

_Verify:_ Bats selects one of two resources and inspects the receipt and provider calls; a tool-only target runs against an intentionally held fixture reconciliation lock.

_Evidence:_ `rig_apply_select_targets` clears stale-resource work, `rig_write_resource_receipt` records the filtered resource plan and carries forward valid existing records, and `tests/rig.bats` verifies the receipt and lock boundary.

### RIG-ORCH-038 — Reviewed Homebrew adoption

Capture MUST use read-only Homebrew inventory for formulae installed on request and installed casks, distinguish declared from unmanaged identities across the whole catalogue, and require explicit selected identities and human-provided category, purpose and rationale for complete proposals. It MUST emit additive TOML on stdout or into a new review file outside active configuration. It MUST NOT overwrite authored files, install software, infer rationale, or remove declarations absent from the current machine. Unsupported providers MUST be rejected explicitly.

Capture MUST permit discovery for legacy central-membership configurations but MUST reject proposals that would mix central and item-owned membership. The diagnostic MUST direct the user to migrate membership or adopt manually, rather than generating invalid configuration.

_Conformance:_ conforming

_Verify:_ Exercise discovery, duplicate and ambiguous identities, unsafe paths, literal metadata, failed inventory and dry-run with inert Homebrew fixtures.

_Evidence:_ `rig_command_capture`, `rig_homebrew_inventory` and `tests/rig-adoption.bats` implement the selective proposal contract.

### RIG-ORCH-039 — Bounded retirement observation

Retired-application observation MUST inspect only explicitly declared application/data/package locations and exact bundle-ID conventional data candidates, without recursive enumeration, data-content reads, mutation or symlink traversal at any path component. Application matching MUST use exact native bundle identity, never a display-name substring. Reports MUST distinguish ordinary missing, inaccessible, symlink, mismatched and unavailable evidence without claiming that a failed existence check rules out all macOS privacy or access restrictions; declared package association and conventional candidate attribution MUST NOT be presented as verified ownership. Other platforms MUST report unavailable observation without macOS probes.

Optional last-used metadata MUST come only from an exact matched application and retain its native source and partial-evidence caveat. Missing, malformed or unavailable metadata MUST NOT be interpreted as never used, and filesystem modification time MUST NOT substitute for usage evidence.

_Conformance:_ conforming

_Verify:_ Isolated native-command fakes cover identity match/mismatch, unreadable ancestry, symlinked ancestors and bundle metadata, absent/failed native commands, uncertain timestamps, Linux isolation and unchanged filesystem sentinels.

_Evidence:_ `src/rig/26-retired-applications.bash` implements bounded observation; `tests/rig-retired-applications.bats` verifies exact identity, uncertainty, platform isolation and no mutation.
