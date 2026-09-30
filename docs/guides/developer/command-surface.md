# Maintain Rig's command surface

Rig is authored as ordered Bash 3.2 modules beneath `src/rig/`. `scripts/assemble-rig` produces the standalone `bin/rig`; there is no runtime module loader. Edit authored modules and regenerate the payload.

## Module ownership

- `00-runtime.bash`: shared state, help and option metadata, JSON, outcomes and progress.
- `10-configuration.bash`: inert parsing, validation, selections, bindings and dependencies.
- `20-orchestration.bash`: plan primitives, capabilities and built-in resource adapters.
- `21-provider-state.bash`: native invocation, observations, inventory and receipts.
- `22-observation.bash`: status and doctor, including verbose diagnostic evidence.
- `23-application.bash`: apply and declared manager prerequisites.
- `30-commands.bash`: catalogue query helpers, diagnostic metadata and retained extension validation helpers.
- `35-adoption.bash`: init, Homebrew discovery and reviewed capture proposals.
- `40-publication-lifecycle.bash`: export and declaration-scoped upgrades.
- `90-main.bash`: public dispatch and shared outcome handling.

`rig_get_value` returns through the shared `RIG_VALUE`; preserve it locally before another helper can replace it.

## One purpose per command

Public commands are `init`, `show`, `status`, `capture`, `apply`, `upgrade`, `doctor`, `export`, `completion`, and `help`. `show` covers selected, catalogue and individual views; `status` compares intent and observation; `doctor` diagnoses operational problems, with `--verbose` adding runtime details.

Apply makes the machine follow declarations. Capture prepares reviewed additions from supported observed inventory. Init creates configuration only. Upgrade advances selected software rather than refreshing configuration.

The command cutover is explicit: retired names are rejected with migration advice, not kept as aliases. Internal helper names and the provider ABI's `update` capability are implementation boundaries, not additional public commands. Custom action records remain validated inert metadata; no public generic action dispatcher exposes them.

## Review and verification

Keep parser, option metadata, help, Bash and Zsh completion, manual, user guide and regression fixtures aligned. Preserve JSON schema and report field meaning; document public command-identifier changes. New adoption code must test exclusive file creation, literal escaping, catalogue deduplication and dry-run purity.

Provider execution owns resolution and installation state. Rig owns package-selection intent and never orchestrates Brewfiles. ChezMoi retains its native source, templates and execution semantics. No native cleanup is implicitly added to apply or upgrade.

Run the complete local gate after integration. Keep benchmarks separate from concurrent test work. Never verify mutation against the live workstation.
