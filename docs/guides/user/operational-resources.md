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

### Share one Dock order across profiles

One layout can serve several machine profiles. Link a machine-specific item to the tool that owns it with `tool = "ID"`; each resolved profile then shows only the linked items whose tool it selects, in the declared order, while unlinked items always show:

```toml
[dock-item.lightroom]
kind = "application"
path = "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app"
tool = "lightroom"
```

The link only filters. It never selects the tool or makes the Dock wait for it. `rig show dock:primary --profile studio` lists each item's declared position, its compact position when included, or `excluded=profile` or `excluded=platform`.

Rig validates resolved item paths before replacing a selected Dock layout. A missing path for an excluded item is ignored; a missing path for an included item is drift. The same exact whole-value home forms are available for Dock paths; other text remains literal.

Status and doctor compare paths and order, then any folder `view` and `display` values you explicitly declared. An omitted attribute is not constrained. A manually changed declared view or display is drift, with a detail naming the item; inaccessible or ambiguous native evidence is unknown, not agreement. Observation reads one shared native Dock snapshot when needed and never changes the Dock. Check the reported difference and your intended declaration before applying a replacement layout.

## Restrict a listener to the tailnet

Some macOS listeners, such as Screen Sharing on port 5900, bind every address and offer no setting to bind one interface. A `[firewall.ID]` declaration keeps chosen ports reachable from loopback and from other devices on your tailnet, and blocks them from any other network:

```toml
[firewall.screen-sharing-tailnet]
name = "Screen Sharing on the tailnet only"
purpose = "Keep remote screen sessions off shared networks"
rationale = "Screen Sharing listens on every address and macOS cannot bind it to one interface"
provider = "macos-pf"
locator = "org.example.rig.firewall.screen-sharing"
platforms = ["macos"]
ports = ["tcp:5900", "udp:5900"]
allow = ["tailnet"]
```

`tailnet` means Tailscale's fixed address ranges, `100.64.0.0/10` and `fd7a:115c:a1e0::/48`. A connection passes only when both its source and destination are in the same range. That shuts out an ordinary local network, but not every one: carrier-grade NAT and some hotspots hand out local addresses from `100.64.0.0/10`, and when your own machine gets one, a neighbour on the same network passes the rule and can reach the port. The rule also names no interface, so a one-way UDP packet with a forged tailnet source can arrive over the local network. On such a network, keep the account password strong or turn the listener off. Each port is `tcp:N` or `udp:N`. Rig rejects port 22 for either protocol, because SSH is how you undo a mistake. `allow` accepts no other value, and the locator is a reverse-DNS label outside `com.apple`.

Rig writes two root-owned files and touches nothing else:

- `/etc/pf.anchors/LOCATOR`, a pf anchor with four rules per port: pass on `lo0`, pass IPv4 tailnet to tailnet, pass IPv6 tailnet to tailnet, then block.
- `/Library/LaunchDaemons/LOCATOR.plist`, a system LaunchDaemon that loads the anchor as `com.apple/LOCATOR` at every boot and whenever `/etc/pf.conf` changes.

Rig never edits `/etc/pf.conf`, never uses the application firewall, and never flushes an anchor it does not own. The anchor sits beneath Apple's own `com.apple/*` anchor point, so a macOS update that restores `/etc/pf.conf` removes nothing Rig owns, and the daemon reloads the anchor afterwards.

Before you apply a firewall for the first time, keep this rollback to hand. It needs no Rig and works over SSH:

```sh
sudo launchctl bootout system/LOCATOR
sudo pfctl -a com.apple/LOCATOR -F all
```

The first command stops the daemon reloading the anchor; the second removes the loaded rules. The files stay until you delete the declaration and apply again, or remove them yourself.

Preview the rendered rules, files and commands, then apply with an attended administrator session:

```sh
rig show firewall:screen-sharing-tailnet
rig apply --target firewall:screen-sharing-tailnet --dry-run
rig apply --target firewall:screen-sharing-tailnet --sudo
```

Without `--sudo`, apply leaves a firewall that needs work untouched and reports it as skipped with `administrator-grant-required`. With the grant, Rig checks the rendered anchor with `pfctl -n` before installing anything, installs the files, loads the daemon, loads the anchor, then rereads the loaded rules and fails unless they match. A correct firewall needs no grant and no prompt.

Status and doctor never use administrator rights. They compare both files with what Rig would render, read the daemon's load state and last exit code, and check whether a declared port listens on every address. A matching firewall reports `present` with `kernel-rules-unverified`, because reading loaded pf rules needs root; `apply --sudo` checks them on every run. A port listening on every address while the firewall is missing or drifted adds `exposed-beyond-tailnet`.

Deleting the declaration and applying with `--sudo` unloads the daemon, flushes only Rig's anchor and removes its two files. pf stays enabled: other components may rely on it, and Apple's anchors alone filter nothing. Removing the firewall from a profile while the catalogue still declares it retires nothing.

On Linux, declare the same restriction with the `linux-nftables` provider and `platforms = ["linux"]`. A profile serving both platforms holds one declaration for each, with the same ports; Rig selects the one for the running platform:

```toml
[firewall.dev-server-tailnet]
name = "Development server on the tailnet only"
purpose = "Keep agent-started listeners off the VPC and the internet"
rationale = "Development servers bind every address by default"
provider = "linux-nftables"
locator = "org.example.rig.firewall.dev-server"
platforms = ["linux"]
ports = ["tcp:3000"]
allow = ["tailnet"]
```

Rig writes two root-owned files and owns one nftables table, `inet rig_NAME`, where NAME is the locator with each `.` and `-` replaced by `_`:

- `/etc/rig/firewall/LOCATOR.nft`, the table with one `input` chain whose policy is accept and four rules per port: accept on `lo`, accept IPv4 tailnet to tailnet, accept IPv6 tailnet to tailnet, then drop.
- `/etc/systemd/system/LOCATOR.service`, a unit that loads the table at every boot, after `nftables.service` and `ufw.service`, and deletes only its own table when stopped.

The chain drops nothing but the declared ports, so it never blocks SSH or another service. Rig never runs `ufw` or `iptables`, never edits `/etc/nftables.conf`, and never flushes the ruleset. If `ufw` is active it keeps governing every other port, and a `ufw` deny on a declared port still wins. Restarting `nftables.service` by hand flushes the whole ruleset, including Rig's table, until the next boot or `rig apply --sudo`. Install the `nftables` package first; without `nft`, apply reports the firewall unavailable. Do not declare Tailscale's own UDP port 41641: peers would fall back to relays. Ports published from a container through a bridge pass the `forward` hook and are not restricted.

Keep this rollback to hand. It needs no Rig and works over Tailscale SSH:

```sh
sudo systemctl disable --now LOCATOR.service
sudo nft delete table inet rig_NAME
```

Apply and preview exactly as on macOS. With the grant, Rig checks the rendered table with `nft -c` before installing anything, installs the files, reloads systemd when the unit changed, enables and restarts the unit, then rereads the table with `nft list table` and fails unless it matches. Status and doctor compare both files, read the unit's state through `systemctl show`, and check listeners with `ss`; the drift reasons are `rules-missing`, `rules-changed`, `unit-missing`, `unit-changed`, `unit-not-enabled`, `unit-not-active` and `unit-result:RESULT`. Retirement disables and stops the unit, deletes only Rig's table and removes its two files.

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
rig show firewall:screen-sharing-tailnet
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

Supported prefixes are `service:`, `scheduled-job:`, `setting:`, `dock:`, and `firewall:`. Rig selects dependencies transitively and produces a deterministic dependency-first plan. Missing targets and cycles fail during configuration loading. A failed resource blocks only its transitive dependants; independent resources remain available.

Dependencies cannot contain conditions, commands, or lifecycle hooks.

## Apply and retire resources

By default, `rig apply` reconciles the exact selected complete profile after full-plan preflight. For one change, preview `rig apply --target scheduled-job:good-morning --dry-run`, then omit `--dry-run` to reconcile only that job and any missing prerequisites. Repeat `--target` for several exact IDs; it composes with `--scope` by intersection. A port target selects its declared owner for reconciliation but does not materialise the port. A targeted apply never retires unrelated stale resources, and its receipt records only the resources it actually reconciled. Apply also stages supported selected manager prerequisites. It needs no bootstrap provider and accepts no arbitrary setup operations.

Rig records only the minimal evidence required to retire a previously managed long-lived resource safely. A receipt is not observed state or configuration authority. Retirement follows the catalogue, not profile membership: a native locator still declared with the same provider and resource kind for this platform is retained even when its resource is absent from the selected profile. Removing its declaration or changing its provider, kind or locator can make the former receipt entry eligible for retirement on a subsequent untargeted application.

When `--scope` would exclude a missing prerequisite of a requested target, Rig rejects that selection before dispatch. Widen the scope or bring the prerequisite to `present` first.

A resource-local preflight finding prevents that resource from being invoked while independent resources may continue. Any selected resource failure withholds stale-resource retirement and receipt replacement. Always review `rig apply --dry-run` after changing profile membership.

For log inspection, restart, or running one scheduled job, use the component's documented native command. Rig has no public imperative action runner. Use an [external provider](provider-actions.md) only when a built-in provider cannot express the required observation or desired-state application.
