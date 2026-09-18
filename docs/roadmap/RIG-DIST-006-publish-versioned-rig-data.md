---
id: RIG-DIST-006
area: DIST
title: Publish versioned rig data
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-18T03:36:25Z
updated_at: 2026-09-18T03:36:25Z
---

# RIG-DIST-006: Publish versioned rig data

## Goal

Make Rig publish a deterministic, versioned public data projection that a personal website such as `rig.midnight.ninja` can render in its own design system without treating Rig as a website generator.

## Context

Rig currently exports a complete static tree containing `index.html` and `assets/rig.css`. That proves the public-profile privacy boundary and trusted publisher handoff, but couples the product's durable catalogue meaning to one presentation. `rig.midnight.ninja` is now available as a receiving site and should be free to combine the Rig projection with its existing documentation, navigation, accessibility, and visual conventions.

The catalogue remains authoritative. A published artifact is a derived public projection and the receiving website remains authoritative for presentation, routing, deployment, and rollback.

## Boundary

The projection must contain only explicitly selected public-profile catalogue data. It must not contain provider declarations or bindings, executable paths, credentials, private profiles, local configuration paths, observed machine state, health findings, unmanaged inventory, or host-specific publication state.

Rig owns deterministic selection, relationship closure, schema versioning, serialization, complete-tree replacement, and offline validation. The website owns parsing, rendering, caching, navigation, accessibility, deployment, and failure presentation. A publisher transports a validated artifact but does not redefine it.

## Discussion

### Candidate contract

Prefer one deterministic `rig.json` artifact with top-level `format = "rig-publication"` and integer `version = 1`. The document should include publication metadata, selected public profile identity, sorted categories, and sorted tools with public catalogue metadata and closed relationships. Canonical site URL may be included as metadata but must not become configuration authority.

The default recommendation is a platform-neutral projection: profile membership is public intent, while each tool retains its declared supported platforms. Host filtering would make a personal public rig vary according to the machine that happened to publish it.

### Questions to resolve before planning

- Replace HTML and CSS in the next pre-1.0 publication contract, or provide one explicitly bounded dual-output transition?
- Confirm platform-neutral publication rather than active-host filtering.
- Retain `base-url` as required canonical metadata, make it optional, or replace it with a clearer `canonical-url` field?
- Which repository owns the `rig.midnight.ninja` renderer and publisher transport, and what receiving-site work record should consume the schema?
- Should a local human preview remain a separate Rig command or be entirely website-owned?

### Candidate steps

- [ ] Decide the data-only or bounded-transition contract and record any durable authority change.
- [ ] Specify the exact public schema, deterministic ordering, escaping, relationship closure, privacy exclusions, compatibility policy, and validation failures.
- [ ] Implement Bash 3.2-compatible serialization without adding a required runtime dependency.
- [ ] Align `rig export`, `rig publish`, help, completion, manual, README, changelog, guides, and publication specifications.
- [ ] Add fixtures proving deterministic byte output, public allow-listing, private-state exclusion, complete-tree replacement, and unchanged trusted publisher boundaries.
- [ ] Create the receiving-site roadmap item in its owning repository once that repository and transport are confirmed.

### Files likely touched

- `bin/rig`
- `tests/rig.bats`
- `README.md`
- `man/rig.1`
- `CHANGELOG.md`
- `docs/decisions/ADR-RIG-004-safe-public-projection.md`
- `docs/specs/publishing.md`
- `docs/guides/user/README.md`

### Verify

- `shellcheck bin/rig install.sh`
- `bash -n bin/rig install.sh`
- `bats tests/`
- `mandoc -T lint man/rig.1`
- `ki repo audit --repo .`
- An exported fixture is byte-identical across declaration order and host platform.
- A schema consumer can render the complete selected public profile without reading private Rig configuration.
- No provider, binding, executable, path, credential, observed-state, or non-public-profile data appears in the artifact.

### Dependencies / blocks

No current Ready batch item depends on this proposal. Planning depends on the publication-contract decisions above and identification of the receiving website repository. Existing HTML export remains supported until a later approved implementation explicitly changes it with equivalent tests.

### Documentation impact

#### Decision Records

Review ADR-RIG-004. Amend it if the authority boundary is unchanged and only the projection representation changes; supersede it only if the durable publication authority model changes.

#### Specifications

Define a versioned machine-readable publication schema and compatibility policy in the publishing specification before implementation.

#### Guides

Explain how a person selects a public profile, inspects exported data, and hands it to a website-owned renderer and publisher.

#### Roadmap

Keep receiving-site renderer and deployment work in that site's canonical workflow. Link the two records rather than duplicating website delivery here.
