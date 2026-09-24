---
id: RIG-CLI-013
area: CLI
title: Export from parameters
theme: cli
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-24T08:01:10Z
updated_at: 2026-09-24T08:01:10Z
---

## Goal

Someone who wants public catalogue data out of Rig asks for it with the arguments that describe what they want, rather than by first declaring a publication in configuration and a provider that does not exist. The unused `rig publish` path retires in the same change, because it is what the declaration exists to serve.

## Context

`rig export PUBLICATION --output DIRECTORY` takes the name of a `[publication.*]` section and reads four values out of it: the profile to project, a title, a base URL, and a publisher. Only the first is about what Rig knows. The title and the canonical URL are presentation metadata owned by whatever renders the result, and the publisher exists solely to feed `rig publish`.

That last one is not free. `rig_validate_config` at `src/rig/10-configuration.bash:1984` requires `publisher` on every publication, requires it to name an existing provider, requires that provider's adapter to be `custom`, and requires it to carry the `publish` capability — all at config-load time, for a publication that will only ever be exported. A consumer that never publishes must therefore declare a provider it will never invoke, or Rig refuses to load the file at all.

The only consumer in practice has done exactly that. `kit-midnight.ninja` builds `rig.midnight.ninja` from `rig export midnight-ninja` in `apps/site-rig/pipeline/pull.ts`, and its `~/.config/rig/conf.d/90-profiles.toml` carries a `[provider.midnight-ninja]` stanza with `capabilities = ["publish"]`, `adapter = "custom"`, and no executable behind it. Its own comment records why: the site is built from the export and deployed by Workers Builds on push, so `rig publish midnight-ninja` is deliberately not a working path. A required field is being satisfied with a fiction to get past validation.

The metadata is dead on arrival too. The export writes `publication.title` and `publication.canonical_url` into `rig.json`; the consuming site surfaces both in `_data/rig.ts` and no template reads either, because the site renders its own `site.title` and owns its own canonical URL. Rig is being asked to hold a domain name it has no way to verify and no reason to know.

`rig publish` itself has no user. It is implemented at `src/rig/40-publication-lifecycle.bash:528`, reachable from `90-main.bash`, and documented in `docs/specs/publishing.md`, `docs/guides/user/publishing.md`, `docs/guides/user/commands.md`, and [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md). Retiring it is what makes the rest collapse: no publish means no publisher, which means no phantom provider, which leaves a publication section holding nothing but two strings that belong to the consumer.

## Boundary

This concerns how an export is requested and what configuration it demands. It does not change what a projection contains, which is [RIG-PUB](../specs/publishing.md)'s allow-list and stays exactly as it is.

In particular it does not touch the opt-in boundary. A profile with `kind = "view"` is where a tool's membership of the public catalogue is declared, and the rule that an export may only ever project a view — never a complete profile — is the safety property this record is built to preserve. `rig_render_public_tool`, `rig_render_public_skill`, `rig_validate_view_closure`, and the exclusion of versions, locators, services, ports, and machine identity all stay untouched.

It does not change `rig export`'s output format or its version, so a consumer reading `rig.json` sees the same document.

## Shaping

Open questions to settle before this is ready.

- What replaces the positional argument? `rig export --profile PROFILE --output DIRECTORY` states what is actually being selected. The view rule then moves from publication validation onto the flag: a `--profile` naming a complete profile is rejected, which is the same refusal in a more direct place.
- Do `title` and `base-url` survive as optional flags, or leave the payload entirely? The one consumer ignores both. Optional flags keep the export self-describing for a consumer that wants that, at the cost of keeping `publication` in the format; dropping them is a format change and needs a version bump, which is a much larger promise to break for two fields nobody reads.
- Does `[publication.*]` disappear, or become a named preset that supplies flag defaults? Removing it is the simpler model and matches the argument that a person exporting should not have to declare anything first. Keeping it as an optional convenience preserves a stable name for a recurring export, but it is the thing this record judges to be over the top, so it should not survive by default.
- How does an existing configuration migrate? A publication section that no longer validates is a hard failure on load, which is a harsh way to learn about a release. Either the section is accepted and ignored for a transitional period with a deprecation notice, or the change is called out as breaking in the changelog and the manual. This is the question most likely to want a `MIG` record of its own.
- Does the export still need an identity at all? `publication.id` is currently the section name. If publications go, either the id goes with them or `--profile` supplies it.
- Is the staging and retention machinery still justified? `publish/staging` and `publish/retained` in [RIG-CACHE](../specs/cache.md) exist for the interrupted-publisher handoff described at `40-publication-lifecycle.bash:438`. With no publisher, an export that writes straight to `--output` may not need either, which would simplify the cache contract as well.

## Discussion

The shape being removed is not accidental — [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) chose a static publication projection deliberately, and a publication that named its own publisher made sense while Rig expected to hand the artefact onward. What has changed is that the only real consumer does not want the handoff. It wants the data, and it deploys the data itself. The declaration is therefore paying for a capability nobody uses, and charging a fabricated provider stanza for the privilege.

There is a boundary argument underneath the convenience one, and it is the more durable of the two. Rig describes what a machine should contain. It does not describe how a website presents that, what it is called, or where it lives. The consuming repository already made this split for itself once: homepage links for each tool are curated in its own `data/tool-links.json` rather than in Rig, on the grounds that Rig has no business knowing where a vendor's marketing page is. A title and a canonical URL sit on precisely the same side of that line, and they are currently on the wrong one.

Worth flagging for whoever picks this up: the easy version of this change is to make the four publication fields optional and leave everything standing. That would remove the immediate friction and keep the dead concept, which is how the phantom provider came to exist in the first place.
