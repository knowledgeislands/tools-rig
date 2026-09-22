# Choose a Rig command

Rig commands follow a deliberate progression from understanding declared intent to observing a machine, previewing changes, applying them, and optionally publishing a public view.

## Understand the declaration

These commands parse configuration and never invoke providers:

- `rig show [--profile NAME]` — describe the resolved default or named profile in a readable tool table.
- `rig list [--category ID] [--profile NAME]` — list declared tools, optionally restricted by category and resolved profile.
- `rig explain TOOL|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID` — show one tool, qualified managed resource, or private port allocation with complete declaration and profile membership.
- `rig diag` — report the running Rig version, executable, Bash, platform, XDG paths, configuration sources, validity, profile-selection mode, and model counts.

Use `show` for the whole selected setup, `list` to browse, `explain` for one tool, and `diag` when Rig itself cannot find or parse what you expect.

## Observe the machine

These commands may invoke only built-in observation operations or explicitly allowed observations for selected external providers:

- `rig doctor [--profile NAME]` — give a compact health answer and actionable findings for tools, resources, and private ports.
- `rig status [--profile NAME] [--unmanaged]` — show the full expected-versus-observed comparison and optionally inventory undeclared tools and TCP listeners.

`status --unmanaged` additionally uses built-in inventory sources and explicitly allowed external inventory operations to find identities that no catalogue installation declares. Those rows are informational and do not make an otherwise healthy status fail.

Neither command applies changes.

## Preview and materialise

Apply and bootstrap preflight the complete selected plan before mutation. Shared configuration, trust, executable, platform, and receipt-boundary failures reject the plan with status 2. A resource-local environmental finding produces a failed row with status 1, prevents that resource from being invoked, and leaves independent work available.

- `rig apply [--profile NAME] [--scope tools|resources|all] [--dry-run]` — preflight the resolved profile, print the selected scope in dry-run mode, or invoke built-in and explicitly allowed external mutation operations.
- `rig bootstrap [--profile NAME] [--scope tools|resources|all] [--dry-run]` — run Rig's native new-machine lifecycle for the configured bootstrap profile, an explicit profile, or the default-profile fallback.

Run the dry-run form first. A dry run invokes no provider and writes no state. Without `--dry-run`, apply reconciles a complete profile after complete preflight. A non-appliable view is rejected by apply, bootstrap, update, maintain, and selected-resource mutation. Reports disclose whether work affects one declaration, a native manifest, or a provider-wide surface before execution. Receipt-backed work serialises the platform target before reading its receipt. Bootstrap can stage only the fixed Homebrew → mise → npm manager chain when the corresponding prerequisite tools are selected; all external and unrelated managers must already be available. It reports each stage before completing a normal apply preflight.

## Advance provider-managed state

- `rig update [--profile NAME] [--dry-run]` — advance selected Homebrew, uv, mise, and npm tools with each manager's fixed native operation.
- `rig maintain [--profile NAME] [--dry-run]` — run one bounded maintenance work item for each supported provider selected by the resolved profile.
- `rig capture PROVIDER [--dry-run]` — deliberately refresh the named provider's native manifest; Homebrew is the current built-in capture target and requires a configured manifest path.

Use a dry run first. Rig preflights every supported target before mutation, deduplicates shared provider work, and reports selected providers without a supported lifecycle operation as skipped. Update and maintenance resolve the default or named profile; capture names one provider directly because it writes that provider's manifest rather than reconciling a profile.

These commands use fixed built-in behaviour. Configuration selects tools and may supply documented provider-native details such as the Homebrew manifest path, but it cannot define lifecycle shell commands, grant capabilities, or route lifecycle work through an external provider. `rig maintain` owns provider-native maintenance such as cache pruning; `rig clean` has a separate and narrower Rig-cache boundary.

Declared `artifacts` are observation-only. `apply`, `bootstrap`, and `update` manage the owning tool through its provider but do not invoke artifact generators; the native tool owns that lifecycle.

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

Resource-local preflight findings are operational outcomes, not invalid configuration. They therefore use status 1. Shared preflight safety failures use status 2 and prevent every mutation.

- Status 0 means the command completed successfully. For health commands, the checked rig is healthy.
- Status 1 means an operational command completed with findings or a provider operation failed.
- Status 2 means Rig rejected its own command syntax, configuration, or profile resolution.
- `rig run`, `rig capture`, and publication dispatch preserve provider-native failure status where their contract requires it; profile-wide update and maintenance report independent provider failures and return status 1.

Progress is written to stderr when interactive so reports remain stable on stdout. Set `RIG_PROGRESS=always` for redirected progress or `RIG_PROGRESS=never` to suppress it.
