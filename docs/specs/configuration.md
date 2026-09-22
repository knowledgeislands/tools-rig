# Declarative configuration — RIG-CONF

This area of the [Rig Specifications](index.md) defines the inert TOML configuration contract established by [ADR-RIG-003](../decisions/ADR-RIG-003-declarative-configuration-grammar.md) and protected by [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Files and versioning

### RIG-CONF-001 — XDG configuration files

Rig MUST read the optional root declaration `${RIG_CONFIG_HOME}/rig.toml` followed by regular fragments `${RIG_CONFIG_HOME}/conf.d/*.toml`. At least one source MUST exist, and the merged model MUST contain exactly one `[rig]` table.

_Conformance:_ conforming

_Verify:_ Bats tests isolate `RIG_CONFIG_HOME`, exercise root-only, root-plus-fragment, fragment-only, and no-source layouts, and assert that Rig reads no undeclared configuration location.

_Evidence:_ `rig_load_config` reads only the selected root and fragment directory; `tests/rig.bats` covers every supported source layout.

### RIG-CONF-002 — Explicit schema version

Every configuration MUST declare exactly one decimal integer `schema = 1` in the root `rig` table. Rig MUST reject a missing, duplicated, non-integer, or unsupported version before resolving declarations.

_Conformance:_ conforming

_Verify:_ Bats tests accept schema version 1 and reject missing, duplicate, float, and unsupported versions.

_Evidence:_ `rig_toml_field`, `rig_toml_mark_field`, and `rig_validate_model` enforce the version contract; `tests/rig.bats` covers its accepted and rejected forms.

### RIG-CONF-003 — Deterministic fragment order

Rig MUST load the root file first and fragments in bytewise filename order independently of the user's locale.

_Conformance:_ conforming

_Verify:_ Bats tests create fragments whose declarations reveal load order and invoke Rig under different locale settings.

_Evidence:_ `rig_load_config` scopes discovery and ordering under `LC_ALL=C`; `tests/rig.bats` proves root-first bytewise loading.

### RIG-CONF-004 — Inert bounded TOML

Rig MUST accept schema 1 tables, bare keys, decimal integer schema value, single-line basic strings, bounded single-line or multiline arrays of basic strings, blank lines, and `#` comments without sourcing files, evaluating commands, interpreting shell syntax, or performing general environment expansion. Every accepted source MUST be valid TOML. Rig MUST reject unsupported TOML types and syntax before returning a resolved rig.

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

Rig MUST expand documented home forms without shell evaluation. Provider `executable` and `manifest` fields and direct-download `install.destination` fields MUST retain their existing leading `~/` loading contract. Tool-artifact comparison MUST derive an absolute identity from a leading `~/` or `$HOME/` without changing the stored declaration. Typed string settings and Dock paths MUST resolve exact whole-value `~`, `~/...`, `$HOME`, and `$HOME/...` forms; typed string settings MUST additionally resolve exact `file://$HOME` and `file://$HOME/...` forms. Observation, validation, dry-run preflight, and application MUST use the same resolved value. Rig MUST preserve the authored declaration, embedded variables, other variable names, relative paths, unsupported tilde forms, and all other value text literally.

_Conformance:_ conforming

_Verify:_ Bats tests compare and apply path and non-path values containing supported whole-value home forms, file URLs, embedded variables, other variable names, tildes, dollar signs, equals signs, and comment characters under an isolated home directory.

_Evidence:_ `rig_add_field`, `rig_normalize_artifact_identity`, and `rig_expand_home_value` implement bounded field-specific conversion; `tests/rig.bats` and `tests/rig-macos.bats` prove supported forms resolve consistently and unsupported shell-significant text remains literal.

## Schema 1 tables

### RIG-CONF-008 — Canonical table identities

Schema 1 MUST accept `[rig]`, `[category.ID]`, `[tool.ID]`, `[profile.ID]`, `[provider.ID]`, `[publication.ID]`, `[service.ID]`, `[scheduled-job.ID]`, `[setting.ID]`, `[dock.ID]`, `[dock-item.ID]`, and `[action.PROVIDER.NAME]` table identities. Every identity segment MUST match `[a-z][a-z0-9-]*`. Any other table shape MUST be rejected. Installation metadata MUST remain in its owning tool table.

_Conformance:_ conforming

_Verify:_ Bats table tests accept every supported table form and reject uppercase, empty, extra, whitespace-containing, and digit-leading identities.

_Evidence:_ `rig_parse_section_identity` and `rig_valid_id` enforce the table and identifier grammar; the `section identities are strict and unique` Bats test covers the accepted and rejected identity grammar.

### RIG-CONF-009 — Root fields

The schema 1 `rig` table MUST require `schema` and `default-profile` and MAY contain `bootstrap-profile`. Both profile fields MUST name declared profiles. An omitted `bootstrap-profile` MUST preserve `default-profile` as the bootstrap fallback.

_Conformance:_ conforming

_Verify:_ Bats tests resolve required root fields, accept one optional bootstrap profile, and reject missing, repeated, or unknown references.

_Evidence:_ `rig_validate_model` validates root fields and references; bootstrap selection tests cover explicit, configured, and fallback profiles.

### RIG-CONF-010 — Catalogue fields

Schema 1 category tables MUST require string `name` and `purpose`. Tool tables MUST require string `name`, `category`, `purpose`, and `rationale`, MUST require a non-empty `platforms` string array, and MAY contain `requires`, `related`, `alternatives`, and `artifacts` string arrays. A materialised non-variant tool MUST co-locate string `install.provider`, `install.kind`, and `install.locator`; it MAY contain string `install.destination` and `install.checksum` and string arrays `install.platforms` and `install.arguments`. `install.provider` MUST name a built-in provider identity or an explicitly declared external provider. A tool without `install.provider` is catalogue-only and MUST NOT contain any other `install.*` field.

_Conformance:_ conforming

_Verify:_ Bats tests parse every catalogue field, preserve array boundaries, resolve built-in and external provider ownership, compare artifacts, and reject missing or misplaced fields.

_Evidence:_ `rig_toml_field` and the tool branch of `rig_validate_model` implement the catalogue field contract; the `schema list fields preserve each declared item boundary`, `required catalogue and provider adapter fields are validated`, and `descriptive tools resolve without installation metadata` Bats tests cover it.

### RIG-CONF-011 — Profile fields

Schema 1 profile tables MAY contain string `name` and `purpose`, `kind` with value `complete` or `view`, and an `inherits` string array naming other profiles. Omitted `kind` MUST mean `complete`. A view MUST inherit only views. Central `profiles`, `tools`, `services`, `scheduled-jobs`, `settings`, and `docks` arrays remain valid only in a configuration that contains no item-owned `profiles` field; every central item MUST name a declaration of the corresponding kind.

_Conformance:_ conforming

_Verify:_ Bats tests compose profiles and every selectable declaration kind, preserve array item boundaries, reject unknown references, and detect profile cycles.

_Evidence:_ `rig_toml_field`, `rig_validate_model`, and `rig_select_profile` resolve every profile member kind; `profiles compose and requirements resolve to a sorted platform-specific set` in `tests/rig.bats` and `typed macOS resources query and dry-run deterministically` in `tests/rig-macos.bats` cover tools and typed resources.

### RIG-CONF-012 — Provider fields

The documented built-in configuration includes bounded native policy as well as executable and manifest details. Homebrew MAY declare a positive integer `autoupdate-interval` and an `autoupdate-options` array containing only `upgrade`, `cleanup`, `immediate`, and `sudo`; options MUST require an interval. No other built-in or external provider may declare this policy. Rig MUST translate the values into fixed native arguments and MUST NOT accept arbitrary autoupdate arguments or commands.

Schema 1 MUST resolve built-in provider identities without a provider table. An optional table for a built-in provider MAY contain only its documented `executable`, `manifest`, or `arguments` configuration and MUST NOT redefine its adapter class or supported operations. A provider identity not reserved by Rig MUST have one `[provider.ID]` table requiring `adapter = "custom"` and a non-empty `capabilities` string array and MAY contain string `executable` and an `arguments` string array. When executable is omitted, Rig MUST resolve exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`; an explicit executable MUST take precedence. Provider tables MUST NOT contain `command`.

_Conformance:_ conforming

_Verify:_ Bats tests use built-ins without provider tables, accept documented built-in overrides, require the custom adapter and operation allow-list for external providers, resolve explicit and exact conventional executables, preserve literal arguments, and reject adapter or capability overrides for built-ins.

_Evidence:_ `rig_validate_model`, `rig_builtin_provider_adapter`, and `rig_provider_has_capability` keep reserved built-ins immutable and external providers explicit; `tests/rig-model-boundaries.bats` covers both rejection boundaries.

### RIG-CONF-013 — Installation fields

Tool installation metadata MUST reference one built-in or explicitly declared external provider and MUST obey that provider's native kind contract. Built-in kinds MUST include Homebrew `formula`, `cask`, and `mas`; uv `tool`; mise `tool`; npm `global`; chezmoi `target`; and direct-download `executable`. `install.destination` and `install.checksum` MUST be valid only for `direct-download` installations. Homebrew `mas` locators MUST be numeric application identities. Direct-download installations MUST use an HTTPS locator, an absolute expanded destination, and a checksum containing `sha256:` followed by exactly 64 lowercase hexadecimal characters.

_Conformance:_ conforming

_Verify:_ Bats tests resolve every built-in kind without provider boilerplate and reject unknown providers, partial installation declarations, incompatible kinds, unsafe downloads, malformed checksums, and invalid Mac App Store identities.

_Evidence:_ `rig_validate_model` owns the exact tool-installation kind matrix and rejects resource-only built-ins; `tests/rig.bats`, `tests/rig-lifecycle.bats`, and `tests/rig-model-boundaries.bats` cover the accepted and rejected classes.

### RIG-CONF-014 — Publication fields

Schema 1 publication tables MUST require string `profile`, `title`, `base-url`, and `publisher`. The profile MUST name a declared profile and the publisher MUST name an explicitly declared external provider allowed to publish.

_Conformance:_ conforming

_Verify:_ Bats tests resolve one publication and reject missing or unknown profile and publisher references, built-in provider identities, and external publishers without the exact publication operation.

_Evidence:_ `rig_validate_model` requires an explicit custom publisher with the `publish` capability before export or handoff; `publication publishers must be explicit custom providers with publish capability` covers each rejection.

### RIG-CONF-015 — Extension action fields

Schema 1 action tables MUST require string `mode` and `description` and MAY contain `platforms`, `arguments`, `allowed-arguments`, and `resource-kinds` string arrays and string `argument-policy`. The provider named by the table identity MUST be an explicitly declared external provider. Mode MUST be `observe` or `mutate`. `argument-policy` defaults to `rig`, MAY be `provider`, and MUST NOT be combined with `allowed-arguments` when set to `provider`. `resource-kinds` accepts only supported managed-resource kinds, requires provider argument policy, and makes the first caller argument a selected qualified resource. Configured and caller arguments MUST retain their literal array boundaries. Built-in provider operations MUST NOT require action tables.

_Conformance:_ conforming

_Verify:_ Bats table tests accept valid external action records; reject malformed identities, missing fields, invalid modes, built-in or unknown providers, and invalid argument policies; preserve configured allow-listed argument boundaries; and exercise built-in operations without action declarations.

_Evidence:_ `rig_validate_action` accepts action tables only for custom providers, while `rig_command_run` dispatches built-in launchd operations directly; `tests/rig.bats` and `tests/rig-model-boundaries.bats` cover both paths.

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

A tool MAY declare bounded dotted `variant.ID.*` fields beneath its single `[tool.ID]` table. Every variant MUST have a non-empty `variant.ID.platforms` string array and at least one installation or artifact field. Installation variants MUST contain `variant.ID.install.provider`, `variant.ID.install.kind`, and `variant.ID.install.locator`; they MAY contain the same bounded destination, checksum, and arguments fields as a non-variant installation. A variant MAY contain `variant.ID.artifacts`. Variant identifiers MUST match normal Rig identifiers.

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
