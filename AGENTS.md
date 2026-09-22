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

Do not push or publish a release unless explicitly asked.
