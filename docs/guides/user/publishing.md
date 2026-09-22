# Publish a public rig

Rig publishes data, not a website. You choose one profile intended for disclosure, inspect a deterministic offline export, and then explicitly hand that data to a trusted publisher. The receiving site owns presentation, navigation, credentials, deployment, and rollback.

## Declare the public boundary

Add `public` membership only to declarations you intend to disclose, create a non-appliable view, and bind it to a publication and publisher:

```toml
[tool.mgit]
profiles = ["default", "public"]

[profile.public]
name = "Public rig"
purpose = "Catalogue choices safe to publish"
kind = "view"

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

Every required tool must opt into the view as well. `base-url` may be a domain root, subdomain, or subpath. Rig normalises it into canonical URL metadata but does not generate presentation.

## Export before publishing

Generate and inspect the complete output locally:

```sh
rig export personal-site --output ./public-rig
cat ./public-rig/rig.json
```

Export performs no network operation and invokes no publisher. The output contains one regular file, `rig.json`. A consumer first checks the `rig-publication` format and version, then renders only fields it understands.

The export includes only the selected view's allow-listed catalogue and skill metadata. It excludes provider configuration, other profiles, private ports, executable paths, native authorities, install sources, runtime projections, local paths, arguments, credentials, observed state, and unmanaged inventory.

Re-export replaces the complete output directory so stale files cannot survive. Rig rejects unsafe targets such as `/`, `.`, `..`, symlinks, and non-directory targets.

## Publish explicitly

After reviewing the offline JSON, run:

```sh
rig publish personal-site
```

Rig validates the publication, view, trusted custom publisher, allowed operation, executable, and generated one-file tree before invoking the publisher once. The publisher receives an isolated absolute export directory through Rig's versioned extension protocol.

On success, Rig removes the isolated cache export. If the publisher fails after export completes, Rig retains the path for diagnosis. Inspect it before using `rig clean --dry-run` and `rig clean`; retention does not mean data was deployed.

## Verify the receiving site

The receiving site should validate the format version, render only understood fields, and use the supplied canonical URL. A site such as `rig.midnight.ninja` remains a consumer of exported data, never the authority for private Rig configuration or machine state.
