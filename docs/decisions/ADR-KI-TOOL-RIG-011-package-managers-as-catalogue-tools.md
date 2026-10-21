---
id: ADR-KI-TOOL-RIG-011
title: 'Package Managers as Catalogue Tools'
date: 2026-10-20
status: current
decision_type: architecture
decision_type_url: https://knowledgeislands.info/specifications/decision-records/adr
decision_depends_on: [PDR-KI-TOOL-RIG-001, ADR-KI-TOOL-RIG-003, ADR-KI-TOOL-RIG-005]
---

# ADR-KI-TOOL-RIG-011: Package Managers as Catalogue Tools

## Context

Rig's built-in managers are Homebrew, mas, mise, npm, uv and chezmoi. Most of them are ordinary catalogue tools that other tools reach through hand-written `requires` links, but Homebrew, the manager behind most installation-bearing tools, sits outside the catalogue: it must already be available, has no rationale or public card, and a missing Homebrew surfaces as one `unavailable` finding for every tool it would install. Nothing checks that a tool installed by mas, mise, npm or uv declares the matching `requires`, so a missing link fails a fresh machine's apply without warning.

Manager knowledge therefore lives in code. Apply may defer a missing manager only for a fixed matrix of four prerequisite shapes, and doctor prints a fixed list of manager executables only when the configuration fails to load. A tool's installation can differ by platform variant while its catalogue identity stays single, so the manager a tool needs is a property of its bound provider on the resolved platform, not of the tool.

## Decision

A catalogue tool may declare `provides = "MANAGER"`, naming one built-in manager. At most one tool provides each manager, and `provides` never appears on a platform variant. Custom providers ship as executables and are never declared through `provides`.

Rig derives a manager edge for every selected tool whose bound provider on the resolved platform is a manager that a selected tool provides. Derived edges sit beside hand-written `requires`: the plan order is their union, a hand-written edge that duplicates a derived one is accepted silently, both enter cycle detection, and `rig explain` labels each edge `derived` or `declared`. Derived edges never enter the public projection.

Homebrew is observed and never installed. A tool that provides Homebrew needs no installation binding, is observation-only, and is never deferred. Apply defers any other missing provided manager when its providing tool runs earlier in the selected plan, by either kind of edge. The fixed deferral matrix remains as a fallback for a manager that no selected tool provides, so a configuration that never declares `provides` keeps its present behaviour.

A missing provided manager produces one actionable finding on the tool that provides it, and each dependant reports as blocked by that tool. With a loaded configuration, doctor reports the availability of every manager the selected plan binds, built-in and custom, and a custom provider's availability is its executable's. The check that warns when a selected tool's manager is provided by no selected tool runs only once the catalogue declares at least one `provides`.

## Consequences

Existing configurations stay valid without edits: about two dozen hand-written manager `requires` keep working beside the derived edges, and a catalogue without `provides` sees neither new warnings nor a change in apply order. Adopting `provides` is a configuration change the person makes when ready.

The specification requirement that Homebrew must already be available becomes "observed, never installed", and manager deferral reads catalogue data rather than a code matrix. Two deferral routes coexist until a later decision removes the matrix.

Homebrew gains a rationale and public card as an ordinary catalogue tool, but whether derived manager edges appear among public relationships needs its own decision. Rig still never installs Homebrew or orchestrates a Brewfile or Homebrew Bundle, as ADR-KI-TOOL-RIG-005 requires.

## References

- [PDR-KI-TOOL-RIG-001](PDR-KI-TOOL-RIG-001-catalogue-led-working-setup.md) - places the manager-of-managers model beneath the catalogue.
- [ADR-KI-TOOL-RIG-003](ADR-KI-TOOL-RIG-003-declarative-configuration-grammar.md) - keeps the new field declarative.
- [ADR-KI-TOOL-RIG-005](ADR-KI-TOOL-RIG-005-provider-execution-contract.md) - fixes the built-in provider registry and declared manager prerequisites this decision moves into data.
