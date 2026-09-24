# Personal-site publication — RIG-PUB

This area of the [Rig Specifications](index.md) defines the public projection established by [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md).

## Projection

### RIG-PUB-001 — Explicit public profile

Rig MUST export only the non-appliable view named by the `--profile` argument of `rig export`. Export resolution MUST include every tool that opts into that view regardless of the active host platform, while retaining each tool's declared platform values.

_Conformance:_ conforming

_Verify:_ Bats tests configure distinct private and public profiles, export on different host platforms, and compare artifacts.

_Evidence:_ `tests/rig.bats` proves private tools are absent and output is byte-equivalent across active host platforms.

### RIG-PUB-002 — Disclosure allow-list

Rig MUST limit the projection to the exported view identity, title, canonical URL, public profile identity, and selected category and tool catalogue fields: identity, name, purpose, rationale, declared platforms, and relationships. It MUST exclude providers, installation metadata, services, scheduled jobs, settings, Dock layouts, executables, arguments, manifests, credentials, local paths, other profiles, observed state, health findings, unmanaged inventory, and host publication state.

_Conformance:_ conforming

_Verify:_ Bats tests scan the complete artifact for private tools, managed resources, provider, installation, path, and argument markers.

_Evidence:_ `rig_render_public_category`, `rig_render_public_tool`, and `rig_render_publication_json` construct the fixed allow-listed projection; `export writes valid allow-listed versioned public data as a complete tree` scans the artifact for excluded private and operational markers.

### RIG-PUB-003 — Public relationship closure

Rig MUST omit any relationship whose source or target lies outside the selected public profile. It MUST emit `requires`, `related`, and `alternatives` arrays for every selected tool, including empty arrays.

_Conformance:_ conforming

_Verify:_ Bats tests connect public tools to public and private tools and parse every exported relationship array.

_Evidence:_ `tests/rig.bats` observes the public relationship while the private alternative is absent.

### RIG-PUB-004 — Versioned deterministic artifact

`rig export` MUST produce a complete tree containing exactly one regular, non-symlink file named `rig.json`. The UTF-8 JSON document MUST use this version-2 shape and MUST order categories, tools, skills, declared platforms, and relationship values bytewise by identity or value:

```json
{
  "format": "rig-publication",
  "version": 2,
  "publication": {
    "id": "public",
    "title": "A public rig",
    "canonical_url": "https://rig.example/"
  },
  "profile": {
    "id": "public",
    "categories": [
      {
        "id": "navigation",
        "name": "Navigation",
        "purpose": "Move between places"
      }
    ],
    "tools": [
      {
        "id": "mgit",
        "name": "MGit",
        "category": "navigation",
        "purpose": "Navigate related repositories",
        "rationale": "Keeps repository context visible",
        "platforms": ["macos"],
        "relationships": {
          "requires": [],
          "related": [],
          "alternatives": []
        }
      }
    ],
    "skills": []
  }
}
```

A consumer MUST inspect both `format` and `version` before interpreting the remaining document. Rig MAY add a new integer version in a later contract, but MUST NOT silently change the meaning or shape of version 2.

_Conformance:_ conforming

_Verify:_ Parse exported JSON, assert format and version, and compare byte output for equivalent permuted declarations on different active host platforms.

_Evidence:_ `tests/rig.bats` parses and compares complete exports.

### RIG-PUB-005 — Canonical URL metadata

`--base-url` MUST be an absolute HTTP or HTTPS URL without user information, query, or fragment. Rig MUST normalise an omitted trailing slash and project the value as `publication.canonical_url`. Omitting the argument MUST project `null`. The value is metadata for a consumer and MUST NOT become configuration authority or generated navigation.

_Conformance:_ conforming

_Verify:_ Bats tests cover valid root, subdomain, and subpath values, an omitted argument, and malformed authorities.

_Evidence:_ `tests/rig.bats` observes normalised canonical metadata, the null default, and fail-closed validation.

### RIG-PUB-006 — Offline export

`rig export` MUST NOT invoke a provider or network command.

_Conformance:_ conforming

_Verify:_ Place recording provider and network-command fakes on `PATH`, export a fixture, and assert none was invoked.

_Evidence:_ `tests/rig.bats` covers offline export.

## Parameters

### RIG-PUB-007 — Export parameters

`rig export` MUST take its complete instruction from the command line. `--profile NAME` and `--output DIRECTORY` MUST both be present; `--title TEXT` and `--base-url URL` are optional. Each MUST be rejected with status 2 when its value is missing, and an unexpected positional argument MUST be rejected with status 2 before the configuration is loaded.

`--profile` MUST name a declared profile whose `kind` is `view`; an unknown profile and an appliable profile MUST each be rejected with status 2 without creating the output. An omitted `--title` MUST default to the view profile's declared `name`, and to the profile identifier when the view declares none. `publication.id` MUST be the exported profile's identifier.

Rig MUST NOT accept any of these values from configuration. A `[publication.ID]` table MUST fail to load, naming `rig export --profile` as its replacement.

_Conformance:_ conforming

_Verify:_ Bats tests export with each argument present and absent, and assert status 2 for a missing value, an unexpected positional, an unknown profile, an appliable profile, and a configuration carrying `[publication.ID]`.

_Evidence:_ `rig_command_export` parses the arguments and validates the view before rendering; `rig_add_section` rejects the retired table; `export help and syntax are local and explicit`, `export refuses a profile that is not a view`, `export titles a view from its declared name`, and the loader rejection case in `tests/rig.bats` cover each boundary.

### RIG-PUB-008 — Safe complete-tree replacement

`rig export --profile NAME --output DIRECTORY` MUST replace the complete output tree so stale files cannot survive. It MUST reject `/`, `.`, `..`, symlink targets, and non-directory targets without altering them.

_Conformance:_ conforming

_Verify:_ Export over a stale directory and attempt each unsafe target.

_Evidence:_ `tests/rig.bats` verifies the one-file tree, stale-file removal, and unchanged unsafe targets.

### RIG-PUB-009 — Non-appliable disclosure view

An export MUST reference a non-appliable view. Every declaration and relationship dependency in its resolved projection MUST opt into that view or an inherited view explicitly. The view MUST NOT inherit a complete profile, acquire reconciliation ownership, or expose declarations assigned implicitly to the configured default profile.

_Conformance:_ conforming

_Verify:_ Bats exports an explicit public view and rejects a complete profile, complete inheritance, implicit default disclosure, and an unlisted dependency.

_Evidence:_ `rig_command_export`, `rig_validate_view_closure`, and item-owned profile resolution enforce the boundary; export and profile-authority Bats cover safe selection and rejection.

### RIG-PUB-010 — Absolute private-port exclusion

Every public projection MUST exclude port declarations, numbers, scopes, modes, owners, listener observations, process details, and unmanaged listener inventory regardless of view membership.

_Conformance:_ conforming

_Verify:_ Bats assigns a declaration containing unique private markers to an exported view, exports it, and scans the complete output tree for every marker.

_Evidence:_ `rig_render_publication_json` has a fixed tool-and-category allow-list; the private-port publication test proves no port field or marker enters `rig.json`.

### RIG-PUB-011 — Explicit user-level skill projection

Publication format 2 MUST always emit deterministic `profile.skills`, including an empty array. A skill MUST enter an export only through explicit view membership and MUST expose only `id`, `name`, `purpose`, `rationale`, and optional reviewed `public-source` as `source`. Rig MUST exclude skill authority, native installation source, runtime projections, local paths and roots, locks, arguments, observed state, and unmanaged inventory. JSON string encoding MUST preserve valid UTF-8 and escape quotes, backslashes, and control characters without changing the existing category or tool semantics.

_Conformance:_ conforming

_Verify:_ Bats exports selected and unselected skills, compares deterministic order and empty arrays, parses JSON containing quotes, controls, and UTF-8, and scans the complete tree for private markers including ports, paths, roots, runtimes, locks, arguments, state, and unmanaged inventory.

_Evidence:_ `rig_render_public_skill`, `rig_render_publication_json`, and `tests/rig-skills.bats` implement and verify the format-2 allow-list.
