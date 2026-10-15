# Declarative configuration — RIG-CONF

This area of the [Rig Specifications](index.md) defines the inert TOML configuration contract established by [ADR-KI-TOOL-RIG-003](../decisions/ADR-KI-TOOL-RIG-003-declarative-configuration-grammar.md) and protected by [XDR-KI-TOOL-RIG-001](../decisions/XDR-KI-TOOL-RIG-001-executable-provider-boundary.md).

## Files and versioning

### RIG-CONF-001 — XDG configuration files

Rig MUST read the optional root declaration `${RIG_CONFIG_HOME}/rig.toml` followed by regular fragments `${RIG_CONFIG_HOME}/conf.d/*.toml`. At least one source MUST exist, and the merged model MUST contain exactly one `[rig]` table.

_Conformance:_ conforming

_Verify:_ Bats tests isolate `RIG_CONFIG_HOME`, exercise root-only, root-plus-fragment, fragment-only, and no-source layouts, and assert that Rig reads no undeclared configuration location.

_Evidence:_ `rig_load_config` reads only the selected root and fragment directory; `tests/rig.bats` covers every supported source layout.

### RIG-CONF-002 — Unversioned input and recognised legacy marker

New configuration MUST omit a schema field. Rig MUST read the current unversioned shape and a structurally valid legacy file with one integer `schema = 1` in `[rig]`. It MUST reject a duplicated, non-integer, or unsupported marker and MUST NOT use the marker to excuse an unknown declaration. Ordinary reads MUST NOT rewrite configuration. `rig repair` MUST preview removing the recognised field; `rig repair --output PATH` MUST write a proposal outside active configuration for explicit review and manual replacement.

_Conformance:_ conforming

_Verify:_ Bats tests accept unversioned and recognised legacy input; reject duplicate, float, unsupported, and structurally invalid legacy input; and verify preview, exclusive proposal creation, and no-write reads.

_Evidence:_ `rig_toml_field`, `rig_toml_mark_field`, `rig_validate_model`, and `rig_schema_repair` enforce the input boundary; `tests/rig.bats` and `tests/rig-schema-migration.bats` cover it.

### RIG-CONF-003 — Deterministic fragment order

Rig MUST load the root file first and fragments in bytewise filename order independently of the user's locale.

_Conformance:_ conforming

_Verify:_ Bats tests create fragments whose declarations reveal load order and invoke Rig under different locale settings.

_Evidence:_ `rig_load_config` scopes discovery and ordering under `LC_ALL=C`; `tests/rig.bats` proves root-first bytewise loading.

### RIG-CONF-004 — Inert bounded TOML

Rig MUST accept its current tables, bare keys, an optional recognised legacy decimal integer schema marker, single-line basic strings, bounded single-line or multiline arrays of basic strings, blank lines, and `#` comments without sourcing files, evaluating commands, interpreting shell syntax, or performing general environment expansion. Every accepted source MUST be valid TOML. Rig MUST reject unsupported TOML types and syntax before returning a resolved rig.

_Conformance:_ conforming

_Verify:_ Bats tests validate representative Rig files with a general TOML reader, prove shell-significant text remains inert, and reject literal strings, unterminated arrays, basic strings split across lines, non-string array members, floats, and unsupported escapes.

_Evidence:_ `rig_parse_file` and its `rig_toml_*` helpers implement the bounded parser without `eval` or external commands; `tests/rig.bats` exercises interoperability, inert values, comments, escapes, and rejection.

### RIG-CONF-005 — Schema-controlled declarations

Rig MUST reject unknown table types, unknown keys, duplicate keys, duplicate tables, conflicting identities, malformed assignments, and unsupported values before returning a resolved rig.

_Conformance:_ conforming

_Verify:_ Bats table tests provide each invalid declaration class and assert status 2 with no provider invocation.

_Evidence:_ `rig_parse_section_identity`, `rig_toml_field`, `rig_toml_mark_field`, and `rig_validate_model` fail closed; `tests/rig.bats` covers the rejection classes.

### RIG-CONF-006 — Array item boundaries

Rig MUST preserve each item in a schema-defined string array as one ordered value without treating commas, spaces, glob characters, or shell syntax inside a string as separators.

_Conformance:_ conforming

_Verify:_ Bats tests load platform, relationship, profile, tool, capability, argument, artifact, and allowed-argument arrays containing spaces, commas, and shell-significant text and assert exact item boundaries.

_Evidence:_ `rig_toml_array_complete` and `rig_toml_parse_array` decode one basic string at a time into the existing ordered field model; `tests/rig.bats` inspects values by occurrence and provider argument boundaries.

### RIG-CONF-007 — Bounded path expansion

Rig MUST expand documented home forms without shell evaluation. Provider `executable` fields and direct-download `install.destination` fields MUST retain their existing leading `~/` loading contract. Tool-artifact comparison MUST derive an absolute identity from a leading `~/` or `$HOME/` without changing the stored declaration. Typed string settings and Dock paths MUST resolve exact whole-value `~`, `~/...`, `$HOME`, and `$HOME/...` forms; typed string settings MUST additionally resolve exact `file://$HOME` and `file://$HOME/...` forms. Observation, validation, dry-run preflight, and application MUST use the same resolved value. Rig MUST preserve the authored declaration, embedded variables, other variable names, relative paths, unsupported tilde forms, and all other value text literally.

_Conformance:_ conforming

_Verify:_ Bats tests compare and apply path and non-path values containing supported whole-value home forms, file URLs, embedded variables, other variable names, tildes, dollar signs, equals signs, and comment characters under an isolated home directory.

_Evidence:_ `rig_add_field`, `rig_normalize_artifact_identity`, and `rig_expand_home_value` implement bounded field-specific conversion; `tests/rig.bats` and `tests/rig-macos.bats` prove supported forms resolve consistently and unsupported shell-significant text remains literal.

## Schema 1 tables

### RIG-CONF-008 — Canonical table identities

Schema 1 MUST accept `[rig]`, `[category.ID]`, `[tool.ID]`, `[skill.ID]`, `[profile.ID]`, `[provider.ID]`, `[service.ID]`, `[scheduled-job.ID]`, `[setting.ID]`, `[dock.ID]`, `[dock-item.ID]`, `[port.ID]`, `[retired-application.ID]`, `[remove.ID]`, `[default-application.ID]`, `[firewall.ID]`, and `[action.PROVIDER.NAME]` table identities. Every identity segment MUST match `[a-z][a-z0-9-]*`. Any other table shape MUST be rejected. Installation metadata MUST remain in its owning tool table.

_Conformance:_ conforming

_Verify:_ Bats table tests accept every supported table form and reject uppercase, empty, extra, whitespace-containing, and digit-leading identities.

_Evidence:_ `RIG_DECLARATION_REGISTRY`, `rig_parse_section_identity` and `rig_valid_id` enforce the table and identifier grammar; `tests/rig-declaration-registry.bats` checks recognition, invalid identities and documentation coverage, and the `section identities are strict and unique` Bats test covers configuration loading.

### RIG-CONF-009 — Root fields

`[rig]` MUST require `default-profile`; the default MUST name a declared profile. A recognised legacy `schema = 1` MAY be present but MUST NOT be written by init. `bootstrap-profile` MUST be rejected with migration guidance, not silently ignored.

_Conformance:_ conforming

_Verify:_ Run isolated Bats tests for valid, invalid, unavailable and dry-run cases.

_Evidence:_ `rig_validate_model` and adoption migration fixtures validate root fields and retirement.

### RIG-CONF-010 — Catalogue fields

Schema 1 category tables MUST require string `name` and `purpose`. Tool tables MUST require string `name`, `category`, `purpose`, and `rationale`, MUST require a non-empty `platforms` string array, and MAY contain `requires`, `related`, `alternatives`, and `artifacts` string arrays. A materialised non-variant tool MUST co-locate string `install.provider`, `install.kind`, and `install.locator`; it MAY contain string `install.destination` and `install.checksum` and string arrays `install.platforms`, `install.arguments`, and `install.executables`. `install.provider` MUST name a built-in provider identity or an explicitly declared external provider. A tool without `install.provider` is catalogue-only and MUST NOT contain any other `install.*` field.

_Conformance:_ conforming

_Verify:_ Bats tests parse every catalogue field, preserve array boundaries, resolve built-in and external provider ownership, compare artifacts, and reject missing or misplaced fields.

_Evidence:_ `rig_toml_field` and the tool branch of `rig_validate_model` implement the catalogue field contract; the `schema list fields preserve each declared item boundary`, `required catalogue and provider adapter fields are validated`, and `descriptive tools resolve without installation metadata` Bats tests cover it.

### RIG-CONF-011 — Profile fields

Schema 1 profile tables MAY contain string `name` and `purpose`, `kind` with value `complete` or `view`, and an `inherits` string array naming other profiles. Omitted `kind` MUST mean `complete`. A view MUST inherit only views. Central `profiles`, `tools`, `services`, `scheduled-jobs`, `settings`, and `docks` arrays remain valid only in a configuration that contains no item-owned `profiles` field; every central item MUST name a declaration of the corresponding kind.

_Conformance:_ conforming

_Verify:_ Bats tests compose profiles and every selectable declaration kind, preserve array item boundaries, reject unknown references, and detect profile cycles.

_Evidence:_ `rig_toml_field`, `rig_validate_model`, and `rig_select_profile` resolve every profile member kind; `profiles compose and requirements resolve to a sorted platform-specific set` in `tests/rig.bats` and `typed macOS resources query and dry-run deterministically` in `tests/rig-macos.bats` cover tools and typed resources.

### RIG-CONF-012 — Provider fields

Rig MUST resolve built-in identities without provider tables. Optional built-in tables MAY provide documented executable overrides but MUST NOT redefine adapter or capabilities. Homebrew `manifest`, `autoupdate-interval` and `autoupdate-options` MUST be rejected with migration guidance. A custom provider MUST declare `adapter = "custom"` and non-empty capabilities; executable and literal arguments MAY be supplied. Without an executable Rig MUST resolve only the exact provider path below its data home. Native source ownership, including chezmoi, MUST remain unchanged.

_Conformance:_ conforming

_Verify:_ Run isolated Bats tests for valid, invalid, unavailable and dry-run cases.

_Evidence:_ `rig_validate_model`, `rig_builtin_provider_adapter`, model-boundary and adoption tests enforce native and external trust boundaries.

### RIG-CONF-013 — Installation fields

Tool installation metadata MUST reference one built-in or explicitly declared external provider and MUST obey that provider's native kind contract. Built-in kinds MUST include Homebrew `formula` and `cask`; mas `app`; uv `tool`; mise `tool`; npm `global`; chezmoi `target`; and direct-download `executable`. `install.destination` and `install.checksum` MUST be valid only for `direct-download` installations. `install.executables`, at tool or variant level, MUST be valid only for mise `tool` installations, and each element MUST be non-empty and MUST NOT begin with `-` or contain `/`, a tab, or a newline. mas `app` locators MUST be numeric App Store application identities, and a mas installation MUST NOT declare platform `linux`. The former Homebrew `mas` kind MUST load as a deprecated alias of mas `app` in tool, variant and removal declarations, so that every later phase and every output names provider `mas`, and `rig doctor` MUST warn once for each such declaration without changing its verdict. Direct-download installations MUST use an HTTPS locator, an absolute expanded destination, and a checksum containing `sha256:` followed by exactly 64 lowercase hexadecimal characters.

_Conformance:_ conforming

_Verify:_ Bats tests resolve every built-in kind without provider boilerplate and reject unknown providers, partial installation declarations, incompatible kinds, unsafe downloads, malformed checksums, invalid Mac App Store identities and Linux App Store installations; alias fixtures prove the former Homebrew `mas` form runs `mas`, prints `mas` and warns in doctor.

_Evidence:_ `rig_validate_model` owns the exact tool-installation kind matrix and rejects resource-only built-ins; `rig_validate_binding_adapter` restricts `install.executables`; `rig_alias_deprecated_mas` rewrites the former Homebrew `mas` kind; `tests/rig.bats`, `tests/rig-lifecycle.bats`, `tests/rig-mas-provider.bats`, and `tests/rig-model-boundaries.bats` cover the accepted and rejected classes, including `install.executables is valid only on a mise tool with safe names`.

### RIG-CONF-014 — ~~Publication fields~~ (deprecated)

Retired with `rig publish`. A `[publication.ID]` table is no longer an accepted identity and fails to load; `rig export --profile NAME --output DIRECTORY [--title TEXT] [--base-url URL]` carries the same values as arguments under [RIG-PUB-007](publishing.md#rig-pub-007--export-parameters). The serial stays claimed and is never reused.

### RIG-CONF-015 — Extension action fields

Schema 1 action tables MUST require string `mode` and `description` and MAY contain `platforms`, `arguments`, `allowed-arguments`, and `resource-kinds` string arrays and string `argument-policy`. The provider named by the table identity MUST be an explicitly declared external provider. Mode MUST be `observe` or `mutate`. `argument-policy` defaults to `rig`, MAY be `provider`, and MUST NOT be combined with `allowed-arguments` when set to `provider`. `resource-kinds` accepts only supported managed-resource kinds, requires provider argument policy, and remains validated resource-selection metadata. Action metadata MUST remain inert; there is no public generic action dispatcher. Built-in provider operations MUST NOT require action tables.

_Conformance:_ conforming

_Verify:_ Bats table tests accept valid external action records; reject malformed identities, missing fields, invalid modes, built-in or unknown providers, and invalid argument policies; preserve configured allow-listed argument boundaries; and exercise built-in operations without action declarations.

_Evidence:_ `rig_validate_action` validates retained custom action metadata; `tests/rig-model-boundaries.bats` and sourceable helper tests cover trust boundaries without exposing a public runner.

### RIG-CONF-016 — Operational resource fields

Schema 1 service and scheduled-job tables MUST require string `name`, `purpose`, `rationale`, `provider`, `locator`, and `desired-state`, plus non-empty `platforms` and `program` string arrays. They MAY contain `requires`, `environment`, optional working-directory and standard-output/error strings. A service desired state MUST be `running` or `stopped`; optional restart policy MUST be `always` or `never`, and start policy MUST be `load` or `manual`. A scheduled-job desired state MUST be `enabled` or `disabled`; it MUST declare exactly one non-empty `schedule.calendar` string array or positive-decimal-string `schedule.interval`; optional run policy MUST be `scheduled-only` or `also-at-load`, and priority MUST be `background` or `normal`. Calendar records MUST contain unique comma-separated `minute|hour|day|weekday|month=DECIMAL` pairs within native-neutral numeric ranges. Environment records MUST be literal `KEY=value` strings. Providers and required tools MUST resolve, the built-in `launchd` provider MUST be valid without a provider table, and provider locator pairs MUST be unique across resources.

_Conformance:_ conforming

_Verify:_ Bats tests accept built-in launchd services and both scheduled-job schedule forms without provider declarations, preserve literal program and environment arguments, and reject unknown references, invalid enums, empty programs, malformed environment, invalid or conflicting schedules, and duplicate provider locators.

_Evidence:_ `rig_validate_resource`, `rig_validate_calendar_entry`, `rig_validate_environment_entry`, and `rig_validate_resource_locators` enforce the resource schema; the `built-in launchd observes applies and retires declared resources` and `resource schema rejects unsafe calendar declarations before provider execution` Bats tests cover accepted and rejected declarations.

### RIG-CONF-017 — Typed macOS settings

Schema 1 setting tables MUST require string `name`, `purpose`, `rationale`, `provider`, `domain`, `key`, `value-type`, and `value`, plus a non-empty `platforms` string array, and MAY contain a `requires` string array. Provider `macos-defaults` MUST be built in and restricted to platform `macos`; `value-type` MUST be `bool`, `int`, `float`, or `string`; and Rig MUST validate the string value against its declared type before observation or mutation.

_Conformance:_ conforming

_Verify:_ Bats tests parse each value type, select settings through composed profiles, preserve literal string values, and reject unsupported providers, platforms, types, values, and tool references before native invocation.

_Evidence:_ `rig_validate_setting` and `rig_validate_macos_platforms` validate typed settings before resolution; `typed macOS resources query and dry-run deterministically` and `typed macOS schema rejects invalid values before invocation` in `tests/rig-macos.bats` cover selection and fail-closed validation.

### RIG-CONF-018 — Semantic Dock declarations

Schema 1 dock tables MUST require string `name`, `purpose`, `rationale`, and `provider`, plus non-empty `platforms` and `items` string arrays, and MAY contain a `requires` string array. Provider `macos-dock` MUST be built in and restricted to platform `macos`. Every item MUST name one `[dock-item.ID]` table requiring `kind` and `path`; kind `application` MUST reject folder-only fields, while kind `folder` MAY contain `view` and `display`. Item array order MUST define the desired Dock order.

_Conformance:_ conforming

_Verify:_ Bats tests parse applications and folders, preserve selected item order, resolve tool requirements, and reject unknown items, duplicate selected items, unsupported kinds, misplaced fields, and non-macOS use before native invocation.

_Evidence:_ `rig_validate_dock`, `rig_validate_dock_item`, and `rig_dock_expected_paths` retain and validate semantic item order; `typed macOS resources query and dry-run deterministically` and `typed macOS resources observe and apply through native command fakes` in `tests/rig-macos.bats` cover application and folder declarations through planning and application.

### RIG-CONF-019 — Observation-only artifact declarations

A tool MAY declare an `artifacts` array of durable paths owned by that capability. Artifact declarations MUST remain inert configuration data and MUST NOT name an executable, command, argument list, or lifecycle hook. Unknown artifact lifecycle fields MUST fail closed during parsing.

_Conformance:_ conforming

_Verify:_ Bats accepts artifact arrays, rejects unknown artifact lifecycle fields before invocation, and proves configuration loading remains non-executing.

_Evidence:_ `rig_toml_field` admits only the `artifacts` array for this concern; `tests/rig-artifacts.bats` and parser rejection tests cover the boundary.

### RIG-CONF-020 — Item-owned profile membership

Every selectable tool, service, scheduled job, setting, and Dock layout MAY declare a `profiles` string array. An omitted array MUST assign the declaration to `[rig].default-profile`; an explicitly empty array MUST assign it to no profile. Profiles MAY declare `name`, `purpose`, `kind`, and `inherits`; `kind` MUST be `complete` or `view`, defaulting to `complete`. Rig MUST reject unknown profile references, inheritance cycles, a view inheriting a complete profile, and a merged configuration that combines any item-owned membership with central profile member arrays.

_Conformance:_ conforming

_Verify:_ Bats resolves a non-`default` configured default, explicit membership, explicit inheritance, an empty membership, and invalid mixed or unsafe view declarations.

_Evidence:_ `rig_detect_profile_selection_mode`, `rig_item_declares_profile`, `rig_activate_profile`, and `rig_validate_model` enforce the schema; `tests/rig-profile-authority.bats` covers its accepted and rejected forms.

### RIG-CONF-021 — Platform-specific tool variants

A tool MAY declare bounded dotted `variant.ID.*` fields beneath its single `[tool.ID]` table. Every variant MUST have a non-empty `variant.ID.platforms` string array and at least one installation or artifact field. Installation variants MUST contain `variant.ID.install.provider`, `variant.ID.install.kind`, and `variant.ID.install.locator`; they MAY contain the same bounded destination, checksum, and arguments fields as a non-variant installation. A variant MAY contain `variant.ID.artifacts` and named `variant.ID.cli.NAME.*` companion groups. Variant identifiers MUST match normal Rig identifiers.

Every platform declared by the tool MUST match exactly one variant. Rig MUST reject zero or multiple variant matches, partial variant installation metadata, and a tool combining a non-variant `install.*` declaration with variant installations. Platform-neutral `artifacts` MAY coexist with selected variant artifacts. Variant installation and artifact values MUST remain private and MUST NOT enter the public publication projection.

_Conformance:_ conforming

_Verify:_ Bats tests select distinct macOS and Linux installations and artifacts beneath one tool, reject zero and multiple matches, and inspect exported JSON for absence of variant materialisation data.

_Evidence:_ `rig_toml_variant_field`, `rig_validate_tool_variants`, and `rig_select_compatible_variant` implement the bounded representation; `tests/rig-human-config.bats` covers selection, rejection, and publication safety.

### RIG-CONF-022 — Qualified resource dependencies

Service, scheduled-job, setting, and Dock declarations MAY contain a `depends-on` string array. Every value MUST use the qualified form `service:ID`, `scheduled-job:ID`, `setting:ID`, or `dock:ID` and MUST name an existing declaration. Rig MUST reject missing endpoints and dependency cycles before provider observation or mutation. The field declares ordering only; it MUST NOT contain commands, conditions, or provider operations.

_Conformance:_ conforming

_Verify:_ Bats tests accept dependencies across resource kinds and reject unqualified, unknown, and cyclic graphs before provider work.

_Evidence:_ `rig_resource_reference`, `rig_validate_resource_dependencies`, and `rig_resource_cycle_visit` validate the graph; `tests/rig-human-config.bats` covers qualified references, missing endpoints, and cycles.

### RIG-CONF-023 — Private port declarations

Schema 1 MUST accept `[port.ID]` with required string `name`, `purpose`, `rationale`, `protocol`, `scope`, `mode`, and qualified `owner`, required decimal integer `port`, and optional item-owned `profiles`. Protocol MUST be `tcp`; port MUST be from 1 through 65535; scope MUST be `loopback` or `all-interfaces`; mode MUST be `required`, `on-demand`, or `allocated`; owner MUST name an existing `tool:ID`, `service:ID`, or `scheduled-job:ID`. A resolved profile MUST reject two selected declarations for the same protocol and number.

_Conformance:_ conforming

_Verify:_ Bats accepts the complete declaration, item-owned membership and central `ports` compatibility, then rejects missing fields, invalid integer ranges and enums, unqualified or unsupported owners, unknown references, and selected collisions.

_Evidence:_ `rig_toml_field`, `rig_validate_port`, `rig_select_port`, and `rig_validate_selected_ports` implement the contract; private-port tests cover accepted, rejected, and conflicting forms.

### RIG-CONF-024 — User-level skill declarations

Schema 1 MUST accept one `[skill.ID]` table per user-level skill with required `name`, `purpose`, `rationale`, `authority`, `source`, `trust`, and `platforms`; optional `source-skill`, `runtimes`, `requires`, `profiles`, and `public-source`; and the same item-owned profile semantics as other selectable declarations. `skills-cli`, `ki`, and `local` MUST require `trust = "reviewed"`; `runtime` and `plugin` MUST require `trust = "authority-owned"`; a merged configuration MUST NOT mix item-owned skill membership with central `profile.skills` selection.

_Conformance:_ conforming

_Verify:_ Bats tests accept each authority/trust pair and reject unknown fields, invalid pairs, invalid sources, invalid runtime identifiers, unresolved required tools, and mixed selection models.

_Evidence:_ `tests/rig-skills.bats` exercises skill schema, trust, source, and profile-selection validation.

### RIG-CONF-025 — Safe initial configuration

`rig init` MUST create a minimal valid default configuration without inspecting or installing software. It MUST refuse existing configuration, fragments and unsafe symlink targets rather than overwrite them. `--dry-run` MUST report the proposal without creating configuration or directories.

_Conformance:_ conforming

_Verify:_ Isolated adoption tests exercise new, existing, fragment-only and symlink targets and parse the generated configuration.

_Evidence:_ `rig_command_init` and `tests/rig-adoption.bats` implement exclusive initialisation.

### RIG-CONF-026 — Retired application declarations

Schema 1 MUST accept separate `[retired-application.ID]` declarations requiring a non-empty `name`, exact dot-separated `bundle-id` and non-empty `application-paths` string array, with optional `data-paths` and `package-paths` arrays. It MUST reject duplicate bundle identities, unknown fields, installation and profile metadata, unsafe path syntax and relative paths other than documented leading `~/` or `$HOME/` forms. Validation MUST remain inert and MUST NOT inspect the declared paths. Retired declarations MUST NOT become selectable installation or resource targets.

_Conformance:_ conforming

_Verify:_ Isolated retired-application tests parse accepted declarations, reject unsafe identities/paths and forbidden fields before any native call, and compare active selection and mutation plans with and without retirement metadata.

_Evidence:_ `rig_validate_retired_application` and `tests/rig-retired-applications.bats` verify the separate inert schema and its exclusions.

### RIG-CONF-027 — Explicit application CLI declarations

A materialised tool MAY declare named `cli.ID.source`, `cli.ID.destination` and `cli.ID.owner` string groups, including `variant.ID.cli.NAME.*` groups. Each group MUST contain all three fields, MUST use absolute source and destination paths with only leading `~/` or `$HOME/` expansion, MUST reject traversal and control characters, and MUST distinguish `owner = "provider"` for an existing Homebrew cask installation from `owner = "link"` for explicit link materialisation. Resolved companions MUST have unique destination paths across selected tools; unknown fields and owners MUST fail before provider work. Existing `artifacts` MUST retain their observation-only meaning, and companion paths MUST remain private in exported views.

_Conformance:_ conforming

_Verify:_ Isolated Bats fixtures parse complete, partial, unsafe and unsupported declarations, select platform variants, reject competing destinations, explain private intent and inspect public export privacy.

_Evidence:_ `rig_toml_cli_field`, `rig_validate_tool_clis`, `rig_validate_selected_cli_destinations` and `tests/rig-app-clis.bats` implement the explicit companion boundary.

### RIG-CONF-028 — Explicit native software removal

Private `[remove.ID]` declarations MUST require `name`, `provider`, `kind`, `locator` and `platforms`, and MAY specify `profiles` with default-profile membership otherwise. Supported identities MUST be Homebrew formula/cask, mas app, uv tool, npm global or mise tool, with the former Homebrew `mas` kind accepted as a deprecated alias of mas app. Cask and mas app platforms MUST be macOS only and mas app IDs MUST be numeric. Removal MUST reject option/control-character locators, provider arguments, duplicate normalised identities and any identity still declared by a tool installation anywhere in the catalogue. Removal declarations MUST NOT enter public export or ordinary apply/upgrade plans.

_Conformance:_ conforming

_Verify:_ Isolated removal fixtures exercise safe parsing, retained identity conflicts, duplicates, unsafe inputs, profile/platform filtering and native operations.

_Evidence:_ `rig_validate_removal`, `rig_collect_removals` and `tests/rig-software-removal.bats` implement and verify the explicit authority boundary.

### RIG-CONF-029 — Private default-application declarations

`[default-application.ID]` MUST require `name`, `purpose`, `rationale`, fixed `provider = "macos-handlers"`, one application `tool`, `bundle-id`, `kind`, `value` and macOS-only `platforms`. `kind` MUST be `uti`, `extension` or `scheme`; content types and bundle IDs MUST use bounded dot-separated identifiers, extensions MUST be lowercase with one optional leading dot, and schemes MUST be lowercase without a colon. The owning tool MUST declare an application artifact. Central profiles MAY select `default-applications`; item `profiles` MUST retain existing membership and inheritance rules. The owner MUST participate in tool prerequisite selection. Selected duplicate normalised kind/value targets MUST fail before native work. Handler choices, bundle identifiers and application paths MUST remain private in public export.

_Conformance:_ conforming

_Verify:_ Isolated fixtures exercise valid selectors, invalid ownership/fields, profile/variant selection, duplicate targets, offline descriptions and public export privacy.

_Evidence:_ `rig_validate_default_application`, `rig_default_application_identity`, profile/native-target resolution and `tests/rig-default-applications.bats` verify the declaration contract.

### RIG-CONF-030 — Tailnet-only firewall declarations

`[firewall.ID]` MUST require `name`, `purpose`, `rationale`, a `provider` of either `macos-pf` or `linux-nftables`, a reverse-DNS `locator` outside `com.apple`, a non-empty `ports` list, `allow = ["tailnet"]` and `platforms` naming only the provider's platform: `macos` for `macos-pf` and `linux` for `linux-nftables`. Each port MUST be `tcp:N` or `udp:N` with N from 1 to 65535 and no leading zero; ports MUST be unique within the declaration, and `tcp:22` and `udp:22` MUST be rejected because SSH is the recovery path. `allow` MUST accept no other source. A firewall MAY declare `requires`, `depends-on` and item `profiles`; central profiles MAY select `firewalls`. Locators MUST be unique across firewall declarations, and two `linux-nftables` locators MUST NOT derive the same nftables table name, which replaces each `.` and `-` with `_`. Every rejection MUST happen before any native invocation.

_Conformance:_ conforming

_Verify:_ Isolated fixtures reject a wrong provider or a provider paired with the other platform, malformed, duplicate or SSH ports, any other `allow` value, missing ports, unknown requirements, a duplicate locator and a colliding nftables table name, each with an empty native-command log.

_Evidence:_ `rig_validate_firewall`, `rig_firewall_locator_valid`, `rig_firewall_port_valid`, `rig_nftables_validate_platforms` and `rig_nftables_validate_table` enforce the declaration; `tests/rig-firewall.bats` and `tests/rig-firewall-linux.bats` cover every rejection.
