# Changelog

All notable changes to `rig` are documented here. This changelog records the evolving v1 release baseline; tags and commit history remain the record of the pre-v1 run-up.

## [1.0.0] — in progress

Rig 1.0.0 is not yet released. Pre-v1 work remains summarised as an evolving baseline; dated 0.x entries record public preview snapshots.

### Shipped commands

- `rig`
- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL|service:ID|scheduled-job:ID|setting:ID|dock:ID`
- `rig status [--profile NAME] [--unmanaged]`
- `rig doctor [--profile NAME]`
- `rig apply [--profile NAME] [--scope tools|resources|all] [--dry-run]`
- `rig bootstrap [--profile NAME] [--scope tools|resources|all] [--dry-run]`
- `rig update [--profile NAME] [--dry-run]`
- `rig maintain [--profile NAME] [--dry-run]`
- `rig capture PROVIDER [--dry-run]`
- `rig run PROVIDER ACTION [-- ARGUMENT...]`
- `rig export PUBLICATION --output DIRECTORY`
- `rig publish PUBLICATION`
- `rig clean [--dry-run]`
- `rig diag`
- `rig completion bash|zsh`
- `rig help [-h|--help]`, `rig --help`, and `rig --version`

### Behaviours

- Tool-owned generated artifacts with a closed `artifact.reconciler` contract; Codex Multi Auth application bundles refresh after successful apply, bootstrap, or update work, while ordinary artifacts remain observation-only.
- macOS application artifact health requires a readable `Info.plist` and a working executable beneath `Contents/MacOS`, exposing broken URL-handler bundles as drift.
- A standalone Bash 3.2-compatible executable with no required runtime dependency beyond Bash.
- Non-mutating runtime, platform, XDG-path, and configuration diagnostics with explicit Rig overrides.
- An inert TOML schema 1 loader with deterministic fragment order, validation, composed-profile resolution, transitive requirements, platform selection, and tool-centred `install.*` metadata.
- Declarative built-in provider identities whose adapters and supported operations are inferred by Rig without `[provider.*]` boilerplate; provider tables are reserved for optional built-in configuration and explicitly trusted external executables.
- A native bootstrap lifecycle that fully preflights configuration and external boundaries, stages only the fixed declared Homebrew → mise → npm manager chain, applies bounded Homebrew autoupdate policy, and then reconciles the selected profile without synthetic setup tools or a bootstrap provider.
- Explicit update and maintenance lifecycles for selected Homebrew, uv, mise, and npm tools, with fixed built-in operations, complete supported-target preflight, non-mutating previews, deduplicated provider work, and deterministic outcomes.
- Explicit Homebrew manifest capture through a declared safe provider-native path, without configuration-defined commands or lifecycle capability grants.
- First-class typed macOS settings and semantic Dock layouts, built-in launchd reconciliation, and built-in application-bundle inventory selected as parts of a workstation profile rather than hidden behind a workstation provider.
- First-class `service` and `scheduled-job` declarations selected by profiles, with literal program and environment arrays, service policies, calendar or interval schedules, desired state, and tool dependencies.
- Source configuration rejects the superseded `[binding.*]` table shape; one tool table is the sole public home for installation metadata.
- Standard TOML-compatible `rig.toml` and `conf.d/*.toml` sources, with a dependency-free schema subset, quoted strings, string arrays, inline comments, and model-wide fail-closed validation.
- Read-only catalogue queries that do not invoke providers.
- Human-readable `rig show` profile metadata and bounded-width, aligned selected-tool tables.
- Compact top-level help aligns command names and descriptions while directing detailed syntax to each command's `--help`.
- Versioned `rig-provider-v1` invocation with literal argument boundaries only for explicitly trusted external providers; Rig inserts the marker automatically and built-ins never receive it.
- Versioned external `observe-resource`, `apply-resource`, and `retire-resource` work units plus resource-aware action binding, while built-in resources use Rig's internal provider registry.
- Explicit `adapter = "custom"` extension declarations and operation allow-lists, with executable resolution limited to an explicit path or exact `${RIG_DATA_HOME}/providers/ID` convention.
- Built-in Homebrew formula, cask, and Mac App Store; uv tool; mise tool; npm global; chezmoi target; launchd; macOS defaults; semantic Dock; and application-inventory adapters with native command mappings and internally defined operations.
- Bounded reconciliation identities for tap-qualified Homebrew formula and cask locators and leading `~/` or `$HOME/` tool artifacts, while provider application retains the authored locator.
- HTTPS direct-download executable adapter with declared SHA-256 verification, sibling temporary files, safe destination checks, atomic replacement, and failure cleanup.
- Five-state observation with deterministic provider, state, and detail reporting without a competing state database.
- A tool `artifacts` array naming machine-observable paths a tool materialises, so one provider can inventory what another installed and catalogue-only tools remain reconcilable.
- Reverse reconciliation through built-in inventory sources or the external `rig-provider-v1 inventory` protocol; `rig status --unmanaged` reports every observed identity that no tool installation declares as an informational row.
- A concise read-only doctor synthesis for configuration, XDG accessibility, provider availability, selected-tool health, and informational catalogue-only or incompatible tools.
- Complete application preflight, a non-mutating dry-run, and dependency-first execution.
- Built-in and external managed-resource observation and reconciliation across `status`, doctor, apply, and bootstrap, with stale-resource retirement and an atomic per-platform receipt beneath Rig state where retirement requires one.
- Bootstrap-profile selection with explicit-profile precedence and default-profile fallback through Rig's native staged bootstrap plan and safety boundaries.
- Built-in provider operations plus configuration-defined external observe and mutate actions with literal `arguments`, exact `allowed-arguments`, optional provider-owned validation, and native outcome propagation.
- Failure handling that suppresses only transitive dependants while independent work continues.
- Terminal-aware, line-oriented stderr progress for configuration loading, provider observation, inventory, application, actions, and publication, with stable stdout and explicit `RIG_PROGRESS=always|never` control.
- Deterministic offline `rig-publication` version 1 JSON export of an explicitly selected, platform-neutral public profile with relationship closure, canonical URL metadata, disclosure allow-listing, and safe complete-tree replacement.
- Explicit trusted publication dispatch through one selected custom provider, with isolated one-file cache staging, fixed literal handoff, native outcome propagation, phase-aware interruption handling, exact-file fail-closed cleanup, and retained complete failure artifacts.
- Explicit `rig clean` maintenance safely classifies Rig-owned retained publication exports, supports non-mutating preview, preserves them until requested, atomically claims deletion work, resumes interrupted claims, and skips unsafe legacy entries.

### Distribution baseline

- `install.sh` supports released and linked development copies, exact positional `vX.Y.Z` selection, exact-version `RIG_VERSION` compatibility, and fail-before-network validation.
- `rig(1)` documents commands, configuration, installation, and shell completion.
- Bash and Zsh completion definitions cover the shipped command and option surface, including command-local help.
- A repository definition-of-done checklist and Bats alignment test keep help, README, user guides, manual, completions, changelog, and distribution guidance synchronised.

### Documentation

- The README and focused user guides now explain Rig's purpose, model, everyday lifecycle, and publication boundary before implementation details.
- The consumer command guide covers every shipped command and participates in the tested public-surface alignment contract.
- The definition of done and release guide now require explicit public-surface alignment and a pre-release documentation check.

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
- Catalogue queries, operational status and doctor checks, provider-backed apply and bootstrap, bounded declared provider actions, static export, and trusted publisher handoff.
- Bash and Zsh completion, the `rig(1)` manual, XDG-aware installation, local development linking, and macOS Bash 3.2 plus Ubuntu CI coverage.
- Built-in Homebrew, uv, chezmoi, and integrity-checked direct-download adapters alongside the versioned custom-provider protocol.

### Distribution

- `RIG_VERSION=0.1.0` is the single executable version source for the annotated `v0.1.0` preview tag.
- The installer stages and validates both the executable and manual before replacing either destination.
