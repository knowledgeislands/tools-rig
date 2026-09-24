# Get started with Rig

This guide takes you from no Rig installation to a readable catalogue, a machine assessment, and a safe preview. It deliberately stops before applying changes.

## Install the public preview

Install the latest immutable release, currently `v0.3.0`:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.3.0/install.sh | bash
```

To make the selected release explicit:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.3.0/install.sh | bash -s -- v0.3.0
```

The executable defaults to `~/.local/bin/rig`. The manual defaults beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1`. Set `RIG_INSTALL_DIR` or `RIG_MAN_INSTALL_DIR` before running the installer when you need different destinations.

Confirm both interfaces:

```sh
rig --version
man rig
```

The released command reports `rig 0.3.0`.

For a local checkout, use `./install.sh --link`. It links the executable and manual so subsequent repository changes are visible without reinstalling. This selected release checkout reports `rig 0.3.0`.

## Create a small catalogue

Create `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.toml` with one category, one tool, and one complete profile:

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

This is intentionally ordinary TOML. Use whitespace, comments, and multiline arrays to make personal configuration comfortable to review. A declaration without `profiles` belongs to the configured default profile, so the first tool needs no repeated membership field.

The Homebrew installation metadata identifies the native owner. Homebrew remains responsible for its own package resolution and state; Rig does not need a `[provider.homebrew]` adapter declaration for this built-in provider.

## Confirm Rig can read it

Start with Rig's local diagnostics:

```sh
rig diag
```

Diagnostics show the running version, executable, platform, XDG paths, configuration sources, selected profile mode, and model counts. They do not invoke providers.

If Rig cannot find your file, compare the reported configuration home with the path you created. If parsing fails, Rig reports the source and problem without evaluating the file as shell code.

## Understand the resolved setup

Use the declaration queries:

```sh
rig show
rig list --category navigation
rig explain mgit
```

`show` is the best overview: it resolves the selected profile and groups its contents into readable tables. `list` browses tool identities. `explain` answers why one declaration belongs and how it is materialised. These commands parse configuration but do not observe or change the machine.

## Check the machine

Next, ask whether Rig and the selected setup can operate:

```sh
rig doctor
rig status
```

`doctor` gives a compact health assessment with actionable findings. `status` gives the detailed expected-versus-observed comparison. A missing tool is a state finding, not a reason for Rig to change the machine automatically.

Observations come from built-in providers or explicitly trusted extension observations. `unknown` and `unavailable` are deliberate results when Rig cannot establish state safely; they are not guessed into `present` or `missing`.

## Preview the first application

Review the complete materialisation plan without changing provider state:

```sh
rig apply --dry-run
```

Dry run resolves the complete profile, validates trust and platform boundaries, preflights the plan, and reports mutation scope. It invokes no provider mutation and writes no reconciliation receipt.

When the plan matches your intent, `rig apply` is the corresponding mutating command. Before taking that step, read [Choose a Rig command](commands.md) so the distinction between reconciliation, bootstrap, update, maintenance, and capture is clear.

## Enable shell completion

Print completion source for the shell you use:

```sh
rig completion bash
rig completion zsh
```

Persist the generated source through the shell configuration manager that already owns your startup files. Rig does not edit personal shell configuration.

## Grow the rig deliberately

Add concepts only when they represent real intent:

- Use [complete profiles and safe views](profiles.md) when another machine, role, or public view needs a materially different selection.
- Use [operational resources and private ports](operational-resources.md) when services, schedules, settings, layouts, or listener allocations belong in desired machine state.
- Use [user-level skills](skills.md) when agent capabilities should be declared alongside tools without copying their instructions into Rig.
- Use [public export](exporting.md) when you are ready to construct and inspect a deliberately public data view.

Keep `man rig` nearby for exhaustive field definitions. The guides show a safe path through the model; the manual is the reference.
