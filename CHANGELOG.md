# Changelog

All notable changes to `rig` are documented here. This changelog records the evolving v1 release baseline; tags and commit history remain the record of the pre-v1 run-up.

## [1.0.0] — in progress

Rig 1.0.0 is not yet released. Pre-v1 work remains summarised as an evolving baseline; dated 0.x entries record public preview snapshots.

### Shipped commands

- `rig`
- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL`
- `rig status [--profile NAME] [--unmanaged]`
- `rig doctor [--profile NAME]`
- `rig apply [--profile NAME] [--dry-run]`
- `rig bootstrap [--profile NAME] [--dry-run]`
- `rig run TOOL OPERATION [-- ARGUMENT...]`
- `rig export PUBLICATION --output DIRECTORY`
- `rig publish PUBLICATION`
- `rig diag`
- `rig completion bash|zsh`
- `rig help [-h|--help]`, `rig --help`, and `rig --version`

### Behaviours

- A standalone Bash 3.2-compatible executable with no required runtime dependency beyond Bash.
- Non-mutating runtime, platform, XDG-path, and configuration diagnostics with explicit Rig overrides.
- An inert schema 1 loader with deterministic fragment order, validation, composed-profile resolution, transitive requirements, platform selection, and provider-binding resolution.
- Direct fragment-only configuration when `rig.conf` is absent, retaining root-first bytewise ordering and model-wide fail-closed validation.
- Read-only catalogue queries that do not invoke providers.
- Human-readable `rig show` profile metadata and bounded-width, aligned selected-tool tables.
- Versioned `rig-provider-v1` custom-provider invocation that preserves every configured literal argument boundary.
- Conventional custom-provider executables at `${RIG_DATA_HOME}/providers/ID`, with explicit `executable` declarations retaining precedence.
- Built-in Homebrew formula, cask, and Mac App Store, uv tool, and chezmoi target adapters with exact capability gates and native command mappings.
- Bounded reconciliation identities for tap-qualified Homebrew formula and cask locators and leading `~/` or `$HOME/` tool artifacts, while provider application retains the authored locator.
- HTTPS direct-download executable adapter with declared SHA-256 verification, sibling temporary files, safe destination checks, atomic replacement, and failure cleanup.
- Five-state observation with deterministic provider, state, and detail reporting without a competing state database.
- A repeatable tool `artifact` field naming a machine-observable path a tool materialises, so one provider can inventory what another installed and catalogue-only tools remain reconcilable.
- Reverse reconciliation through the `rig-provider-v1 inventory` protocol: providers declaring the `inventory` capability enumerate their domain, and `rig status --unmanaged` reports every observed identity that no binding declares as an informational row.
- A concise read-only doctor synthesis for configuration, XDG accessibility, provider availability, selected-tool health, and informational catalogue-only or incompatible tools.
- Complete application preflight, a non-mutating dry-run, and dependency-first execution.
- Bootstrap-profile selection with explicit-profile precedence and default-profile fallback, delegated to the exact application plan and safety boundaries.
- Configuration-defined observe and mutate operations with custom-provider capability checks, literal argument allow-lists, and native outcome propagation.
- Failure handling that suppresses only transitive dependants while independent work continues.
- Deterministic offline `rig-publication` version 1 JSON export of an explicitly selected, platform-neutral public profile with relationship closure, canonical URL metadata, disclosure allow-listing, and safe complete-tree replacement.
- Explicit trusted publication dispatch through one selected custom provider, with isolated one-file cache staging, fixed literal handoff, native outcome propagation, phase-aware interruption handling, exact-file fail-closed cleanup, and retained complete failure artifacts.

### Distribution baseline

- `install.sh` supports released and linked development copies, exact positional `vX.Y.Z` selection, exact-version `RIG_VERSION` compatibility, and fail-before-network validation.
- `rig(1)` documents commands, configuration, installation, and shell completion.
- Bash and Zsh completion definitions cover the shipped command and option surface, including command-local help.
- A repository definition-of-done checklist and Bats alignment test keep help, README, user guides, manual, completions, changelog, and distribution guidance synchronised.

## [0.2.0] — 2026-09-18

Second public preview of the catalogue-led Rig baseline.

### Added

- `rig status --unmanaged` reverse reconciliation through the custom-provider `inventory` capability, with informational undeclared identities scoped to each provider.
- Machine-observable tool `artifact` declarations, allowing catalogue-only tools to be reconciled independently of their materialising provider.
- Direct fragment-only configuration and conventional custom-provider executables beneath `${RIG_DATA_HOME}/providers/ID`.
- Exact positional release selection through `install.sh vX.Y.Z`, while retaining `RIG_VERSION=vX.Y.Z` for automation.
- Deterministic `rig-publication` version 1 JSON export for platform-neutral public profiles and trusted one-file publisher handoff.

### Changed

- Normalised provider observations to preserve stable identities separately from version and diagnostic detail.
- Aligned help, completions, README, user guide, manual, changelog, Decision Records, and Specifications with the complete CLI and publication contract.

### Migration

- `rig export` and `rig publish` now produce exactly one `rig.json` artifact instead of `index.html` and `assets/rig.css`. Receiving websites own presentation and must consume the documented version-1 schema.

## [0.1.0] — 2026-09-17

First public preview of the catalogue-first Rig baseline. The `1.0.0 — in progress` section remains the authority for ongoing v1 development.

### Added

- Declarative categories, tool metadata, rationale, relationships, profiles, providers, publications, and expected-versus-observed state.
- Catalogue queries, operational status and doctor checks, provider-backed apply and bootstrap, bounded declared operations, static export, and trusted publisher handoff.
- Bash and Zsh completion, the `rig(1)` manual, XDG-aware installation, local development linking, and macOS Bash 3.2 plus Ubuntu CI coverage.
- Built-in Homebrew, uv, chezmoi, and integrity-checked direct-download adapters alongside the versioned custom-provider protocol.

### Distribution

- `RIG_VERSION=0.1.0` is the single executable version source for the annotated `v0.1.0` preview tag.
- The installer stages and validates both the executable and manual before replacing either destination.
