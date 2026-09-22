# Manage user-level skills

Use Rig to describe agent skills that belong in your personal working setup, explain why they are present, and compare the declaration with their native authority. Rig records intent and provenance; it does not copy, inspect, or evaluate skill instructions.

## Choose the authority

Every `[skill.ID]` names one authority and matching trust boundary:

- **`skills-cli`** — a deliberately installed `skills` executable owns a remote global skill. Rig invokes that executable directly; it never uses unqualified `npx`.
- **`ki`** — KI owns the projection. Rig reports observation unavailable until KI exposes a stable machine-readable inventory and never parses human output.
- **`local`** — a reviewed local source is projected into declared runtime roots through leaf symlinks. Rig requires real, non-symlink source and root directories and never replaces an existing target.
- **`runtime` or `plugin`** — the runtime or plugin manager owns the skill. Rig observes the declared projection only; apply and update do not materialise it.

Repository-local skills remain repository concerns. Runtime-bundled and plugin-provided skills should stay under their native owner instead of being duplicated as a global installation.

## Declare a remotely sourced skill

Declare the skill beside its human meaning and reviewed provenance:

```toml
[skill.caveman]
name = "Caveman"
purpose = "Provide a compact communication mode"
rationale = "Keeps low-token collaboration available across agent runtimes"
authority = "skills-cli"
source = "JuliusBrussee/caveman"
source-skill = "caveman"
trust = "reviewed"
platforms = ["macos"]
runtimes = ["claude-code", "codex"]
profiles = ["default", "public"]
public-source = "https://github.com/JuliusBrussee/caveman"
```

`source-skill` is optional when the native skill name matches the Rig ID. `public-source` is optional and must be a reviewed HTTP or HTTPS URL. It is not the materialisation source.

The `skills-cli` executable may itself be declared as a normal tool when bootstrap must install it first. A skill can use `requires = ["skills-cli"]` to make that order explicit.

## Declare a bounded local projection

Use `local` only for a source you control and have reviewed:

```toml
[skill.personal-audits]
name = "Personal audits"
purpose = "Run personal workstation audits"
rationale = "Keeps private maintenance guidance available to selected agents"
authority = "local"
source = "$HOME/src/personal-audits"
trust = "reviewed"
platforms = ["macos"]
runtimes = ["claude-code", "codex"]
```

Before creating a projection, Rig canonicalises the source and each runtime root, confirms each is a real directory rather than a symlink, verifies the target remains contained beneath that root, then revalidates immediately before creating only a missing leaf symlink. A file, directory, or symlink already at the target is a collision and remains untouched.

## Inspect and materialise

Queries are read-only:

```sh
rig show
rig explain skill:caveman
rig status --unmanaged
rig doctor
```

`status --unmanaged` asks the direct Skills CLI inventory for global skills not represented by any `skills-cli` declaration. If the executable is absent, returns non-zero, reports an unsupported version, or emits malformed JSON, Rig reports the inventory unavailable.

Preview before applying:

```sh
rig apply --scope skills --dry-run
rig apply --scope skills
```

The full apply and bootstrap order is tools → skills → resources. `rig update --dry-run` previews explicit Skills CLI updates, and `rig update` advances selected `skills-cli` skills. `rig maintain`, `rig clean`, and selecting another profile never update or remove skills.

## Publish only deliberate metadata

A publication view must explicitly select a skill. Publication format 2 emits only `id`, `name`, `purpose`, `rationale`, and optional `public-source` as `source`. It never emits native authority, install source, runtime mappings, local paths or roots, locks, arguments, observed state, or unmanaged inventory.

Inspect `rig export` output before handing it to a publisher. A skill being installed or selected in a complete profile does not make it public.
