---
id: RIG-CLI-007
title: Consolidate audience-centric guides
area: CLI
theme: cli
horizon: now
status: draft
blocks: []
blocked_by: []
transferred_from: ki-website
baseline_ref: null
created_at: 2026-09-21T17:20:00Z
updated_at: 2026-09-21T17:20:00Z
---

## Goal

Every practical instruction for Rig lives in the guide collection under the audience that needs it, and the README orients rather than instructs.

## Context

`docs/guides/` already splits `user/` and `developer/`, each with its own index, and `.ki.toml` declares `[skills.ki-guides]`. The user collection covers getting started, commands, provider actions, operational resources, and publishing. The structure is right.

What this item questions is duplication. The 179-line README carries Install, Create a first rig, Workstations are profiles, Generated artifacts, Commands, and Safety and ownership — material that either restates the user guides or contradicts them. A README that both orients and instructs is the thing being consolidated, and two copies of an install procedure is worse than one.

KI Website now declares, for every page it publishes under `apps/site/src/guidance/`, the exact upstream document and pinned ref that page was written from, and a `verify:guidance --network` sweep reports the pages whose source has moved. The site intends to derive public guidance for this project from this repository's own guides and cite them at a pinned ref, so the quality and stability of `docs/guides/` here directly determines the quality of what the site can publish.

That is a pull, not an obligation: KI Website derives, it does not own. This repository decides what its guides say and when they change.

Separately, `ki-guides` is being asked to require audience directories under `docs/guides/` rather than permitting a flat collection (`ki-agentic-harness` `KI-HARNESS-GOV-083`). If that lands, this repository's collection has to satisfy it.

## Boundary

Adopted into `Now` by explicit approval, so this is prioritised work rather than intake. It remains `status: draft`: `ki-plan` shapes it to `Ready` before any implementation, and this repository still owns its plan and sequencing.

KI Website derives and cites; it does not own this collection and must not be given approval rights over it. Nothing here requires a guide to be written for the website's benefit — if a guide would not serve this repository's own readers, it should not exist.

## Shaping

- Compare each instructional README section against the user guide that covers the same ground, and decide which is authoritative.
- Reduce the README to orientation: what Rig is, what it answers, and where to go next. The plain-language model and the lifecycle sketch earn their place; step-by-step setup does not.
- Confirm `docs/guides/user/commands.md` and the README's command list cannot disagree, ideally by having only one of them.
- Check whether anything practical still lives only in `docs/specs/` or `AGENTS.md`.

## Current state

`docs/guides/` splits `user/` and `developer/` with an index each, `.ki.toml` declares `[skills.ki-guides]`, and ten guides exist. The collection is in good shape. The unverified part is the README, which carries six instructional sections covering ground the user guides also cover, with nothing establishing which is authoritative.

## Steps

- [ ] Map each instructional README section to the user guide covering the same ground, and note where they disagree.
- [ ] Decide the authoritative home for each, resolving toward the guide.
- [ ] Reduce the README to orientation and links.
- [ ] Sweep `docs/specs/` and `AGENTS.md` for practical instruction that belongs in the collection.
- [ ] Run the guides audit and repair what it reports.

## Files touched

`README.md`, `docs/guides/user/` and `docs/guides/developer/`.

## Verify

`ki repo audit --skill ki-guides --repo .` passes, and `ki repo audit --skill ki-authoring --repo .` passes over the collection.

## Dependencies / blocks

Nothing blocks this. `KI-HARNESS-GOV-083` in `ki-agentic-harness` proposes making audience directories a `ki-guides` requirement: if it lands first this collection satisfies it by construction, and if it lands later this collection already conforms. KI Website intends to derive public guidance from these guides and cite them at a pinned ref, but it derives rather than owns and its schedule does not gate this work.

## Documentation impact

### Decision Records

No decision record is needed. Audience-centric grouping is the house arrangement `ki-guides` already encodes, so adopting it here is conformance rather than a new decision. One becomes owed only if this repository concludes it needs an exception.

### Specifications

No behaviour-level contract changes. This item changes only where instructions live and who they are written for.

### Guides

This item is entirely guide impact: it establishes or completes the collection, its audience directories, and their indexes.

### Roadmap

No further roadmap change is expected. If writing the guides exposes behaviour that cannot honestly be explained, that is a separate item raised at the time.

## Discussion

Shaping settles how far this goes, not whether it happens. The prompting question is whether a reader who has never opened this repository can do what it is for without reading source.
