# Runtime portability — RIG-PORT

This area of the [Rig Specifications](index.md) defines the installed runtime and persistent-path contract. It follows [ADR-RIG-001](../decisions/ADR-RIG-001-shell-only-runtime.md) and [ADR-RIG-002](../decisions/ADR-RIG-002-xdg-directory-contract.md).

## Runtime

### RIG-PORT-001 — Shell-only core

The installed Rig executable MUST require only Bash 3.2 or later for its command parsing, configuration loading, catalogue and profile resolution, built-in provider adapters, extension dispatch, state comparison, and public-data export. Built-in launchd and macOS workstation behaviour MUST NOT introduce a Bun, Node.js, Python, or other runtime dependency.

_Conformance:_ conforming

_Verify:_ ShellCheck validates the Bash executable and Bats runs core, launchd, settings, Dock, and inventory commands without another language runtime on `PATH`.

_Evidence:_ `bin/rig` implements parsing, resolution, built-in adapters, state, and export in Bash; ShellCheck plus `built-in launchd observes applies and retires declared resources` and the four `tests/rig-macos.bats` tests exercise those native surfaces without another language runtime.

### RIG-PORT-002 — XDG application directories

Rig MUST place configuration, data, state, and cache beneath the corresponding XDG Base Directory roots unless a complete Rig application-directory override is set.

_Conformance:_ conforming

_Verify:_ `bats tests/rig.bats` invokes `rig diag` with isolated XDG and Rig-specific environment values.

_Evidence:_ `tests/rig.bats` covers XDG-derived paths and the precedence of `RIG_CONFIG_HOME`, `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME`.

### RIG-PORT-003 — Conventional executable location

The release installer MUST default to `~/.local/bin` and MUST allow `RIG_INSTALL_DIR` to replace that destination.

_Conformance:_ conforming

_Verify:_ Bats installer tests link into isolated default and overridden destinations.

_Evidence:_ `install.sh` implements the destination contract and `tests/rig.bats` verifies overridden executable and manual destinations.

### RIG-PORT-004 — Local diagnostics

`rig diag` MUST report the Rig version, invoked executable, Bash version, active platform, effective configuration, data, state, and cache directories, root configuration file, fragment count, and configuration status. When configuration is valid it MUST also report the schema, default profile, profile-selection mode, and counts for profiles, tools, managed resources, and tool variants.

Diagnostics MUST NOT invoke a provider. The command MUST return status 0 for valid configuration, status 1 for missing or invalid configuration, and status 2 for invalid command syntax.

_Conformance:_ conforming

_Verify:_ Bats tests compare stable diagnostics for default and overridden paths, linked invocation, valid, missing, and invalid configuration; assert provider non-execution; and cover command help and exit statuses.

_Evidence:_ `tests/rig.bats` covers the exact labelled output, path precedence, invoked symlink paths, fragment counting, validity states, provider non-execution, local help, and removal of `paths`.

### RIG-PORT-005 — Doctor XDG accessibility

`rig doctor` MUST inspect the effective configuration, data, state, and cache application paths without creating or changing them. An existing non-directory or inaccessible path, or an absent path without an accessible writable ancestor, MUST be a configuration-owned health finding.

_Conformance:_ conforming

_Verify:_ Bats supplies a regular file as an effective Rig data directory and asserts a deterministic status-1 XDG finding while provider mutation remains absent.

_Evidence:_ `rig_doctor_path_finding` performs read-only path checks and the doctor XDG Bats case covers the non-directory boundary.

### RIG-PORT-006 — Exact release selection

The release installer MUST accept an optional positional version in exact `vX.Y.Z` form. The positional version MUST take precedence over the `RIG_VERSION` compatibility environment variable, which MUST accept the same exact form. With neither input, the installer MUST discover the latest GitHub release and MUST NOT fall back to a mutable branch. Invalid positional or environment versions MUST return status 2 before network access or destination mutation. A discovered tag that is absent or not an exact version MUST fail before artifact download. A valid release installation MUST continue to stage and validate both executable and manual before replacing either destination.

_Conformance:_ conforming

_Verify:_ Bats installer fixtures cover positional precedence, environment compatibility, latest-release discovery, invalid-input non-execution, immutable artifact URLs, and staged validation.

_Evidence:_ `install.sh` implements the exact-version contract and `tests/rig.bats` exercises isolated network fixtures and destinations.

### RIG-PORT-007 — Public interface alignment

*** End of File

The shipped command inventory and each command synopsis MUST agree across top-level and command-local help, README, consumer command guide, `rig(1)`, Bash and Zsh completion output, and the current changelog baseline. User and developer guides, Specifications, and Decision Records MUST describe affected configuration, lifecycle, built-in-provider, extension, and trust-boundary behaviour consistently. The release procedure MUST include an explicit pre-release alignment check.

_Conformance:_ conforming

_Verify:_ Bats checks the shipped command inventory across README, consumer command guide, changelog, manual, and generated completions; compares human-facing synopsis; and exercises command-local help plus targeted manual structure. Repository guide, specification, and decision audits verify documentation structure.

_Evidence:_ `help describes the current command surface`, `public command inventory stays aligned across documentation`, `completion help provide command-local help`, and `completion definitions evaluate and expose accepted options` in `tests/rig.bats` enforce the shipped interface alignment.

### RIG-PORT-008 — Optional skill-authority executables

Rig core MUST remain Bash 3.2-compatible and dependency-free. Skill-authority executables MUST be optional native integrations discovered only for observation or explicit mutation; their absence MUST produce a bounded unavailable result rather than prevent declaration queries. Tests MUST isolate fake homes and executables and MUST NOT read or modify real user skill roots.

_Conformance:_ conforming

_Verify:_ ShellCheck and Bash syntax gates cover the runtime; isolated Bats tests exercise absent executables and temporary runtime roots.

_Evidence:_ `bin/rig` implements skill parsing and state in Bash; `tests/rig-skills.bats` supplies fake HOME, configuration, Skills CLI, KI, and runtime roots.

### RIG-PORT-009 — Deterministic authored assembly

Rig's authored Bash modules MUST assemble byte-for-byte into the committed `bin/rig`. `src/rig/00-runtime.bash` MUST own the sole authored `RIG_VERSION`, assembly MUST copy it into the single installed executable, and release verification MUST check the assembled runtime version. Every authored module and assembled output MUST parse under macOS Bash 3.2 and pass ShellCheck without introducing a runtime module loader.

_Conformance:_ conforming

_Verify:_ Run `scripts/assemble-rig --check`, Bash 3.2 syntax checks, and ShellCheck over `src/rig/*.bash` and `bin/rig`.

_Evidence:_ `scripts/assemble-rig` concatenates the ordered `src/rig/` modules and detects drift; repository verification covers the source modules and committed payload.

### RIG-PORT-010 — Representative query performance

On the documented reference macOS machine, `rig diag`, `rig show`, and `rig list` SHOULD each complete the deterministic 100-tool, 1,434-line benchmark in no more than two seconds. Automated verification MUST apply an overrideable five-second portable query guard and eight-second fake-provider observation guard so shared or contended runners do not turn the measured macOS target into a flaky correctness test.

_Conformance:_ conforming

_Verify:_ Run `RIG_BENCHMARK_BUDGET_SECONDS=2 scripts/benchmark-rig` on the reference machine and the default portable budget in Bats.

_Evidence:_ `tests/helpers/large-catalogue-fixture.bash`, `scripts/benchmark-rig`, and `tests/rig-performance.bats` provide the deterministic fixture, measured target, and portable regression guard.

### RIG-PORT-011 — Bounded native smoke

Development verification MUST probe available native managers only through read-only version operations in a disposable HOME and XDG environment. An absent optional manager MUST report an explicit skip, while a failed probe for an available manager MUST fail the smoke check. Native smoke MUST complement rather than replace deterministic fake-based provider behaviour tests.

_Conformance:_ conforming

_Verify:_ Run `scripts/smoke-native-providers` with available and unavailable native-manager commands and inspect its outcome classifications.

_Evidence:_ `scripts/smoke-native-providers` bounds Homebrew, uv, mise, npm, chezmoi, and mas probes to disposable-environment version calls; the complete Bats suite retains fake-based command and state assertions.
