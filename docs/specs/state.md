# Expected and observed state — RIG-STATE

This area of the [Rig Specifications](index.md) defines comparison and application beneath [PDR-RIG-001](../decisions/PDR-RIG-001-catalogue-led-working-setup.md) and the execution boundary in [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Observation

### RIG-STATE-001 — Profile expectation

`rig status` MUST compare every tool expected by the resolved profile with an observation from its selected provider.

_Conformance:_ pending

_Verify:_ Bats tests resolve explicit, inherited, and required tools and assert each receives one provider observation.

### RIG-STATE-002 — Observation vocabulary

Rig MUST classify an expected tool as exactly one of `present`, `missing`, `drifted`, `unavailable`, or `unknown`.

_Conformance:_ pending

_Verify:_ Bats table tests make a fake provider return every supported observation and reject an unrecognised result.

### RIG-STATE-003 — Provider-owned evidence

Rig MUST derive observed state from the selected provider without creating a competing persistent installation database.

_Conformance:_ pending

_Verify:_ Bats tests change fake-provider output between invocations and assert `rig status` reflects the current provider result without a Rig state file.

### RIG-STATE-004 — Read-only status

`rig status` MUST invoke only declared observation capabilities and MUST NOT invoke a mutation capability.

_Conformance:_ pending

_Verify:_ Bats tests give observation and mutation capabilities separate marker logs and assert only observation runs.

## Application

### RIG-STATE-005 — Explicit apply

`rig apply` MUST invoke mutation capabilities only for providers selected by the resolved profile and an explicitly requested scope.

_Conformance:_ pending

_Verify:_ Bats tests configure selected and unselected recording providers, apply a bounded scope, and assert only matching providers run.

### RIG-STATE-006 — Dry-run plan

`rig apply --dry-run` MUST report the resolved provider plan without invoking a mutation capability.

_Conformance:_ pending

_Verify:_ Bats tests inspect ordered dry-run output and assert every provider mutation marker remains absent.

### RIG-STATE-007 — Failed prerequisite

Rig MUST report a failed provider and each skipped dependent distinctly from providers that were not selected.

_Conformance:_ pending

_Verify:_ Bats tests fail a provider in a mixed dependency graph and assert distinct failed, skipped, completed, and unselected outcomes.
