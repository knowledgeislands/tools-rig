# Manage user-level skills

Use Rig to describe agent skills that belong in your personal setup, explain why they are present, and compare the declaration with their native authority. Rig records intent and provenance; it does not copy, inspect, or evaluate skill instructions.

## Choose the native authority

Every `[skill.ID]` names one authority matching the real ownership boundary:

- **`skills-cli`** means a deliberately installed `skills` executable owns a remote global skill. Rig invokes that executable directly and never falls back to unqualified `npx`.
- **`ki`** means Knowledge Islands owns the projection. Rig reports observation unavailable until KI exposes a stable machine-readable inventory.
- **`local`** means a reviewed local source is projected into declared runtime roots through leaf symlinks.
- **`runtime` or `plugin`** means a runtime or plugin manager owns the skill. Rig observes the declared projection but does not materialise or update it.

Repository-local skills remain repository concerns. Runtime-bundled and plugin-provided skills should use their existing owners rather than being copied into a global store.

## Declare a remote global skill

```toml
[skill.caveman]
name = "Caveman"
purpose = "Provide compact communication mode"
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

`source-skill` is optional when the native skill name matches the Rig ID. `public-source` is an optional reviewed HTTP or HTTPS URL for publication; it is not a materialisation source.

The Skills CLI may itself be a normal tool in the catalogue when bootstrap needs to make it present first. Use `requires = ["skills-cli"]` on the skill when that ordering should be explicit.

## Declare a bounded local projection

Use `local` only for source you control and have reviewed:

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

Before creating a projection, Rig canonicalises the source and runtime root, confirms the source is a real non-symlink directory, verifies the target remains inside the runtime root, and revalidates immediately before creating one missing leaf symlink. An existing file, directory, or symlink collision remains untouched.

## Inspect and materialise skills

Declaration and observation commands remain read-only:

```sh
rig show
rig explain skill:caveman
rig status --unmanaged
rig doctor
```

For `skills-cli`, `status --unmanaged` asks the installed executable for global skills not represented by a declaration. An absent executable, unsupported version, failed command, or malformed machine output makes inventory unavailable rather than guessed.

Preview before materialising:

```sh
rig apply --scope skills --dry-run
rig apply --scope skills
```

Full application orders tools → skills → resources. `rig update --dry-run` previews explicit Skills CLI updates, and `rig update` advances selected `skills-cli` skills. Maintenance, cleanup, and profile selection never remove a skill.

## Publish only deliberate metadata

A publication view must select a skill explicitly. Public output emits only its identity, explanatory metadata, and optional reviewed public source. It never emits authority details, install source, runtime mappings, local paths, locks, arguments, observed state, or unmanaged inventory.

Inspect `rig export` output before handing it to a publisher. Being installed or selected by a complete profile never makes a skill public.
