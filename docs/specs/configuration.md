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

Rig MUST accept schema 1 tables, bare keys, decimal integer schema value, single-line basic strings, single-line arrays of basic strings, blank lines, and `#` comments without sourcing files, evaluating commands, interpreting shell syntax, or performing general environment expansion. Every accepted source MUST be valid TOML. Rig MUST reject unsupported TOML types and syntax before returning a resolved rig.

_Conformance:_ conforming

_Verify:_ Bats tests validate representative Rig files with a general TOML reader, prove shell-significant text remains inert, and reject literal strings, multiline arrays, non-string array members, floats, and unsupported escapes.

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

_Evidence:_ `rig_toml_parse_array` decodes one basic string at a time into the existing ordered field model; `tests/rig.bats` inspects values by occurrence and provider argument boundaries.

### RIG-CONF-007 — Bounded path expansion

Rig MUST expand a leading `~/` only while loading provider `executable` and `manifest` fields and direct-download `install.destination` fields. When comparing tool artifacts, Rig MUST derive absolute comparison identity from a leading `~/` or `$HOME/` without changing the stored declaration. Rig MUST preserve embedded variables, other variable names, relative paths, and all other value text literally.

_Conformance:_ conforming

_Verify:_ Bats tests compare path and non-path values containing supported home prefixes, embedded variables, variable names, tildes, dollar signs, equals signs, and comment characters under an isolated home directory.

_Evidence:_ `rig_add_field` performs the loading expansion allow-list; artifact comparison has its own bounded identity conversion; `tests/rig.bats` proves unsupported shell-significant text remains literal.

## Schema 1 tables

### RIG-CONF-008 — Canonical table identities

Schema 1 MUST accept `[rig]`, `[category.ID]`, `[tool.ID]`, `[profile.ID]`, `[provider.ID]`, `[publication.ID]`, `[service.ID]`, `[scheduled-job.ID]`, and `[action.PROVIDER.NAME]` table identities. Every identity segment MUST match `[a-z][a-z0-9-]*`. Any other table shape, including `[binding.TOOL.PROVIDER]`, MUST be rejected; installation metadata belongs only in the tool table.

_Conformance:_ conforming

_Verify:_ Bats table tests accept every supported table form and reject uppercase, empty, extra, whitespace-containing, digit-leading, and binding identities.

_Evidence:_ `rig_parse_section_identity` validates table arity and identity segments; `tests/rig.bats` covers canonical and malformed identities.

### RIG-CONF-009 — Root fields

The schema 1 `rig` table MUST require `schema` and `default-profile` and MAY contain `bootstrap-profile`. Both profile fields MUST name declared profiles. An omitted `bootstrap-profile` MUST preserve `default-profile` as the bootstrap fallback.

_Conformance:_ conforming

_Verify:_ Bats tests resolve required root fields, accept one optional bootstrap profile, and reject missing, repeated, or unknown references.

_Evidence:_ `rig_validate_model` validates root fields and references; bootstrap selection tests cover explicit, configured, and fallback profiles.

### RIG-CONF-010 — Catalogue fields

Schema 1 category tables MUST require string `name` and `purpose`. Tool tables MUST require string `name`, `category`, `purpose`, and `rationale`, MUST require a non-empty `platforms` string array, and MAY contain `requires`, `related`, `alternatives`, and `artifacts` string arrays. A materialised tool MUST co-locate string `install.provider`, `install.kind`, and `install.locator`; it MAY contain string `install.destination` and `install.checksum` and string arrays `install.platforms` and `install.arguments`. A tool without `install.provider` is catalogue-only and MUST NOT contain any other `install.*` field.

_Conformance:_ conforming

_Verify:_ Bats tests parse every catalogue field, preserve array boundaries, resolve relationships, compare artifacts, and reject missing or misplaced fields.

_Evidence:_ `rig_toml_field` maps public TOML keys into the catalogue model; `rig_validate_model` validates required meaning and references; `tests/rig.bats` covers resolution and rejection.

### RIG-CONF-011 — Profile fields

Schema 1 profile tables MAY contain `profiles`, `tools`, `services`, and `scheduled-jobs` string arrays. Every item MUST name a declared profile, tool, service, or scheduled job respectively.

_Conformance:_ conforming

_Verify:_ Bats tests compose profiles and tool membership, preserve array item boundaries, reject unknown references, and detect profile cycles.

_Evidence:_ `rig_validate_references_for_field` and `rig_validate_cycles` validate the mapped values; `tests/rig.bats` covers composition and cycles.

### RIG-CONF-012 — Provider fields

Schema 1 provider tables MUST require string `adapter`, MAY contain string `command`, `executable`, and `manifest`, and MAY contain `arguments` and `capabilities` string arrays. A provider whose adapter is `custom` MAY omit `executable`; Rig MUST then resolve exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`. An explicit executable MUST take precedence.

_Conformance:_ conforming

_Verify:_ Bats tests parse provider fields, require the adapter, preserve argument and capability boundaries, resolve conventional custom executables, and preserve explicit overrides.

_Evidence:_ `rig_validate_model` and `rig_custom_provider_executable` enforce the provider contract; `tests/rig.bats` exercises every executable trust-boundary invocation.

### RIG-CONF-013 — Installation fields

Tool installation metadata MUST reference one declared provider and MUST obey that provider adapter's native kind contract. `install.destination` and `install.checksum` MUST be valid only for `direct-download` installations. Homebrew `mas` locators MUST be numeric application identities. Direct-download installations MUST use kind `executable`, an HTTPS locator, an absolute expanded destination, and a checksum containing `sha256:` followed by exactly 64 lowercase hexadecimal characters.

_Conformance:_ conforming

_Verify:_ Bats tests resolve co-located installation ownership and reject unknown providers, partial installation declarations, incompatible adapter kinds, unsafe downloads, malformed checksums, and invalid Mac App Store identities.

_Evidence:_ `rig_validate_binding_adapter` enforces adapter-specific installation integrity after internal normalisation; `tests/rig.bats` covers valid and invalid declarations.

### RIG-CONF-014 — Publication fields

Schema 1 publication tables MUST require string `profile`, `title`, `base-url`, and `publisher`. The profile MUST name a declared profile and the publisher MUST name a declared provider.

_Conformance:_ conforming

_Verify:_ Bats tests resolve one publication and reject missing or unknown profile and publisher references.

_Evidence:_ `rig_validate_model` validates publication fields and references; `tests/rig.bats` covers the contract.

### RIG-CONF-015 — Action fields

Schema 1 action tables MUST require string `mode` and `description` and MAY contain `platforms`, `arguments`, `allowed-arguments`, and `resource-kinds` string arrays and string `argument-policy`. The provider named by the table identity MUST exist and use the `custom` adapter. Mode MUST be `observe` or `mutate`. `argument-policy` defaults to `rig`, MAY be `provider`, and MUST NOT be combined with `allowed-arguments` when set to `provider`. `resource-kinds` accepts only `service` and `scheduled-job`, requires provider argument policy, and makes the first caller argument a selected qualified resource. Configured and caller arguments MUST retain their literal array boundaries.

_Conformance:_ conforming

_Verify:_ Bats table tests accept valid action records; reject malformed identities, missing fields, invalid modes, unknown providers, non-custom providers, and invalid argument policies; and preserve configured allow-listed argument boundaries.

_Evidence:_ `rig_validate_action` validates bounded action records; `tests/rig.bats` covers declarations and rejection before invocation.

### RIG-CONF-016 — Operational resource fields

Schema 1 service and scheduled-job tables MUST require string `name`, `purpose`, `rationale`, `provider`, `locator`, and `desired-state`, plus non-empty `platforms` and `program` string arrays. They MAY contain `requires`, `environment`, optional working-directory and standard-output/error strings. A service desired state MUST be `running` or `stopped`; optional restart policy MUST be `always` or `never`, and start policy MUST be `load` or `manual`. A scheduled-job desired state MUST be `enabled` or `disabled`; it MUST declare exactly one non-empty `schedule.calendar` string array or positive-decimal-string `schedule.interval`; optional run policy MUST be `scheduled-only` or `also-at-load`, and priority MUST be `background` or `normal`. Calendar records MUST contain unique comma-separated `minute|hour|day|weekday|month=DECIMAL` pairs within native-neutral numeric ranges. Environment records MUST be literal `KEY=value` strings. Providers and required tools MUST resolve, providers MUST be custom, and provider locator pairs MUST be unique across resources.

_Conformance:_ conforming

_Verify:_ Bats tests accept service and both scheduled-job schedule forms, preserve literal program and environment arguments, and reject unknown references, invalid enums, empty programs, malformed environment, invalid or conflicting schedules, and duplicate provider locators.

_Evidence:_ `rig_validate_resource`, calendar and environment validators, model reference validation, and focused operational-resource tests enforce the schema before any provider invocation.
