# Manage application CLIs

Declare an application's bundled command alongside the application so Rig can check that it is executable, restore a missing command and explain a conflicting path before changing your machine. Keep the companion in the application's existing catalogue entry and choose the installer that owns its link.

## Declare a companion

Add one named group to the owning tool. The application keeps its normal installation declaration, purpose, rationale and profile membership:

```toml
[tool.example]
name = "Example"
category = "apps"
purpose = "An application with a terminal companion."
rationale = "The same capability is needed from the desktop and terminal."
platforms = ["macos"]
install.provider = "homebrew"
install.kind = "cask"
install.locator = "vendor/tap/example"
cli.example.source = "/Applications/Example.app/Contents/Helpers/ExampleCLI"
cli.example.destination = "/opt/homebrew/bin/example"
cli.example.owner = "provider"
```

The source names the executable inside the app. The destination names the expected command link. Both paths must be absolute, or start with `~/` or `$HOME/`; other shell expressions remain literal. Declare the actual executable directory used by your installer, which may differ between machines.

Use `owner = "provider"` when the selected Homebrew cask installs that binary link. Rig lets Homebrew own it: after installing or upgrading the app, a missing companion triggers a cask reinstall, followed by a fresh health check. This can replace the application bundle and retains Homebrew's prompts, permissions and failure behaviour. Rig never adds a force flag or independently replaces the provider's link.

Use `owner = "link"` when the app's installer does not create its companion command. After the application installer succeeds, Rig creates a missing leaf symlink to the declared executable. The destination directory must already exist, be writable and have no symlinked ancestors. Rig does not create directories, change executable permissions or overwrite occupied destinations.

Several commands use several names, for example `cli.example.*` and `cli.example-admin.*`. A platform-specific command can use `variant.macos.cli.example.*` within an existing variant. A variant containing only companions still needs its `platforms` array; each tool must retain exactly one matching variant per platform.

## Inspect and apply

Run `rig show example` to see the private source, destination and owner. `rig status` and `rig doctor` include companion health even when the application package is already installed. The check covers the declared executable and link; your shell's PATH remains a separate configuration choice.

Preview the selected work with `rig apply --target example --scope tools --dry-run`. Its companion detail names the owner and conditional repair. The preview does not invoke the installer or create links. Then run the same command without `--dry-run` to apply the reviewed work.

A healthy companion needs no additional repair. `rig upgrade` checks and restores companions after the native upgrade succeeds. Deselecting an application does not remove its command links. Companion paths are private configuration and do not enter `rig export`.

## Resolve conflicts

A command pointing to another target, an occupied regular file or directory, and an unsafe destination parent are reported before the application's installer runs. Rig preserves those paths. Inspect which application or installer owns the command and deliberately resolve that conflict before applying again.

A dangling link to the expected helper can recover when the installer restores its source. If the helper is still missing or not executable after installation, the tool fails with a companion finding. A successful native command alone is insufficient: Rig verifies the resulting link and executable before reporting success.
