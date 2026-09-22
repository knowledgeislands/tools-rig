# Catalogue queries — RIG-QUERY

This area of the [Rig Specifications](index.md) defines read-only ways to answer catalogue questions under [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md) and within the non-execution boundary established by [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Resolved views

### RIG-QUERY-001 — Show a rig

`rig show` MUST describe the resolved default profile, and `rig show --profile NAME` MUST describe a named profile without changing the configured default. The output MUST present profile metadata, a human-readable aligned tool table, and concise selected service, scheduled-job, setting, and Dock-layout sections. Table rows MUST use a stable 120-character budget and mark abbreviated values with `...`; qualified `rig explain` retains complete metadata.

_Conformance:_ conforming

_Verify:_ Bats tests compare exact default and named profile summaries, every selected declaration kind, and bounded-width abbreviation.

_Evidence:_ `rig_command_show`, `rig_print_profile_tool_table`, and `rig_print_profile_resource_tables` render the resolved profile within the width budget; `show describes the resolved profile in an aligned table` and the typed macOS query test cover tool and managed-resource sections.

### RIG-QUERY-002 — List catalogue tools

`rig list` MUST list catalogue tools deterministically and support narrowing the result by declared category and resolved profile.

_Conformance:_ conforming

_Verify:_ Bats tests assert stable full, `--category`, `--profile`, and combined outputs across permuted input declarations.

_Evidence:_ `tests/rig.bats` compares exact tabular output before and after fragment permutation and covers category, profile, and intersected filters.

### RIG-QUERY-003 — Explain a tool

`rig explain TOOL` MUST report the tool's name, category, purpose, rationale, platforms, relationships, profile membership, and compatible installation metadata.

_Conformance:_ conforming

_Verify:_ Bats tests explain one fixture tool and assert every declared and derived field is attributed correctly.

_Evidence:_ `tests/rig.bats` checks exact identity and meaning fields plus sorted platforms, requirements, relationships, profile membership, and active-platform installation.

### RIG-QUERY-004 — Declarative query boundary

`rig show`, `rig list`, and `rig explain` MUST NOT invoke a built-in or external provider.

_Conformance:_ conforming

_Verify:_ Bats tests configure marker providers, run every query form, and assert the marker log remains absent.

_Evidence:_ `tests/rig.bats` runs all three public query commands against an executable marker provider and proves its marker file is never created.

### RIG-QUERY-005 — Unknown query identity

Rig MUST reject an unknown category, profile, tool, or qualified managed-resource query with status 2 and a namespaced diagnostic.

_Conformance:_ conforming

_Verify:_ Bats tests query each unknown identity class and assert status 2, stderr naming, and no provider invocation.

_Evidence:_ `rig_command_show`, `rig_command_list`, `rig_command_explain`, and `rig_explain_resource` fail closed on unknown identities; `catalogue queries reject unknown identities with status two` covers category, profile, and tool diagnostics without provider execution.

### RIG-QUERY-006 — Managed resource disclosure

`rig show` MUST include every managed resource selected by the resolved profile. `rig explain service:ID`, `rig explain scheduled-job:ID`, `rig explain setting:ID`, and `rig explain dock:ID` MUST report complete declarative identity, profile membership, native ownership, desired values, literal items, paths, policies, and defaults appropriate to that kind. Dock explanation MUST include ordered item details. The commands MUST NOT invoke any provider or write state.

_Conformance:_ conforming

_Verify:_ Bats tests compare selected resource sections and complete qualified explanations while provider markers and an isolated state directory remain untouched.

_Evidence:_ `rig_explain_resource` expands Dock item identities and their ordered kind, path, view, and display fields without dispatching providers; `dock explanation expands ordered semantic item details` covers the complete projection.

### RIG-QUERY-007 — Private port disclosure

`rig show` MUST list every private port selected by the resolved profile with identity, name, number, scope, mode, and qualified owner; `rig explain port:ID` MUST report its complete authored intent and profile membership. Both commands MUST remain inert and MUST NOT inspect listeners or mutate sockets.

_Conformance:_ conforming

_Verify:_ Bats invokes both queries with a recording listener command and asserts deterministic content and no command invocation.

_Evidence:_ `rig_print_profile_ports`, `rig_explain_resource`, and the private-port query test implement and verify the contract.
