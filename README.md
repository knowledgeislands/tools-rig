# Rig

Rig configures and orchestrates package and configuration systems for bootstrapping machines. It manages targets such as Homebrew, uv, and chezmoi without replacing their native package resolution, manifests, or state.

## Principles

- **Manager of managers** — Rig selects targets, orders actions, and reports outcomes; each target remains authoritative for its own work.
- **Configurable profiles** — users choose their default programs, target implementations, and machine profiles.
- **Shell-only core** — the installed `rig` executable requires Bash and no language runtime or package-manager dependency.
- **XDG-aligned state** — configuration, data, state, and cache use the XDG Base Directory locations and explicit Rig overrides.
- **Incremental adoption** — a profile may use one target or many, and custom targets remain first-class.

## Status

Rig is at its repository-foundation stage. The executable currently exposes version, help, completion, and XDG-path discovery while the configuration and orchestration contracts are shaped through the [roadmap](ROADMAP.md).

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
- [Roadmap](ROADMAP.md) points to the canonical forward-work records.

## Contributing

Issues and pull requests are welcome. Follow the [developer guide](docs/guides/developer/README.md) and run its complete verification gate before submitting a change.

## License

[MIT](LICENSE) © 2026 Kris Brown.
