# Changelog

All notable changes to `rig` are documented here. Dated `0.x` entries record immutable public previews; the development checkout accumulates only under `Unreleased` until another preview is explicitly selected.

## [Unreleased]

### Changed

- `rig status` now renders every expected, observed, and unmanaged section as an aligned human-readable table bounded to 120 characters, with deterministic visible ellipsis and useful path-tail context.

### Added

- A declared tool artifact may now be a symbolic link. Rig resolves it and observes the target, so a command line an application installs into a shared executable directory is declarable state: healthy links are `present`, a dangling link is `missing` and names the target it resolved to, a link into a damaged application bundle is `drifted`, and a link that cannot be resolved is `unavailable` with a detail saying so rather than calling the artifact unsafe.

### Fixed

- A declared private port now identifies the process actually bound to it by reading the listener's whole command line, so a service or tool started through an interpreter no longer reports `conflicting` against its own declaration. `conflicting` now asserts that a readable command line identifies a different process and names it; a listener Rig cannot inspect reports `unknown` with `owner-unavailable` instead.
- The interactive progress bar now erases the whole line it previously drew and keeps each redraw within the terminal's width, so a long item name no longer leaves fragments of an earlier line stranded to the right of a shorter one.

## [0.3.0] — 2026-09-22

Third public preview of Rig, establishing the declarative lifecycle baseline for tools, skills, managed resources, ports, native providers, and private-safe publication.

This release includes the following commands, behaviours, distribution baseline, and documentation.

### Shipped commands

- `rig`
- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID`
- `rig status [--profile NAME] [--unmanaged]`
- `rig doctor [--profile NAME]`
- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]`
- `rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]`
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

- Honest `0.2.0+dev` runtime identity for post-v0.2.0 development, with final `vX.Y.Z` release tags rejected unless they match an exact final executable version.
- First-class user-level skill declarations with human meaning, reviewed provenance, native authority, intended runtimes, item-owned profile membership, read-only queries, expected-versus-observed state, doctor findings, and informational unmanaged Skills CLI inventory.
- Bounded skill lifecycle through a deliberately installed Skills CLI, non-invoked KI authority, canonical local leaf-symlink projection, observation-only runtime/plugin ownership, tools → skills → resources application order, explicit update, and no lifecycle removal on deselection, maintain, or clean.
- Deterministic `rig-publication` version 2 JSON with explicit skill view membership, an always-present `profile.skills` array, narrow public metadata allow-list, and exclusion of authorities, native sources, runtime mappings, paths, roots, locks, arguments, state, unmanaged inventory, and private ports.
- Typed string settings and Dock paths resolve bounded whole-value home forms consistently across observation, preflight, and application while preserving inert authored configuration and literal query output.
- Resource-local preflight findings produce failed rows without blocking independent work; shared safety failures remain fail-before-mutation, and any selected resource failure withholds retirement and receipt replacement.
- Tool-owned generated artifacts remain observation-only under the lifecycle of their native tool.
- macOS application artifact health requires a readable `Info.plist` and a working executable beneath `Contents/MacOS`, exposing broken URL-handler bundles as drift.
- A standalone Bash 3.2-compatible executable with no required runtime dependency beyond Bash.
- Non-mutating runtime, platform, XDG-path, and configuration diagnostics with explicit Rig overrides.
- An inert TOML schema 1 loader with deterministic fragment order, validation, composed-profile resolution, transitive requirements, platform selection, and tool-centred `install.*` metadata.
- Item-owned profile membership for tools and every selectable resource, with omission mapped to the configured default profile, explicit empty exclusion, named inheritance, and mixed-model rejection.
- Complete appliable profiles and non-appliable views, including explicit public dependency closure and mutation rejection for views.
- Resolved-selection native conflict checks for provider locators, macOS defaults targets, and semantic Dock layouts, allowing mutually exclusive catalogue alternatives.
- Per-platform exclusive reconciliation locks held from receipt read through atomic replacement, with active, stale, and unknown owner diagnostics that fail before mutation.
- Declaration, manifest, and provider-wide operation-scope disclosure before apply, bootstrap, update, maintain, and capture work.
- Declarative built-in provider identities whose adapters and supported operations are inferred by Rig without `[provider.*]` boilerplate; provider tables are reserved for optional built-in configuration and explicitly trusted external executables.
- A native bootstrap lifecycle that fully preflights configuration and external boundaries, stages only the fixed declared Homebrew → mise → npm manager chain, applies bounded Homebrew autoupdate policy, and then reconciles the selected profile without synthetic setup tools or a bootstrap provider.
- Explicit update and maintenance lifecycles for selected Homebrew, uv, mise, and npm tools, with fixed built-in operations, complete supported-target preflight, non-mutating previews, deduplicated provider work, and deterministic outcomes.
- Explicit Homebrew manifest capture through a declared safe provider-native path, without configuration-defined commands or lifecycle capability grants.
- First-class typed macOS settings and semantic Dock layouts, built-in launchd reconciliation, and built-in application-bundle inventory selected as parts of a workstation profile rather than hidden behind a workstation provider.
- First-class `service` and `scheduled-job` declarations selected by profiles, with literal program and environment arrays, service policies, calendar or interval schedules, desired state, and tool dependencies.
- Private TCP port declarations with qualified owners, required, on-demand, and allocated modes, read-only macOS listener observation, unmanaged-listener reporting, and absolute exclusion from public exports.
- Source configuration rejects the superseded `[binding.*]` table shape; one tool table is the sole public home for installation metadata.
- Standard TOML-compatible `rig.toml` and `conf.d/*.toml` sources, with a dependency-free schema subset, quoted strings, string arrays, inline comments, and model-wide fail-closed validation.
- Bounded multiline basic-string arrays with comments and trailing commas, while split strings, unsupported values, and unterminated arrays still fail closed.
- One logical tool may declare deterministic `variant.ID.*` platform installations and artifacts; exactly one variant matches each declared platform and public exports omit private variant data.
- Managed resources support qualified `depends-on` graphs with missing-reference and cycle validation, deterministic topological order, and transitive failure blocking.
- `rig diag` summarises profile-selection mode and model counts for profiles, tools, managed resources, and platform variants.
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
- Truthful terminal-aware stderr progress with an in-place ASCII bar for interactive phases, durable redirected or explicitly selected line events, completed-not-started counts, succeeded/skipped/failed outcomes, interruption termination, pre-mutation scope, private-value redaction, stable stdout, quiet declaration queries, and explicit `RIG_PROGRESS=always|lines|never` control.
- Indexed configuration declarations and fast-path TOML parsing keep the representative 1,434-line catalogue near a two-second macOS query target, guarded by a portable deterministic benchmark.
- Equivalent built-in native observation commands share one command-local in-memory snapshot while preserving per-tool identity, dependency, artifact, and progress evaluation.
- Domain-focused authored Bash modules assemble deterministically into the single dependency-free `bin/rig` installation payload, with byte-drift, Bash 3.2, ShellCheck, and bounded native-smoke gates.
- Deterministic offline `rig-publication` version 2 JSON export of an explicitly selected, platform-neutral public profile with relationship closure, skill metadata allow-listing, canonical URL metadata, disclosure allow-listing, and safe complete-tree replacement.
- Explicit trusted publication dispatch through one selected custom provider, with isolated one-file cache staging, fixed literal handoff, native outcome propagation, phase-aware interruption handling, exact-file fail-closed cleanup, and retained complete failure artifacts.
- Explicit `rig clean` maintenance safely classifies Rig-owned retained publication exports, supports non-mutating preview, preserves them until requested, atomically claims deletion work, resumes interrupted claims, and skips unsafe legacy entries.

### Distribution baseline

- `install.sh` supports released and linked development copies, exact positional `vX.Y.Z` selection, exact-version `RIG_VERSION` compatibility, and fail-before-network validation.
- `rig(1)` documents commands, configuration, installation, and shell completion.
- Bash and Zsh completion definitions cover the shipped command and option surface, including command-local help.
- A repository definition-of-done checklist and Bats alignment test keep help, README, user guides, manual, completions, changelog, and distribution guidance synchronised.

### Documentation

- Release guidance distinguishes the latest immutable v0.2.0 install from a linked development checkout and defines the local candidate checks required before an exact preview is selected.
- Living decisions retain durable rationale, Specifications own detailed accepted behaviour, and the manual separates configuration schema from filesystem locations.
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

First public preview of the catalogue-first Rig baseline. Ongoing development is recorded under `Unreleased`.

### Added

- Declarative categories, tool metadata, rationale, relationships, profiles, providers, publications, and expected-versus-observed state.
- Catalogue queries, operational status and doctor checks, provider-backed apply and bootstrap, bounded declared provider actions, static export, and trusted publisher handoff.
- Bash and Zsh completion, the `rig(1)` manual, XDG-aware installation, local development linking, and macOS Bash 3.2 plus Ubuntu CI coverage.
- Built-in Homebrew, uv, chezmoi, and integrity-checked direct-download adapters alongside the versioned custom-provider protocol.

### Distribution

- `RIG_VERSION=0.1.0` is the single executable version source for the annotated `v0.1.0` preview tag.
- The installer stages and validates both the executable and manual before replacing either destination.
