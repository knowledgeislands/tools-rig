# Rig

Rig helps you describe the tools, user-level agent skills, managed resources, and private port allocations that make up your working setup, explain why each one belongs, and see whether the setup you expect is present on a machine.

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
- A **skill** describes one user-level agent capability, its reviewed source, native authority, and intended runtime projections without copying its instruction content into Rig.
- A **managed resource** declares a service, scheduled job, typed machine setting, or semantic layout together with its desired state.
- A **profile** selects catalogue tools and managed resources for a machine, role, or context. One `default` profile is enough unless two contexts genuinely select different intent.
- A **provider** is the native system that owns a declaration, such as Homebrew, uv, mise, npm, chezmoi, launchd, or macOS defaults. Rig knows its built-in providers; ordinary configuration does not register their adapters or capabilities.
- **State** compares the selected profile with what providers observe on the current machine.
- A **private port allocation** records stable TCP intent, expected bind scope, lifecycle mode, and the tool or service that owns it. Rig observes listeners but never opens, reserves, closes, or kills sockets.
- A **publication** exports one deliberately public profile as data that a website such as `rig.midnight.ninja` can render.

Rig is therefore a manager of managers. It does not replace package-manager manifests, chezmoi source state, provider credentials, or native configuration.

## A typical Rig lifecycle

1. Declare the tools and operational resources you care about and why they belong.
2. Group them into profiles for different machines or contexts.
3. Use `rig show`, `rig list`, and `rig explain` to understand the declaration.
4. Use `rig diag`, `rig doctor`, and `rig status` to inspect Rig and compare intent with the machine.
5. Use `rig apply --dry-run` to review the complete plan before allowing provider changes.
6. Use `rig apply` to reconcile an operable machine in tools → skills → resources order, or `rig bootstrap` to stage required managers and then materialise the selected bootstrap profile.
7. Use explicit `rig update` and `rig maintain` runs when selected tools or provider state should advance; use `rig capture` only when deliberately refreshing a provider-native manifest.
8. Optionally use `rig export` and `rig publish` to share a deliberately public view.

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

[profile.default]
name = "Default rig"
purpose = "Complete everyday setup"
kind = "complete"
```

Long string arrays may span lines, retain comments, and use a trailing comma. Rig still accepts only basic strings inside arrays and never evaluates configuration.

Then inspect before changing anything:

```sh
rig diag
rig show
rig explain mgit
rig doctor
rig status
rig apply --dry-run
```

The `homebrew` provider is built into Rig, so the declaration says only what owns the installation. Catalogue queries and diagnostics do not invoke providers. Doctor and status use only built-in observations or explicitly trusted extension observations. A dry run preflights the complete tool and resource plan, including stale-resource retirement, without invoking provider changes or writing state.

User-level agent skills are separate catalogue capabilities. A skill declaration names a reviewed source and one native authority: the deliberately installed `skills` CLI, a KI projection, a bounded local-source projection, or observation-only runtime/plugin ownership. See [Manage user-level skills](docs/guides/user/skills.md) before adding one; Rig never evaluates or stores skill instructions.

## Workstations are profiles

Rig does not model a whole machine as a provider. A workstation profile composes the tools and resources that belong together:

```toml
[setting.show-file-extensions]
name = "Show file extensions"
purpose = "Keep file identities visible in Finder"
rationale = "Visible extensions reduce ambiguity when working with source files"
provider = "macos-defaults"
platforms = ["macos"]
domain = "NSGlobalDomain"
key = "AppleShowAllExtensions"
value-type = "bool"
value = "true"
profiles = ["workstation"]

[profile.workstation]
name = "Workstation"
purpose = "Default tools plus workstation settings"
kind = "complete"
inherits = ["default"]
```

The provider name identifies the native authority. Rig supplies the adapter, observation, validation, and application behaviour for built-in providers such as `macos-defaults` and `launchd`.

Do not create separate profiles merely to name lifecycle commands. `bootstrap-profile` must name a complete profile; add another complete profile only when it selects materially different machine intent. Declarations own direct membership: omission means the configured default profile and `profiles = []` means no profile. Complete profiles may inherit shared complete intent, while non-appliable views opt in explicitly for inspection or publication. See [Build complete profiles and safe views](docs/guides/user/profiles.md).

## Generated artifacts

Generated paths belong to the tool whose capability they expose rather than becoming separate catalogue tools. Declare a path in the tool's `artifacts` array only when it is a durable part of that capability which a user wants Rig to inspect. `explain`, `status`, and `doctor` then account for it, while the native tool remains responsible for creating, updating, and removing it. Rig configuration cannot turn an artifact into a lifecycle command or task hook.

## One tool on different platforms

Keep one catalogue identity when the same capability is installed differently on macOS and Linux. Bounded dotted variants live inside the tool declaration:

```toml
[tool.example]
name = "Example"
category = "development"
purpose = "Provide one cross-platform capability"
rationale = "One identity keeps its meaning and relationships together"
platforms = ["macos", "linux"]

variant.macos.platforms = ["macos"]
variant.macos.install.provider = "homebrew"
variant.macos.install.kind = "formula"
variant.macos.install.locator = "example"

variant.linux.platforms = ["linux"]
variant.linux.install.provider = "uv"
variant.linux.install.kind = "tool"
variant.linux.install.locator = "example"
```

Every declared tool platform must match exactly one variant. A variant may also declare `variant.ID.artifacts`; `status` and `explain` use only the active variant. Installations and artifacts are private materialisation details and are never published.

Managed resources can declare deterministic ordering with qualified dependencies such as `depends-on = ["setting:development-defaults"]`. Rig closes those dependencies transitively, rejects missing endpoints or cycles, and blocks only transitive dependants after a resource failure.

## Commands

- `rig` shows top-level help.
- `rig show [--profile NAME]` describes the default or named resolved profile.
- `rig list [--category ID] [--profile NAME]` lists catalogue tools, optionally filtered by category and profile.
- `rig explain TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID` explains one tool, user-level skill, qualified managed resource, or private port allocation.
- `rig status [--profile NAME] [--unmanaged]` compares selected tools, resources, and private ports with read-only observations and can report undeclared tool identities and TCP listeners.
- `rig doctor [--profile NAME]` gives a compact health assessment for configuration, paths, providers, selected tools, selected resources, and private ports.
- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` previews or materialises the resolved plan in tools → skills → resources order.
- `rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` previews or runs the native bootstrap lifecycle for the configured bootstrap profile.
- `rig update [--profile NAME] [--dry-run]` advances selected Homebrew, uv, mise, and npm tools through their native managers.
- `rig maintain [--profile NAME] [--dry-run]` runs one bounded native maintenance work item for each supported selected provider.
- `rig capture PROVIDER [--dry-run]` deliberately refreshes a supported provider-native manifest; Homebrew capture is the current built-in operation.
- `rig run PROVIDER ACTION [-- ARGUMENT...]` invokes a built-in provider operation or one explicitly trusted external-provider action.
- `rig export PUBLICATION --output DIRECTORY` writes deterministic public Rig data without deploying it.
- `rig publish PUBLICATION` exports and hands public Rig data to one trusted publisher.
- `rig clean [--dry-run]` removes only safely classified Rig-owned cache artifacts; preview it first.
- `rig diag` reports runtime, platform, XDG paths, configuration discovery, profile-selection mode, and model counts.
- `rig completion bash|zsh` prints shell completion source.
- `rig help [-h|--help]`, `rig --help`, and `rig --version` provide command and version information.

The [command guide](docs/guides/user/commands.md) groups these commands by user lifecycle and explains their trust boundaries. `man rig` is the complete command and configuration reference.

Rig-cache cleanup is deliberately separate from provider maintenance. Retained publication diagnostics remain available until you explicitly inspect them with `rig clean --dry-run` and remove eligible artifacts with `rig clean`; provider-native caches remain provider-owned and are touched only by an explicit supported `rig maintain` operation.

Operational commands show phase, completed denominator, current safe identity, terminal outcome, and mutation scope on interactive stderr without changing their stdout reports. `RIG_PROGRESS=always` retains the same line-oriented events when redirected, while `RIG_PROGRESS=never` suppresses them. Fast declaration queries remain quiet in the default automatic mode, and Rig-authored progress omits private configuration values and machine paths.

## Safety and ownership

Rig configuration is inert TOML; Rig never sources it as shell code. Built-in operations are fixed by Rig, while external operations require an explicit `adapter = "custom"` declaration and allow-list. A custom executable is either named directly or resolved at the exact `${RIG_DATA_HOME}/providers/ID` path. Literal argument boundaries are preserved, and read-only inspection remains separate from mutation and publication.

Personal catalogue data, host-specific paths, credentials, provider-native state, and observed machine state belong in private configuration or their native systems. A public export contains only the selected public profile's allow-listed catalogue data. Port declarations and listener observations are always private and never enter `rig.json`.

Rig resolves only documented whole-value home forms for typed string settings and Dock paths; configuration remains inert and queries retain authored values. Application completes preflight before mutation: shared safety failures reject the plan, while a resource-local environmental finding fails only that resource and leaves independent work available. Any selected resource failure blocks retirement and receipt replacement.

Skill publication is explicit and limited to `id`, `name`, `purpose`, `rationale`, and an optional reviewed public source. Authorities, runtime projections, local paths, locks, and observed state never enter `rig.json`.

## Documentation

- [Use Rig](docs/guides/user/README.md) explains the user journey and routes to focused guides.
- [Getting started](docs/guides/user/getting-started.md) walks from installation to a safe dry run.
- [Command guide](docs/guides/user/commands.md) explains every command by lifecycle and trust boundary.
- [Publish a rig](docs/guides/user/publishing.md) covers offline export and trusted publisher handoff.
- [External provider actions](docs/guides/user/provider-actions.md) covers advanced host-specific extensions.
- [Managed resources](docs/guides/user/operational-resources.md) covers services, scheduled jobs, typed machine settings, semantic Dock layouts, and reconciliation.
- [Decision Records](docs/decisions/README.md) explain durable product and architecture rationale.
- [Specifications](docs/specs/index.md) define accepted, testable behaviour.
- [Roadmap](ROADMAP.md) points to canonical forward work.

## Status

Rig is a pre-v1 public preview. Its catalogue-led model keeps provider mechanics beneath a declarative configuration in which profiles describe complete working contexts, including tools and managed machine resources.

## Contributing

Issues and pull requests are welcome. Follow the [developer guide](docs/guides/developer/README.md) and its definition of done before submitting a change.

## License

[MIT](LICENSE) © 2026 Kris Brown.
