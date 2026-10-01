# Manage operational resources and private ports

Rig treats selected machine policy as part of a working setup. Put desired state in private Rig configuration, select it through a complete profile, inspect it without execution, and review the complete plan before applying it.

Built-in providers such as `launchd`, `macos-defaults`, and `macos-dock` need no provider table, adapter name, capability list, or extension protocol configuration.

## Record a private port allocation

Declare a port when its number is durable personal machine intent rather than an ephemeral application choice:

```toml
[port.example-api]
name = "Example API"
purpose = "Keep a local endpoint predictable"
rationale = "Several development tools connect to the same private endpoint"
protocol = "tcp"
port = 3333
scope = "loopback"
mode = "required"
owner = "service:example-daemon"
profiles = ["workstation"]
```

Use `scope = "loopback"` when a listener must not be reachable through normal network interfaces. Use `all-interfaces` only when broader binding is deliberate.

Choose a lifecycle mode that matches the owner:

- `required` expects the selected owner to be listening continuously; absence is a finding.
- `on-demand` permits absence, but an active listener must match the expected scope and owner.
- `allocated` records planning ownership; absence is healthy, while a positively different occupant is a conflict.

The owner must be a qualified `tool:ID`, `service:ID`, or `scheduled-job:ID`. Rig observes supported listeners but never opens, reserves, closes, or kills a socket. `rig status --unmanaged` can show listeners whose port has no declaration.

Port declarations and observations are always private. They never enter exported data, even if a port is accidentally assigned to a view.

## Declare a service

```toml
[service.example-daemon]
name = "Example daemon"
purpose = "Keep a local example endpoint available"
rationale = "The selected development profile depends on the endpoint"
provider = "launchd"
locator = "example.daemon"
platforms = ["macos"]
requires = ["example"]
desired-state = "running"
program = ["~/bin/example", "serve", "--foreground"]
environment = ["EXAMPLE_CONFIG=~/.config/example/config.toml"]
restart-policy = "always"
start-policy = "load"
standard-output = "~/Library/Logs/example-daemon.log"
standard-error = "~/Library/Logs/example-daemon.log"
profiles = ["workstation"]
```

The provider field identifies native authority. Rig already knows how supported launchd resources are observed, rendered, loaded, stopped, and retired.

## Declare a scheduled job

```toml
[scheduled-job.good-morning]
name = "Good morning"
purpose = "Show a daily workstation notification"
rationale = "A visible job makes scheduler failures easy to notice"
provider = "launchd"
locator = "example.good-morning"
platforms = ["macos"]
desired-state = "enabled"
program = [
  "/usr/bin/osascript",
  "-e",
  "display notification \"Ready\"",
]
schedule.calendar = ["hour=8,minute=0"]
run-policy = "scheduled-only"
priority = "background"
standard-output = "~/Library/Logs/example.good-morning.log"
standard-error = "~/Library/Logs/example.good-morning.log"
profiles = ["workstation"]
```

Use `schedule.interval = "3600"` instead of `schedule.calendar` for a positive interval in seconds. Calendar entries accept comma-separated decimal pairs for `minute`, `hour`, `day`, `weekday`, and `month`. Declare exactly one schedule form.

A job whose program is `rig upgrade --unattended` keeps every declared manager current on one schedule; [Upgrade without watching](unattended-updates.md) carries that recipe and what the run records.

## Name a resource so its owner is obvious

A `locator` is the native label, and `~/Library/LaunchAgents` holds Rig's rendered agents beside every agent an installer put there itself. Give the labels you invent a reverse-DNS form carrying `rig` as their last element before the identifier — `uk.me.kris.rig.good-morning` for `[scheduled-job.good-morning]` — so the label, the file name, and the `rig status` row all read the same, and the managed agents sort together.

Keep a label its own vendor defines. Adopting `sh.example.daemon` unchanged is what stops that tool installing a second agent of its own alongside Rig's, so the prefix is a convention for new labels rather than a rule applied to every resource.

Ownership is therefore recorded in the file rather than in its name. Every rendered plist opens with a comment naming Rig and the declaration it came from, so `grep -l 'Managed by rig' ~/Library/LaunchAgents/*.plist` answers which agents Rig will replace or retire, including those keeping a vendor label.

## Present a resource in Login Items

macOS lists background agents in System Settings, under General, Login Items & Extensions. An agent appears there under the file name of the program it runs, never under its label, so `[scheduled-job.good-morning]` running `~/bin/report` is listed as `report`. Naming the program after the job is what makes that list legible. Name one or more application bundle identifiers to ask for the entry to be presented under an application instead:

```toml
associated-applications = ["com.example.ExampleApp"]
```

Rig renders these as `AssociatedBundleIdentifiers`. macOS decides whether to honour the association, and it honours one only for an agent whose own program carries a code signature: a shell script cannot carry one, so such an agent is recorded with no association and no developer name whatever bundle identifier it names, and keeps its program's file name and a generic icon. `sudo sfltool dumpbtm` shows which of the two happened. Treat the field as a request about presentation, never as a claim about what the agent runs.

## Declare a typed macOS setting

```toml
[setting.show-file-extensions]
name = "Show file extensions"
purpose = "Keep file identities visible in Finder"
rationale = "Visible extensions reduce ambiguity when working with source files"
provider = "macos-defaults"
platforms = ["macos"]
domain = "NSGlobalDomain"
key = "AppleShowAllExtensions"
value-type = "bool"
value = "true"
profiles = ["workstation"]
```

The explicit value type lets Rig validate, compare, and apply the setting without a provider-owned YAML file or arbitrary workstation script.

String settings may use exact whole-value `~`, `~/...`, `$HOME`, or `$HOME/...` forms. File URLs may use exact `file://$HOME` forms. Rig does not expand embedded variables, unrelated environment names, or shell syntax.

## Declare a semantic Dock layout

A Dock layout names ordered items. Applications and folders retain their semantic options:

```toml
[dock-item.system-settings]
kind = "application"
path = "/System/Applications/System Settings.app"

[dock-item.downloads]
kind = "folder"
path = "~/Downloads"
view = "grid"
display = "folder"

[dock.primary]
name = "Primary Dock"
purpose = "Keep frequent workstation destinations in stable order"
rationale = "A semantic layout is portable across equivalent Macs"
provider = "macos-dock"
platforms = ["macos"]
items = ["system-settings", "downloads"]
profiles = ["workstation"]
```

Rig validates resolved item paths before replacing a selected Dock layout. The same exact whole-value home forms are available for Dock paths; other text remains literal.

Status and doctor compare paths and order, then any folder `view` and `display` values you explicitly declared. An omitted attribute is not constrained. A manually changed declared view or display is drift, with a detail naming the item; inaccessible or ambiguous native evidence is unknown, not agreement. Observation reads one shared native Dock snapshot when needed and never changes the Dock. Check the reported difference and your intended declaration before applying a replacement layout.

## Select and inspect the workstation

A workstation is a complete profile, not a provider:

```toml
[profile.workstation]
name = "Workstation"
purpose = "Complete everyday machine intent"
kind = "complete"
```

When `workstation` is not the configured default, place `profiles = ["workstation"]` in each selected declaration. Then inspect the complete profile before mutation:

```sh
rig show --profile workstation
rig show service:example-daemon
rig show scheduled-job:good-morning
rig show setting:show-file-extensions
rig show dock:primary
rig show port:example-api
rig status --profile workstation
rig doctor --profile workstation
rig apply --profile workstation --dry-run
```

Declaration queries are inert. Status and doctor only observe. Dry run preflights the complete plan and discloses programs, schedules, settings, ordered Dock items, paths, policies, and pending retirements without provider mutation or state writes.

## Order related resources

Use qualified `depends-on` references when one managed resource must reconcile before another:

```toml
[service.example-daemon]
# Other service fields appear above.
depends-on = ["setting:show-file-extensions"]

[scheduled-job.good-morning]
# Other scheduled-job fields appear above.
depends-on = ["service:example-daemon"]
```

Supported prefixes are `service:`, `scheduled-job:`, `setting:`, and `dock:`. Rig selects dependencies transitively and produces a deterministic dependency-first plan. Missing targets and cycles fail during configuration loading. A failed resource blocks only its transitive dependants; independent resources remain available.

Dependencies cannot contain conditions, commands, or lifecycle hooks.

## Apply and retire resources

By default, `rig apply` reconciles the exact selected complete profile after full-plan preflight. For one change, preview `rig apply --target scheduled-job:good-morning --dry-run`, then omit `--dry-run` to reconcile only that job and any missing prerequisites. Repeat `--target` for several exact IDs; it composes with `--scope` by intersection. A port target selects its declared owner for reconciliation but does not materialise the port. A targeted apply never retires unrelated stale resources, and its receipt records only the resources it actually reconciled. Apply also stages supported selected manager prerequisites. It needs no bootstrap provider and accepts no arbitrary setup operations.

Rig records only the minimal evidence required to retire a deselected long-lived resource safely. A receipt is not observed state or configuration authority. Removing a service or scheduled job from the selected profile schedules its former native locator for retirement on the next application.

When `--scope` would exclude a missing prerequisite of a requested target, Rig rejects that selection before dispatch. Widen the scope or bring the prerequisite to `present` first.

A resource-local preflight finding prevents that resource from being invoked while independent resources may continue. Any selected resource failure withholds stale-resource retirement and receipt replacement. Always review `rig apply --dry-run` after changing profile membership.

Built-in launchd actions such as log inspection, restart, or running one scheduled job are explicit exceptions to desired-state reconciliation. Use an [external provider action](provider-actions.md) only when the operation cannot be represented by a built-in provider or managed declaration.
