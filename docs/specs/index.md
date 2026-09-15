# Rig specifications

This corpus records Rig's accepted, testable behaviour. Decision Records explain why the behaviour exists, Guides explain how to use it, and roadmap records schedule delivery.

## Reading a requirement

Each numbered requirement contains one normative statement, its current conformance state, and a concrete verification plan. IDs are append-only and never reused.

## Conformance states

- `conforming` means current implementation evidence satisfies the requirement.
- `pending` means the requirement is accepted but not implemented.
- `divergent` means the implementation and accepted contract currently differ.

## Gaps

An unnumbered `## Gaps` entry is a candidate behaviour, not an accepted requirement. Promotion allocates the next identifier and records an honest conformance state.

## Areas

| File | Prefix | Covers |
| --- | --- | --- |
| orchestration.md | `RIG-ORCH` | Profiles, targets, actions, and native authority |
| portability.md | `RIG-PORT` | Runtime dependencies and XDG persistence |
