# Maintain Rig's command surface

Rig is authored as ordered Bash 3.2 modules beneath `src/rig/`. `scripts/assemble-rig` concatenates them into the installed `bin/rig`, so source organization has no runtime loading cost. Edit a module, assemble, and verify the generated executable; never patch `bin/rig` directly.

## Find the owner

- `00-runtime.bash` owns shared state, top-level help, JSON primitives, command outcomes, and live progress.
- `10-configuration.bash` parses and validates the catalogue, then resolves profiles, variants, bindings, and dependencies.
- `20-orchestration.bash` owns built-in provider and resource operations, observations, state reports, `apply`, and `bootstrap`.
- `30-commands.bash` owns bounded declared actions, environment diagnostics, catalogue queries, and the current table helper.
- `40-publication-lifecycle.bash` owns public export, provider lifecycle tasks, their last-run report, and manifest capture.
- `90-main.bash` dispatches commands, selects query or operational progress context, and emits the common outcome.

Trace an operational command from `90-main.bash` through profile resolution in `10-configuration.bash`, its command body, then outcome reporting in `00-runtime.bash`. `rig_get_value` returns through the global `RIG_VALUE`; copy that value before calling another helper that may replace it.

## Keep the commands distinct

- `show` resolves one profile; `list` browses catalogue tools with optional filters; `explain` describes one declared identity. They answer different questions and should keep one identifier vocabulary.
- `status` compares the selected declaration with observation. `doctor` turns operational problems into findings and next actions. `diag` reports runtime paths and configuration shape even when a normal profile cannot resolve. A fix to unusable configuration belongs in `doctor`, while `diag` remains the lower-level environment view.
- `apply` reconciles a complete selected profile or a bounded part of it. `bootstrap` prepares a new machine with prerequisite ordering and deferred managers. Their similar flags do not make their execution semantics interchangeable.
- `update` and `maintain` already share `rig_command_lifecycle`; each delegates native operation details to the selected provider. `capture` refreshes one provider-native manifest, while `run` invokes an explicitly declared action. Neither is a generic shell task runner.
- `export` produces a public, non-appliable projection. `completion` prints shell integration. `help` and version report on Rig itself.

The fourteen named commands above are dispatched in `90-main.bash`; `help` and version are meta commands. When adding or changing a public option, check its parser, command help, Bash and Zsh completion, manual page, user command guide, and tests together.

## Review overlap before adding a path

The confirmed presentation duplication is in two places: command usage and completion options are authored in several command bodies, and state/report commands mix `rig_table_*` with raw tab-separated rows. RIG-CLI-019 owns option descriptions; RIG-CLI-018 owns completed report rendering. `rig_outcome_report` and `rig_progress_*` are already common owners. Keep live progress on stderr and completed reports on stdout.

`apply` and `bootstrap` each parse `--profile`, `--scope`, and `--dry-run`; their common syntax deserves a shared option description, while their different prerequisite and application flows should stay explicit. `status` and `doctor` both observe the same plan but differ in their reader-facing result. Shared observation is intentional; duplicated output formatting is not.

`20-orchestration.bash` contains provider adapters, macOS resources, state synthesis, and two operational commands in one large authored module. A source-only split can improve navigation while preserving the assembled payload and function order. Make that change independently from behaviour changes, and verify byte-for-byte assembly plus the full suite. Keep the manager-of-managers boundary: providers retain their native manifests, credentials, and execution semantics.
