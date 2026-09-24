# Export a public rig

Rig produces data, not a website. You choose one profile intended for disclosure, generate a deterministic offline export, and inspect it before anything leaves the machine. The receiving site owns presentation, navigation, credentials, deployment, and rollback — and it also owns the export's parameters, because it is the party that changes them.

## Declare the public boundary

Add `public` membership only to declarations you intend to disclose, and create a non-appliable view:

```toml
[tool.mgit]
profiles = ["default", "public"]

[profile.public]
name = "My Rig"
purpose = "Catalogue choices safe to publish"
kind = "view"
```

Every required tool must opt into the view as well. Nothing else in the configuration concerns the export: there is no publication table, no publisher, and no stored URL.

## Export the view

Generate and inspect the complete output:

```sh
rig export --profile public --output ./public-rig
cat ./public-rig/rig.json
```

`--profile` must name a view; an appliable profile is rejected before anything is written. `--output` is the directory the tree replaces.

Two optional arguments describe the document the data becomes:

```sh
rig export --profile public --output ./public-rig \
  --title 'Kris — working setup' --base-url https://rig.example.com/
```

`--title` defaults to the view's declared `name`, and to the profile identifier when the view declares none. `--base-url` may be a domain root, subdomain, or subpath; Rig normalises it into canonical URL metadata but does not generate presentation. Omit it and `canonical_url` is `null`.

Export performs no network operation and invokes no provider. The output contains one regular file, `rig.json`. A consumer first checks the `rig-publication` format and version, then renders only fields it understands.

The export includes only the selected view's allow-listed catalogue and skill metadata. It excludes provider configuration, other profiles, private ports, executable paths, native authorities, install sources, runtime projections, local paths, arguments, credentials, observed state, and unmanaged inventory.

Re-export replaces the complete output directory so stale files cannot survive. Rig rejects unsafe targets such as `/`, `.`, `..`, symlinks, and non-directory targets.

## Deploy from the consuming side

Rig does not deploy. Put the export where the site expects it, using whatever that system already uses — a build step, a commit, a copy over SSH. A site pipeline that calls Rig directly owns the whole instruction:

```sh
rig export --profile public --output "$SITE/src/data/rig" \
  --title 'Kris — working setup' --base-url https://rig.midnight.ninja/
```

Because the parameters travel with the command, the same catalogue can be projected more than once — a subdomain and a sub-page, with different titles — without changing anything on the workstation.

## Verify the receiving site

The receiving site should validate the format version, render only understood fields, and use the supplied canonical URL. A site such as `rig.midnight.ninja` remains a consumer of exported data, never the authority for private Rig configuration or machine state.
