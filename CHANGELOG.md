# Changelog

All notable changes to `rig` are documented here. This changelog records the evolving v1 release baseline; tags and commit history remain the record of the pre-v1 run-up.

## [1.0.0] — in progress

Rig 1.0.0 is not yet released. The current 0.1.0 scaffold and the accepted work still needed for v1 are recorded separately below.

### Available in 0.1.0

#### Commands

- `rig`
- `rig --help`
- `rig --version`
- `rig help`
- `rig paths`
- `rig completion bash`
- `rig completion zsh`

#### Foundation

- A standalone Bash 3.2-compatible executable with no required runtime dependency beyond Bash.
- XDG-aligned config, data, state, and cache path discovery with explicit Rig overrides.
- An installer for released or linked development copies of the executable and `rig(1)` manual.

### Accepted for 1.0.0

- A catalogue-first configuration model for tool categories, metadata, rationale, relationships, supported platforms, profiles, providers, publications, and expected-versus-observed state.
- Profile resolution and manager-of-managers orchestration that leave native manifests, resolution, credentials, and provider state with their owning systems.
- Catalogue queries, doctor diagnostics, bootstrap, status, apply, public export and publication, and a Homebrew formula remain in progress; none are part of the current 0.1.0 command surface.
