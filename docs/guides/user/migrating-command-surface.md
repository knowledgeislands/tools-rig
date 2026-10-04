# Migrate the command surface

This guide is for an existing Rig configuration or script moving to the current command surface. Earlier cutovers were breaking: retired commands are rejected with migration advice, not accepted as aliases. The [release history](https://github.com/knowledgeislands/tools-rig/releases) records immutable preview snapshots.

## Change invocations

- Replace `rig list` with `rig show --all`; use `rig show --category ID` for selected tools or add `--all` for the whole tool catalogue.
- Replace `rig explain ITEM` with `rig show ITEM`.
- Use `rig diag` for share-safe offline facts, `rig diag --full` for local configuration-path detail, and `rig doctor` for read-only health evaluation that may return 1 for findings.
- Replace `rig init --repair-schema --dry-run` with `rig repair` and `rig init --repair-schema --output PATH` with `rig repair --output PATH`.
- Replace `rig bootstrap` with `rig apply`. Use an explicit `--profile` when the former bootstrap selection differed from the default.
- Replace `rig update` with `rig upgrade`, including scheduled jobs and shell wrappers.
- Remove `rig maintain` invocations. Run deliberate native housekeeping separately; do not add package removal to an upgrade wrapper.
- Replace `rig run PROVIDER ACTION` with the component's documented native operation. Provider ABI arguments are not a user command template.
- Replace Brewfile snapshot capture with `rig capture` discovery and selective reviewed proposals.

Scripts consuming JSON must recognise `show` and `upgrade` command identifiers. Selected, catalogue and individual show views keep distinct payload shapes. Capture emits discovery text or TOML, not the old mutation-report JSON. Verbose doctor adds path-bearing diagnostics; review that field before sharing.

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

New unattended upgrades write `last-upgrade` below Rig's state home with action `upgrade`. Update wrapper paths and scheduled command arguments together. Old `last-update` files are left untouched and are not evidence of a new run.

Preview configuration with `rig show`, diagnose with `rig doctor --verbose`, and inspect `rig apply --dry-run` and `rig upgrade --dry-run` before any live operation.

## Keep chezmoi separate

This Rig change does not edit or apply your chezmoi source. Review host configuration, launchd declarations and wrapper scripts in their owning repository next. ChezMoi still owns its source files, templates and native behaviour; removing Brewfile orchestration does not move that authority into Rig.
