# Update without watching

A machine running Rig usually ends up with one manager on a private timer and everything else advanced only when somebody remembers. Homebrew's `brew autoupdate` agent is the common case: it is useful, and it covers exactly one of the managers Rig orchestrates, so uv, mise, npm, chezmoi, and the Skills CLI go unattended while the notification tells you the machine is up to date.

One scheduled `rig update --unattended` advances everything the profile declares and records one honest outcome instead.

## Run it by hand first

`--unattended` is accepted by `rig update` and `rig maintain` and by no other command. Try it interactively before scheduling anything:

```sh
rig update --unattended --dry-run
rig update --unattended
```

It changes nothing about which targets are selected, the order they run in, or the statuses the command returns. What it changes is what happens when a provider wants a person:

- Every provider invocation reads end-of-file rather than your terminal, so nothing can block on a prompt. Rig also exports `NONINTERACTIVE=1` for Homebrew, which is Homebrew's own way of saying the same thing.
- Work that cannot proceed without a person — a Mac App Store upgrade, for instance — is reported `unavailable` with the reason and is never invoked. The rest of the run still completes, and the command returns 1 so the gap stays visible. Run `rig update` interactively to finish that part.

## Schedule it as a declared job

Rig has no scheduler and will not grow one. The job is machine state, so it is a declared resource like any other:

```toml
[scheduled-job.rig-update]
name = "Rig update"
purpose = "Advance every declared manager on one schedule"
rationale = "One pass reporting one outcome beats one manager reporting well"
provider = "launchd"
locator = "example.rig-update"
platforms = ["macos"]
desired-state = "enabled"
program = ["~/.local/bin/rig", "update", "--unattended"]
schedule.calendar = ["hour=4,minute=0"]
run-policy = "scheduled-only"
priority = "background"
standard-output = "~/Library/Logs/example.rig-update.log"
standard-error = "~/Library/Logs/example.rig-update.log"
profiles = ["workstation"]
```

Materialise it with `rig apply`. Add `--profile NAME` to `program` if the scheduled run should select a profile other than the default.

## Read the outcome

Each unattended run that dispatches work replaces one file:

```sh
cat "${XDG_STATE_HOME:-$HOME/.local/state}/rig/last-update"
```

```text
rig-last-run	1
action	update
profile	workstation
platform	macos
finished	2026-09-25T04:00:11Z
status	1
result	incomplete
detail	planned=0 completed=11 failed=0 unavailable=1
summary	planned=0 completed=11 failed=0 unavailable=1 skipped=2
TARGET	PROVIDER	RESULT	DETAIL
store-app	homebrew	unavailable	interactive-required
manifest	homebrew	completed	update
```

It is tab-separated text and a stable contract, so a wrapper can read it without parsing terminal output. A dry run writes nothing, because no run happened.

Rig does not notify you. A notification on macOS means `osascript` or `terminal-notifier`, and Rig's only runtime dependency is Bash. Notify from the job's own wrapper instead:

```sh
#!/usr/bin/env bash
rig update --unattended
status=$?
report=${XDG_STATE_HOME:-$HOME/.local/state}/rig/last-update
[ "$status" -eq 0 ] || osascript -e "display notification \"$(awk -F'\t' '$1 == "detail" { print $2 }' "$report")\" with title \"Rig update\""
```

## Retire the manager's own timer

If you already run `brew autoupdate`, `rig doctor` names it as information once it observes the agent:

```text
Information:
  homebrew: autoupdate-agent; owner=homebrew; action=none
```

That is a statement, not a finding: it does not change the exit status, and Rig will never install, modify, or remove another tool's agent for you. Coexistence is fine — the two will simply both update Homebrew. To retire it, run `brew autoupdate delete` yourself.

Rig can also own that agent instead, if you would rather keep Homebrew on its own timer and declare the fact:

```toml
[provider.homebrew]
autoupdate-interval = 86400
autoupdate-options = ["upgrade"]
```

A declared interval makes the agent Rig's own, and `rig doctor` stops reporting it as a competing updater.

## Related

- [Choose a command](commands.md) for the wider command surface and what each exit status means.
- [Manage operational resources and private ports](operational-resources.md) for the scheduled-job declaration in full.
