# Personal-site publication — RIG-PUB

This area of the [Rig Specifications](index.md) defines the public projection established by [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) and constrained by [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Static export

### RIG-PUB-001 — Explicit public profile

Rig MUST export only the profile explicitly named by a publication declaration.

_Conformance:_ conforming

_Verify:_ Bats tests configure distinct private and public profiles and assert only public-profile tools enter the artifact.

_Evidence:_ `tests/rig.bats` exports a publication whose public profile excludes the configured default profile's private tool.

### RIG-PUB-002 — Disclosure allow-list

Rig MUST limit static export to public category and tool identity, name, purpose, rationale, platform, and relationship fields.

_Conformance:_ conforming

_Verify:_ Bats tests export a fixture containing provider commands, arguments, paths, manifests, host identity, private profiles, and observed state and assert none appear in any artifact file.

_Evidence:_ `tests/rig.bats` scans the complete exported tree for private tools and provider, binding, path, and argument markers.

### RIG-PUB-003 — Public relationship closure

Rig MUST omit a relationship from static export when either endpoint is outside the selected public profile.

_Conformance:_ conforming

_Verify:_ Bats tests connect public tools to public and private tools and inspect the exported relationship set.

_Evidence:_ `tests/rig.bats` verifies a public relationship link is present while a private alternative and its anchor are absent.

### RIG-PUB-004 — Deterministic artifact

`rig export` MUST generate equivalent static content for the same schema version, resolved public profile, and publication configuration.

_Conformance:_ conforming

_Verify:_ Bats tests export equivalent permuted declarations into two temporary directories and compare their file trees and contents.

_Evidence:_ `tests/rig.bats` recursively compares exports after permuting equivalent profile tool declarations.

### RIG-PUB-005 — Portable base URL

`rig export` MUST generate valid navigation for a configured domain root, subdomain, or subpath base URL.

_Conformance:_ conforming

_Verify:_ Bats tests export fixtures for `https://rig.example/` and `https://example/rig/` and verify every generated internal link against its base URL.

_Evidence:_ `tests/rig.bats` verifies stylesheet, catalogue, and relationship URLs for root and subpath publication bases.

### RIG-PUB-006 — Offline export

`rig export` MUST NOT invoke a provider, publisher, or network command.

_Conformance:_ conforming

_Verify:_ Bats tests configure marker provider and publisher executables, remove network tools from `PATH`, export the site, and assert a complete artifact with no marker calls.

_Evidence:_ `tests/rig.bats` shadows the network client and configures an executable publisher; export completes without invoking either marker.

## Deployment

### RIG-PUB-007 — Explicit trusted publisher

`rig publish PUBLICATION` MUST invoke only that publication's configured publisher and preserve the publisher's native deployment result.

_Conformance:_ pending

_Verify:_ Bats tests configure two recording publishers, invoke one publication, and assert one literal invocation and its exit result.

## Export filesystem boundary

### RIG-PUB-008 — Safe complete-tree replacement

`rig export PUBLICATION --output DIRECTORY` MUST render a complete sibling staging tree before replacing only an explicit safe directory and MUST reject root, dot, dot-dot, symlink, and non-directory output targets.

_Conformance:_ conforming

_Verify:_ Bats tests seed stale output, verify complete-tree replacement, and exercise every rejected target class without altering the target.

_Evidence:_ `tests/rig.bats` verifies the exported tree contains only `index.html` and `assets/rig.css`, stale files disappear, and unsafe targets remain unchanged.
