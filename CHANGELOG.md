# Changelog

This is the consolidated Pre-1.0 baseline for Rig's current command surface and notable capabilities and changes. It is updated as the tool evolves rather than divided into 0.x release entries. Tags, GitHub releases, and commit history retain the exact public-preview snapshots.

## Pre-1.0 baseline

### Command surface

- `rig init`
- `rig show`
- `rig status`
- `rig capture`
- `rig apply`
- `rig upgrade`
- `rig doctor`
- `rig export`
- `rig completion`
- `rig help`, `rig --help`, and `rig --version`

Run `rig COMMAND --help` for options and exact arguments.

### Capabilities

- A readable catalogue declares tools, user-level agent skills, managed services and scheduled jobs, typed machine settings, Dock layout, private ports, relationships, providers, and profiles. Profiles select a machine or role setup; provider observations produce expected-versus-observed state.
- `show`, `status`, and `doctor` explain intent, observed state, and capability or health findings without changing the machine. `status --unmanaged` and `status --retired` add informational observations; `capture` proposes additive declarations for review.
- `init` writes unversioned configuration. Recognised legacy `schema = 1` input remains readable; `init --repair-schema` previews a repaired source or writes a reviewable proposal outside active configuration without rewriting it.
- `apply` supports exact target selection, complete preflight, dependency order, non-mutating dry runs, and independent outcomes. Reconciliation preserves receipts for declared resources outside the selected profile and retires a resource only when no catalogue declaration still owns it.
- `upgrade` delegates execution to the appropriate native provider. Homebrew, uv, chezmoi, direct downloads, and declared custom providers retain their own resolution, credentials, and installation state. Rig owns selection and reporting, not a competing package database.
- `export` generates a deterministic, platform-neutral `rig-publication` version 1 JSON view of an explicitly selected public profile. Private paths, credentials, runtime mappings, state, and private ports are excluded.
- Terminal progress keeps diagnostics visible, redacts private values, and leaves machine-readable standard output stable. Multi-item native phases use adjacent line events rather than reopening a footer between items. The Bash and Zsh completion definitions follow the current commands and options.

### Changed and removed

- The current command surface replaces `bootstrap`, `maintain`, `run`, `publish`, and `clean` without compatibility aliases. Imperative provider operations and housekeeping remain native; Rig exports data, while a receiving system owns publication and transport.
- Homebrew Bundle, Brewfile orchestration, and Homebrew autoupdate management are retired. Rig configuration declares desired packages; retired configuration fields fail with migration guidance. No migration deletes an existing Brewfile, package, timer, or state file.
- Managed-resource retirement follows catalogue ownership rather than the last applied profile, avoiding unloads of still-declared services and scheduled jobs. Launchd replacement waits for a departing service before bootstrapping its successor; failures withhold retirement and receipt replacement.
- Provider and observation fixes preserve stable identities, distinguish unavailable evidence from proven conflicts, handle dual-stack listeners without duplicate rows, and keep native diagnostics intact through terminal progress.

### Distribution baseline

- One deterministic, dependency-free Bash 3.2 executable is assembled from domain modules; XDG-aware `install.sh` supports exact release selection and a linked development checkout.
- The physical `rig(1)` manual, Bash and Zsh completions, isolated Bats suite, ShellCheck, and macOS/Linux CI accompany the command surface.
