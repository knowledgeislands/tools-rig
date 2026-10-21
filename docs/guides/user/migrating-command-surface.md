# Review configuration and automation

Use this guide to review an existing Rig setup before changing configuration or scheduled operations. The [command guide](commands.md) describes the current CLI; unknown command names print a syntax error and current usage.

## Move from v0.7.0 to v0.8.0

The v0.8.0 candidate is unpublished. These notes describe its changes since v0.7.0; the sections below also cover older transitions. No command is removed, and this range introduces no mandatory configuration or persisted-state migration.

### Review scripts and query consumers

Long options now accept `--name=value`, supported commands accept `--json` as `--format json`, dry runs accept `-n`, and `--` ends options. A word following a value option is taken verbatim even when it resembles another option. Supply each intended value explicitly. `status` now rejects repeated `--profile`, `--format`, `--problems`, `--unmanaged` and `--retired` with exit 2; remove duplicates, including combinations of `--json` and `--format`.

Profile `show` JSON tool entries include an additive `configured_by` array, and doctor JSON includes `managers`. Doctor can report manager and deprecation warnings without changing its health verdict. Keep consumers keyed to the documented verdict and counts rather than assuming every diagnostic line is a failure.

### Adopt new declarations deliberately

Manager declarations are optional. A tool's scalar `provides` names its built-in manager; selected consumer bindings gain platform-resolved prerequisite edges. Keep one providing tool per manager, review the union with declared `requires` for cycles, and preview targeted applies. Homebrew remains an observed prerequisite. Once any tool declares `provides`, doctor warns about used built-in managers without a selected providing tool. Existing configurations without `provides` retain their previous fallback. [Getting Started](getting-started.md#declare-the-package-managers) describes adoption. A declared mise-installed uv prerequisite can now be staged before its uv consumers.

Resource `tool` links are optional and also create a prerequisite on the named tool. [Operational resources](operational-resources.md) explains those relationships and the new observe-only menu-bar declarations. Menu-bar layouts report differences for manual correction; apply skips them and never writes icon positions or visibility. Protected or sandboxed preferences can remain unreadable, and persistence across applications or displays is not guaranteed.

The [signed-release guide](signed-releases.md) describes the optional authenticated direct-download kind and version floors. Existing executable downloads need no conversion. Prepare a local trusted public key and an existing writable destination inside HOME before opting in; Rig never acquires the verifier or trust key. An exact pin can replace a newer installed command; a minimum-only policy preserves a compatible newer version. Homebrew formula floors retain native version resolution.

### Review macOS firewall drift before an attended rollout

The `macos-pf` adapter now discovers the Mac's own paired tailnet IPv4 and IPv6 addresses through `ifconfig` and restricts pass-rule destinations to those addresses. Existing range-based anchors report `drifted (anchor-changed)` because the generated header also changed. Later destination-only changes report `tailnet-address-stale`. Missing or ambiguous addresses report `unknown (tailnet-address-undiscoverable)` and leave the firewall unchanged even with an administrator grant.

Installing this executable does not rewrite an anchor. Rewriting one requires a separately approved, attended `rig apply --sudo` with a tested restore path that reconnects first; review [operational resources](operational-resources.md) before planning it. The read-only discovery check on the second Mac and independent firewall acceptance remain outstanding in the work records. Linux nftables behaviour is unchanged. A targeted on-link sender can still address the Mac's tailnet address directly: these rules do not promise authenticated Tailscale ingress or resolve the outstanding NordVPN root-ruleset bypass investigation.

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
