# Publish a public rig

Rig publishes data, not a website. You choose one profile intended for disclosure, inspect a deterministic offline export, and then explicitly hand that data to a trusted publisher. The receiving website owns presentation, navigation, credentials, deployment, and rollback.

## Declare the public boundary

Create a profile containing only tools you intend to disclose, then bind it to a publication and publisher:

```toml
[profile.public]
tools = ["mgit"]

[provider.site]
adapter = "custom"
executable = "~/.local/libexec/rig-site-publisher"
capabilities = ["publish"]

[publication.personal-site]
profile = "public"
title = "My Rig"
base-url = "https://rig.example.com/"
publisher = "site"
```

The `base-url` may be a domain root, subdomain, or subpath. Rig normalises it into public `publication.canonical_url` metadata; it does not generate presentation.

## Export before publishing

Generate a complete output tree locally:

```sh
rig export personal-site --output ./public-rig
cat ./public-rig/rig.json
```

The output contains exactly one regular file, `rig.json`. Consumers must check `format` is `rig-publication` and integer `version` is `1` before reading the remaining document.

Export invokes no provider and performs no network operation. It includes only the selected profile's public catalogue fields and relationships whose endpoints are also public. It excludes provider configuration, other profiles, executable paths, credentials, and observed machine state.

Re-export replaces the complete output directory so stale files cannot survive. Rig rejects unsafe output targets including `/`, `.`, `..`, symlinks, and non-directory targets.

## Publish explicitly

After reviewing the profile and offline JSON, run:

```sh
rig publish personal-site
```

Rig validates the publication, profile, publisher, exact `publish` capability, executable, and generated one-file tree before invoking the publisher once. The publisher receives an isolated absolute export directory through the versioned custom-provider protocol.

On success, Rig removes the isolated cache export. If the publisher fails after a complete export exists, Rig reports and retains that path for diagnosis. Remove a retained tree only after inspection; Rig never treats it as deployed.

## Verify the receiving site

The receiving site should validate the format and version, render only fields it understands, and use the canonical URL supplied by the publication. A site such as `rig.midnight.ninja` remains a consumer of the exported data rather than an authority for private configuration or machine state.
