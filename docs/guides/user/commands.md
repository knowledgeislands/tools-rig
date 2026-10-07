# Choose a Rig command

Rig configuration describes the setup you want. Providers install or observe their part of it. There is no Brewfile to keep in sync with Rig.

## Command synopsis

- `rig init [--dry-run]`
- `rig repair [--output PATH]`
- `rig show [ITEM] [--profile NAME] [--all] [--category ID] [--format text|json]`
- `rig status [--profile NAME] [--problems] [--unmanaged] [--retired] [--format text|json]`
- `rig doctor [--profile NAME] [--verbose] [--format text|json]`
- `rig diag [--full]`
- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--target ID]... [--dry-run] [--format text|json]`
- `rig upgrade [--profile NAME] [--dry-run] [--unattended] [--format text|json]`
- `rig capture [ITEM...] [--provider homebrew] [--profile NAME] [--category ID] [--purpose TEXT] [--rationale TEXT] [--output FILE] [--dry-run]`
- `rig export --profile NAME --output DIRECTORY [--title TEXT] [--base-url URL]`
- `rig completion bash|zsh`
- `rig help [COMMAND]`

Use `rig help COMMAND` or `rig COMMAND --help` for command-local details. Item lookup cannot be combined with selection filters; `--all` and `--profile` are alternative selections. The optional `--profile` selects configuration; it is not a separate lifecycle.

## Set up configuration

`rig init` creates a minimal unversioned default configuration. It does not inspect or install software, overwrite existing configuration, or adopt what happens to be installed. Preview with `rig init --dry-run`. For a valid older configuration carrying `schema = 1`, `rig repair` previews the source with that obsolete line removed. `rig repair --output PATH` writes the repaired source to a new file outside active configuration; review it and replace the named source manually. Ordinary commands never rewrite configuration, and unknown or invalid legacy shapes receive no repair proposal.

Add categories and declarations to the resulting file, or use capture to prepare reviewed additions. See [Get started](getting-started.md).

## Understand intent

`rig show` displays the selected setup: tools, skills, resources and private ports. `rig show --all` browses all catalogue tools, including unselected ones. `rig show --category ID` filters selected tools; combine it with `--all` to filter the whole tool catalogue.

`rig show ITEM` explains one declaration, including purpose, rationale, relationships and native ownership. Qualify non-tool identities, such as `skill:caveman`, `service:daemon`, `setting:screenshots` or `port:api`. These queries never invoke providers.

Human-readable tables preserve identifiers and wrap descriptive values rather than abbreviating them. Interactive tables use the terminal's current width; when the columns cannot fit, entries use a labelled, stacked layout. Exceptionally long identifiers remain intact even when wider than the terminal. Redirected output is plain and deterministic, using a 120-column budget independent of `COLUMNS`; unavailable terminal geometry uses the same fallback. Use `--format json` for lossless structured values.

Human cells show terminal control characters and malformed UTF-8 bytes as visible escapes, never executable terminal sequences. Valid UTF-8 characters are kept intact and conservatively budgeted at two display cells per non-ASCII code point, so combining marks and joined emoji can leave extra room. On an exceptionally small terminal, preserving a single wide glyph or identifier takes precedence over the width budget. JSON retains the original values.

## Compare with the machine

`rig status` compares declared intent with observed state. It is not a package-outdated check or an exact mutation plan. `--problems` narrows the display without changing the verdict. `--unmanaged` also asks supported inventory sources about undeclared items; unavailable inventory is reported, not interpreted as empty. Homebrew inventory covers formulae installed on request and installed casks, not all transitive dependencies. macOS application discovery does not imply Homebrew ownership.

`rig doctor` gives actionable configuration and environment findings, a `healthy` or `unhealthy` verdict, and pass/warn/fail/skipped counts. One item means one configuration, XDG directory, history-availability, selected tool/resource/port/skill, retirement or historical-failure check; it is not a subprocess count. Catalogue-only and incompatible selections are skipped, not failures. If configuration cannot load, dependent selection is one skipped group and coverage lists only independently evaluated areas. Warnings are currently zero: actionable findings retain failure status. Healthy means declared setup health, not available package updates, which are explicitly not checked. `rig doctor --verbose` includes runtime paths, configuration sources and model counts. A configuration finding returns 1, while invalid command syntax returns 2.

`rig diag` is an offline, share-safe factual summary with the same Tool, Version, Installation, Platform, Architecture, Runtime and Configuration fields as doctor. Platform and architecture describe the runtime host; doctor's selected platform is separate. Installation is `local` for a proven checkout-backed executable, `release` for a Homebrew Cellar payload with its installation receipt, and `unknown` where provenance is unavailable, including a standalone copied release. Version or working directory alone is not provenance. Root or fragment configuration presence is reported without parsing its contents. Use `rig diag --full` to include executable and effective configuration/data/state/cache paths when troubleshooting privately; configuration values and secrets are never printed. `doctor` is the read-only health evaluation.

Neither status nor doctor repairs anything. A catalogue-only tool is neutral, not an installation failure. The JSON state envelope and exit status describe the same result as the text report. Verbose diagnostic metadata includes local paths and must be reviewed before sharing.

Doctor JSON keeps its existing selected-platform envelope and verbose `diagnostics.runtime.platform` fields; the additive `context.platform` describes the runtime host. The verbose human block labels the legacy value Selected platform to avoid conflating the two.

Status and doctor also show selected historical apply failures separately from live observations. A tool can be present now while its last completed apply failed. The historical finding includes the attempt's completion time, age and native exit status; it is not proof that the current declaration will fail again. Same-provider declaration edits retain that caveat. Use the native diagnostic output from the original attempt to investigate, review `rig apply --target ID --dry-run`, and retry deliberately when appropriate. A later successful apply clears that target's visible failure; applying an unrelated target does not. `--problems` retains these findings and JSON carries them in `apply_failures`, separate from native state counts.

History is local per-platform evidence beneath Rig's state directory, not configuration or a package database. Read-only commands never clear or repair it. Missing history is neutral; damaged, inaccessible or unsafe history is an unavailable-history finding. Future completion times are reported as clock discrepancies. If an apply cannot save history, Rig warns separately without changing the provider's actual result. Successful ordering records remain internal; neither success nor failure history retains arguments, locators or provider output.

If you intentionally run without `HOME`, set `RIG_STATE_HOME` or `XDG_STATE_HOME` explicitly as well as any configuration/data overrides. An unresolved state location is unavailable evidence, not proof that no history exists.

`rig status --retired` adds private, read-only evidence for separately declared retired applications. It does not change health counts or cause cleanup, installation or removal. The section is configuration-wide even with `--profile` or `--problems`, and does not appear without the flag. See [Review a retired application's traces](retired-applications.md) for declarations, ownership caveats and partial usage evidence.

## Make the machine follow intent

Preview with `rig apply --dry-run`, then use `rig apply` when the plan is right. It handles supported declared manager prerequisites and reconciles tools, skills and resources in dependency order. Homebrew itself must already be available when required; this is not an arbitrary empty-machine installer.

Repeat `--target ID` for exact entries or use `--scope` to restrict kinds. Selected dependencies remain explicit; Rig does not install an unrelated manager merely because it appears elsewhere in the catalogue. Complete preflight happens before mutation. A local resource problem can fail that row while independent work proceeds.

Apply does not remove unknown software or silently perform provider housekeeping. Receipt-backed resource retirement concerns declarations removed from the catalogue, not items merely omitted by a profile.

## Upgrade declared software

`rig upgrade` advances selected software and skills through supported native providers. It does not execute a Brewfile or upgrade an undeclared package list. Native dependency resolution still belongs to the package manager.

Preview with `--dry-run`. Unavailable managers and independent failures are reported per target rather than hiding the rest of the run. `--unattended` supplies EOF on provider stdin, sets Homebrew's noninteractive flag and records the outcome in `last-upgrade`; selected App Store upgrades are excluded before invocation. It cannot prevent native terminal or graphical authentication. See [Upgrade without watching](unattended-updates.md).

Run cache cleanup, service restarts, logs and other imperative operations with the owning native tool. Rig has no generic `run` or catch-all `maintain` command.

## Make selected intent follow the machine

`rig capture` discovers supported Homebrew inventory without changing it. Capture currently supports Homebrew formulae installed on request and installed casks, not settings, arbitrary applications or every provider.

Select an installed identity and supply an existing category plus your own purpose and rationale:

```sh
rig capture formula:jq --category development \
  --purpose "Query JSON" --rationale "Small composable data queries" --dry-run
rig capture formula:jq --category development \
  --purpose "Query JSON" --rationale "Small composable data queries" \
  --output ./jq-proposal.toml
```

Bare capture or missing metadata produces discovery rather than invented intent. Complete proposals are additive TOML on stdout or in a newly created review file outside active Rig configuration. Review the proposal, then deliberately copy its declarations into your configuration. Capture never overwrites an existing file, removes absent declarations, or duplicates an identity already declared elsewhere in the catalogue. Use a kind-qualified identity when formula and cask names collide.

Proposal generation requires item-owned profile membership. Legacy central membership configurations may use discovery, then migrate membership or adopt manually; Rig rejects an incompatible mixed-mode proposal.

## Export and shell utilities

`rig export --profile NAME --output DIRECTORY` generates a public projection without providers, network access or deployment. The selected profile must be a non-appliable view. `--title` and `--base-url` describe the publication, not private machine intent. See [Export a public rig](exporting.md).

`rig help`, `rig --help` and `rig --version` describe the executable. `rig completion bash|zsh` emits shell registration; Rig does not edit shell startup files.

## Reports, progress and exit status

Text reports and JSON belong on stdout; progress, provider diagnostics and the final outcome belong on stderr. Apply and upgrade buffer completed reports until native work finishes so diagnostics do not split a table. Capture emits reviewable TOML rather than a JSON report.

Status 0 means success or a healthy observation; 1 means operational findings or failed work; 2 means rejected syntax, configuration or selection. Signals return 129, 130 or 143. With `RIG_OUTCOME=auto`, terminal stderr receives a final outcome line; `always` includes redirected stderr and `never` suppresses it. Help, completion and version carry no outcome.

`RIG_PROGRESS=auto` uses a two-line bottom footer on supported interactive terminals for Rig-owned phases and single native-capable items. It shows the command, resolved selection (or selection pending), phase, completed/total work, current target and phase-local outcome counts. These are task counts, not an estimate of elapsed time. Multi-item native phases show compact handoff headers with the target, scope, ordinal and completed count. They omit routine per-item success lines and keep skips, failures and a final phase summary, without reserving footer rows. Rig releases the terminal and emits a durable task header before invoking a native tool, so its prompts, progress display and diagnostics remain unmodified; a separating newline protects output that did not end with one before Rig resumes reporting. Native output can scroll the handoff header away; Rig does not keep a footer over it. Because native streams stay opaque, the separator can leave a blank line after newline-terminated output or a silent item, including a skip.

Completed, failure-free footer phases leave no permanent success summary, including phases with skipped work. The four configuration phases share one footer instead of leaving a growing gap between each phase. Failures, interruption, incomplete work and phases with failed items still leave durable summaries. This does not remove native diagnostic separators or the final command outcome.

Redirected stderr, unsupported or dumb terminals, unavailable geometry and terminals smaller than eight rows or sixty columns receive line events and their phase summaries. Resize is handled at the next safe rendering boundary, never by redrawing over a native tool. If resizing has moved or reflowed the old footer, Rig leaves that text in scrollback rather than risking erasing diagnostics at uncertain coordinates. `lines` explicitly requests line events, `always` also enables declaration-query progress, and `never` suppresses Rig-authored progress. These controls do not change stdout or exit status. Rig uses neither a full-screen interface nor a terminal multiplexer, and restores terminal scrolling on completion, failure and handled interruption; an uncatchable kill cannot guarantee terminal cleanup.

Unknown commands print an error and current usage. For an existing setup, [review configuration and automation](migrating-command-surface.md) before applying changes.
