# Runtime portability — RIG-PORT

This area of the [Rig specifications](index.md) defines the installed runtime and persistent-path contract. It follows [ADR-RIG-001](../decisions/ADR-RIG-001-shell-only-runtime.md) and [ADR-RIG-002](../decisions/ADR-RIG-002-xdg-directory-contract.md).

## Runtime

### RIG-PORT-001 — Shell-only core

The installed Rig executable MUST require only Bash 3.2 or later for its own command parsing, path resolution, profile selection, and target dispatch.

_Conformance:_ conforming

_Verify:_ ShellCheck validates the Bash executable and Bats runs its core commands without a language runtime or package manager on `PATH`.

_Evidence:_ `bin/rig` contains the Bash-only scaffold and `.github/workflows/ci.yml` runs ShellCheck and Bats.

## Persistent paths

### RIG-PORT-002 — XDG application directories

Rig MUST place configuration, data, state, and cache beneath their corresponding XDG Base Directory roots unless the matching complete Rig application-directory override is set.

_Conformance:_ conforming

_Verify:_ `bats tests/rig.bats` invokes `rig paths` with isolated XDG and Rig-specific environment values.

_Evidence:_ `tests/rig.bats` covers XDG-derived paths and precedence of `RIG_CONFIG_HOME`, `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME`.

### RIG-PORT-003 — Conventional executable location

The release installer MUST default to `~/.local/bin` and MUST allow `RIG_INSTALL_DIR` to replace that destination.

_Conformance:_ conforming

_Verify:_ Bats installer tests link into an isolated default and overridden destination.

_Evidence:_ `install.sh` implements the destination contract and `tests/rig.bats` verifies overridden executable and manual destinations.
