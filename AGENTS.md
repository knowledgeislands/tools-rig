# Working in Rig

Rig is one standalone command-line tool. The runtime entry point is `bin/rig`; keep it compatible with Bash 3.2 and do not introduce a runtime dependency beyond Bash.

## Product boundary

Rig is the declarative description and manager of a person's working setup. Its catalogue owns tool identity, category, purpose, rationale, relationships, and supported platforms; profiles select catalogue subsets; providers materialise them; state compares the selection with provider observations.

Rig's manager-of-managers model belongs beneath that catalogue. It owns profile resolution, provider selection, dependency ordering, capability checks, action dispatch, and outcome reporting. Homebrew, uv, chezmoi, downloads, custom executables, and publishers retain their native manifests, resolution, execution semantics, credentials, deployment, and state.

Do not embed a workstation's personal catalogue, package list, profile, publication, or machine-specific path in the executable. Portable behaviour belongs here; a person's choices belong in their Rig configuration. A published rig is a derived public projection, never the authority for private configuration or observed machine state.

## XDG contract

Use `${XDG_CONFIG_HOME:-$HOME/.config}/rig`, `${XDG_DATA_HOME:-$HOME/.local/share}/rig`, `${XDG_STATE_HOME:-$HOME/.local/state}/rig`, and `${XDG_CACHE_HOME:-$HOME/.cache}/rig`. Honour the corresponding `RIG_CONFIG_HOME`, `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME` overrides.

XDG defines no executable directory. `install.sh` therefore defaults to `~/.local/bin` and honours `RIG_INSTALL_DIR`. Manual pages default beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1` and honour `RIG_MAN_INSTALL_DIR`.

## Repository shape

- `src/rig/*.bash` are ordered authored modules; `src/rig/00-runtime.bash` owns the sole authored `RIG_VERSION`, and `scripts/assemble-rig` deterministically generates the committed `bin/rig`.
- `bin/rig` is the single executable installation payload and contains the assembled runtime version; never edit it directly or introduce a runtime module loader.
- `install.sh` supports released installation and `--link` local development.
- `man/rig.1`, CLI help, README command summaries, and completion output stay aligned.
- `tests/rig.bats` tests the public command contract.
- Decisions explain why, Specifications state what, Guides explain how, and roadmap records state when.

## Authoring notes

`rig_get_value` returns through the single global `RIG_VALUE`, so any helper that calls it clobbers a value the caller has not yet read. Read `RIG_VALUE` into a local before calling anything else.

Bash 3.2 does not apply `set -e` to a failing compound command, so a bats assertion that must fail the test ends `|| false`. Expanding a possibly-empty array under `set -u` needs `"${A[@]+"${A[@]}"}"`.

Run `bats tests/` with stdin redirected from `/dev/null`; without it a test that reads a prompt hangs on the terminal.

Every `setup` calls `rig_test_isolate` from `tests/helpers/isolate.bash` as its first statement. A person's shell exports `XDG_CONFIG_HOME` and `XDG_STATE_HOME`, and the launchd adapter defaults to `/bin/launchctl` in `gui/<uid>`, so an invocation that names no override reconciles the runner's own machine and an apply retires the resources it finds there. The helper removes the inherited base directories, moves `HOME` into the test's tree, and points launchd at an inert stub in a domain no machine owns; an explicit override on a single invocation still wins.

The focused isolation guard in `tests/rig.bats` checks the default state path and destructive adapter overrides. Run the suite with a hostile inherited `XDG_STATE_HOME` when changing the helper; that proves containment survives an ambient state directory rather than only a normal developer shell.

The helper also sets `RIG_PLATFORM=macos` and gives each test a manager-free `PATH` rooted in `/usr/bin:/bin`. A native-provider test either names its own explicit executable or calls `rig_test_provider NAME`, then registers exact argv, exit status, and output with `rig_test_provider_response NAME 'ARGUMENTS' STATUS 'OUTPUT'` (`-` means no output). The fixture logs invocations in `RIG_TEST_PROVIDER_LOG` and fails an undeclared call with exit 99. Use explicit `RIG_PLATFORM=linux` for the second platform branch. `scripts/smoke-native-providers` remains the real-manager integration check; never make `bin/rig` test-aware.

`defaults`, `dockutil`, and `killall` are the same hazard by a different route, and the helper stubs all three for it. Moving `HOME` does not contain `defaults`: it reaches the user domain through `cfprefsd`, so a run under a sandboxed `HOME` writes the real domain using the sandboxed path as its value, which is how this workstation's screenshot location came to point at a deleted temporary directory. Each stub logs its own argv beside itself, because asserting on an observed value cannot distinguish a contained read from a real one when the runner has never set the key.

## Verification

Run the complete local gate before committing:

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers
bash -n bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers
scripts/assemble-rig --check
scripts/benchmark-rig
scripts/smoke-native-providers
bats tests/
mandoc -T lint man/rig.1
```

Never reproduce a destructive Rig defect by applying against the live workstation, even with every sandbox variable set. Rig manages the machine you are working on, and an apply that escapes its sandbox by one unset variable unloads that machine's running services. A defect that retires, unloads, or deletes is reproduced by a test under `tests/`, or by a throwaway catalogue whose declarations name nothing the machine owns — never by running the failing scenario against the real estate to watch it fail. One such experiment left a leak path that was never isolated, so the sandbox was not proof.

Do not push or publish a release unless explicitly asked.
