# Changelog

All notable changes to `rig` are documented here. This changelog records the evolving v1 release baseline; tags and commit history remain the record of the pre-v1 run-up.

## [1.0.0] — in progress

Rig 1.0.0 is not yet released. The current 0.1.0 capabilities and accepted work still needed for v1 are recorded separately below.

### Available in 0.1.0

#### Commands

- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL`
- `rig diag`
- `rig completion bash|zsh`
- `rig help`, `rig --help`, and `rig --version`

#### Foundation

- A standalone Bash 3.2-compatible executable with no required runtime dependency beyond Bash.
- Non-mutating runtime, platform, XDG-path, and configuration diagnostics with explicit Rig overrides.
- An inert schema 1 loader with deterministic fragment order, validation, composed-profile resolution, transitive requirements, platform selection, and provider-binding resolution.
- Read-only catalogue queries that do not invoke providers.
- An installer for released or linked development copies of the executable and `rig(1)` manual.

### Accepted for 1.0.0

- Provider observation and expected-versus-observed `status` reporting.
- Explicit `apply`, provider adapters, and top-level `doctor` diagnostics.
- Bootstrap migration and configuration-led machine-audit and service operations through declared `rig run` operations.
- Public export and publication suitable for a personal site such as `rig.midnight.ninja`.
- A formula in the Knowledge Islands Homebrew tap.
