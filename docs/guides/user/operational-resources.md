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

A job whose program is `rig update --unattended` keeps every declared manager current on one schedule; [Update without watching](unattended-updates.md) carries that recipe and what the run records.

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
rig explain service:example-daemon
rig explain scheduled-job:good-morning
rig explain setting:show-file-extensions
rig explain dock:primary
rig explain port:example-api
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

`rig apply` reconciles the exact selected complete profile after full-plan preflight. `rig bootstrap` may first stage Rig's fixed declared manager prerequisites, then performs the same declared reconciliation. Neither command needs a bootstrap provider or accepts arbitrary setup operations.

Rig records only the minimal evidence required to retire a deselected long-lived resource safely. A receipt is not observed state or configuration authority. Removing a service or scheduled job from the selected profile schedules its former native locator for retirement on the next application.

A resource-local preflight finding prevents that resource from being invoked while independent resources may continue. Any selected resource failure withholds stale-resource retirement and receipt replacement. Always review `rig apply --dry-run` after changing profile membership.

Built-in launchd actions such as log inspection, restart, or running one scheduled job are explicit exceptions to desired-state reconciliation. Use an [external provider action](provider-actions.md) only when the operation cannot be represented by a built-in provider or managed declaration.
