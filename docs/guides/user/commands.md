# Choose a Rig command

Rig commands follow a deliberate progression from understanding declared intent to observing a machine, previewing changes, applying them, and optionally publishing a public view.

## Understand the declaration

These commands parse configuration and never invoke providers:

- `rig show [--profile NAME]` — describe the resolved default or named profile in a readable tool table.
- `rig list [--category ID] [--profile NAME]` — list declared tools, optionally restricted by category and resolved profile.
- `rig explain TOOL` — show one tool's complete declared purpose, rationale, relationships, profile membership, platforms, artifacts, and compatible installation.
- `rig diag` — report the running Rig version, executable, Bash, platform, XDG paths, configuration sources, and validity.

Use `show` for the whole selected setup, `list` to browse, `explain` for one tool, and `diag` when Rig itself cannot find or parse what you expect.

## Observe the machine

These commands may invoke only selected providers' declared observation capabilities:

- `rig doctor [--profile NAME]` — give a compact health answer and actionable findings.
- `rig status [--profile NAME] [--unmanaged]` — show the full expected-versus-observed comparison.

`status --unmanaged` additionally asks providers with the `inventory` capability for identities in their domain that no catalogue installation declares. Those rows are informational and do not make an otherwise healthy status fail.

Neither command applies changes.

## Preview and materialise

- `rig apply [--profile NAME] [--dry-run]` — preflight the resolved profile, print the complete plan in dry-run mode, or invoke declared apply capabilities.
- `rig bootstrap [--profile NAME] [--dry-run]` — use the configured bootstrap profile, an explicit profile, or the default-profile fallback through the same application plan.

Run the dry-run form first. A dry run invokes no provider. Without `--dry-run`, these commands cross the provider-mutation boundary.

## Run a declared host action

- `rig run PROVIDER ACTION [-- ARGUMENT...]` — invoke one action declared for one custom provider.

This is an advanced trust transition. The configuration fixes the provider, mode, base arguments, platforms, and caller-argument policy before Rig dispatches it. See [custom provider actions](provider-actions.md).

## Export or publish a public view

- `rig export PUBLICATION --output DIRECTORY` — generate deterministic `rig-publication` version 1 data without invoking a publisher.
- `rig publish PUBLICATION` — generate the same isolated data and pass it to the publication's explicitly selected custom publisher.

Export is the review boundary; publish is the network-capable transition. See [publish a rig](publishing.md).

## Maintain Rig-owned cache data

- `rig clean [--dry-run]` — remove complete retained publication exports and resumable cleanup claims that Rig can prove it owns.

Use `rig clean --dry-run` first to see the exact paths and reasons. Retained publication exports remain indefinitely until this explicit command removes them. Unsafe shapes and cache entries from the earlier flat layout are reported and skipped; active publication staging, provider-native caches, configuration, data, and state are never cleanup targets.

Cleanup is maintenance, not a step in the everyday Rig lifecycle. It does not load configuration or invoke providers.

## Get help and completion

- `rig completion bash|zsh` — print completion source for the selected shell.
- `rig help [-h|--help]` — print top-level help.
- `rig --help` — print top-level help.
- `rig --version` — print the installed Rig version.

Every subcommand accepts `-h` or `--help` for command-local usage. `man rig` is the exhaustive reference.

## Interpret exit status

- Status 0 means the command completed successfully. For health commands, the checked rig is healthy.
- Status 1 means an operational command completed with findings or a provider operation failed.
- Status 2 means Rig rejected its own command syntax, configuration, or profile resolution.
- `rig run` and publication dispatch preserve provider-native failure detail where their contract requires it.

Progress is written to stderr when interactive so reports remain stable on stdout. Set `RIG_PROGRESS=always` for redirected progress or `RIG_PROGRESS=never` to suppress it.
