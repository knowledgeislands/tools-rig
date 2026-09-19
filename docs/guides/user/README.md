# Install and inspect Rig

Rig `v0.2.0` is a public preview. Install the released executable and manual together:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.0/install.sh | bash
```

To request that exact release explicitly, pass it to the installer:

```sh
curl -fsSL https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.2.0/install.sh | bash -s -- v0.2.0
```

Use a local development link when working from a checkout.

## Link a checkout

From the repository root, run:

```sh
./install.sh --link
```

This links `bin/rig` into `${RIG_INSTALL_DIR:-$HOME/.local/bin}` and the manual into `${RIG_MAN_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/man/man1}`. Add the executable directory to `PATH` through your own shell or configuration manager; the installer does not edit startup files.

## Inspect Rig diagnostics

Run:

```sh
rig diag
```

Rig prints its version, invoked executable, Bash version, active platform, effective configuration, data, state, and cache directories, and a summary of configuration discovery and validity. It does not invoke providers or inspect installed tools.

Status 0 means the configuration is valid. Status 1 means no configuration source exists or the merged configuration is invalid; the available runtime and path diagnostics are still printed. `rig.toml` is optional when at least one regular `conf.d/*.toml` fragment supplies the complete model, including exactly one `[rig]` table. Status 2 is reserved for invalid command syntax. Set an XDG base variable to relocate its whole category, or set the corresponding `RIG_*_HOME` value to replace Rig's complete application directory.

Schema 1 uses a strict, dependency-free TOML subset: named tables, `schema = 1`, double-quoted basic strings, single-line string arrays, and `#` comments. Standard TOML tooling can read accepted Rig files, but Rig rejects unused TOML features such as literal strings, multiline values, floats, booleans, dates, and inline tables.

Use `rig doctor` for selected-profile and provider health rather than treating diagnostics as a machine audit:

```sh
rig doctor
rig doctor --profile developer
```

Doctor prints one healthy summary or grouped configuration and tool findings. A missing or drifted tool points to `rig apply`; provider availability and observation failures name the provider that owns the next action. Catalogue-only and incompatible-platform declarations are informational. Status 0 means the selected rig is healthy, status 1 means completed checks found issues, and status 2 means syntax, configuration, or profile resolution failed. Doctor invokes only selected providers' declared `observe` capability and does not repair or apply anything.

## Check and apply a profile

Declare an exact `observe` or `apply` capability on each provider, then inspect the selected profile before mutation:

```sh
rig status
rig doctor
rig apply --dry-run
rig apply
```

Built-in adapters use `brew` or `mas` for Homebrew installations, `uv` for uv tools, `chezmoi` for managed targets, and `curl` plus an available SHA-256 utility for direct downloads. A custom provider without `executable` resolves exactly `${RIG_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/rig}/providers/PROVIDER`; Rig does not search the directory or execute adjacent files. Declare `executable` when an external command, non-default path, or test fake is required. Rig checks executables only for selected tool installations.

Configuration loading and provider-backed checks and changes show progress on stderr in an interactive terminal while preserving report stdout. Use `RIG_PROGRESS=always` for redirected logs or `RIG_PROGRESS=never` to suppress progress.

Keep Homebrew manifests, uv state, and chezmoi source state in their native systems. Rig selects and orders catalogue work; it does not replace those authorities. In particular, `rig status` never runs `chezmoi apply`, and `rig apply --dry-run` invokes no provider.

For direct downloads, declare an HTTPS locator, absolute destination, and lowercase `sha256:` checksum. Rig refuses symlink and non-regular destinations and verifies a sibling temporary file before replacement. Review `rig apply --dry-run` before the first installation.

## Bootstrap a new machine

Declare an optional profile dedicated to first materialisation:

```toml
[rig]
schema = 1
default-profile = "default"
bootstrap-profile = "bootstrap"

[profile.bootstrap]
tools = ["homebrew", "dotfiles"]
```

Then inspect and execute the same dependency-ordered, fully preflighted plan used by `apply`:

```sh
rig bootstrap --dry-run
rig bootstrap
```

An explicit `--profile NAME` takes precedence over `bootstrap-profile`. If the field is absent, bootstrap falls back to `default-profile`, so existing configurations remain valid. Dry-run invokes no provider. Missing capabilities or executables fail before mutation; provider failures suppress only dependent work and independent work continues. Provider-native manifests remain authoritative, including any stale-state guard implemented by the selected provider.

## Run a declared provider action

Actions keep host-specific audits and controls in private configuration while giving them one bounded command surface:

```toml
[provider.local]
adapter = "custom"
executable = "~/.local/libexec/rig-local-provider"

[action.local.service-status]
mode = "observe"
description = "Inspect configured launchd services"
platforms = ["macos"]
arguments = ["user"]
allowed-arguments = ["verbose"]
```

Invoke the declaration by provider and action identity:

```bash
rig run local service-status
rig run local service-status -- verbose
```

Rig invokes only the custom provider named by the action. `observe` maps to the provider's `observe` verb and `mutate` maps to `apply`. Configured arguments precede caller arguments, and every caller argument must exactly match one `allowed-arguments` array item unless `argument-policy = "provider"` explicitly delegates native-domain validation. Values remain literal; Rig does not evaluate shell text. The command passes provider output through and returns its native status.

## Export a public rig

Declare a publication that names the one profile intended for disclosure. The publisher remains a provider declaration for the separate deployment boundary; export does not invoke it.

```toml
[profile.public]
tools = ["mgit"]

[provider.site]
adapter = "custom"
executable = "~/.local/libexec/rig-site-publisher"
capabilities = ["publish"]

[publication.personal-site]
profile = "public"
title = "Kris's Rig"
base-url = "https://rig.midnight.ninja/"
publisher = "site"
```

Generate the complete public-data tree and inspect it before making it public:

```sh
rig export personal-site --output ./public-rig
cat ./public-rig/rig.json
```

The tree contains exactly one regular file, `rig.json`. It declares `format` as `rig-publication` and integer `version` as `1`; consumers should check both fields before reading the remaining document. Re-export replaces the complete directory so stale files cannot survive. Rig rejects `/`, `.`, `..`, symlinks, and non-directory output targets. The artifact contains only the selected profile's public catalogue fields and relationships whose endpoints are both public; it excludes provider configuration, other profiles, paths, credentials, and observed machine state.

Set `base-url` to the final domain root, subdomain, or subpath, including `https://rig.midnight.ninja/` or `https://midnight.ninja/rig/`. Rig normalizes it into `publication.canonical_url` metadata; it does not generate presentation or navigation. Export is offline and does not deploy the result.

## Publish a public rig

After reviewing the public profile and an offline export, dispatch the configured publisher explicitly:

```bash
rig publish personal-site
```

Rig validates the publication, publisher adapter, exact `publish` capability, executable, profile, and generated one-file data tree before invocation. It then calls the selected executable once with this fixed literal protocol:

```text
EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 publish PROVIDER PUBLICATION directory ABS_EXPORT_DIR
```

The publisher and receiving website own presentation, credentials, hosting destination, deployment, and rollback. Rig removes the isolated cache export after success. A staging or render failure invokes no publisher, and an interruption before the export is complete removes its incomplete `rig.json`. Once the export is complete, publisher failure or interruption returns the native or conventional signal status, reports the retained export path, and leaves that tree available for diagnosis. Cleanup revalidates and pins the cache parent before unlinking only `rig.json`; a path substitution or unexpected tree fails closed. Remove a retained tree after inspection; Rig never treats it as deployed.

## Generate completion

Print completion source with one stable command:

```sh
rig completion bash
rig completion zsh
```

Persist generated completion through the shell or configuration manager that owns startup configuration. Rig does not edit shell startup files.

## Verify the link

Run `rig --version`, `rig --help`, and `man rig`. If the executable is not found, confirm `${RIG_INSTALL_DIR:-$HOME/.local/bin}` is on `PATH`. If the manual is not found, confirm its parent `man` directory is on `MANPATH`.
