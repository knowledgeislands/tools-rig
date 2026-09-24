# Rig Specifications

This corpus records Rig's accepted, testable behaviour. Decision Records explain why behaviour exists, Guides explain how to use it, and roadmap records schedule delivery.

## Reading a requirement

Each numbered requirement contains one normative statement, its current conformance state, and a concrete verification plan. IDs are append-only and never reused.

## Conformance states

- `conforming` means current implementation evidence satisfies the requirement.
- `pending` means the requirement is accepted but not implemented.
- `divergent` means the implementation and accepted contract currently differ.

## Gaps

An unnumbered `## Gaps` entry is candidate behaviour, not an accepted requirement. Promotion allocates the next identifier and records an honest conformance state.

## Areas

| File | Prefix | Covers |
| --- | --- | --- |
| [catalogue.md](catalogue.md) | `RIG-CAT` | Categories, tools, rationale, platforms, relationships, installations |
| [configuration.md](configuration.md) | `RIG-CONF` | Inert TOML schema, built-ins, extensions, managed-resource declarations |
| [orchestration.md](orchestration.md) | `RIG-ORCH` | Profiles, native bootstrap, work ordering, built-ins, extension protocol |
| [portability.md](portability.md) | `RIG-PORT` | Runtime dependencies and XDG persistence |
| [publishing.md](publishing.md) | `RIG-PUB` | Public view profiles, versioned public data, canonical URLs |
| [queries.md](queries.md) | `RIG-QUERY` | Show, list, filtering, tool and managed-resource explanation, non-execution |
| [state.md](state.md) | `RIG-STATE` | Observations, bootstrap/apply plans, machine-resource state, receipts, outcomes |
