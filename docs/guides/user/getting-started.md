# Get started with Rig

This guide takes you from no Rig installation to a readable catalogue, a machine assessment, and a safe preview. It deliberately stops before applying changes.

The commands below describe Rig's current command surface. For an existing setup, [review configuration and automation](migrating-command-surface.md) before applying changes.

## What Rig can manage

Rig describes your working setup and compares it with the machine. Its supported item types are:

- **Tools and apps:** install and observe command-line tools, development runtimes and desktop applications, or keep catalogue-only entries for things you want to document without managing their installation. ChezMoi-managed configuration targets use this same tool model.
- **Agent skills:** install remote user-level skills, project reviewed local skills into agent runtimes, or observe skills owned by a runtime or plugin. See [Manage user-level skills](skills.md).
- **Services:** declare and reconcile background services through macOS launchd.
- **Scheduled jobs:** declare and reconcile jobs with calendar or interval schedules through macOS launchd.
- **Settings:** compare and apply typed macOS preferences, such as Finder options or a screenshot location.
- **Default applications:** declare which installed application opens a content type, extension or URL scheme on macOS. See [Declare default applications](default-applications.md).
- **Firewall restrictions:** keep chosen macOS listener ports reachable only from loopback and your tailnet. See [Restrict a listener to the tailnet](operational-resources.md#restrict-a-listener-to-the-tailnet).
- **Dock layouts:** compare and apply an ordered macOS Dock containing applications and folders.
- **Private ports:** record TCP allocations and check listener ownership and scope. Rig does not open, reserve or close ports.
- **Retired applications:** observe explicitly declared macOS application traces after retirement. These records are observation-only and do not remove retained files. See [Review retired applications](retired-applications.md).

The [operational resources and private ports guide](operational-resources.md) covers services, scheduled jobs, settings, Dock layouts and ports.

Supported installation methods for tools and apps are:

- **Homebrew formulae:** command-line tools and packages through `brew`.
- **Homebrew casks:** macOS desktop applications through `brew`.
- **Mac App Store:** macOS applications through `mas`, declared with the `mas` provider. See [Declare a Mac App Store application](#declare-a-mac-app-store-application).
- **uv:** Python command-line tools through `uv tool`.
- **mise:** development tools and runtimes through `mise`.
- **npm:** global Node.js packages through `npm`.
- **chezmoi:** configuration targets applied through `chezmoi`.
- **Direct download:** standalone executables downloaded over HTTPS with a required SHA-256 checksum.
- **External providers:** explicitly trusted custom executables when a built-in provider cannot express the required observation or application. See [Use external providers safely](provider-actions.md).

Profiles select the active items that belong on a machine or in a role. The catalogue records tool purpose and your rationale; native providers retain their own execution semantics, credentials and installation state. Tool declarations can select different installation methods on macOS and Linux, while the built-in service, scheduled-job, settings and Dock providers are macOS-specific.

## Install the public preview

Install the latest immutable release, currently `v0.7.0`:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.7.0/install.sh | bash
```

To make the selected release explicit:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.7.0/install.sh | bash -s -- v0.7.0
```

The executable defaults to `~/.local/bin/rig`. The manual defaults beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1`. Set `RIG_INSTALL_DIR` or `RIG_MAN_INSTALL_DIR` before running the installer when you need different destinations.

Confirm both interfaces:

```sh
rig --version
man rig
```

The released command reports `rig 0.7.0`.

For a local checkout now, use `./install.sh --link`. It links the executable and manual so subsequent repository changes are visible without reinstalling. The current checkout reports `rig 0.7.0+dev`; the marker means development after the latest immutable release and does not choose the next preview number.

## Create a small catalogue

Run `rig init --dry-run`, then `rig init` to create a minimal `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.toml`. Init refuses existing configuration and does not install software. Extend the file with a category and tool so the complete configuration resembles this:

```toml
[rig]
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

### Declare a Mac App Store application

Mac App Store applications use the built-in `mas` provider, kind `app`, and the numeric App Store identity that `mas list` prints as the locator:

```toml
[tool.telegram]
name = "Telegram"
category = "communication"
purpose = "Message people and groups"
rationale = "The App Store build updates through the App Store"
platforms = ["macos"]
install.provider = "mas"
install.kind = "app"
install.locator = "747648890"
```

Rig runs `mas list`, `mas install ID` and `mas upgrade ID`, never `brew`, and names `mas` in status, plan, apply and upgrade output. An unattended upgrade reports these applications `interactive-required`, because the App Store needs a person signed in. If `mas` itself comes from Homebrew, declare it as a Homebrew formula and add `requires = ["mas"]` to each App Store tool, so one apply can install `mas` before the applications.

Earlier configurations declared these applications as `install.provider = "homebrew"` with `install.kind = "mas"`. That form still works as a deprecated alias: Rig runs the same `mas` commands and names `mas` in its output, and `rig doctor` lists each such declaration under `Warnings` with action `declare-provider-mas-kind-app`. To migrate, change those two lines to `install.provider = "mas"` and `install.kind = "app"`, or the `variant.ID.install.*` and `[remove.ID]` equivalents, and keep the locator.

## Confirm Rig can read it

Start with Rig's local diagnostics:

```sh
rig doctor --verbose
```

Verbose doctor shows the running version, executable, platform, XDG paths, configuration sources, selection mode and model counts, alongside read-only health observations. Findings may return status 1; no machine changes are made.

If Rig cannot find your file, compare the reported configuration home with the path you created. If parsing fails, Rig reports the source and problem without evaluating the file as shell code.

## Understand the resolved setup

Use the declaration queries:

```sh
rig show
rig show --all --category navigation
rig show mgit
```

Bare `show` gives the selected setup. `show --all` browses catalogue tools; `show mgit` explains one declaration. These forms parse configuration but do not observe or change the machine.

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

When the plan matches your intent, `rig apply` makes the machine follow it, including supported declared prerequisites. Read [Choose a Rig command](commands.md) for the distinction between apply, upgrade and reviewed capture.

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
