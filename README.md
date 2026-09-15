# Rig

Rig is the declarative description and manager of a person's working setup. Its catalogue records preferred tools, what they are for, why they belong, how they relate, where they are supported, and how providers materialise them.

Profiles select catalogue subsets for machines, roles, or contexts. Rig can compare a selected profile with provider observations and derive an explicitly public profile into a personal site such as `rig.midnight.ninja`.

## Principles

- **Catalogue first** — stable categories and tool identities make the setup understandable before any installation or mutation occurs.
- **Purpose and rationale** — the catalogue records both what a tool does and why it belongs in this rig.
- **Composable profiles** — named subsets describe machines, roles, contexts, and a deliberately public view.
- **Provider authority** — Homebrew, uv, chezmoi, downloads, custom executables, and publishers retain their native manifests, resolution, execution, deployment, and state.
- **Expected versus observed** — Rig reports whether the selected declaration is present, missing, drifted, unavailable, or unknown on a machine.
- **Safe publication** — a static public projection excludes provider configuration, private profiles, and observed machine state.
- **Shell-only core** — the installed `rig` executable requires Bash and no language runtime or package-manager dependency.
- **XDG-aligned state** — configuration, data, state, and cache use XDG Base Directory locations and explicit Rig overrides.

## Product model

The catalogue is Rig's source of meaning. Profiles resolve that catalogue for a context. Providers are the manager-of-managers mechanism that observes or materialises selected tools. State compares the resolved intent with provider evidence. Publication projects only an explicitly selected public profile into a reviewable static artifact before a trusted publisher deploys it.

Personal catalogue contents and machine-specific paths belong in private Rig configuration, not in this executable. Provider-native manifests such as a Brewfile remain authoritative for their own systems.

## Status

Rig is at its contract stage. The executable currently exposes version, help, completion, and XDG-path discovery. The accepted product, configuration, trust, state, query, and publication contracts are recorded in [Decision Records](docs/decisions/README.md) and [Specifications](docs/specs/index.md); implementation is sequenced through the [roadmap](ROADMAP.md).

## Try the scaffold

Link the checkout into the conventional user executable and manual locations:

```sh
./install.sh --link
rig --help
rig paths
```

The default executable location is `~/.local/bin`. XDG does not define a binary directory, so `RIG_INSTALL_DIR` remains the explicit installation override.

## Documentation

- [Decision Records](docs/decisions/README.md) explain why Rig has its current boundaries.
- [Specifications](docs/specs/index.md) define accepted behaviour and current conformance.
- [Guides](docs/guides/README.md) explain how to use and develop Rig.
- [Roadmap](ROADMAP.md) points to canonical forward-work records.

## Contributing

Issues and pull requests are welcome. Follow the [developer guide](docs/guides/developer/README.md) and run its complete verification gate before submitting a change.

## License

[MIT](LICENSE) © 2026 Kris Brown.
