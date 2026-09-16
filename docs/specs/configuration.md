# Declarative configuration — RIG-CONF

This area of the [Rig Specifications](index.md) defines the inert configuration contract established by [ADR-RIG-003](../decisions/ADR-RIG-003-declarative-configuration-grammar.md) and protected by [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Files and versioning

### RIG-CONF-001 — XDG configuration files

Rig MUST read its root declaration from `${RIG_CONFIG_HOME}/rig.conf` and optional fragments from `${RIG_CONFIG_HOME}/conf.d/*.conf`.

_Conformance:_ conforming

_Verify:_ Bats tests isolate `RIG_CONFIG_HOME`, create a root file and fragments, and assert Rig reads no undeclared configuration location.

_Evidence:_ `tests/rig.bats` isolates both `HOME` and `RIG_CONFIG_HOME`; `rig_load_config` reads only the selected root and fragment directory.

### RIG-CONF-002 — Explicit schema version

Every configuration MUST declare one supported schema version in its root `rig` section.

_Conformance:_ conforming

_Verify:_ Bats tests accept schema version 1 and reject missing, duplicate, and unsupported versions before resolving declarations.

_Evidence:_ `tests/rig.bats` covers accepted schema 1 plus missing, duplicate, and unsupported root schema values.

### RIG-CONF-003 — Deterministic fragment order

Rig MUST load the root file first and then matching fragments in bytewise filename order independent of the user's locale.

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

Rig MUST expand a leading `~/` only in provider `executable` and `manifest` fields and MUST preserve all other value text literally.

_Conformance:_ conforming

_Verify:_ Bats tests compare path and non-path values containing tildes, dollar signs, equals signs, and comment characters under an isolated home directory.

_Evidence:_ `tests/rig.bats` proves only provider executable and manifest values expand leading `~/`; other tildes and shell-significant characters remain literal.

## Schema 1 sections

### RIG-CONF-008 — Canonical section identities

Schema 1 MUST accept `[rig]`, `[category.ID]`, `[tool.ID]`, `[profile.ID]`, `[provider.ID]`, `[binding.TOOL.PROVIDER]`, and `[publication.ID]` section identities whose ID segments match `[a-z][a-z0-9-]*`.

_Conformance:_ conforming

_Verify:_ Bats table tests accept each section form and reject uppercase, empty, dotted, whitespace-containing, and digit-leading identifier segments.

_Evidence:_ `tests/rig.bats` loads every schema 1 section form and rejects malformed category and binding identities.

### RIG-CONF-009 — Root fields

The schema 1 `rig` section MUST accept one `schema` field and one `default-profile` field.

_Conformance:_ conforming

_Verify:_ Bats tests resolve the two root fields and reject missing or repeated values.

_Evidence:_ `rig_validate_model` requires one root schema and default profile; `tests/rig.bats` covers missing and duplicate root scalars.

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

Schema 1 provider sections MUST require `adapter` and accept `command`, `executable`, `manifest`, repeated `argument`, and repeated `capability` fields. A provider whose adapter is `custom` MUST identify one `executable`; other adapter-specific field and capability rules belong to the selected provider adapter.

_Conformance:_ conforming

_Verify:_ Bats tests parse provider fields, require an adapter, require a custom provider executable, and preserve other adapter declarations for later adapter-specific validation.

_Evidence:_ `rig_validate_model` requires provider adapters and custom executables; `tests/rig.bats` preserves provider commands, manifests, arguments, and capabilities literally.

### RIG-CONF-013 — Binding fields

Schema 1 binding sections MUST accept `kind`, `locator`, repeated `platform`, and repeated `argument` fields for the tool and provider named by the section identity.

_Conformance:_ conforming

_Verify:_ Bats tests resolve binding ownership and reject section identities whose tool or provider does not exist.

_Evidence:_ `tests/rig.bats` resolves binding fields and rejects unknown tool and provider identities before binding selection.

### RIG-CONF-014 — Publication fields

Schema 1 publication sections MUST require `profile`, `title`, `base-url`, and `publisher` fields, with `profile` naming a declared profile and `publisher` naming a declared provider.

_Conformance:_ conforming

_Verify:_ Bats tests resolve a public profile and publisher from one publication and reject missing or unknown references.

_Evidence:_ `tests/rig.bats` loads all publication fields and rejects missing and unknown profile or provider references.
