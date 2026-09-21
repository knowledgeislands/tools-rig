# Get started with Rig

Use this guide to install Rig, describe one tool, understand the resulting profile, check the current machine, and preview the first provider change.

## Install the public preview

Install the executable and manual together:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.0/install.sh | bash -s -- v0.2.0
```

The default executable location is `~/.local/bin/rig`. The manual is installed beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1`. Set `RIG_INSTALL_DIR` or `RIG_MAN_INSTALL_DIR` before running the installer to choose another destination.

Verify the installation:

```sh
rig --version
rig --help
man rig
```

If `rig` is not found, add its executable directory to `PATH` through the shell or configuration manager that owns your startup configuration. Rig does not edit shell startup files.

## Create a small catalogue

Create `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.toml`. This example describes one navigation tool, delegates its installation to Homebrew, and selects it in the default profile:

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
tools = ["mgit"]
```

Rig recognises `homebrew` as a built-in provider, including its supported formula operations. You declare the native owner with `install.provider`; you do not register its adapter or capabilities.

Rig reads this optional root file first and then regular `conf.d/*.toml` fragments in bytewise filename order. The merged configuration must contain exactly one `[rig]` table. Rig accepts a deliberately small TOML subset and never evaluates the values as shell code.

Use `RIG_CONFIG_HOME` when you want the complete Rig configuration directory somewhere else.

## Confirm Rig can read it

Run the local diagnostic:

```sh
rig diag
```

`diag` reports the executable, Bash version, active platform, XDG paths, discovered configuration sources, and configuration validity. It does not invoke Homebrew or any other provider.

If the configuration is invalid, Rig reports the source and reason. Correct that before moving to machine checks; every model-dependent command fails closed on invalid configuration.

## Understand the declaration

Start with the profile summary:

```sh
rig show
```

Then explore the catalogue:

```sh
rig list
rig list --category navigation
rig explain mgit
```

- `show` answers “what does this profile contain?”
- `list` answers “what tools have I declared?”
- `explain` answers “what is this tool for, why is it here, and how can it be materialised?”

These commands only read inert configuration. They do not inspect or change the machine.

## Check the machine

Use the concise health view first:

```sh
rig doctor
```

Use the detailed comparison when you need every selected tool and provider observation:

```sh
rig status
```

Doctor and status use built-in observations or observations explicitly allowed for a selected external provider. Status 0 means the completed checks are healthy, status 1 means checks completed with findings, and status 2 means command syntax, configuration, or profile resolution is invalid.

## Preview before applying

Review the complete application plan without invoking providers:

```sh
rig apply --dry-run
```

Only after the plan is expected should you allow provider changes:

```sh
rig apply
```

Rig preflights the complete selected plan before mutation, orders required tools before dependants, and invokes only built-in or explicitly trusted external operations. Homebrew remains responsible for Homebrew resolution and state; Rig coordinates the declared intent.

## Update and maintain selected tools

Reconciliation makes declared tools present; it does not silently advance every installed version or perform package-manager maintenance. Preview those explicit lifecycle operations separately:

```sh
rig update --dry-run
rig maintain --dry-run
```

`rig update` advances selected Homebrew, uv, mise, and npm tools through fixed native commands. `rig maintain` runs one bounded provider-native maintenance work item per supported selected provider. Both report unsupported selected providers without dispatching them, and both preflight all supported work before the first mutation.

Homebrew's own background update job is optional provider policy applied by `rig bootstrap`, not an operation script. Declare only the interval and bounded native options you want:

```toml
[provider.homebrew]
manifest = "~/.config/homebrew/Brewfile"
autoupdate-interval = 43200
autoupdate-options = ["upgrade", "cleanup", "immediate", "sudo"]
```

Bootstrap reports this policy in dry-run output and re-arms Homebrew's native job only when the selected profile uses Homebrew. The configuration cannot contain a shell command or an arbitrary flag.

When a Homebrew provider declares a native manifest, refresh it only through an explicit capture:

```sh
rig capture homebrew --dry-run
rig capture homebrew
```

Capture writes the configured provider-native manifest; it does not turn that file into Rig configuration. Rig configuration cannot supply arbitrary lifecycle commands or grant built-in capabilities.

## Add another profile

Most people can start and remain with one `default` profile. A profile is not a stage in Rig's lifecycle: `show`, `doctor`, `apply`, and `bootstrap` can all operate on the same profile, and `bootstrap-profile` may name `default`.

Add another profile only when a machine, role, context, or public projection selects materially different intent. Profiles let the same catalogue describe those differences without duplicating tool records. For example, append a second catalogue tool and two profiles:

```toml
[category.quality]
name = "Quality"
purpose = "Check work before it is shared"

[tool.shellcheck]
name = "ShellCheck"
category = "quality"
purpose = "Check shell scripts"
rationale = "Finds portability and correctness defects before changes are committed"
platforms = ["macos"]
install.provider = "homebrew"
install.kind = "formula"
install.locator = "shellcheck"
install.platforms = ["macos"]

[profile.minimal]
tools = ["mgit"]

[profile.developer]
profiles = ["minimal"]
tools = ["shellcheck"]
```

Inspect a named profile without changing the default:

```sh
rig show --profile developer
rig doctor --profile developer
rig apply --profile developer --dry-run
```

For the bootstrap path, declare `bootstrap-profile` under `[rig]` and use `rig bootstrap --dry-run` before `rig bootstrap`. Bootstrap is a native Rig lifecycle: it identifies and verifies required managers, then preflights and reconciles the profile. It does not install missing manager systems, and you do not declare setup tools or a bootstrap provider.

## Describe a workstation declaratively

A workstation is a profile rather than a provider. Add the settings and resources the machine should have, then select them alongside its tools:

```toml
[setting.show-file-extensions]
name = "Show file extensions"
purpose = "Keep file identities visible in Finder"
rationale = "Visible extensions make source files easier to distinguish"
provider = "macos-defaults"
platforms = ["macos"]
domain = "NSGlobalDomain"
key = "AppleShowAllExtensions"
value-type = "bool"
value = "true"

[profile.workstation]
profiles = ["developer"]
settings = ["show-file-extensions"]
```

The `macos-defaults` provider is built in. The same rule applies to launchd services and scheduled jobs: declare the desired resource and select it from a profile, without a `[provider.launchd]` table.

## Enable completion

Print completion source for your shell:

```sh
rig completion bash
rig completion zsh
```

Persist the generated source through the shell or configuration manager that already owns completion startup. Rig does not install personal completion files or edit startup configuration.

## Next steps

- Use the [command guide](commands.md) to choose between queries, health checks, mutation, and publication.
- Use the [publication guide](publishing.md) to share a deliberately public profile.
- Use the [external action guide](provider-actions.md) only when a host-specific operation does not fit a portable built-in adapter.
- Use the [managed-resource guide](operational-resources.md) when a profile should own services, scheduled jobs, settings, or a semantic Dock layout as desired state.
- Use `man rig` for the exhaustive schema, native adapter matrix, environment, exit status, and extension-provider protocol.
