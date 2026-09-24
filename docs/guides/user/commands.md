# Choose a Rig command

Rig's commands follow a deliberate progression from understanding declared intent, through observing the machine, to previewing and applying changes. Start with the least powerful command that answers the question.

## Command synopsis

- `rig show [--profile NAME]`
- `rig list [--category ID] [--profile NAME]`
- `rig explain TOOL|skill:ID|service:ID|scheduled-job:ID|setting:ID|dock:ID|port:ID`
- `rig status [--profile NAME] [--unmanaged] [--format text|json]`
- `rig doctor [--profile NAME] [--format text|json]`
- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]`
- `rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]`
- `rig update [--profile NAME] [--dry-run] [--unattended]`
- `rig maintain [--profile NAME] [--dry-run] [--unattended]`
- `rig capture PROVIDER [--dry-run]`
- `rig run PROVIDER ACTION [-- ARGUMENT...]`
- `rig export --profile NAME --output DIRECTORY [--title TEXT] [--base-url URL]`
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

- `rig doctor [--profile NAME] [--format text|json]` gives a compact health answer and actionable findings.
- `rig status [--profile NAME] [--unmanaged] [--format text|json]` gives the detailed expected-versus-observed comparison. `--unmanaged` also asks supported inventory sources for undeclared tools, skills, or listeners.

Status groups tools, skills, managed resources, private ports, and unmanaged observations into aligned tables. Columns grow to fit ordinary values but each table remains within 120 characters; unusually long values use a visible `...` marker, with paths retaining both their beginning and identifying tail where useful. The display is for people rather than scripts: use `rig explain ID` for the complete declaration, and do not parse spacing as a machine interface.

The port table compares each declared owner against the process actually bound. A listener launched through an interpreter — `node` running a service's `program`, or a virtual environment's `python` running a tool — matches its declaration, because the comparison reads the whole command line rather than the executable name alone. `conflicting` therefore asserts something specific: the command line was read, and it identifies a different process. Where that command line cannot be read and the executable name does not match either, the port reports `unknown` with `owner-unavailable`, or stays informational for an `allocated` port. A stranger on the port and a process Rig could not inspect are different answers, and the table says which one it means.

A declared artifact may be a symbolic link, which is how applications install their command line into a shared executable directory. Rig observes the link through the target it resolves to, so a healthy `code` or `subl` is `present` rather than an unexplained `unavailable`. The resolved target still has to answer for itself: a link whose target has gone is `missing`, a link into a damaged application bundle is `drifted`, and a link Rig cannot resolve at all is `unavailable` with a detail saying resolution failed. Where a link was followed, the detail names the resolved target beside the declared path, so you can see what answered the question. Declaring a command line this way also makes its absence visible — a link an application never created is reported against the tool that owes it.

Neither command applies changes. A healthy `doctor` is a concise confidence check; `status` is the diagnostic detail behind it.

### Ask for a machine-readable answer

Add `--format json` to either command for a single JSON object on one line on stdout, emitted after observation finishes. It is a projection of the same observation the tables render, so the two can never disagree about a state, a count, or a verdict; the exit status is unchanged, and the payload carries `healthy` and the summary counts so a script never has to read it.

```sh
rig status --format json | jq '.summary'
rig doctor --format json | jq -r '.findings.tools[]'
```

The payload opens with `schema`, the running `rig` version, the `command`, the resolved `profile` and `platform`, and an `observed_at` timestamp. `rig status` then carries `tools`, `skills`, `resources`, and `ports` arrays naming each item's identity, owner, state, and detail, plus `unmanaged` and `unmanaged_problems`, which stay `null` unless you asked for `--unmanaged`. `rig doctor` carries its `findings` grouped by origin and its `information`. Pin `schema`: a change that removes or repurposes a field increments it.

One caution about disclosure. `detail`, `findings`, and `information` are human-facing text and are the only fields that may carry a local path; no other field does. A consumer that must not disclose paths can discard exactly those three and keep everything else. Progress and native provider diagnostics stay on stderr, so redirecting stdout gives you the payload alone.

## Preview and reconcile

Run the dry-run form before either materialising command:

```sh
rig apply --dry-run
rig bootstrap --dry-run
```

- `rig apply [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` reconciles an operable complete profile in tools → skills → resources order.
- `rig bootstrap [--profile NAME] [--scope tools|skills|resources|all] [--dry-run]` runs Rig's bounded new-machine lifecycle, stages supported declared manager prerequisites where needed, and then materialises the selected bootstrap profile.

Bootstrap is a lifecycle stage, not a provider or a reason to create another profile. It can stage only Rig's fixed Homebrew → mise → npm prerequisite chain when the selected declarations require it; configuration cannot supply arbitrary setup commands.

Both commands preflight the selected plan before the first mutation. A shared safety problem rejects the plan. A finding local to one managed resource fails that row while allowing independent work to remain visible.

## Advance native provider state

Reconciliation makes declared intent present. It does not silently upgrade every tool, run package-manager maintenance, or rewrite a native manifest. Those changes are explicit:

- `rig update [--profile NAME] [--dry-run] [--unattended]` advances selected tools through supported native managers.
- `rig maintain [--profile NAME] [--dry-run] [--unattended]` runs one bounded maintenance operation for each supported selected provider.
- `rig capture PROVIDER [--dry-run]` deliberately refreshes a supported provider-native manifest.

Use dry run first. These commands have broader provider effects than applying one declaration, and Rig reports whether each operation has declaration, manifest, or provider-wide scope.

Update and maintenance work is independent per target, so one target Rig cannot advance does not stop the others. A target whose native manager is not installed is reported as `unavailable` with the reason, is never invoked, and leaves the rest of the run to complete; the command then returns 1 so the gap stays visible. Install the missing manager — usually with `rig apply` — and run the command again.

`--unattended` states that nobody is watching. No provider can ask a question, work that needs a person is reported `unavailable` before it is invoked, and the run records what happened where a wrapper can read it. See [Update without watching](unattended-updates.md).

## Run a bounded provider action

`rig run PROVIDER ACTION [-- ARGUMENT...]` invokes a fixed built-in action or one action allow-listed for an explicitly trusted custom provider.

This is not a general shell runner. Read [Run external provider actions](provider-actions.md) before adding a custom action.

## Export a public view

`rig export --profile NAME --output DIRECTORY` generates deterministic public data locally, invoking no provider and no network command. `--profile` must name a non-appliable view.

`--title TEXT` and `--base-url URL` describe the document the data becomes; both are optional, and both belong to the consuming site rather than to your configuration. Follow [Export a public rig](exporting.md) before wiring it into a site.

Rig does not deploy. Take the exported tree wherever it belongs, using the credentials and transport that system already has.

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

Some direct dispatch commands preserve a provider-native non-zero status. Profile-wide operations aggregate independent provider failures and return status 1. An interrupted command returns 129, 130, or 143 for HUP, INT, or TERM.

You do not have to read the status out of the shell. Unless it is suppressed, a command states its own outcome on the last line it writes to stderr:

```text
rig: status unhealthy: status 1 (unhealthy=2 present=13)
rig: apply succeeded: status 0 (planned=6 completed=6 skipped=0)
rig: update incomplete: status 1 (planned=4 completed=3 failed=1 unavailable=0)
```

The result is one of `succeeded`, `healthy`, `unhealthy`, `incomplete`, or `failed`. A rejection is not restated: a command that exits 2 has already printed `rig: error:` naming the cause, which tells you more than a second line would.

The default `RIG_OUTCOME=auto` states the outcome when stderr is a terminal. Use `RIG_OUTCOME=always` to state it when stderr is redirected too, or `RIG_OUTCOME=never` to suppress it. The line is always on stderr, so it never enters a table or a JSON payload a script is parsing, and `help`, `completion`, and `--version` never carry one.

## Follow progress

Operational commands report phases, completed counts, safe current identities, mutation scope, and terminal outcomes on stderr. Interactive phases update a fixed-width ASCII progress bar in place instead of printing one line for every event. Tables, JSON, and other command results remain on stdout.

The default `RIG_PROGRESS=auto` shows the bar for operational work on an interactive terminal and keeps fast declaration queries quiet. `RIG_PROGRESS=always` forces progress: it uses the bar on a terminal and stable line-oriented events when stderr is redirected. Use `RIG_PROGRESS=lines` to request those durable events even on a terminal, or `RIG_PROGRESS=never` to suppress Rig-authored progress.

The bar advances only after a real succeeded, skipped, or failed outcome; it is not a duration estimate. Progress labels omit private values such as paths, locators, arguments, environment entries, export titles, observed details, and credentials. Native provider diagnostics may still use stderr in their own format and can temporarily interrupt the bar; the next Rig event redraws it.
