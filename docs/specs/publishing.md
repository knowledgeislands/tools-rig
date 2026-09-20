# Personal-site publication — RIG-PUB

This area of the [Rig Specifications](index.md) defines the public projection established by [ADR-RIG-004](../decisions/ADR-RIG-004-static-publication-projection.md) and constrained by [XDR-RIG-001](../decisions/XDR-RIG-001-executable-provider-boundary.md).

## Projection

### RIG-PUB-001 — Explicit public profile

Rig MUST export only the profile explicitly named by a publication declaration. Publication resolution MUST include every tool selected by that profile regardless of the active host platform, while retaining each tool's declared platform values.

_Conformance:_ conforming

_Verify:_ Bats tests configure distinct private and public profiles, export on different host platforms, and compare artifacts.

_Evidence:_ `tests/rig.bats` proves private tools are absent and output is byte-equivalent across active host platforms.

### RIG-PUB-002 — Disclosure allow-list

Rig MUST limit the projection to publication identity, title, canonical URL, public profile identity, and selected category and tool catalogue fields: identity, name, purpose, rationale, declared platforms, and relationships. It MUST exclude providers, installation metadata, services, scheduled jobs, settings, Dock layouts, executables, arguments, manifests, credentials, local paths, other profiles, observed state, health findings, unmanaged inventory, and host publication state.

_Conformance:_ conforming

_Verify:_ Bats tests scan the complete artifact for private tools, managed resources, provider, installation, path, and argument markers.

_Evidence:_ `rig_render_public_category`, `rig_render_public_tool`, and `rig_render_publication_json` construct the fixed allow-listed projection; `export writes valid allow-listed versioned public data as a complete tree` scans the artifact for excluded private and operational markers.

### RIG-PUB-003 — Public relationship closure

Rig MUST omit any relationship whose source or target lies outside the selected public profile. It MUST emit `requires`, `related`, and `alternatives` arrays for every selected tool, including empty arrays.

_Conformance:_ conforming

_Verify:_ Bats tests connect public tools to public and private tools and parse every exported relationship array.

_Evidence:_ `tests/rig.bats` observes the public relationship while the private alternative is absent.

### RIG-PUB-004 — Versioned deterministic artifact

`rig export` MUST produce a complete tree containing exactly one regular, non-symlink file named `rig.json`. The UTF-8 JSON document MUST use this version-1 shape and MUST order categories, tools, declared platforms, and relationship values bytewise by identity or value:

```json
{
  "format": "rig-publication",
  "version": 1,
  "publication": {
    "id": "site",
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
    ]
  }
}
```

A consumer MUST inspect both `format` and `version` before interpreting the remaining document. Rig MAY add a new integer version in a later contract, but MUST NOT silently change the meaning or shape of version 1.

_Conformance:_ conforming

_Verify:_ Parse exported JSON, assert format and version, and compare byte output for equivalent permuted declarations on different active host platforms.

_Evidence:_ `tests/rig.bats` parses and compares complete exports.

### RIG-PUB-005 — Canonical URL metadata

`base-url` MUST be an absolute HTTP or HTTPS URL without user information, query, or fragment. Rig MUST normalise an omitted trailing slash and project the value as `publication.canonical_url`. The value is metadata for a consumer and MUST NOT become configuration authority or generated navigation.

_Conformance:_ conforming

_Verify:_ Bats tests cover valid root, subdomain, and subpath values plus malformed authorities.

_Evidence:_ `tests/rig.bats` observes normalised canonical metadata and fail-closed validation.

### RIG-PUB-006 — Offline export

`rig export` MUST NOT invoke a provider, publisher, or network command.

_Conformance:_ conforming

_Verify:_ Place recording publisher and network-command fakes on `PATH`, export a fixture, and assert none was invoked.

_Evidence:_ `tests/rig.bats` covers offline export.

## Deployment

### RIG-PUB-007 — Explicit trusted publisher

Publication staging MUST use the effective Rig cache's `publish/staging` namespace. After publisher failure or post-export interruption, Rig MUST atomically move the complete export into `publish/retained` before reporting its retained path. Explicit retained-artifact cleanup is governed by [RIG-CACHE](cache.md).

A selected publisher MUST be explicitly declared with `adapter = "custom"` and the exact `publish` operation allowed. An omitted executable MUST resolve exactly `${RIG_DATA_HOME}/providers/PROVIDER-ID`; an explicit executable MUST take precedence. Resolution MUST use the same no-search trust boundary as external observation, application, inventory, and declared actions.

`rig publish PUBLICATION` MUST validate and render one complete isolated export beneath the effective Rig cache before invoking only the publication's configured publisher. Rig MUST invoke it once as `EXECUTABLE [PROVIDER_ARGUMENT ...] rig-provider-v1 publish PROVIDER PUBLICATION directory ABS_EXPORT_DIR`, preserving literal argument boundaries and the publisher's native deployment result. Validation, staging, or render failure MUST invoke no publisher.

A successful publisher result MUST remove only the validated Rig-owned staged tree without reporting a retained export. Once export is complete, publisher failure or interruption MUST retain and report its path. Successful cleanup MUST revalidate the canonical staging parent, operate relative to a pinned directory, unlink only `rig.json`, and remove the now-empty staging directory. A substituted parent, symlink, unexpected file, or unsafe shape MUST fail closed without recursive traversal.

_Conformance:_ conforming

_Verify:_ Bats tests configure recording external publishers; assert one selected invocation and exact handoff; exercise unavailable operations, staging failure, interruption phases, native failure, retained artifacts, success cleanup, and adversarial cache-parent substitution.

_Evidence:_ `rig_command_publish`, `rig_prepare_publish_stage`, `rig_cleanup_publish_stage`, `rig_prepare_custom_invocation`, and `tests/rig.bats` implement and cover the boundary.

### RIG-PUB-008 — Safe complete-tree replacement

`rig export PUBLICATION --output DIRECTORY` MUST replace the complete output tree so stale files cannot survive. It MUST reject `/`, `.`, `..`, symlink targets, and non-directory targets without altering them.

_Conformance:_ conforming

_Verify:_ Export over a stale directory and attempt each unsafe target.

_Evidence:_ `tests/rig.bats` verifies the one-file tree, stale-file removal, and unchanged unsafe targets.
