# Target orchestration — RIG-ORCH

This area of the [Rig specifications](index.md) defines observable profile and target orchestration without prescribing a target's native implementation. It follows [PDR-RIG-001](../decisions/PDR-RIG-001-manager-of-managers.md).

## Profiles

### RIG-ORCH-001 — Configurable default profile

Rig MUST allow a user to define the targets that constitute the default machine-bootstrap profile.

_Conformance:_ pending

_Verify:_ Bats tests create isolated configuration, invoke Rig without an explicit profile, and assert only configured default targets are selected in declared order.

### RIG-ORCH-002 — Explicit profile selection

Rig MUST allow a user to select a non-default configured profile without changing the stored default.

_Conformance:_ pending

_Verify:_ Bats tests invoke two named profiles against the same isolated configuration and assert their target selections remain independent.

## Targets

### RIG-ORCH-003 — Native target authority

Rig MUST delegate package resolution, manifest interpretation, and target state changes to the selected target's native command rather than maintaining a competing package database.

_Conformance:_ pending

_Verify:_ Bats tests substitute recording target commands and assert Rig forwards the configured native manifest and arguments without resolving packages itself.

### RIG-ORCH-004 — Capability-aware actions

Rig MUST reject an action that a configured target does not declare as supported before invoking that target.

_Conformance:_ pending

_Verify:_ Bats tests select a target without the requested capability and assert status 2 with no recorded target invocation.

### RIG-ORCH-005 — Ordered failure boundary

Rig MUST execute selected targets in resolved dependency order and MUST stop dependent execution after a target failure.

_Conformance:_ pending

_Verify:_ Bats tests configure three recording targets with dependencies, force the middle target to fail, and assert ordered execution excludes its dependent.

### RIG-ORCH-006 — Initial target classes

Rig MUST support Homebrew, uv, chezmoi, and an explicitly configured executable as initial target classes without requiring any target executable when its target is not selected.

_Conformance:_ pending

_Verify:_ Bats tests exercise each target through fakes and run an unrelated profile with all four native executables absent.
