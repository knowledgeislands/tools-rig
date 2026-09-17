---
id: RIG-DIST-005
area: DIST
title: Adopt website tool routes
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-17T21:05:58Z
updated_at: 2026-09-17T21:05:58Z
---

# RIG-DIST-005: Adopt website tool routes

## Goal

Keep the website's advertised `rig` version matching what this repository has released, and align this installer's version-pinning interface with the other Knowledge Islands tools.

## Context

`knowledgeislands/ki-website` delivered `KI-WEB-SITE-007`, which gives every released Knowledge Islands tool the same two public routes: `/tooling/<tool>/` for people and `/install/<tool>/` for machines. Both are generated from one website-owned registry.

`rig` now has a product page at `https://knowledgeislands.info/tooling/rig/` and a stable installer endpoint at `https://knowledgeislands.info/install/rig`, which redirects to `https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.1.0/install.sh`. The registry currently advertises `v0.1.0`.

The website does not discover releases. It advances only when this repository hands it the new version, which keeps the public recommendation deliberate — but it also means a release that is not handed over leaves the site advertising an older version.

This installer also accepts an explicit version only through `RIG_VERSION`, while `ki` and `git-almanac` accept a positional `vX.Y.Z`. That inconsistency is the subject of `tools-ki` `KI-TOOL-CLI-076`.

## Boundary

This does not move release authority, installer behaviour, artifact hosting, or checksum verification to the website. The website is an indirection layer over what this repository publishes.

Do not remove the latest-release default from the installer. Pinning is an explicit opt-in; an unpinned `curl | sh` must keep working.

## Discussion

### The release handoff

Add a named release follow-up: after publishing a release intended for general recommendation, hand `ki-website` an item naming the exact version and the immutable installer target `https://raw.githubusercontent.com/knowledgeislands/tools-rig/v0.1.0/install.sh` with the new tag substituted. The website updates its registry entry and ships.

The website verifies declared routes before deployment and reports upstream drift as a warning rather than a failure, so an outstanding handoff is visible without breaking anyone's build.

### Version pinning

Accept a positional `vX.Y.Z` argument in addition to `RIG_VERSION`, per the interface proposed in `tools-ki` `KI-TOOL-CLI-076`. Keep `RIG_VERSION` working as an alias. Follow that item rather than deciding the interface here.

### Related

Originating repository and item: `knowledgeislands/ki-website` `KI-WEB-SITE-007`. That item is done and this one does not block it. The route contract is documented at `docs/guides/tool-routes.md` in that repository.
