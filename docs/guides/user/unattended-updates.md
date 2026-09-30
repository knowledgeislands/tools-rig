# Upgrade without watching

Use one scheduled `rig upgrade --unattended` to advance software and skills supported by Rig's upgrade providers. ChezMoi application, native housekeeping and unsupported provider lifecycles are not silently included.

## Preview first

```sh
rig upgrade --unattended --dry-run
```

The flag is accepted only by upgrade. Every native invocation receives standard input from `/dev/null`; Homebrew also receives `NONINTERACTIVE=1`. Known work requiring a person, such as a Mac App Store upgrade, is reported unavailable without invocation. Other native failures remain failures: Rig does not guess that every error is a credential problem. Independent targets continue and findings produce status 1.

After reviewing the plan, run `rig upgrade --unattended`. Use an interactive upgrade for work requiring a person.

## Declare a schedule

Rig uses a declared native job rather than implementing a scheduler:

```toml
[scheduled-job.rig-upgrade]
name = "Rig upgrade"
purpose = "Advance declared software on one schedule"
rationale = "One visible report across supported managers"
provider = "launchd"
locator = "example.rig-upgrade"
platforms = ["macos"]
desired-state = "enabled"
program = ["~/.local/bin/rig", "upgrade", "--unattended"]
schedule.calendar = ["hour=4,minute=0"]
run-policy = "scheduled-only"
priority = "background"
standard-output = "~/Library/Logs/example.rig-upgrade.log"
standard-error = "~/Library/Logs/example.rig-upgrade.log"
```

Omitted membership selects the default configuration. Add `--profile NAME` to the program only when another selection is intended. Preview the job with `rig apply --target scheduled-job:rig-upgrade --dry-run`; apply it only after review.

A calendar schedule can recover missed work after sleep, whereas a native interval schedule has different sleep semantics. Use the schedule appropriate to the machine.

## Read the report

Every unattended run that dispatches work atomically replaces `${XDG_STATE_HOME:-$HOME/.local/state}/rig/last-upgrade`, or the same filename below `RIG_STATE_HOME`. A dry run writes nothing.

The tab-separated report starts with `rig-last-run` and version `1`, followed by `action`, `profile`, `platform`, `finished`, `status`, `result`, `detail`, and `summary` records, then the result rows. The action is `upgrade`. Use the status and counts rather than parsing terminal spacing. An unsafe report target is left untouched.

Rig does not send notifications. A host-owned wrapper can read this report and use the platform's notification tool. Migrating wrappers must change both the command and the former `last-update` path; old reports are not deleted and do not describe new runs.

## Review other timers

Doctor can report an observed Homebrew autoupdate agent as information, not a health failure. Rig does not install, reconfigure or delete that agent. Choose whether to retain it alongside Rig's schedule or retire it deliberately through Homebrew. Old `autoupdate-interval` and `autoupdate-options` Rig fields are rejected.

Personal scheduled jobs and wrappers managed by chezmoi must be reviewed in their owning repository. This guide does not imply that changing the Rig executable migrates them.

See [Choose a command](commands.md), [Manage operational resources](operational-resources.md) and [Migrate the command surface](migrating-command-surface.md).
