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
- `rig doctor [--profile NAME]`
- `rig apply [--profile NAME] [--dry-run]`
- `rig run TOOL OPERATION [-- ARGUMENT...]`
- `rig export PUBLICATION --output DIRECTORY`
- `rig publish PUBLICATION`
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
- Built-in Homebrew formula, cask, and Mac App Store, uv tool, and chezmoi target adapters with exact capability gates and native command mappings.
- HTTPS direct-download executable adapter with declared SHA-256 verification, sibling temporary files, safe destination checks, atomic replacement, and failure cleanup.
- Five-state observation with deterministic provider, state, and detail reporting without a competing state database.
- A concise read-only doctor synthesis for configuration, XDG accessibility, provider availability, selected-tool health, and informational catalogue-only or incompatible tools.
- Complete application preflight, a non-mutating dry-run, and dependency-first execution.
- Configuration-defined observe and mutate operations with custom-provider capability checks, literal argument allow-lists, and native outcome propagation.
- Failure handling that suppresses only transitive dependants while independent work continues.
- Deterministic offline static export of an explicitly selected public profile with HTML escaping, relationship closure, portable base URLs, disclosure allow-listing, and safe complete-tree replacement.
- Explicit trusted publication dispatch through one selected custom provider, with isolated cache staging, fixed literal handoff, native outcome propagation, phase-aware interruption handling, exact-file fail-closed cleanup, and retained complete failure artifacts.

### Distribution baseline

- `install.sh` supports released and linked development copies.
- `rig(1)` documents commands, configuration, installation, and shell completion.
- Bash and Zsh completion definitions cover the shipped command and option surface.
