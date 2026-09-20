# Profile and provider orchestration — RIG-ORCH

This area of the [Rig Specifications](index.md) defines profile and provider orchestration beneath the catalogue model in [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md). Provider execution follows [ADR-RIG-005](../decisions/ADR-RIG-005-provider-execution-contract.md) and the trust boundary in [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Profiles

### RIG-ORCH-001 — Configurable default profile

Rig MUST allow a user to define which catalogue tools constitute the default profile.

_Conformance:_ conforming

_Verify:_ Bats tests create isolated configuration, invoke Rig without an explicit profile, and assert only configured default tools are selected.

_Evidence:_ Catalogue query and operational command tests resolve the configured default without mutating it.

### RIG-ORCH-002 — Explicit profile selection

Rig MUST allow a user to select a non-default configured profile without changing the stored default.

_Conformance:_ conforming

_Verify:_ Bats tests invoke two named profiles against the same isolated configuration and assert their resolved selections remain independent.

_Evidence:_ `rig_resolve_profile` accepts an explicit profile independently of the stored default; command tests cover `--profile` parsing.

### RIG-ORCH-018 — Bootstrap profile precedence

Rig MUST allow one optional bootstrap profile distinct from the default profile. `rig bootstrap --profile NAME` MUST select the explicit profile; otherwise bootstrap MUST select `bootstrap-profile` when declared and fall back to `default-profile` when absent. The selected profile MUST use the same resolver and provider plan as apply.

_Conformance:_ conforming

_Verify:_ Bats selects distinct default and bootstrap profiles, proves explicit precedence and default fallback, and compares bootstrap with apply plan output and provider order.

_Evidence:_ `rig_command_bootstrap` resolves the root-field precedence before delegating to `rig_command_apply`; configuration validation and focused Bats cases cover all three selection paths.

### RIG-ORCH-007 — Profile composition

Rig MUST allow a profile to include other declared profiles and MUST expand required tool relationships transitively. Resolution MUST fail when a selected tool supports the active platform but one of its required tools does not.

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

_Evidence:_ The custom-provider boundary delegates observation and application while retaining no persistent observed state.

### RIG-ORCH-004 — Capability-aware actions

Rig MUST report a missing observation capability as unavailable without invocation and MUST reject a missing application capability during full-plan preflight before mutation.

_Conformance:_ conforming

_Verify:_ Bats tests remove exact `observe` and `apply` capabilities and assert status 1 or preflight status 2 respectively with no provider invocation.

_Evidence:_ `rig_provider_has_capability`, `rig_command_status`, and `rig_preflight_apply` enforce exact atomic capability values.

### RIG-ORCH-005 — Dependency order

Rig MUST order selected bound-tool work dependency-first, using bytewise tool identity to break ties.

_Conformance:_ conforming

_Verify:_ Bats configures a graph whose dependency order differs from lexical order and asserts the exact invocation sequence.

_Evidence:_ `rig_build_plan` emits a stable dependency-first work plan consumed by status and apply.

### RIG-ORCH-006 — Initial provider classes

Rig MUST support Homebrew, uv, chezmoi, direct-download, and custom executable providers without requiring an unselected provider's executable. A selected custom provider without `executable` MUST resolve exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`, respecting Rig then XDG data-home precedence; an explicit executable MUST win.

_Conformance:_ conforming

_Verify:_ Bats tests exercise each provider through fakes, cover explicit and conventional custom executables under Rig and XDG data homes, and run an unrelated profile while native executables are absent.

_Evidence:_ `rig_provider_executable` and `rig_custom_provider_executable` resolve defaults only for selected actions; Bats records built-in and custom adapter calls and proves a declared unselected missing executable is not invoked.

### RIG-ORCH-017 — Built-in native command matrix

Built-in adapters MUST preserve each provider argument and tool `install.argument` as one literal native argument and MUST use the following command matrix, where configured provider arguments precede the native command and installation arguments precede the locator:

- Homebrew `formula`: `brew list --formula --versions OBSERVED_IDENTITY` to observe and `brew install --formula LOCATOR` to apply.
- Homebrew `cask`: `brew list --cask --versions OBSERVED_IDENTITY` to observe and `brew install --cask LOCATOR` to apply.
- Homebrew `mas`: `mas list` with exact numeric identity matching to observe and `mas install LOCATOR` to apply.
- uv `tool`: `uv tool list` with exact package identity matching to observe and `uv tool install LOCATOR` to apply.
- chezmoi `target`: `chezmoi status --path-style=absolute -- LOCATOR` to observe and `chezmoi apply -- LOCATOR` to apply.
- direct-download `executable`: local destination and checksum inspection to observe; `curl --fail --location --proto =https --proto-redir =https --silent --show-error --output TEMP HTTPS_LOCATOR`, SHA-256 verification, executable mode, and sibling rename to apply.

For a Homebrew formula or cask, `OBSERVED_IDENTITY` MUST be the terminal token of a possibly tap-qualified locator and `LOCATOR` MUST remain the complete authored value. An explicit provider `executable` MUST replace the matrix default. A built-in provider MUST expose no action without the exact corresponding declared `observe` or `apply` capability.

_Conformance:_ conforming

_Verify:_ Bats fake executables record exact native argument boundaries for every built-in kind, including provider and installation arguments containing spaces.

_Evidence:_ `rig_prepare_builtin_invocation`, `rig_observe_provider`, and `rig_apply_provider` implement the matrix; focused Bats coverage compares exact call logs.

### RIG-ORCH-009 — Platform installation selection

Rig MUST select the tool's single declared installation when materialisation is requested on a compatible active platform and MUST reject an incompatible installation. Installation metadata with no `install.platforms` value or value `any` is compatible with every platform; other platform values match exactly.

_Conformance:_ conforming

_Verify:_ Bats tests resolve compatible and `any` tool installations, then assert incompatible installation metadata fails before provider invocation.

_Evidence:_ `tests/rig.bats` covers exact, `any`, incompatible, and catalogue-only installation declarations without invoking providers unexpectedly.

### RIG-ORCH-010 — Literal executable arguments

Rig MUST invoke a custom provider as one resolved executable with each configured provider and tool installation argument preserved as a literal argument boundary. Resolution MUST use only the explicit field or exact conventional data-home path and MUST NOT search, copy, generate, or recursively discover executables.

_Conformance:_ conforming

_Verify:_ Bats tests record custom-provider arguments containing spaces and shell metacharacters, exercise every invocation surface through the conventional provider directory, and assert no shell interpretation or directory discovery occurs.

_Evidence:_ `rig_custom_provider_executable` resolves one explicit or conventional path and `rig_prepare_provider_invocation` constructs a Bash indexed argument array; Bats verifies paths, spaces, globs, and command syntax remain inert.

### RIG-ORCH-011 — Ordered failure boundary

After a work unit fails, Rig MUST suppress only its transitive dependants, identify the blocking tool, and continue independent work.

_Conformance:_ conforming

_Verify:_ Bats fails a prerequisite and asserts its dependant is skipped with `blocked-by:TOOL` while independent work completes.

_Evidence:_ `rig_plan_blocker` and apply result arrays retain native failure detail and bound suppression to the failed branch.

### RIG-ORCH-014 — Versioned custom-provider protocol

For tool observation and application, Rig MUST invoke a custom provider as `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER TOOL KIND LOCATOR [INSTALL_ARGUMENT ...]`, with `VERB` exactly `observe` or `apply`. Publication uses the separate fixed `publish` variant specified by RIG-PUB-007.

_Conformance:_ conforming

_Verify:_ Bats records every argument for observation and application and compares the version marker, verb, identities, installation data, and argument order.

_Evidence:_ `rig_prepare_custom_invocation` and `rig_prepare_provider_invocation` implement the ADR-RIG-005 installation protocol, while recording-provider tests compare its argument boundaries.

### RIG-ORCH-015 — Observation response boundary

Rig MUST accept custom-provider observation stdout only as one supported state token, mapping invalid output to `unknown` with `invalid-response` and a non-zero exit to `unknown` with `exit:N`.

_Conformance:_ conforming

_Verify:_ Bats exercises every state token, invalid, empty, multiline, and non-zero provider responses.

_Evidence:_ `rig_command_status` parses the isolated protocol channel and retains provider-native failure status as detail.

### RIG-ORCH-016 — Application diagnostic boundary

Rig MUST reserve stdout for its deterministic application report and route custom-provider application stdout and stderr to Rig's stderr.

_Conformance:_ conforming

_Verify:_ Bats redirects command channels separately and asserts provider diagnostics never contaminate Rig's stdout table and summary.

_Evidence:_ `rig_command_apply` redirects provider stdout to stderr while leaving provider stderr on the same diagnostic channel.

### RIG-ORCH-019 — Provider progress channel

Configuration loading and provider-backed observation, inventory, application, declared actions, and publication MUST report line-oriented progress on stderr when stderr is a terminal. Rig MUST keep deterministic reports and exported data on stdout. `RIG_PROGRESS=always` MUST retain progress when stderr is redirected, and `RIG_PROGRESS=never` MUST suppress it.

_Conformance:_ conforming

_Verify:_ Bats redirects stdout and stderr separately, forces and suppresses progress, and proves the command report is unchanged.

_Evidence:_ `rig_progress_start`, `rig_progress_step`, and `rig_progress_finish` gate progress independently of provider diagnostics; `tests/rig.bats` covers the forced and suppressed modes.

## Declared provider actions

### RIG-ORCH-012 — Explicit action dispatch

`rig run PROVIDER ACTION` MUST resolve one declared provider action, verify that it supports the active platform, map `observe` mode to the provider `observe` verb and `mutate` mode to `apply`, and invoke the action with configured arguments. It MUST preserve the provider's native outcome and MUST reject invalid input before provider invocation.

_Conformance:_ conforming

_Verify:_ Bats tests use recording providers to assert exact operation selection, platform and capability validation, invocation boundaries, exit status, and no invocation after validation failure.

_Evidence:_ `rig_command_run` maps declared modes to the versioned custom-provider ABI, preflights the selected operation and executable, passes provider output through, and preserves its native exit status; `tests/rig.bats` records exact invocations.

### RIG-ORCH-013 — Bounded caller arguments

`rig run PROVIDER ACTION [-- ARGUMENT...]` MUST accept a caller argument only when it exactly matches one `allowed-arguments` array item, unless the action explicitly declares `argument-policy = "provider"`. Under provider policy Rig MUST pass literal caller arguments to that one declared custom provider, which owns domain validation. Rig MUST append accepted caller arguments literally without shell interpretation. An action with neither policy nor `allowed-arguments` MUST reject all caller arguments.

_Conformance:_ conforming

_Verify:_ Bats tests cover allowed and rejected arguments containing spaces and shell metacharacters, exact-match behaviour, argument order, and an empty provider-call log for rejected input.

_Evidence:_ `rig_operation_allows_argument` performs literal equality checks before dispatch; `rig_command_run` appends accepted caller arguments without evaluation; `tests/rig.bats` covers rejection and literal boundary preservation.

## Operational resources

### RIG-ORCH-020 — Resource profile resolution

Composed profiles MUST select services and scheduled jobs in addition to tools. Every resource `requires` entry MUST select that tool and its transitive requirements for the active platform. Resource work MUST be ordered bytewise after the dependency-ordered tool plan; an unavailable or failed required tool MUST suppress only its dependent resource.

_Conformance:_ conforming

_Verify:_ Bats tests select resources directly and through composed profiles, assert required tools enter the plan, compare stable resource ordering, and exercise dependent and independent failures.

_Evidence:_ resource selection shares profile traversal and tool selection, then builds a separate sorted resource plan consumed after tool execution.

### RIG-ORCH-021 — Resource provider protocol

For resource observation, application, and retirement, Rig MUST invoke `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 VERB PROVIDER RESOURCE-ID RESOURCE-KIND LOCATOR [FIELD=VALUE ...]`. `VERB` MUST be `observe-resource`, `apply-resource`, or `retire-resource`; `RESOURCE-KIND` MUST be `service` or `scheduled-job`. Selected declarations MUST use ordered literal field records, repeating array keys in declaration order and supplying documented policy defaults. Providers MUST declare the exact corresponding `resource-observe`, `resource-apply`, or `resource-retire` capability. Observation accepts only the standard five state tokens.

_Conformance:_ conforming

_Verify:_ Recording-provider Bats tests assert exact verbs, identities, repeated key order, metacharacter and leading-dash boundaries, default fields, capability rejection, observation tokens, and native failure detail.

_Evidence:_ resource invocation and observation helpers extend `rig-provider-v1` without shell evaluation or provider-side configuration discovery.

### RIG-ORCH-022 — Resource-aware actions

An action declaring `resource-kinds` MUST use provider argument policy and MUST consume its first caller argument as `service:ID` or `scheduled-job:ID`. Rig MUST reject an unknown kind, identity, foreign-provider resource, or resource not selected by the default profile. The provider invocation MUST append `resource-v1 KIND ID LOCATOR [FIELD=VALUE ...] --` before remaining literal caller arguments. Actions without `resource-kinds` MUST preserve the existing action ABI.

_Conformance:_ conforming

_Verify:_ Bats tests cover both kinds, selected and rejected targets, provider ownership, complete literal declaration payloads, caller arguments after the separator, and unchanged ordinary actions.

_Evidence:_ `rig_command_run_action` resolves and validates the qualified resource before extending the existing action invocation.
