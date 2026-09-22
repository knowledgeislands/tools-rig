# Choose a Rig command

Rig's commands follow a deliberate progression from understanding declared intent, through observing the machine, to previewing and applying changes. Start with the least powerful command that answers the question.

## Command synopsis

- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID`
- `rig status [--profile NAME] [--unmanaged]`
- `rig doctor [--profile NAME]`
- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]`
- `rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]`
- `rig update [--profile NAME] [--dry-run]`
- `rig maintain [--profile NAME] [--dry-run]`
- `rig capture PROVIDER [--dry-run]`
- `rig run PROVIDER ACTION [-- ARGUMENT...]`
- `rig export PUBLICATION --output DIRECTORY`
- `rig publish PUBLICATION`
- `rig clean [--dry-run]`
- `rig diag`
- `rig completion bash|zsh`
- `rig help [-h|--help]`

`rig --help` shows top-level help, while `rig --version` prints the installed version. The sections below explain when to use each command rather than repeating the manual's complete option reference.

## Understand declarations

These commands parse configuration and never invoke providers:

- `rig show [--profile NAME]` describes the resolved default or named profile in readable tables.
- `rig list [--category ID] [--profile NAME]` browses catalogue tools, optionally restricted by category or profile.
- `rig explain ID` shows one complete declaration and its profile membership. Qualify non-tool identities, for example `skill:caveman`, `service:example-daemon`, or `port:example-api`.
- `rig diag` reports the running executable, Bash and platform details, XDG paths, configuration sources, selection mode, and model counts.

Use `show` for the whole selected setup, `list` to browse tools, `explain` for one identity, and `diag` when Rig is not finding or parsing what you expect.

## Observe the machine

These commands are read-only, but may invoke built-in observations or observations explicitly allowed for a trusted extension:

- `rig doctor [--profile NAME]` gives a compact health answer and actionable findings.
- `rig status [--profile NAME] [--unmanaged]` gives the detailed expected-versus-observed comparison. `--unmanaged` also asks supported inventory sources for undeclared tools, skills, or listeners.

Neither command applies changes. A healthy `doctor` is a concise confidence check; `status` is the diagnostic detail behind it.

## Preview and reconcile

Run the dry-run form before either materialising command:

```sh
rig apply --dry-run
rig bootstrap --dry-run
```

- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` reconciles an operable complete profile in tools → skills → resources order.
- `rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` runs Rig's bounded new-machine lifecycle, verifies the required native managers, and then materialises the selected bootstrap profile.

Bootstrap is a lifecycle stage, not a provider or a reason to create another profile. It does not install an absent package manager from arbitrary configuration.

Both commands preflight the selected plan before the first mutation. A shared safety problem rejects the plan. A finding local to one managed resource fails that row while allowing independent work to remain visible.

## Advance native provider state

Reconciliation makes declared intent present. It does not silently upgrade every tool, run package-manager maintenance, or rewrite a native manifest. Those changes are explicit:

- `rig update [--profile NAME] [--dry-run]` advances selected tools through supported native managers.
- `rig maintain [--profile NAME] [--dry-run]` runs one bounded maintenance operation for each supported selected provider.
- `rig capture PROVIDER [--dry-run]` deliberately refreshes a supported provider-native manifest.

Use dry run first. These commands have broader provider effects than applying one declaration, and Rig reports whether each operation has declaration, manifest, or provider-wide scope.

## Run a bounded provider action

`rig run PROVIDER ACTION [-- ARGUMENT...]` invokes a fixed built-in action or one action allow-listed for an explicitly trusted custom provider.

This is not a general shell runner. Read [Run external provider actions](provider-actions.md) before adding a custom action.

## Export or publish a public view

- `rig export PUBLICATION --output DIRECTORY` generates deterministic public data locally without invoking a publisher.
- `rig publish PUBLICATION` generates the same isolated data and hands it to the explicitly selected trusted publisher.

Export is the review boundary; publish is the network-capable transition. Follow [Publish a public rig](publishing.md) before configuring either command.

## Clean Rig-owned cache data

`rig clean [--dry-run]` removes only retained cache artifacts that Rig can prove it owns. Use `rig clean --dry-run` first to inspect exact targets and reasons.

Clean is maintenance, not part of the everyday reconciliation lifecycle. It never removes provider-native caches, configuration, data, or state.

## Get help and completion

- `rig help`, `rig -h`, and `rig --help` show top-level help.
- `rig COMMAND --help` shows command-local help where available.
- `rig --version` prints the version.
- `rig completion bash|zsh` prints completion source.

Use `man rig` for the exhaustive command synopsis, options, configuration schema, environment variables, and exit-status contract.

## Read exit statuses

- Status 0 means the command completed successfully; for a health command, the checked rig is healthy.
- Status 1 means an operational command completed with findings or provider work failed.
- Status 2 means Rig rejected command syntax, configuration, or profile resolution before valid work could proceed.

Some direct dispatch commands preserve a provider-native non-zero status. Profile-wide operations aggregate independent provider failures and return status 1.

## Follow progress

Operational commands report phases, completed counts, safe current identities, mutation scope, and terminal outcomes on stderr. Tables, JSON, and other command results remain on stdout.

The default `RIG_PROGRESS=auto` shows progress for operational work on an interactive terminal and keeps fast declaration queries quiet. Use `RIG_PROGRESS=always` for stable line-oriented progress when stderr is redirected, or `RIG_PROGRESS=never` to suppress Rig-authored progress.

Progress labels omit private values such as paths, locators, arguments, environment entries, publication titles, observed details, and credentials. Native provider diagnostics may still use stderr in their own format.
