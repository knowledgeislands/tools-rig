# Catalogue — RIG-CAT

This area of the [Rig Specifications](index.md) defines the catalogue that [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md) makes Rig's primary product concept.

## Categories and tools

### RIG-CAT-001 — Declared categories

Rig MUST require every catalogue tool to reference exactly one declared category with a stable identifier, display name, and purpose.

_Conformance:_ conforming

_Verify:_ Bats tests resolve valid categories and reject missing, unknown, and multiply assigned tool categories.

_Evidence:_ `rig_validate_model` requires category name and purpose and one declared category reference per tool; `tests/rig.bats` exercises valid and unknown references.

### RIG-CAT-002 — Tool meaning

Rig MUST require every tool to declare a stable identifier, display name, purpose, and personal rationale.

_Conformance:_ conforming

_Verify:_ Bats table tests omit each required field in turn and assert resolution fails with the affected tool identifier.

_Evidence:_ `rig_validate_model` requires tool name, category, purpose, rationale, and platform; `tests/rig.bats` asserts required-field failures are namespaced to the tool.

### RIG-CAT-003 — Supported platforms

Rig MUST require every tool to declare one or more platform identifiers. The reserved identifier `any` declares a platform-independent tool; omitting every platform is invalid.

_Conformance:_ conforming

_Verify:_ Bats tests resolve macOS-only, Linux-only, multi-platform, and `any` fixtures and reject a tool with no platform.

_Evidence:_ `tests/rig.bats` resolves exact-platform and `any` tools, filters unsupported tools, and rejects a tool with no platform declaration.

## Relationships and materialisation

### RIG-CAT-004 — Typed relationships

Rig MUST support `requires`, `related`, and `alternatives` relationships between declared tool identifiers and reject unknown relationship endpoints.

_Conformance:_ conforming

_Verify:_ Bats tests resolve each relationship type and reject a relationship to an undeclared tool.

_Evidence:_ `tests/rig.bats` preserves `requires`, `related`, and `alternatives` values and rejects unknown endpoints before resolution.

### RIG-CAT-005 — Tool installations

Rig MUST treat a tool with complete `install.*` metadata as materialisable and connect it to exactly one built-in or explicitly declared external provider while retaining provider-native kind and locator values. Built-in provider identities MUST NOT require provider declarations. A catalogue-only tool has no installation metadata. Source configuration MUST NOT define a separate binding table.

_Conformance:_ conforming

_Verify:_ Bats tests resolve co-located tool installation metadata for implicit built-ins and explicit extensions without interpreting native manifests or locators as a Rig package database, and reject source-authored `[binding.*]` tables.

_Evidence:_ `rig_synthesise_bindings`, `rig_validate_binding_adapter`, and `rig_resolve_bindings` derive one internal binding from each complete `install.*` declaration; the `source configuration rejects former binding tables before writing stdout` and `tool installation selects its declared provider when compatible` Bats tests cover the public boundary.

### RIG-CAT-006 — Stable validation result

Rig MUST return the same validated catalogue for equivalent declarations regardless of section order or fragment boundaries.

_Conformance:_ conforming

_Verify:_ Bats tests permute equivalent category, tool, provider, and installation declarations across fragments and compare bytewise-sorted internal resolver output.

_Evidence:_ `rig_sort_selected_tools` applies bytewise ordering and `tests/rig.bats` resolves declarations split and reordered across fragments to stable output.

### RIG-CAT-007 — Tool-owned generated artifacts

Rig MUST keep a durable generated launcher, handler, or comparable path with the catalogue tool whose capability it exposes. A generated artifact MUST NOT require a second catalogue entry merely to acknowledge its path. Installation, rationale, relationships, profile membership, and artifacts MUST resolve through the same tool identity. Artifact creation, update, and removal remain the native tool's responsibility.

_Conformance:_ conforming

_Verify:_ Bats explains one tool with co-located installation and artifact metadata, then observes artifact health through that tool.

_Evidence:_ `rig_command_explain` reports the owning tool's artifacts; `tests/rig-artifacts.bats` covers ownership and observation.
