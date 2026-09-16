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

## Install

Install the latest available release, falling back to the current `main` build while Rig is pre-release:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/main/install.sh | bash
```

The executable defaults to `~/.local/bin/rig`, and the manual defaults beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1`. Set `RIG_INSTALL_DIR` or `RIG_MAN_INSTALL_DIR` to choose other locations. Set `RIG_VERSION` to install a specific tag or branch.

### Local checkout

Link the executable and manual from this checkout into their conventional user locations:

```sh
./install.sh --link
rig --version
rig --help
```

Re-run `./install.sh --link` after moving the checkout.

## Configure a catalogue

Rig reads `${RIG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/rig}/rig.conf` followed by optional `conf.d/*.conf` fragments. The grammar is inert data: Rig does not source it as shell code.

Queries derive the active platform from Bash's `OSTYPE`. Set `RIG_PLATFORM` to an explicit catalogue platform identifier when testing a different target or when the host value is not recognised.

```ini
[rig]
schema = 1
default-profile = default
bootstrap-profile = bootstrap

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

[profile.bootstrap]
tool = mgit
```

Providers declare exact `observe` and `apply` capabilities. Built-in adapters map selected bindings to native tools:

| Adapter | Binding kinds | Default executable | Native authority |
| --- | --- | --- | --- |
| `homebrew` | `formula`, `cask`, `mas` | `brew`; `mas` for `mas` | Homebrew and Mac App Store state |
| `uv` | `tool` | `uv` | uv-managed tools |
| `chezmoi` | `target` | `chezmoi` | chezmoi target state |
| `direct-download` | `executable` | `curl` | HTTPS artifact selected by its declared SHA-256 |
| `custom` | Configured by its executable | Required `executable` | Versioned `rig-provider-v1` protocol |

Set a provider `executable` to use a non-default installation or an isolated test fake. Provider and binding `argument` fields remain literal argument boundaries. A direct-download binding additionally requires an HTTPS `locator`, absolute `destination`, and lowercase `checksum = sha256:...`; Rig verifies a sibling temporary file before replacing a regular destination.

`[operation.TOOL.NAME]` declarations bind one tool to a custom provider's exact capability. Their mode is `observe` or `mutate`; repeated `argument` values are fixed configuration, while repeated `allow-argument` values are the only caller arguments accepted after `--`.

`[publication.ID]` names one public profile and one publisher. Offline `export` never invokes that provider. Explicit `publish` requires its `custom` adapter to declare the exact `publish` capability and passes one isolated static tree through the versioned provider protocol.

See `man rig` for the exact native command matrix and custom-provider protocol.

## Commands

- `rig` shows top-level help.
- `rig show [--profile NAME]` summarises the default or named resolved profile in a bounded-width, aligned tool table; `rig explain TOOL` provides complete metadata.
- `rig list [--category ID] [--profile NAME]` lists catalogue tools, optionally narrowed by category and profile.
- `rig explain TOOL` explains a tool's declared meaning, relationships, profile membership, and compatible provider binding.
- `rig status [--profile NAME]` compares expected tools with selected built-in or custom-provider observations.
- `rig doctor [--profile NAME]` gives a compact health answer for configuration, XDG paths, providers, and selected tools.
- `rig apply [--profile NAME] [--dry-run]` materialises a resolved profile; dry-run preflights and prints planned work without invoking providers.
- `rig bootstrap [--profile NAME] [--dry-run]` materialises the configured bootstrap profile through the same apply plan; an explicit profile wins, and older configurations fall back to `default-profile`.
- `rig run TOOL OPERATION [-- ARGUMENT...]` invokes one declared custom-provider operation with bounded literal arguments.
- `rig export PUBLICATION --output DIRECTORY` generates a deterministic static site from the publication's explicitly selected public profile.
- `rig publish PUBLICATION` renders an isolated static export and hands it to the publication's one trusted custom publisher.
- `rig diag` reports the effective Rig runtime, active platform, XDG paths, and configuration discovery and validity.
- `rig completion bash|zsh` prints shell completion source; `-h` or `--help` prints command usage.
- `rig help [-h|--help]`, `rig --help`, and `rig --version` provide command and version information.

Catalogue queries, `diag`, and `export` never invoke providers. `status` and `doctor` invoke only declared `observe` capabilities. `apply` and `bootstrap` invoke exact `apply` capabilities only after complete plan preflight. `run` is an explicit trust transition to one configured operation. `publish` is the separate network-capable transition to one selected publisher after export validation. See `man rig` for the complete command contract.

Use `diag` to inspect Rig's runtime, paths, and configuration discovery without provider execution. Use `doctor` for a concise operational health answer and `status` for the complete expected-versus-observed table. Doctor returns 0 when healthy, 1 when completed checks find issues, and 2 when syntax, configuration, or profile resolution is invalid.

## Status

Rig is a pre-v1 tool under active development. Catalogue parsing, validation, profile resolution, provider-binding resolution, read-only queries, operational health checks, built-in and custom-provider observation, dependency-ordered application and bootstrap, declared operations, integrity-checked direct downloads, deterministic static public export, and trusted publication dispatch are implemented. Private cutover and the Homebrew formula remain tracked work in the [roadmap](ROADMAP.md).

## Documentation

- [Decision Records](docs/decisions/README.md) explain why Rig has its current boundaries.
- [Specifications](docs/specs/index.md) define accepted behaviour and current conformance.
- [Guides](docs/guides/README.md) explain how to use and develop Rig.
- [Roadmap](ROADMAP.md) points to canonical forward-work records.

## Contributing

Issues and pull requests are welcome. Follow the [developer guide](docs/guides/developer/README.md) and run its complete verification gate before submitting a change.

## License

[MIT](LICENSE) © 2026 Kris Brown.
