# Maintain Rig's command surface

Rig is authored as ordered Bash 3.2 modules beneath `src/rig/`. `scripts/assemble-rig` produces the standalone `bin/rig`; there is no runtime module loader. Edit authored modules and regenerate the payload.

## Module ownership

- `00-runtime.bash`: shared state, help and option metadata, JSON, outcomes and progress.
- `10-configuration.bash`: inert parsing, validation, selections, bindings and dependencies.
- `20-orchestration.bash`: plan primitives, capabilities and built-in resource adapters.
- `21-provider-state.bash`: native invocation, observations, inventory and receipts.
- `22-observation.bash`: status and doctor, including verbose diagnostic evidence.
- `23-application.bash`: apply and declared manager prerequisites.
- `24-app-clis.bash`: named application companions, bounded link creation and native cask repair.
- `30-commands.bash`: catalogue query helpers, diagnostic metadata and proven installation context, terminal-width-aware wrapped/stacked tables, and retained extension validation helpers.
- `35-adoption.bash`: init, Homebrew discovery and reviewed capture proposals.
- `40-publication-lifecycle.bash`: export and declaration-scoped upgrades.
- `90-main.bash`: public dispatch and shared outcome handling.

`rig_get_value` returns through the shared `RIG_VALUE`; preserve it locally before another helper can replace it.

## One purpose per command

Public commands are `init`, `show`, `status`, `capture`, `apply`, `upgrade`, `doctor`, `export`, `completion`, and `help`. `show` covers selected, catalogue and individual views; `status` compares intent and observation; `doctor` diagnoses operational problems, with `--verbose` adding runtime details.

Apply makes the machine follow declarations. Capture prepares reviewed additions from supported observed inventory. Init creates configuration only. Upgrade advances selected software rather than refreshing configuration.

Unknown command names follow the normal syntax-error path and print current usage. Internal helper names and the provider ABI's `update` capability are implementation boundaries, not additional public commands. Custom action records remain validated inert metadata; no public generic action dispatcher exposes them.

## Review and verification

The `ki-repo-tools` diagnostic baseline owns common context and health labels. Rig keeps runtime host context separate from its selected provider platform. `tests/diagnostics-tables.bats` verifies provenance, default redaction, fragment presence, item-count coverage, actual pseudo-terminal geometry, UTF-8 width and escaped terminal controls; unknown provenance or geometry must remain explicit rather than guessed. JSON doctor adds context and checks without removing domain summaries; native provider operations remain observation-only. Tables add no ANSI decoration or runtime dependency, conservatively budget non-ASCII code points, and never abbreviate identifiers.

Keep parser, option metadata, help, Bash and Zsh completion, manual, user guide and regression fixtures aligned. Preserve JSON schema and report field meaning; document public command-identifier changes. New adoption code must test exclusive file creation, literal escaping, catalogue deduplication and dry-run purity.

Provider execution owns resolution and installation state. Rig owns package-selection intent and never orchestrates Brewfiles. ChezMoi retains its native source, templates and execution semantics. No native cleanup is implicitly added to apply or upgrade.

Run the complete local gate after integration. Keep benchmarks separate from concurrent test work. Never verify mutation against the live workstation.
