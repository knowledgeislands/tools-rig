# Declarative configuration — RIG-CONF

This area of the [Rig Specifications](index.md) defines the inert configuration contract established by [ADR-RIG-003](../decisions/ADR-RIG-003-declarative-configuration-grammar.md) and protected by [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Files and versioning

### RIG-CONF-001 — XDG configuration files

Rig MUST read an optional root declaration from `${RIG_CONFIG_HOME}/rig.conf` followed by regular fragments from `${RIG_CONFIG_HOME}/conf.d/*.conf`. At least one source MUST exist, and the merged model MUST contain exactly one `[rig]` section.

_Conformance:_ conforming

_Verify:_ Bats tests isolate `RIG_CONFIG_HOME`, exercise root-only, root-plus-fragment, fragment-only, and no-source layouts, and assert Rig reads no undeclared configuration location.

_Evidence:_ `tests/rig.bats` isolates both `HOME` and `RIG_CONFIG_HOME`; `rig_load_config` accepts one or more selected sources and reads only the selected root and fragment directory.

### RIG-CONF-002 — Explicit schema version

Every configuration MUST declare one supported schema version in its root `rig` section.

_Conformance:_ conforming

_Verify:_ Bats tests accept schema version 1 and reject missing, duplicate, and unsupported versions before resolving declarations.

_Evidence:_ `tests/rig.bats` covers accepted schema 1 plus missing, duplicate, and unsupported root schema values.

### RIG-CONF-003 — Deterministic fragment order

Rig MUST load the root file first when present and then matching fragments in bytewise filename order independent of the user's locale.

_Conformance:_ conforming

_Verify:_ Bats tests create fragments whose names and declarations reveal load order, vary `LC_ALL`, and assert one stable result.

_Evidence:_ `rig_load_config` scopes `LC_ALL=C` around root-first fragment loading; `tests/rig.bats` asserts bytewise fragment precedence.

## Grammar and validation

### RIG-CONF-004 — Inert records

Rig MUST parse configuration as named sections and literal `key = value` records without sourcing files, evaluating commands, interpreting shell quoting, or performing general environment expansion.

_Conformance:_ conforming

_Verify:_ Bats tests place shell syntax and command substitutions in values, assert no marker command runs, and inspect the literal parsed values.

_Evidence:_ `tests/rig.bats` loads command substitutions and shell metacharacters as literal values and proves the marker command is not executed.

### RIG-CONF-005 — Schema-controlled declarations

Rig MUST reject unknown section types, unknown keys, duplicate scalar fields, conflicting identities, and malformed records before returning a resolved rig.

_Conformance:_ conforming

_Verify:_ Bats table tests provide each invalid declaration class and assert status 2 with no provider invocation.

_Evidence:_ `tests/rig.bats` exercises unknown sections and fields, duplicate scalars and sections, malformed records, and invalid identities with exit status 2.

### RIG-CONF-006 — Repeatable list fields

Rig MUST preserve every occurrence of a schema-defined repeatable field without treating commas or shell words as implicit separators.

_Conformance:_ conforming

_Verify:_ Bats tests repeat platform, relationship, profile-tool, and capability fields containing spaces or commas and assert exact item boundaries.

_Evidence:_ `tests/rig.bats` retrieves repeated relationship, profile, capability, argument, platform, space-containing, and comma-containing values by occurrence.

### RIG-CONF-007 — Bounded path expansion

Rig MUST expand a leading `~/` only while loading provider `executable` and `manifest` fields and direct-download binding `destination` fields. When comparing a tool `artifact`, Rig MUST derive an absolute comparison identity from a leading `~/` or `$HOME/` without changing the stored declaration. Rig MUST preserve embedded variables, other variable names, relative paths, and all other value text literally.

_Conformance:_ conforming

_Verify:_ Bats tests compare path and non-path values containing supported home prefixes, embedded variables, other variable names, tildes, dollar signs, equals signs, and comment characters under an isolated home directory.

_Evidence:_ `tests/rig.bats` proves loaded path fields expand only a leading `~/`, artifact comparison expands only leading `~/` and `$HOME/`, and all unsupported or embedded shell-significant text remains literal.

## Schema 1 sections

### RIG-CONF-008 — Canonical section identities

Schema 1 MUST accept `[rig]`, `[category.ID]`, `[tool.ID]`, `[profile.ID]`, `[provider.ID]`, `[binding.TOOL.PROVIDER]`, and `[publication.ID]` section identities whose ID segments match `[a-z][a-z0-9-]*`.

_Conformance:_ conforming

_Verify:_ Bats table tests accept each section form and reject uppercase, empty, dotted, whitespace-containing, and digit-leading identifier segments.

_Evidence:_ `tests/rig.bats` loads every schema 1 section form and rejects malformed category and binding identities.

### RIG-CONF-009 — Root fields

The schema 1 `rig` section MUST require one `schema` field and one `default-profile` field and MAY accept one `bootstrap-profile` field. Both profile fields MUST name declared profiles. A missing `bootstrap-profile` preserves `default-profile` as the bootstrap fallback.

_Conformance:_ conforming

_Verify:_ Bats tests resolve required root fields, accept one optional bootstrap profile, and reject missing, repeated, or unknown references.

_Evidence:_ `rig_validate_model` requires one root schema and default profile and validates the optional bootstrap reference; `tests/rig.bats` covers fallback, explicit selection, and invalid root scalars.

### RIG-CONF-010 — Catalogue fields

Schema 1 category and tool sections MUST accept category `name` and `purpose` fields and tool `name`, `category`, `purpose`, `rationale`, repeated `platform`, repeated `requires`, repeated `related`, and repeated `alternative` fields.

_Conformance:_ conforming

_Verify:_ Bats tests parse every catalogue field, preserve repeated-field boundaries, and reject a field in the wrong section type.

_Evidence:_ `tests/rig.bats` loads every catalogue field, validates required category and tool meaning, and exercises relationship preservation.

### RIG-CONF-011 — Profile fields

Schema 1 profile sections MUST accept repeated `profile` and `tool` fields.

_Conformance:_ conforming

_Verify:_ Bats tests parse nested profile and tool membership and reject scalar treatment of either repeated field.

_Evidence:_ `tests/rig.bats` composes nested profiles, repeats profile and tool fields, and resolves their de-duplicated selection.

### RIG-CONF-012 — Provider fields

Schema 1 provider sections MUST require `adapter` and accept `command`, `executable`, `manifest`, repeated `argument`, and repeated `capability` fields. A provider whose adapter is `custom` MAY omit `executable`; Rig MUST then resolve exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`. An explicit `executable` MUST take precedence. Other adapter-specific field and capability rules belong to the selected provider adapter.

_Conformance:_ conforming

_Verify:_ Bats tests parse provider fields, require an adapter, resolve omitted custom executables through Rig and XDG data-home precedence, preserve explicit executable overrides, and report unavailable conventional paths without discovery.

_Evidence:_ `rig_validate_model` requires provider adapters; `rig_custom_provider_executable` applies one exact conventional path or the explicit override; `tests/rig.bats` exercises every custom-provider trust-boundary invocation.

### RIG-CONF-013 — Binding fields

Schema 1 binding sections MUST accept `kind`, `locator`, optional scalar `destination` and `checksum`, and repeated `platform` and `argument` fields for the tool and provider named by the section identity. `destination` and `checksum` are valid only for `direct-download` bindings. A Homebrew `mas` binding MUST use a numeric application identity as its locator. A direct-download binding MUST use kind `executable`, an HTTPS locator, an absolute destination after bounded path expansion, and a checksum of `sha256:` followed by exactly 64 lowercase hexadecimal characters.

_Conformance:_ conforming

_Verify:_ Bats tests resolve binding ownership, reject section identities whose tool or provider does not exist, and reject incomplete, non-HTTPS, or malformed direct-download bindings.

_Evidence:_ `rig_validate_binding_adapter` enforces the adapter-kind and direct-download integrity schema; `tests/rig.bats` exercises valid and invalid direct-download declarations.

### RIG-CONF-014 — Publication fields

Schema 1 publication sections MUST require `profile`, `title`, `base-url`, and `publisher` fields, with `profile` naming a declared profile and `publisher` naming a declared provider.

_Conformance:_ conforming

_Verify:_ Bats tests resolve a public profile and publisher from one publication and reject missing or unknown references.

_Evidence:_ `tests/rig.bats` loads all publication fields and rejects missing and unknown profile or provider references.

### RIG-CONF-015 — Operation fields

Schema 1 MUST additionally accept `[operation.TOOL.NAME]` section identities, where both identifier segments match `[a-z][a-z0-9-]*`. An operation MUST name one declared tool through its section identity and MUST require scalar `provider`, `capability`, `mode`, and `description` fields. It MAY repeat `platform`, `argument`, and `allow-argument` fields.

The provider MUST exist, use the `custom` adapter in schema 1, and declare the referenced capability. The `mode` MUST be `observe` or `mutate`. Configured and allowed arguments remain literal values with the same repeated-field boundaries as other schema lists.

_Conformance:_ conforming

_Verify:_ Bats table tests accept valid operation records; reject malformed identities, missing required fields, invalid modes, unknown tools or providers, and undeclared capabilities; and preserve configured and allow-listed argument boundaries.

_Evidence:_ `rig_parse_section_identity`, `rig_field_kind`, and `rig_validate_operation` enforce bounded operation records; `tests/rig.bats` covers valid declarations and rejection before invocation.
