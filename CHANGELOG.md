# Changelog

All notable changes to `rig` are documented here. This changelog records the evolving v1 release baseline; tags and commit history remain the record of the pre-v1 run-up.

## [1.0.0] — in progress

Rig 1.0.0 is not yet released. Pre-v1 work is summarised as this evolving baseline; separate 0.x release entries are not maintained.

### Shipped commands

- `rig`
- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL`
- `rig status [--profile NAME]`
- `rig apply [--profile NAME] [--dry-run]`
- `rig diag`
- `rig completion bash|zsh`
- `rig help`, `rig --help`, and `rig --version`

### Behaviours

- A standalone Bash 3.2-compatible executable with no required runtime dependency beyond Bash.
- Non-mutating runtime, platform, XDG-path, and configuration diagnostics with explicit Rig overrides.
- An inert schema 1 loader with deterministic fragment order, validation, composed-profile resolution, transitive requirements, platform selection, and provider-binding resolution.
- Read-only catalogue queries that do not invoke providers.
- Human-readable `rig show` profile metadata and bounded-width, aligned selected-tool tables.
- Versioned `rig-provider-v1` custom-provider invocation that preserves every configured literal argument boundary.
- Five-state observation with deterministic provider, state, and detail reporting without a competing state database.
- Complete application preflight, a non-mutating dry-run, and dependency-first execution.
- Failure handling that suppresses only transitive dependants while independent work continues.

### Distribution baseline

- `install.sh` supports released and linked development copies.
- `rig(1)` documents commands, configuration, installation, and shell completion.
- Bash and Zsh completion definitions cover the shipped command and option surface.
