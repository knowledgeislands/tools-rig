# Rig

Rig helps you describe the tools and operational resources that make up your working setup, explain why each one belongs, and see whether the setup you expect is present on a machine.

Instead of treating a Brewfile, dotfiles repository, language tool manager, and download scripts as separate answers to “what is my setup?”, Rig gives them one catalogue and one set of profiles. Those native systems still install and configure their own tools; Rig describes the whole and coordinates them.

## What Rig helps you answer

- What tools are part of my setup?
- What is each tool for, and why did I choose it?
- Which subset belongs on this machine or in this role?
- Which system installs or observes each tool?
- What is present, missing, drifted, unavailable, or unknown?
- Which part of my rig can I publish without exposing private machine state?

## The model in plain language

- A **catalogue** describes your tools: their category, purpose, rationale, relationships, platforms, and optional installation.
- An **operational resource** declares a service or scheduled job, including what it runs and its intended provider-managed state.
- A **profile** selects catalogue tools and operational resources for a machine, role, or context such as `default`, `minimal`, or `developer`.
- A **provider** connects a selected tool to the system that already manages it, such as Homebrew, uv, chezmoi, a verified download, or your own executable.
- **State** compares the selected profile with what providers observe on the current machine.
- A **publication** exports one deliberately public profile as data that a website such as `rig.midnight.ninja` can render.

Rig is therefore a manager of managers. It does not replace package-manager manifests, chezmoi source state, provider credentials, or native configuration.

## A typical Rig lifecycle

1. Declare the tools and operational resources you care about and why they belong.
2. Group them into profiles for different machines or contexts.
3. Use `rig show`, `rig list`, and `rig explain` to understand the declaration.
4. Use `rig diag`, `rig doctor`, and `rig status` to inspect Rig and compare intent with the machine.
5. Use `rig apply --dry-run` to review the complete plan before allowing provider changes.
6. Use `rig apply` or `rig bootstrap` when you are ready to materialise a profile.
7. Optionally use `rig export` and `rig publish` to share a deliberately public view.

## Install

Install the `v0.2.0` public preview:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.0/install.sh | bash
```

Pin that exact release explicitly:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.0/install.sh | bash -s -- v0.2.0
```

The executable defaults to `~/.local/bin/rig` and the manual defaults beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1`. The [getting-started guide](docs/guides/user/getting-started.md) covers alternate locations, first configuration, shell completion, and troubleshooting.

## Create a first rig

Rig reads `${RIG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/rig}/rig.toml` followed by regular `conf.d/*.toml` fragments in bytewise filename order. A minimal provider-backed rig looks like this:

```toml
[rig]
schema = 1
default-profile = "default"

[category.navigation]
name = "Navigation"
purpose = "Move between related work"

[tool.mgit]
name = "MGit"
category = "navigation"
purpose = "Navigate related repositories"
rationale = "Keeps repository context visible"
platforms = ["macos"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "mgit"
install.platforms = ["macos"]

[provider.homebrew]
adapter = "homebrew"
capabilities = ["observe", "apply"]

[profile.default]
tools = ["mgit"]
```

Then inspect before changing anything:

```sh
rig diag
rig show
rig explain mgit
rig doctor
rig status
rig apply --dry-run
```

Catalogue queries and diagnostics do not invoke providers. Doctor and status use only declared observation capabilities. A dry run preflights the complete tool and resource plan, including stale-resource retirement, without invoking provider changes or writing the resource receipt.

## Commands

- `rig` shows top-level help.
- `rig show [--profile NAME]` describes the default or named resolved profile.
- `rig list [--category ID] [--profile NAME]` lists catalogue tools, optionally filtered by category and profile.
- `rig explain TOOL|service:ID|scheduled-job:ID` explains one tool or qualified operational resource.
- `rig status [--profile NAME] [--unmanaged]` compares selected tools and resources with provider observations and can report undeclared tool identities.
- `rig doctor [--profile NAME]` gives a compact health assessment for configuration, paths, providers, selected tools, and selected resources.
- `rig apply [--profile NAME] [--dry-run]` previews or materialises the resolved tool and resource plan.
- `rig bootstrap [--profile NAME] [--dry-run]` previews or materialises the configured bootstrap profile.
- `rig run PROVIDER ACTION [-- ARGUMENT...]` invokes one explicitly declared custom-provider action.
- `rig export PUBLICATION --output DIRECTORY` writes deterministic public Rig data without deploying it.
- `rig publish PUBLICATION` exports and hands public Rig data to one trusted publisher.
- `rig clean [--dry-run]` removes only safely classified Rig-owned cache artifacts; preview it first.
- `rig diag` reports runtime, platform, XDG paths, and configuration discovery.
- `rig completion bash|zsh` prints shell completion source.
- `rig help [-h|--help]`, `rig --help`, and `rig --version` provide command and version information.

The [command guide](docs/guides/user/commands.md) groups these commands by user lifecycle and explains their trust boundaries. `man rig` is the complete command and configuration reference.

Cache maintenance is deliberately outside the normal lifecycle. Retained publication diagnostics remain available until you explicitly inspect them with `rig clean --dry-run` and remove eligible artifacts with `rig clean`; provider-native caches remain provider-owned.

## Safety and ownership

Rig configuration is inert TOML; Rig never sources it as shell code. It invokes only explicitly selected provider capabilities, preserves literal argument boundaries, and separates read-only inspection, provider mutation, and publication.

Personal catalogue data, host-specific paths, credentials, provider-native state, and observed machine state belong in private configuration or their native systems. A public export contains only the selected public profile's allow-listed catalogue data.

## Documentation

- [Use Rig](docs/guides/user/README.md) explains the user journey and routes to focused guides.
- [Getting started](docs/guides/user/getting-started.md) walks from installation to a safe dry run.
- [Command guide](docs/guides/user/commands.md) explains every command by lifecycle and trust boundary.
- [Publish a rig](docs/guides/user/publishing.md) covers offline export and trusted publisher handoff.
- [Custom provider actions](docs/guides/user/provider-actions.md) covers advanced host-specific operations.
- [Operational resources](docs/guides/user/operational-resources.md) covers services, scheduled jobs, deferred execution, and reconciliation receipts.
- [Decision Records](docs/decisions/README.md) explain durable product and architecture rationale.
- [Specifications](docs/specs/index.md) define accepted, testable behaviour.
- [Roadmap](ROADMAP.md) points to canonical forward work.

## Status

Rig is a pre-v1 public preview. Its catalogue, operational resources, profile resolution, queries, diagnostics, health checks, provider observation and application, bootstrap flow, declared actions, public-data export, and trusted publication dispatch are implemented.

## Contributing

Issues and pull requests are welcome. Follow the [developer guide](docs/guides/developer/README.md) and its definition of done before submitting a change.

## License

[MIT](LICENSE) © 2026 Kris Brown.
