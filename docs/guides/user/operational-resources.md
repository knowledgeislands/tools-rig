# Manage services, jobs, settings, and layouts

Rig treats operational resources and stable machine policy as part of the selected working setup. Put the desired state in private Rig configuration, select it from a profile, inspect it without execution, and review the complete plan before applying it.

Built-in providers such as `launchd`, `macos-defaults`, and `macos-dock` need no provider table, adapter name, capability list, or executable protocol configuration.

## Declare a service

```toml
[service.example-daemon]
name = "Example daemon"
purpose = "Keep the local example endpoint available"
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
```

The provider field identifies the native authority. Rig already knows how launchd resources are observed, rendered, loaded, stopped, and retired.

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
program = ["/usr/bin/osascript", "-e", "display notification \"Ready\""]
schedule.calendar = ["hour=8,minute=0"]
run-policy = "scheduled-only"
priority = "background"
standard-output = "~/Library/Logs/example.good-morning.log"
standard-error = "~/Library/Logs/example.good-morning.log"
```

Use `schedule.interval = "3600"` instead of `schedule.calendar` for a positive interval in seconds. Calendar entries accept comma-separated `minute`, `hour`, `day`, `weekday`, and `month` decimal pairs. Declare exactly one schedule form.

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
```

The explicit value type lets Rig validate, compare, and apply the setting without a provider-owned YAML file or an arbitrary workstation script.

String settings may use exact whole-value `~`, `~/...`, `$HOME`, or `$HOME/...` forms. A file URL may use exact `file://$HOME` or `file://$HOME/...`. Rig expands those values consistently for observation, preview validation, and application while `rig explain` retains the authored value. It does not expand embedded variables such as `prefix-$HOME`, other names such as `$WORK_HOME`, or shell syntax.

## Declare a semantic Dock layout

A Dock layout names ordered items. Applications and folders retain their own semantic options:

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
purpose = "Keep frequent workstation destinations in a stable order"
rationale = "A semantic layout is portable across equivalent Macs"
provider = "macos-dock"
platforms = ["macos"]
items = ["system-settings", "downloads"]
```

Rig validates every item and required path before replacing the selected Dock layout.

Dock paths accept exact whole-value `~`, `~/...`, `$HOME`, and `$HOME/...` forms. Rig validates the resolved path before replacing a selected layout; all other text remains literal.

## Select a workstation

A workstation is a profile composed from the declarations it needs:

```toml
[profile.workstation]
name = "Workstation"
purpose = "Complete everyday machine intent"
kind = "complete"
```

Place `profiles = ["workstation"]` in each selected tool, service, scheduled job, setting, and Dock declaration. A declaration without `profiles` belongs to the configured default profile; use explicit membership when `workstation` is not that default.

Inspect the complete profile before mutation:

```sh
rig show --profile workstation
rig explain service:example-daemon
rig explain scheduled-job:good-morning
rig explain setting:show-file-extensions
rig explain dock:primary
rig status --profile workstation
rig doctor --profile workstation
rig apply --profile workstation --dry-run
```

Declaration queries are inert. Status and doctor perform observation only. Dry-run preflights the complete plan and discloses deferred programs, schedules, settings, ordered Dock items, paths, policies, and pending retirements without invoking providers or writing state.

Configuration, provider trust, executable, platform, and receipt-boundary failures reject the complete plan before mutation. A finding local to one resource appears as a failed row while independent resources remain planned.

## Apply and retire

A resource with a local preflight finding is not invoked, independent resources may still reconcile, and the command exits with status 1. Any selected resource failure withholds stale retirement and receipt replacement.

`rig apply` reconciles the exact selected profile after complete preflight. `rig bootstrap` first identifies and verifies required managers and then performs the same declared reconciliation; it does not install missing manager systems, and neither command requires a bootstrap provider or setup tools.

Rig records only minimal successful-application evidence needed to retire a deselected long-lived resource safely. A receipt is not observed state or configuration authority. Removing a service or scheduled job from the selected profile makes its former native locator retirement work on the next apply.

Review profile changes and `rig apply --dry-run` before applying them. Native providers own their manifests and operating mechanics, but the selected desired state comes from Rig configuration.

## Use provider operations only for exceptions

Built-in launchd operations can expose exceptional tasks such as reading logs, restarting a selected service, or triggering one scheduled job immediately:

```sh
rig run launchd logs -- service:example-daemon
rig run launchd run -- scheduled-job:good-morning
```

These explicit operations do not replace the desired-state model. Use an [external provider action](provider-actions.md) only when the operation cannot be expressed through a built-in provider or managed declaration.
