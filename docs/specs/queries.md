# Catalogue queries — RIG-QUERY

This area of the [Rig Specifications](index.md) defines read-only ways to answer catalogue questions from [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md) within the non-execution boundary of [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Resolved views

### RIG-QUERY-001 — Show a rig

`rig show` MUST describe the resolved default profile, and `rig show --profile NAME` MUST describe the named profile without changing the configured default.

_Conformance:_ pending

_Verify:_ Bats tests compare default and named profile summaries from one isolated catalogue.

### RIG-QUERY-002 — List catalogue tools

`rig list` MUST list catalogue tools deterministically and support narrowing the result by declared category or resolved profile.

_Conformance:_ pending

_Verify:_ Bats tests assert stable full, `--category`, and `--profile` outputs across permuted input declarations.

### RIG-QUERY-003 — Explain a tool

`rig explain TOOL` MUST report the tool's name, category, purpose, rationale, platforms, relationships, profile membership, and compatible provider binding.

_Conformance:_ pending

_Verify:_ Bats tests explain one fixture tool and assert every declared and derived field is attributed correctly.

## Query safety

### RIG-QUERY-004 — Declarative query boundary

`rig show`, `rig list`, and `rig explain` MUST NOT invoke a built-in or custom provider.

_Conformance:_ pending

_Verify:_ Bats tests configure marker providers, run every query form, and assert the marker log remains absent.

### RIG-QUERY-005 — Unknown query identity

Rig MUST reject an unknown category, profile, or tool query with status 2 and a namespaced diagnostic.

_Conformance:_ pending

_Verify:_ Bats tests query each unknown identity class and assert status 2, stderr naming, and no provider invocation.
