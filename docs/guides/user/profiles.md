# Build complete profiles and safe views

Use profiles when the same catalogue needs more than one meaningful selection: for example, a complete workstation, a development machine, or a deliberately public view. Keep membership beside each selectable declaration so a reader can see where one tool or resource belongs without finding a central inventory.

## Start with the configured default

A declaration without `profiles` belongs to the profile named by `[rig].default-profile`. This is the concise path for the tools and resources that make up your ordinary setup:

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

Use `profiles = []` when an item should remain in the catalogue but belong to no profile. Use a non-empty array when it belongs only to named profiles:

```toml
[tool.shellcheck]
name = "ShellCheck"
category = "quality"
purpose = "Check shell scripts"
rationale = "Finds portability defects before changes are shared"
platforms = ["macos", "linux"]
profiles = ["developer"]
```

Skills use the same item-owned membership rule as tools and managed resources. Omitted `profiles` selects the configured default profile, an empty array selects none, and every skill disclosed through a view must name that view explicitly. Changing profiles never removes an installed or projected skill.

## Inherit shared complete intent

A complete machine or role profile can inherit another profile explicitly. Inheritance adds the parent membership before Rig closes tool dependencies:

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

A complete profile is the whole desired Rig intent for one machine target. Switching complete profiles may retire previously receipted services and scheduled jobs that are absent from the new selection. It does not uninstall packages, remove tool artifacts, reverse settings, replace a Dock merely because it was deselected, or clean ports and skills. Review the dry-run retirement rows before applying a different complete profile.

## Create a non-appliable public view

A publication profile is a view. Every disclosed declaration opts into it explicitly, and a view may inherit only another view:

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

If a public tool requires another tool, that dependency must also opt into `public`. Rig rejects an implicit dependency rather than disclosing it accidentally. A view can be shown, listed, explained, checked, or exported, but `apply`, `bootstrap`, `update`, `maintain`, and selected-resource mutation reject it. It never owns retirement receipts.

A public skill follows the same explicit membership rule as a public tool. It exports only allow-listed public metadata, never its authority, runtime projections, local source, or observed state.

## Read an application plan

Rig checks native conflicts only after resolving the selected profile. Mutually exclusive service or setting alternatives may therefore coexist in the catalogue, while a profile selecting both fails before provider observation or mutation.

Each mutating plan identifies its scope:

- **declaration** — work for one selected tool or resource;
- **manifest** — work that can reconcile a complete provider-native manifest;
- **provider-wide** — maintenance or policy affecting the provider beyond one declaration.

Receipt-backed reconciliation is serialised per platform. If another apply owns that target, Rig stops before mutation and reports the lock owner as active, stale, or unknown. Rig does not remove an existing unverified lock automatically; inspect the reported owner and the effective state path from `rig diag` before deciding how to recover.
