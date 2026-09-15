# Install and inspect Rig

Rig is currently an early scaffold. Use a local development link until a tagged release is published.

## Link a checkout

From the repository root, run:

```sh
./install.sh --link
```

This links `bin/rig` into `${RIG_INSTALL_DIR:-$HOME/.local/bin}` and the manual into `${RIG_MAN_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/man/man1}`. Add the executable directory to `PATH` through your own shell or configuration manager; the installer does not edit startup files.

## Inspect paths

Run:

```sh
rig paths
```

Rig prints its resolved configuration, data, state, and cache directories. Set an XDG base variable to relocate its whole category, or set the corresponding `RIG_*_HOME` value to replace Rig's complete application directory.

## Generate completion

Print completion source with one stable command:

```sh
rig completion bash
rig completion zsh
```

Persist generated completion through the shell or configuration manager that owns startup configuration. Rig does not edit shell startup files.

## Verify the link

Run `rig --version`, `rig --help`, and `man rig`. If the executable is not found, confirm `${RIG_INSTALL_DIR:-$HOME/.local/bin}` is on `PATH`. If the manual is not found, confirm its parent `man` directory is on `MANPATH`.
