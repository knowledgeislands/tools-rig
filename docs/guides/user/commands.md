# Choose a Rig command

Rig commands follow a deliberate progression from understanding declared intent to observing a machine, previewing changes, applying them, and optionally publishing a public view.

## Understand the declaration

These commands parse configuration and never invoke providers:

- `rig show [--profile NAME]` — describe the resolved default or named profile in a readable tool table.
- `rig list [--category ID] [--profile NAME]` — list declared tools, optionally restricted by category and resolved profile.
- `rig explain TOOL|service:ID|scheduled-job:ID|setting:ID|dock:ID` — show one tool or qualified managed resource's complete declaration and profile membership.
- `rig diag` — report the running Rig version, executable, Bash, platform, XDG paths, configuration sources, and validity.

Use `show` for the whole selected setup, `list` to browse, `explain` for one tool, and `diag` when Rig itself cannot find or parse what you expect.

## Observe the machine

These commands may invoke only built-in observation operations or explicitly allowed observations for selected external providers:

- `rig doctor [--profile NAME]` — give a compact health answer and actionable findings.
- `rig status [--profile NAME] [--unmanaged]` — show the full expected-versus-observed comparison for tools and resources.

`status --unmanaged` additionally uses built-in inventory sources and explicitly allowed external inventory operations to find identities that no catalogue installation declares. Those rows are informational and do not make an otherwise healthy status fail.

Neither command applies changes.

## Preview and materialise

- `rig apply [--profile NAME] [--scope tools|resources|all] [--dry-run]` — preflight the resolved profile, print the selected scope in dry-run mode, or invoke built-in and explicitly allowed external mutation operations.
- `rig bootstrap [--profile NAME] [--scope tools|resources|all] [--dry-run]` — run Rig's native new-machine lifecycle for the configured bootstrap profile, an explicit profile, or the default-profile fallback.

Run the dry-run form first. A dry run invokes no provider and writes no state. Without `--dry-run`, apply reconciles an operable profile; bootstrap first identifies and verifies required managers and then reconciles it. Bootstrap reports a missing manager rather than installing that manager system. Both cross the mutation boundary only after complete preflight.

## Run a declared host action

- `rig run PROVIDER ACTION [-- ARGUMENT...]` — invoke one built-in provider operation or an action explicitly allowed for one external provider.

Built-in operations are fixed by Rig. An external action is an advanced trust transition: configuration fixes its executable, allowed operation, mode, base arguments, platforms, and caller-argument policy before dispatch. See [external provider actions](provider-actions.md).

## Export or publish a public view

- `rig export PUBLICATION --output DIRECTORY` — generate deterministic `rig-publication` version 1 data without invoking a publisher.
- `rig publish PUBLICATION` — generate the same isolated data and pass it to the publication's explicitly selected custom publisher.

Export is the review boundary; publish is the network-capable transition. See [publish a rig](publishing.md).

## Maintain Rig-owned cache data

- `rig clean [--dry-run]` — remove complete retained publication exports and resumable cleanup claims that Rig can prove it owns.

Use `rig clean --dry-run` first to see the exact paths and reasons. Retained publication exports remain indefinitely until this explicit command removes them. Unsafe or unclassified cache shapes are reported and skipped; active publication staging, provider-native caches, configuration, data, and state are never cleanup targets.

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
