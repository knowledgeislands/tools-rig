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

Rig MUST support `requires`, `related`, and `alternative` relationships between declared tool identifiers and reject unknown relationship endpoints.

_Conformance:_ conforming

_Verify:_ Bats tests resolve each relationship type and reject a relationship to an undeclared tool.

_Evidence:_ `tests/rig.bats` preserves `requires`, `related`, and `alternative` values and rejects unknown endpoints before resolution.

### RIG-CAT-005 — Provider bindings

Rig MUST treat a tool with at least one binding as materialisable and connect it to providers through separately identified bindings that retain provider-native kind and locator values. A catalogue-only tool may have no binding.

_Conformance:_ conforming

_Verify:_ Bats tests resolve tool-to-provider bindings for native manifests and package locators without interpreting either as a Rig package database.

_Evidence:_ `rig_select_bindings` resolves declared tool-provider sections while preserving kind and locator fields; `tests/rig.bats` covers bound and catalogue-only tools together.

### RIG-CAT-006 — Stable validation result

Rig MUST return the same validated catalogue for equivalent declarations regardless of section order or fragment boundaries.

_Conformance:_ conforming

_Verify:_ Bats tests permute equivalent category, tool, provider, and binding sections across fragments and compare bytewise-sorted internal resolver output.

_Evidence:_ `rig_sort_selected_tools` applies bytewise ordering and `tests/rig.bats` resolves declarations split and reordered across fragments to stable output.
