# Install signed releases and share role policies

Use this guide to declare a signed archive, inspect its installed version and share one role between hosts that need an exact Linux pin or a macOS Homebrew minimum. All examples use a synthetic tool and an intentionally invalid release address; substitute a real producer's documented release base, name and trusted public key before using them.

## Prepare the trust and destination

Obtain the producer's Ed25519 public key through a trusted channel and keep its PEM file locally. Rig never downloads a trust key or falls back to an unsigned checksum. Prepare an existing writable command directory inside your home, such as `~/bin`, and place the example key at `~/keys/public.pem`. These are illustrative paths, not paths created automatically by Rig. Do not declare a private signing key.

An installed OpenSSL capable of Ed25519 raw signature verification, curl, tar and SHA-256 tooling must be available. Set `RIG_OPENSSL` to an installed compatible OpenSSL executable if the system default cannot verify these signatures. Rig does not acquire a verifier. A missing or unsupported verifier leaves installation incomplete.

The producer must publish `<name>-checksums.txt`, its detached `.sig` and `<name>-<version>-<target>.tar.gz` under `/releases/download/<version>/`. Supported targets are `darwin-arm64`, `darwin-x64`, `linux-arm64` and `linux-x64`; support does not mean every producer publishes every target. Native architecture is used unless `RIG_ARCH` explicitly selects `arm64`/`aarch64` or `x64`/`x86_64`/`amd64`.

The signed manifest starts with `format=<name>-release-checksums-v1` and `version=<version>`. Each subsequent row contains a lowercase SHA-256 digest, two spaces and an exact archive filename. All lines end in LF. One to four unique supported targets are accepted, including the selected one. The archive contains exactly two regular files in order: `<name>` and `man/<name>.1`. Only the command is installed; this kind does not install the manual.

## Declare the shared role once

Put the host's root selection in `rig.toml`:

```toml
[rig]
default-profile = "host"
```

Place the common catalogue and role in `conf.d/10-agentic-role.toml`. Both machines can consume the same fragment:

```toml
[category.core]
name = "Core"
purpose = "Shared role"

[tool.sample]
name = "Sample"
category = "core"
purpose = "One shared tool declaration"
rationale = "Platform policies without host copies"
platforms = ["macos", "linux"]
variant.linux.platforms = ["linux"]
variant.linux.install.provider = "direct-download"
variant.linux.install.kind = "signed-release"
variant.linux.install.locator = "https://releases.invalid/sample"
variant.linux.install.release-name = "sample"
variant.linux.install.public-key = "~/keys/public.pem"
variant.linux.install.destination = "~/bin/sample"
variant.linux.install.version = "v1.2.3"
variant.linux.install.minimum-version = "v1.0.0"
variant.macos.platforms = ["macos"]
variant.macos.install.provider = "homebrew"
variant.macos.install.kind = "formula"
variant.macos.install.locator = "sample"
variant.macos.install.minimum-version = "v1.0.0"

[profile.agentic-rig]
name = "Shared agentic rig"
tools = ["sample"]
```

Place the local host profile in the distinct `conf.d/90-host.toml` fragment:

```toml
[profile.host]
name = "Local host"
inherits = ["agentic-rig"]
```

Inheritance selects the common tool once. Linux selects the signed exact pin, which also satisfies the role's minimum. macOS selects a native Homebrew formula with the same floor. Homebrew continues to resolve its own available version. This uses existing platform variants, profile inheritance and additive fragments; it needs no second host-specific copy of the tool. Fragments cannot override or reopen the same table, so keep each declaration in one fragment.

For a signed-release installation on either platform, use the same installation fields directly on a tool or on that platform's variant. Remove `install.version` to select minimum-only behaviour. Versions must be stable canonical `vMAJOR.MINOR.PATCH`, with no leading zeros except zero and at most nine digits in each component. Prerelease and build suffixes are unsupported. An exact pin below the minimum is an error.

## Inspect and reconcile

Run `rig show sample` to inspect the resolved declaration, `rig status` to observe its installed version and `rig apply --dry-run` to inspect the plan. Dry-run invokes no download or installer. After substituting valid producer details and reviewing the plan, `rig apply` reconciles the selection; `rig status` then reports the actual version alongside `exact:v1.2.3` or `minimum:v1.0.0` in its detail.

Status reads the local command's own `--version`; signature verification authenticates a release when Rig fetches it for installation. An exact pin replaces a different installed version, including a newer one. A minimum-only signed release installs that immutable floor when missing or too old and keeps any compatible newer installed version. It never looks up a latest release. On Homebrew formulae, missing means native install, below-floor means native upgrade and a satisfying version needs no mutation. Formula revisions such as `_2` do not change the upstream numeric version. Unparseable versions remain unknown, and cask update policies do not accept this formula-floor field.

The fixture suite exercises this exact composition with disposable keys, local archives and native-command stubs. It does not converge a real host, edit a consumer's role files or release a consumer's deployment hold.

## Recover from a failed install

Check the reported cause before retrying. Confirm the public key belongs to the intended producer, the version and target exist, the local verifier supports Ed25519 and the command directory is a real writable directory inside HOME. Key files, destinations and destination ancestry must not be symbolic links. Do not remove signature requirements to work around a failure.

Rig authenticates the manifest before parsing it or requesting an archive, verifies the archive digest and rejects unsafe paths or non-regular members. It streams the command into sibling staging, checks its reported version and replaces the destination with one final rename. Verification or replacement failure keeps any previous command and removes staging, so correcting the declaration or producer assets and retrying does not require cleaning up a partial installation.

For broader selection choices, [compose complete profiles and views](profiles.md). [Inspect provider ownership](provider-actions.md) when a producer does not fit this fixed signed-release contract.
