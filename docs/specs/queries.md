# Catalogue queries — RIG-QUERY

This area of the [Rig Specifications](index.md) defines read-only ways to answer catalogue questions under [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md) and within the non-execution boundary of [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Resolved views

### RIG-QUERY-001 — Show a rig

`rig show` MUST describe the resolved default profile, and `rig show --profile NAME` MUST describe a named profile without changing the configured default.

_Conformance:_ conforming

_Verify:_ Bats tests compare default and named profile summaries from one isolated catalogue.

_Evidence:_ `tests/rig.bats` asserts exact deterministic default and named-profile output, including selected tools and active platform.

### RIG-QUERY-002 — List catalogue tools

`rig list` MUST list catalogue tools deterministically and support narrowing the result by declared category and resolved profile.

_Conformance:_ conforming

_Verify:_ Bats tests assert stable full, `--category`, `--profile`, and combined outputs across permuted input declarations.

_Evidence:_ `tests/rig.bats` compares exact tabular output before and after fragment permutation and covers category, profile, and intersected filters.

### RIG-QUERY-003 — Explain a tool

`rig explain TOOL` MUST report the tool's name, category, purpose, rationale, platforms, relationships, profile membership, and compatible provider binding.

_Conformance:_ conforming

_Verify:_ Bats tests explain one fixture tool and assert every declared and derived field is attributed correctly.

_Evidence:_ `tests/rig.bats` checks exact identity and meaning fields plus sorted platforms, required, related, alternative, direct, inherited, and required profile membership and the active-platform binding.

## Query safety

### RIG-QUERY-004 — Declarative query boundary

`rig show`, `rig list`, and `rig explain` MUST NOT invoke a built-in or custom provider.

_Conformance:_ conforming

_Verify:_ Bats tests configure marker providers, run every query form, and assert the marker log remains absent.

_Evidence:_ `tests/rig.bats` runs all three public query commands against an executable marker provider and proves its marker file is never created.

### RIG-QUERY-005 — Unknown query identity

Rig MUST reject an unknown category, profile, or tool query with status 2 and a namespaced diagnostic.

_Conformance:_ conforming

_Verify:_ Bats tests query each unknown identity class and assert status 2, stderr naming, and no provider invocation.

_Evidence:_ `tests/rig.bats` covers unknown category, profile, and tool identities with exact `rig: error:` diagnostics and an untouched provider marker.
