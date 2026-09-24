# Build complete profiles and safe views

Use profiles when one catalogue needs more than one meaningful selection: for example, an everyday workstation, a smaller development machine, or a deliberately public view. Keep membership beside each selectable declaration so a reader can see where an item belongs without finding a separate central inventory.

## Start with one configured default

A declaration without `profiles` belongs to the profile named by `[rig].default-profile`. That keeps the ordinary setup concise:

```toml
[rig]
schema = 1
default-profile = "workstation"

[tool.mgit]
name = "MGit"
category = "navigation"
purpose = "Navigate related repositories"
rationale = "Keeps repository context visible"
platforms = ["macos"]

[profile.workstation]
name = "Workstation"
purpose = "Complete everyday machine intent"
kind = "complete"
```

Stay with one profile while it expresses your real setup. Commands such as `show`, `doctor`, `apply`, and `bootstrap` are lifecycle stages, not reasons to create separate profiles.

Use `profiles = []` when an item should remain in the catalogue but belong to no profile. Use a non-empty array when an item belongs only to named profiles:

```toml
[tool.shellcheck]
name = "ShellCheck"
category = "quality"
purpose = "Check shell scripts"
rationale = "Finds portability defects before changes are shared"
platforms = ["macos", "linux"]
profiles = ["developer"]
```

Tools, skills, and managed resources all use this item-owned membership rule. Omission selects the configured default, an empty array selects nothing, and explicit names select only those profiles.

## Inherit shared complete intent

A complete machine or role profile can inherit another complete profile:

```toml
[profile.developer]
name = "Developer workstation"
purpose = "Everyday setup plus development tools"
kind = "complete"
inherits = ["workstation"]
```

Inspect the resolved result before applying it:

```sh
rig show --profile developer
rig status --profile developer
rig apply --profile developer --dry-run
```

A complete profile is the whole desired Rig intent for one target. Switching complete profiles may retire previously receipted services or scheduled jobs that are absent from the new selection. It does not uninstall packages, remove tool artifacts, reverse settings, replace the Dock, close ports, or remove skills merely because they were deselected. Review retirement rows in the dry-run plan before applying a different complete profile.

## Create a non-appliable public view

An export profile is a view. Every disclosed declaration opts in explicitly, and a view may inherit only another view:

```toml
[tool.mgit]
name = "MGit"
category = "navigation"
purpose = "Navigate related repositories"
rationale = "Keeps repository context visible"
platforms = ["macos"]
profiles = ["workstation", "public"]

[profile.public]
name = "Public rig"
purpose = "Catalogue choices safe to publish"
kind = "view"
```

If a public tool requires another tool, that dependency must opt into `public` as well. Rig rejects an implicit dependency rather than disclosing it accidentally.

A view can be shown, listed, explained, checked, and exported. Mutating commands reject it, and it never owns reconciliation receipts. Public exports contain only the allow-listed metadata described in the [export guide](exporting.md), never native authority details or observed machine state.

## Read application scope

After resolving a complete profile, mutating plans identify the reach of each operation:

- **Declaration** affects one selected tool or resource.
- **Manifest** may reconcile a complete provider-native manifest.
- **Provider-wide** affects provider maintenance or policy beyond one declaration.

Rig also checks native conflicts after profile resolution. Conflicting alternatives can coexist in the catalogue, but a profile that selects both fails before provider observation or mutation.

Receipt-backed reconciliation is serialised per platform. If another application owns the target, Rig reports whether the lock owner appears active, stale, or unknown. It does not remove an unverified lock automatically. Use `rig diag` to locate effective state before deciding how to recover.
