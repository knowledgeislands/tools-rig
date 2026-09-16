# Install and inspect Rig

Rig is currently an early scaffold. Use a local development link until a tagged release is published.

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

Status 0 means the configuration is valid. Status 1 means the root configuration is missing or invalid; the available runtime and path diagnostics are still printed. Status 2 is reserved for invalid command syntax. Set an XDG base variable to relocate its whole category, or set the corresponding `RIG_*_HOME` value to replace Rig's complete application directory.

Use the planned `rig doctor` command for selected-profile and provider health rather than treating diagnostics as a machine audit.

## Check and apply a profile

Declare an exact `observe` or `apply` capability on each provider, then inspect the selected profile before mutation:

```sh
rig status
rig apply --dry-run
rig apply
```

Built-in adapters use `brew` or `mas` for Homebrew bindings, `uv` for uv tools, `chezmoi` for managed targets, and `curl` plus an available SHA-256 utility for direct downloads. Set provider `executable` only when the native command has a non-default path or a test fake is required. Rig checks executables only for selected bindings.

Keep Homebrew manifests, uv state, and chezmoi source state in their native systems. Rig selects and orders catalogue work; it does not replace those authorities. In particular, `rig status` never runs `chezmoi apply`, and `rig apply --dry-run` invokes no provider.

For direct downloads, declare an HTTPS locator, absolute destination, and lowercase `sha256:` checksum. Rig refuses symlink and non-regular destinations and verifies a sibling temporary file before replacement. Review `rig apply --dry-run` before the first installation.

## Export a public rig

Declare a publication that names the one profile intended for disclosure. The publisher remains a provider declaration for the separate deployment boundary; export does not invoke it.

```ini
[profile.public]
tool = mgit

[publication.personal-site]
profile = public
title = Kris's Rig
base-url = https://rig.midnight.ninja/
publisher = site
```

Generate a complete static tree and inspect it before making it public:

```sh
rig export personal-site --output ./public-rig
```

The tree contains `index.html` and `assets/rig.css`. Re-export replaces that complete directory so stale files cannot survive. Rig rejects `/`, `.`, `..`, symlinks, and non-directory output targets. The artifact contains only the selected profile's public catalogue fields and relationships whose endpoints are both public; it excludes provider configuration, other profiles, paths, credentials, and observed machine state.

Set `base-url` to the final domain root, subdomain, or subpath, including `https://rig.midnight.ninja/` or `https://midnight.ninja/rig/`. Export is offline and does not deploy the result.

## Generate completion

Print completion source with one stable command:

```sh
rig completion bash
rig completion zsh
```

Persist generated completion through the shell or configuration manager that owns startup configuration. Rig does not edit shell startup files.

## Verify the link

Run `rig --version`, `rig --help`, and `man rig`. If the executable is not found, confirm `${RIG_INSTALL_DIR:-$HOME/.local/bin}` is on `PATH`. If the manual is not found, confirm its parent `man` directory is on `MANPATH`.
