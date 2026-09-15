# Profile and provider orchestration — RIG-ORCH

This area of the [Rig Specifications](index.md) defines profile and provider orchestration beneath the catalogue model in [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md). Executable transitions follow [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Profiles

### RIG-ORCH-001 — Configurable default profile

Rig MUST allow a user to define which catalogue tools constitute the default profile.

_Conformance:_ pending

_Verify:_ Bats tests create isolated configuration, invoke Rig without an explicit profile, and assert only the configured default tools are selected.

### RIG-ORCH-002 — Explicit profile selection

Rig MUST allow a user to select a non-default configured profile without changing the stored default.

_Conformance:_ pending

_Verify:_ Bats tests invoke two named profiles against the same isolated configuration and assert their resolved selections remain independent.

### RIG-ORCH-007 — Profile composition

Rig MUST allow a profile to include other declared profiles and expand required tool relationships transitively.

_Conformance:_ pending

_Verify:_ Bats tests compose nested profiles with required tools and assert one de-duplicated resolved tool set.

### RIG-ORCH-008 — Invalid profile graph

Rig MUST reject unknown profile references, unknown tool references, and profile or required-tool cycles before invoking a provider.

_Conformance:_ pending

_Verify:_ Bats table tests exercise every invalid graph class and assert status 2 with an empty provider-call log.

## Providers

### RIG-ORCH-003 — Native provider authority

Rig MUST delegate package resolution, manifest interpretation, and provider state changes to the selected provider rather than maintain a competing package database.

_Conformance:_ pending

_Verify:_ Bats tests substitute recording providers and assert Rig forwards configured native manifest and locator arguments without resolving packages itself.

### RIG-ORCH-004 — Capability-aware actions

Rig MUST reject an action that a configured provider does not declare as supported before invoking that provider.

_Conformance:_ pending

_Verify:_ Bats tests select a provider without the requested capability and assert status 2 with no recorded provider invocation.

### RIG-ORCH-005 — Dependency order

Rig MUST execute selected providers in resolved dependency order.

_Conformance:_ pending

_Verify:_ Bats tests configure recording providers with dependencies and assert the exact invocation sequence.

### RIG-ORCH-006 — Initial provider classes

Rig MUST support Homebrew, uv, chezmoi, direct-download, and explicitly configured executable providers without requiring an unselected provider's executable.

_Conformance:_ pending

_Verify:_ Bats tests exercise each provider through fakes and run an unrelated profile while all five native executables are absent.

### RIG-ORCH-009 — Platform binding selection

Rig MUST select exactly one compatible provider binding for each materialisable tool on the active platform and reject zero or ambiguous compatible bindings.

_Conformance:_ pending

_Verify:_ Bats tests resolve disjoint macOS and Linux bindings, then assert missing and overlapping bindings fail before provider invocation.

### RIG-ORCH-010 — Literal executable arguments

Rig MUST invoke a custom provider as one configured executable with each configured argument preserved as a literal argument boundary.

_Conformance:_ pending

_Verify:_ Bats tests record custom-provider arguments containing spaces and shell metacharacters and assert no shell interpretation occurs.

### RIG-ORCH-011 — Ordered failure boundary

Rig MUST skip every dependent provider after its prerequisite fails while reporting the native failure result.

_Conformance:_ pending

_Verify:_ Bats tests force a middle provider to fail and assert its dependent is not invoked while independent completed work remains reported.
