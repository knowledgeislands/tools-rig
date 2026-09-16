# Rig

Rig is the declarative description and manager of a person's working setup. Its catalogue records preferred tools, what they are for, why they belong, how they relate, where they are supported, and how providers materialise them.

Profiles select catalogue subsets for machines, roles, or contexts. Rig can compare a selected profile with provider observations and derive an explicitly public profile into a personal site such as `rig.midnight.ninja`.

## Principles

- **Catalogue first** — stable categories and tool identities make the setup understandable before installation or mutation.
- **Purpose and rationale** — the catalogue records both what a tool does and why it belongs.
- **Composable profiles** — named subsets describe machines, roles, contexts, and a deliberately public view.
- **Provider authority** — Homebrew, uv, chezmoi, downloads, custom executables, and publishers retain their native manifests, resolution, execution, deployment, and state.
- **Expected versus observed** — Rig reports whether selected declarations are present, missing, drifted, unavailable, or unknown.
- **Safe publication** — a static public projection excludes provider configuration, private profiles, and observed machine state.
- **Shell-only core** — the installed executable requires Bash and no language runtime or package-manager dependency.
- **XDG-aligned state** — configuration, data, state, and cache use XDG Base Directory locations and explicit Rig overrides.

## Product model

The catalogue is Rig's source of meaning. Profiles resolve the catalogue for a context. Providers are the manager-of-managers mechanism that observes or materialises selected tools. State compares resolved intent with provider evidence. Declared operations attach host-specific actions to tools without turning them into permanent command families. Publication projects only an explicitly selected public profile into a reviewable static artifact before a trusted publisher deploys it.

Personal catalogue contents, operations, and machine-specific paths belong in private Rig configuration, not in this executable. Provider-native manifests such as a Brewfile remain authoritative for their own systems.

## Install a local checkout

Link the executable and manual from this checkout into their conventional user locations:

```sh
./install.sh --link
rig --version
rig --help
```

The executable defaults to `~/.local/bin/rig`; set `RIG_INSTALL_DIR` to choose another location. The manual defaults beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1`; set `RIG_MAN_INSTALL_DIR` to override it. Re-run `./install.sh --link` after moving the checkout.

## Configure a catalogue

Rig reads `${RIG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/rig}/rig.conf` followed by optional `conf.d/*.conf` fragments. The grammar is inert data: Rig does not source it as shell code.

Queries derive the active platform from Bash's `OSTYPE`. Set `RIG_PLATFORM` to an explicit catalogue platform identifier when testing a different target or when the host value is not recognised.

```ini
[rig]
schema = 1
default-profile = default

[category.navigation]
name = Navigation
purpose = Move through Knowledge Islands

[tool.mgit]
name = MGit
category = navigation
purpose = Navigate related repositories
rationale = Keeps repository context visible
platform = macos

[profile.default]
tool = mgit
```

## Commands

- `rig show [--profile NAME]` summarises the default or named resolved profile.
- `rig list [--category ID] [--profile NAME]` lists catalogue tools, optionally narrowed by category and profile.
- `rig explain TOOL` explains a tool's declared meaning, relationships, profile membership, and compatible provider binding.
- `rig diag` reports the effective Rig runtime, active platform, XDG paths, and configuration discovery and validity.
- `rig completion bash|zsh` prints shell completion source.
- `rig help`, `rig --help`, and `rig --version` provide command and version information.

Catalogue queries resolve declarations only and never invoke provider code. See `man rig` for the complete command contract.

Diagnostics are also non-mutating and never invoke providers. A valid configuration returns status 0; missing or invalid configuration returns status 1 while still printing the available diagnostic snapshot. The planned `doctor` command is the separate, deeper check of selected tools and providers.

## Status

Rig is a pre-v1 tool under active development. Catalogue parsing, validation, profile resolution, provider-binding resolution, and read-only catalogue queries are implemented. Provider observation, apply, doctor, bootstrap migration, declared operations, publication, and the Homebrew formula remain tracked work in the [roadmap](ROADMAP.md).

## Documentation

- [Decision Records](docs/decisions/README.md) explain why Rig has its current boundaries.
- [Specifications](docs/specs/index.md) define accepted behaviour and current conformance.
- [Guides](docs/guides/README.md) explain how to use and develop Rig.
- [Roadmap](ROADMAP.md) points to canonical forward-work records.

## Contributing

Issues and pull requests are welcome. Follow the [developer guide](docs/guides/developer/README.md) and run its complete verification gate before submitting a change.

## License

[MIT](LICENSE) © 2026 Kris Brown.
