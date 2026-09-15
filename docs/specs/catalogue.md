# Catalogue — RIG-CAT

This area of the [Rig Specifications](index.md) defines the catalogue that [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md) makes Rig's primary product concept.

## Categories and tools

### RIG-CAT-001 — Declared categories

Rig MUST require every catalogue tool to reference exactly one declared category with a stable identifier, display name, and purpose.

_Conformance:_ pending

_Verify:_ Bats tests resolve valid categories and reject missing, unknown, and multiply assigned tool categories.

### RIG-CAT-002 — Tool meaning

Rig MUST require every tool to declare a stable identifier, display name, purpose, and personal rationale.

_Conformance:_ pending

_Verify:_ Bats table tests omit each required field in turn and assert resolution fails with the affected tool identifier.

### RIG-CAT-003 — Supported platforms

Rig MUST preserve one or more declared platform identifiers for every tool and distinguish an explicit platform-independent declaration from an omitted platform.

_Conformance:_ pending

_Verify:_ Bats tests resolve macOS-only, Linux-only, multi-platform, platform-independent, and missing-platform fixtures.

## Relationships and materialisation

### RIG-CAT-004 — Typed relationships

Rig MUST support `requires`, `related`, and `alternative` relationships between declared tool identifiers and reject unknown relationship endpoints.

_Conformance:_ pending

_Verify:_ Bats tests resolve each relationship type and reject a relationship to an undeclared tool.

### RIG-CAT-005 — Provider bindings

Rig MUST connect materialisable tools to providers through separately identified bindings that retain provider-native kind and locator values.

_Conformance:_ pending

_Verify:_ Bats tests resolve tool-to-provider bindings for native manifests and package locators without interpreting either as a Rig package database.

### RIG-CAT-006 — Stable validation result

Rig MUST return the same validated catalogue for equivalent declarations regardless of section order or fragment boundaries.

_Conformance:_ pending

_Verify:_ Bats tests permute equivalent category, tool, provider, and binding sections across fragments and compare normalised query output.
