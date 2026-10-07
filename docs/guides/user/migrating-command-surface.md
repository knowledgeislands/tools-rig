# Review configuration and automation

Use this guide to review an existing Rig setup before changing configuration or scheduled operations. The [command guide](commands.md) describes the current CLI; unknown command names print a syntax error and current usage.

## Make Rig the package authority

Remove `[rig].bootstrap-profile` and Homebrew `manifest`, `autoupdate-interval` and `autoupdate-options` fields. Rig rejects them rather than silently ignoring their effect.

Before removing a Brewfile declaration, compare its direct package choices with your Rig catalogue. Add desired missing entries to Rig, using capture where supported. Do not delete the Brewfile until you have checked whether another workflow still uses it. Rig neither reads, writes nor cleans up from it.

Homebrew remains responsible for installation and native dependency resolution. Rig does not uninstall undeclared packages. Homebrew itself must be available for apply; selected declared mise and node/npm prerequisites can be staged, but an unrelated declaration does not expand a targeted apply.

Rig no longer manages Homebrew's autoupdate agent. Removing the configuration does not remove an existing agent. Inspect and deliberately retain or retire it through Homebrew's native command. Doctor can still identify the competing timer.

## Review adoption

`rig init --dry-run` previews new configuration; init refuses existing configuration. It is not a migration command and should not be used to overwrite a working setup.

Bare `rig capture` discovers Homebrew formulae installed on request and installed casks. Complete selective proposals require an existing category and your own purpose and rationale. The output is a new review file outside active configuration, or TOML on stdout. Review before copying declarations into `conf.d`. Capture does not import arbitrary applications, settings or other providers.

Configurations using central profile membership arrays can still discover inventory, but cannot emit capture proposals until migrated to item-owned membership. Capture rejects the mixed model rather than producing a fragment that would make configuration invalid; manual adoption is also available.

## Check unattended consumers

Unattended upgrades write `last-upgrade` below Rig's state home with action `upgrade`. Keep scheduled invocations aligned with the current command guide and review their recorded outcomes.

Preview configuration with `rig show`, diagnose with `rig doctor --verbose`, and inspect `rig apply --dry-run` and `rig upgrade --dry-run` before any live operation.

## Keep chezmoi separate

This Rig change does not edit or apply your chezmoi source. Review host configuration, launchd declarations and wrapper scripts in their owning repository next. ChezMoi still owns its source files, templates and native behaviour; removing Brewfile orchestration does not move that authority into Rig.
