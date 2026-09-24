---
id: RIG-CLI-013
area: CLI
title: Export from parameters
theme: cli
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: 27fced00b00fa7ab5adff6e7d7a9cf9a0e5999ff
created_at: 2026-09-24T08:01:10Z
updated_at: 2026-09-24T14:00:00Z
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

## Current state

`rig export PUBLICATION --output DIRECTORY` resolves `[publication.<name>]` and reads `profile`, `title`, `base-url`, and `publisher` from it. `rig_validate_config` in `src/rig/10-configuration.bash` requires all four on every publication, requires `publisher` to name an existing `custom` provider carrying the `publish` capability, and requires the named profile to be a view. `rig publish` in `src/rig/40-publication-lifecycle.bash` stages the same projection beneath `${XDG_CACHE_HOME}/rig/publish/staging`, invokes the publisher, retains the stage on interruption beneath `publish/retained`, and `rig clean` exists to sweep `publish/retained` and `publish/cleanup` afterwards. Nothing else writes to that cache root: `rig export` stages beside its own `--output` target and never touches it.

## Decisions

- **`rig export --profile NAME --output DIRECTORY` replaces the positional publication.** The flag states what is being selected. `--profile` must name a `kind = "view"` profile; naming a complete profile is rejected with status 2. The view rule moves from publication validation onto the flag, which is the same refusal in a more direct place, and it is the safety property the whole record is built to preserve.
- **`[publication.*]` is removed outright, not deprecated.** Keeping it as an optional preset preserves the dead concept, which is how the phantom provider came to exist. A configuration carrying the section fails to load with a message naming the replacement flag, and the changelog and manual call the change breaking. Rig is a `0.x` preview with one known consumer; a transitional period costs more than it buys.
- **`--title` and `--base-url` survive as optional flags.** The payload keeps `format: rig-publication` and `version: 2` so no consumer has to change to read it. `title` defaults to the view profile's declared `name`. `canonical_url` is `null` when `--base-url` is not given, which is the honest projection of a fact Rig was never able to verify.
- **`publication.id` in the payload becomes the profile name.** With publications gone there is no other identity, and the profile is what the document actually projects.
- **`rig publish` retires, and `rig clean` retires with it.** `rig clean` sweeps only the staging tree `rig publish` created; with no publisher there is nothing in that tree and nothing to sweep. Retiring the command rather than leaving it to report `eligible=0` forever removes `${XDG_CACHE_HOME}/rig/publish`, the staging and retention machinery, the interrupted-publisher handoff, the `publish` provider capability, `RIG-CACHE` in its entirety, and the signal statuses that only publication used.
- **The consuming repository migrates itself.** `kit-midnight.ninja` invokes `rig export midnight-ninja`; the new form is `rig export --profile <view> --output <directory>`. That repository owns its own pipeline, so this record does not edit it and does not stay open waiting for it.

## Steps

- [ ] Replace `rig export`'s positional publication with `--profile`, `--output`, and the optional `--title` and `--base-url`, rejecting a non-view profile with status 2.
- [ ] Render `publication.id` from the profile, `title` from `--title` or the profile's name, and `canonical_url` as `null` when no `--base-url` is given, leaving the format at version 2.
- [ ] Remove `[publication.*]` from the configuration grammar and validation, and reject a configuration that still declares one with a message naming `rig export --profile`.
- [ ] Remove `rig publish`, its staging, retention, interrupted-publisher handoff, and the `publish` provider capability.
- [ ] Remove `rig clean` and the `${XDG_CACHE_HOME}/rig/publish` cache root it swept.
- [ ] Retire `docs/specs/cache.md` and its `RIG-CACHE` clauses, and update `docs/specs/publishing.md` so the projection contract stands on `rig export` alone.
- [ ] Supersede [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) with a decision record stating why the projection stays static while the handoff goes.
- [ ] Reproject `man/rig.1`, `rig --help`, shell completion, `README.md`, the user guides, and `CHANGELOG.md` as a breaking change.
- [ ] Update every test that declares a publication, publisher, or publish capability, and cover the new flags, the view refusal, and the rejection of a stale `[publication.*]`.

## Files touched

- `src/rig/00-runtime.bash` for help and completion output and the retired publication state.
- `src/rig/10-configuration.bash` for the grammar, validation, and the rejection message.
- `src/rig/40-publication-lifecycle.bash` for the export flags and the removal of publish and clean.
- `src/rig/90-main.bash` for the retired dispatch entries.
- `bin/rig` by assembly.
- `docs/specs/publishing.md`, `docs/specs/cache.md`, `docs/specs/configuration.md`, `docs/specs/index.md`, `docs/specs/state.md`.
- `docs/decisions/ADR-RIG-004-static-publication-projection.md` and its successor.
- `docs/guides/user/publishing.md`, `docs/guides/user/commands.md`, `docs/guides/user/getting-started.md`, `docs/guides/user/profiles.md`, `docs/guides/README.md`.
- `man/rig.1`, `README.md`, `CHANGELOG.md`.
- `tests/rig.bats`, `tests/rig-human-config.bats`, `tests/rig-model-boundaries.bats`, `tests/rig-profile-authority.bats`, `tests/rig-skills.bats`.

## Verify

- `rig export --profile <view> --output <directory>` writes the same `rig.json` a publication produced, with `publication.id` naming the profile.
- `rig export --profile <complete profile>` is rejected with status 2 and a message saying a view is required.
- A configuration declaring `[publication.x]` is rejected with a message naming the replacement.
- A configuration declaring a provider with no `publish` capability and no publisher loads cleanly, with no provider stanza fabricated to satisfy validation.
- `rig publish` and `rig clean` are unknown commands; `rig --help`, completion, and the manual do not mention them.
- The complete local gate, and CI green on both runners.

## Dependencies / blocks

Nothing blocks it. It lands after [RIG-CLI-014](RIG-CLI-014-state-command-outcomes.md), whose outcome line covers the commands this record removes, so the two must not disagree about which commands exist.

## Documentation impact

### Decision Records

[ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) chose a static publication projection with a handoff to a publisher. The projection survives; the handoff does not. That needs a superseding record, because a reader of ADR-RIG-004 would otherwise conclude `rig publish` still exists.

### Specifications

`docs/specs/publishing.md` loses the publication section and the publisher contract and gains the export flags. `docs/specs/cache.md` retires with `rig clean`. `docs/specs/configuration.md` loses the publication grammar. `docs/specs/index.md` loses the cache entry.

### Guides

`docs/guides/user/publishing.md` becomes a guide to exporting. Every guide that names `rig publish` or `rig clean` loses that mention.

### Roadmap

None expected. The migration question raised in Triage is answered by the breaking-change decision rather than by a `MIG` record.

## Discussion

The shape being removed is not accidental — [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) chose a static publication projection deliberately, and a publication that named its own publisher made sense while Rig expected to hand the artefact onward. What has changed is that the only real consumer does not want the handoff. It wants the data, and it deploys the data itself. The declaration is therefore paying for a capability nobody uses, and charging a fabricated provider stanza for the privilege.

There is a boundary argument underneath the convenience one, and it is the more durable of the two. Rig describes what a machine should contain. It does not describe how a website presents that, what it is called, or where it lives. The consuming repository already made this split for itself once: homepage links for each tool are curated in its own `data/tool-links.json` rather than in Rig, on the grounds that Rig has no business knowing where a vendor's marketing page is. A title and a canonical URL sit on precisely the same side of that line, and they are currently on the wrong one.

Worth flagging for whoever picks this up: the easy version of this change is to make the four publication fields optional and leave everything standing. That would remove the immediate friction and keep the dead concept, which is how the phantom provider came to exist in the first place.
