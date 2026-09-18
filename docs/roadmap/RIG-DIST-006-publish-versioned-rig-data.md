---
id: RIG-DIST-006
area: DIST
title: Publish versioned rig data
theme: distribution
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-18T03:36:25Z
updated_at: 2026-09-18T04:23:41Z
---

# RIG-DIST-006: Publish versioned rig data

## Goal

Make Rig publish a deterministic, versioned public data projection that a personal website such as `rig.midnight.ninja` can render in its own design system without treating Rig as a website generator.

## Context

Rig currently exports a complete static tree containing `index.html` and `assets/rig.css`. That proves the public-profile privacy boundary and trusted publisher handoff, but couples the product's durable catalogue meaning to one presentation. `rig.midnight.ninja` is available as a receiving site and should be free to combine the Rig projection with its documentation, navigation, accessibility, and visual conventions.

The catalogue remains authoritative. A published artifact is a derived public projection, and the receiving website remains authoritative for presentation, routing, deployment, and rollback.

## Boundary

The projection contains only explicitly selected public-profile catalogue data. It excludes provider declarations and bindings, executable paths, credentials, private profiles, local configuration paths, observed machine state, health findings, unmanaged inventory, and host-specific publication state.

Rig owns deterministic selection, relationship closure, schema versioning, serialization, complete-tree replacement, offline validation, and trusted publisher dispatch. The website owns parsing, rendering, caching, navigation, accessibility, deployment, and failure presentation. A publisher transports a validated artifact but does not redefine it.

## Current state

`rig export` and the internal `rig publish` staging path render two presentation files. The export is host-filtered because it resolves the publication profile through the active platform. Cleanup and interruption safety deliberately recognise only `index.html` and `assets/rig.css`. Existing tests cover allow-listing, relationship closure, deterministic file trees, portable base URLs, offline execution, safe replacement, and publisher staging.

No receiving-site implementation belongs in this repository. The currently configured `base-url` remains useful canonical metadata even when Rig does not generate links.

## Decisions

- Replace the HTML and CSS tree with one `rig.json` artifact now. Rig is pre-1.0, so no dual-output transition or compatibility presentation files are required.
- Publish a platform-neutral profile. Include every tool selected by the declared profile and each tool's declared `platform` values; do not vary public data according to the publishing host.
- Retain required configuration field `base-url` and project it as publication metadata key `canonical_url`. This avoids an unrelated configuration migration while naming its public meaning clearly.
- Use top-level `format: "rig-publication"` and integer `version: 1`. Include publication metadata, profile identity, selected categories, and selected tools with public metadata and closed relationship arrays.
- Keep `rig export PUBLICATION --output DIRECTORY`, `rig publish PUBLICATION`, and the publisher directory handoff unchanged. Only the complete tree's declared artifact changes.
- Leave preview and rendering entirely to the receiving website. Rig will not add a local server, templates, themes, or a second presentation command.

## Steps

- [ ] Add Bash 3.2-compatible JSON escaping and deterministic rendering for the version-1 public schema.
- [ ] Resolve publication profiles independently of the active host while retaining declared tool platforms and relationship closure.
- [ ] Replace export and publish staging with exactly one regular non-symlink `rig.json`; update safe cleanup and interruption handling without recursive deletion.
- [ ] Update Bats fixtures for byte-stable JSON, schema parsing, platform neutrality, allow-listing, relationship closure, offline export, safe replacement, and publisher lifecycle safety.
- [ ] Align help, completions, README, manual, changelog, user guide, publication Decision Record, and publishing Specifications with the data-first contract.
- [ ] Run the full repository gate and record the six-part delivery review packet.

## Files touched

- `bin/rig`
- `tests/rig.bats`
- `README.md`
- `man/rig.1`
- `CHANGELOG.md`
- `docs/decisions/ADR-RIG-004-static-publication-projection.md`
- `docs/specs/publishing.md`
- `docs/guides/user/README.md`
- `docs/roadmap/RIG-DIST-006-publish-versioned-rig-data.md`

## Verify

- `shellcheck bin/rig install.sh`
- `bash -n bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`
- Exported `rig.json` is byte-identical across declaration order and active host platform.
- A JSON parser accepts the complete artifact and observes `format = rig-publication`, `version = 1`.
- No provider, binding, executable, path, credential, observed-state, or non-public-profile data appears in the artifact.
- Publisher success, native failure, interruption, and adversarial cache-parent substitution preserve their existing safety boundaries with the one-file tree.

## Dependencies / blocks

No implementation dependency remains. The receiving website repository and its renderer can consume the documented schema later through their own canonical workflow; they do not block Rig's offline data projection.

## Delegation

No delegated lane is planned. The serializer, filesystem allow-list, publishing cleanup, fixtures, and contract documentation are tightly coupled and should land as one locally integrated delivery.

## Documentation impact

### Decision Records

Amend ADR-RIG-004 because the authority boundary is unchanged while the projection representation moves from presentation files to versioned data.

### Specifications

Replace HTML-specific publication requirements with the exact versioned machine-readable schema, platform-neutral resolution, deterministic ordering, privacy exclusions, and single-file tree.

### Guides

Explain how a person selects a public profile, inspects `rig.json`, and hands it to a website-owned renderer and publisher.

### Roadmap

Keep receiving-site renderer and deployment work in that site's canonical workflow. Link future receiving work to this schema rather than duplicating website delivery here.

## Discussion

### Data is the durable product

Categories, purposes, rationale, platform support, and relationships are Rig's durable public meaning. HTML and CSS are one consumer's presentation choice. A versioned data artifact lets `rig.midnight.ninja` and future consumers use the same reviewed projection without importing private Rig configuration.

### Privacy remains allow-listed

Changing representation must not widen disclosure. The schema names every allowed field, closes relationships over the selected public set, and excludes provider and observed state by construction. A single deterministic artifact is easier to inspect and compare than generated presentation assets.

### Pre-1.0 compatibility

The public preview can replace the original HTML contract before 1.0, provided help, manual, changelog, Decision Record, Specification, tests, and publisher cleanup move together. Retaining both formats would create an unnecessary compatibility surface and obscure which artifact a website should consume.
