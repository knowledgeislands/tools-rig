# Runtime portability — RIG-PORT

This area of the [Rig Specifications](index.md) defines the installed runtime and persistent-path contract. It follows [ADR-RIG-001](../decisions/ADR-RIG-001-shell-only-runtime.md) and [ADR-RIG-002](../decisions/ADR-RIG-002-xdg-directory-contract.md).

## Runtime

### RIG-PORT-001 — Shell-only core

The installed Rig executable MUST require only Bash 3.2 or later for its own command parsing, path resolution, catalogue and profile resolution, provider dispatch, and static export.

_Conformance:_ conforming

_Verify:_ ShellCheck validates the Bash executable and Bats runs its core commands without a language runtime or package manager on `PATH`.

_Evidence:_ `bin/rig` contains the Bash-only scaffold and `.github/workflows/ci.yml` runs ShellCheck and Bats.

## Persistent paths

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

`rig diag` MUST report the Rig version, invoked executable, Bash version, active platform, effective configuration, data, state, and cache directories, root configuration file, fragment count, and configuration status. When configuration is valid it MUST also report the schema and default profile.

Diagnostics MUST NOT invoke a provider. The command MUST return status 0 for valid configuration, status 1 for missing or invalid configuration, and status 2 for invalid command syntax.

_Conformance:_ conforming

_Verify:_ Bats tests compare stable diagnostics for default and overridden paths, linked invocation, valid, missing, and invalid configuration; assert provider non-execution; and cover command help and exit statuses.

_Evidence:_ `tests/rig.bats` covers exact labelled output, XDG and Rig-specific precedence, invoked symlink paths, fragment counting, valid, missing, and invalid configuration, provider non-execution, local help, and removal of `paths`.
