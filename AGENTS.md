# Working in Rig

Rig is one standalone command-line tool. The runtime entry point is `bin/rig`; keep it compatible with Bash 3.2 and do not introduce a runtime dependency beyond Bash.

## Product boundary

Rig orchestrates package and configuration systems. It owns profile selection, dependency ordering, action dispatch, and outcome reporting. Homebrew, uv, chezmoi, and custom targets retain their native manifests, resolution, installation semantics, and state.

Do not embed a workstation's personal package list or machine-specific paths in the executable. Portable behaviour belongs here; a workstation's choices belong in its Rig configuration.

## XDG contract

Use `${XDG_CONFIG_HOME:-$HOME/.config}/rig`, `${XDG_DATA_HOME:-$HOME/.local/share}/rig`, `${XDG_STATE_HOME:-$HOME/.local/state}/rig`, and `${XDG_CACHE_HOME:-$HOME/.cache}/rig`. Honour the corresponding `RIG_CONFIG_HOME`, `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME` overrides.

XDG defines no executable directory. `install.sh` therefore defaults to `~/.local/bin` and honours `RIG_INSTALL_DIR`. Manual pages default beneath `${XDG_DATA_HOME:-$HOME/.local/share}/man/man1` and honour `RIG_MAN_INSTALL_DIR`.

## Repository shape

- `bin/rig` is executable, contains the single `RIG_VERSION` source, and owns the public CLI.
- `install.sh` supports released installation and `--link` local development.
- `man/rig.1`, CLI help, README command summaries, and completion output stay aligned.
- `tests/rig.bats` tests the public command contract.
- Decisions explain why, Specifications state what, Guides explain how, and roadmap records state when.

## Verification

Run the complete local gate before committing:

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh
bats tests/
mandoc -T lint man/rig.1
```

Do not push or publish a release unless explicitly asked.
