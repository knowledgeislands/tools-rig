# Declare operational resources

Rig treats a long-running service or scheduled job as part of the selected working setup. Put the declaration in private Rig configuration, select it from a profile, inspect it without execution, and review the complete provider plan before applying it.

## Declare a service

```toml
[service.example-daemon]
name = "Example daemon"
purpose = "Keep the local example endpoint available."
rationale = "The selected development profile depends on the endpoint."
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

Each `program` and `environment` item remains one literal provider argument. Rig does not run a shell, expand embedded variables, or discover missing details from a provider registry.

## Declare a scheduled job

```toml
[scheduled-job.good-morning]
name = "Good morning"
purpose = "Show a daily workstation notification."
rationale = "A small visible job proves the personal scheduler path."
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

## Select and inspect

```toml
[profile.default]
tools = ["example"]
services = ["example-daemon"]
scheduled-jobs = ["good-morning"]
```

```sh
rig show
rig explain service:example-daemon
rig explain scheduled-job:good-morning
rig status
rig doctor
rig apply --dry-run
```

The catalogue queries are inert. Status and doctor invoke only resource observation. Dry-run preflights providers and prints deferred program, environment, schedule, paths, policies, and pending retirements without invoking or recording changes.

## Apply and retire

`rig apply` and `rig bootstrap` reconcile the exact selected resource set after their tool plan. Rig records only the provider, kind, identity, and locator that a successful application managed. Removing a resource from the selected profile makes its receipt entry retirement work on the next apply. Renaming an identity while retaining the same provider, kind, and locator transfers receipt ownership without stopping the native resource.

Review profile changes and `rig apply --dry-run` before applying them. A provider owns native manifests and service-manager mechanics, but it must receive the resolved declaration from Rig rather than parse Rig TOML or call another manager to discover an authority.

## Bind an exceptional action

Generic provider actions remain available for operations such as reading logs or triggering one selected job immediately:

```toml
[action.launchd.run-now]
mode = "mutate"
description = "Run one selected scheduled job immediately."
platforms = ["macos"]
argument-policy = "provider"
resource-kinds = ["scheduled-job"]
```

```sh
rig run launchd run-now -- scheduled-job:good-morning
```

Rig validates that the qualified resource belongs to the default profile and provider, then sends its full declaration before any remaining caller arguments. The action is an escape hatch, not the desired-state model.
