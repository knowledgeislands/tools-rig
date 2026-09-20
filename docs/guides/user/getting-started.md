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

[provider.homebrew]
adapter = "homebrew"
capabilities = ["observe", "apply"]

[profile.default]
tools = ["mgit"]
```

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

Doctor and status invoke only providers whose selected work declares the exact `observe` capability. Status 0 means the completed checks are healthy, status 1 means checks completed with findings, and status 2 means command syntax, configuration, or profile resolution is invalid.

## Preview before applying

Review the complete application plan without invoking providers:

```sh
rig apply --dry-run
```

Only after the plan is expected should you allow provider changes:

```sh
rig apply
```

Rig preflights the complete selected plan before mutation, orders required tools before dependants, and invokes only providers with the exact `apply` capability. Homebrew remains responsible for Homebrew resolution and state; Rig coordinates the declared intent.

## Add another profile

Profiles let the same catalogue answer different contexts. Append a second catalogue tool and two profiles:

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

For a new-machine path, declare `bootstrap-profile` under `[rig]` and use `rig bootstrap --dry-run` before `rig bootstrap`. Bootstrap uses the same preflighted application plan as apply.

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
- Use the [custom action guide](provider-actions.md) only when a host-specific operation does not fit a portable built-in adapter.
- Use `man rig` for the exhaustive schema, native adapter matrix, environment, exit status, and custom-provider protocol.
