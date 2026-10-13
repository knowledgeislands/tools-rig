---
id: KI-TOOL-RIG-CORE-051
area: CORE
title: Linux tailnet-only listener firewall
initiative: rig
kind: deliver
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T23:40:07Z
updated_at: 2026-10-13T23:40:07Z
---

# KI-TOOL-RIG-CORE-051: Linux Tailnet-Only Listener Firewall

## Goal

The `[firewall.ID]` declaration delivered by [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) works on Linux through a second built-in provider, `linux-nftables`. The same ports and `allow = ["tailnet"]` keep declared listeners reachable only from loopback and the tailnet, so the person's Macs and a Linux agent host, such as Techne's Ubuntu host on AWS, share one firewall model. `rig apply --sudo` installs a Rig-owned nftables table that survives restarts; `rig doctor` reports the same kinds of drift as on macOS. Port 22 is never filtered.

## Context

Kris approved a Linux provider in mac-studio-bootstrap Decision 51 (14 October 2026), answering AGENT-HOST-FW, which Decision 50 left open. KI-TOOL-RIG-CORE-047 deliberately left Linux out (FW-LINUX, Decision 49) and shaped the declaration so a later provider needs no schema change. That record is Awaiting review; its code is on `main`.

Techne's agent host runs Ubuntu on AWS and is reached only through Tailscale SSH. Its boot script disables OpenSSH (`ssh.socket` and `ssh.service`) and the SSM agent, and installs neither `nftables` nor `ufw` rules; its security group has no ingress rules. The host is described by the Rig profile `agent-host` in `ki-techne-harness/recipes/agent-host/rig.toml`. Any listener an agent starts on that host is reachable from the VPC and, through its public address, would be reachable from the internet the moment a security-group rule opened it. A host firewall gives the tailnet-only guarantee independently of the AWS perimeter.

## Boundary

- **In:** the `linux-nftables` built-in provider for `firewall` declarations; validation per provider; rendering a Rig-owned nftables table and a systemd unit; unprivileged observation in `rig status`, `rig doctor` and `rig show`; `rig apply --sudo` install and repair; catalogue-scoped retirement under [ADR-KI-TOOL-RIG-008](../decisions/ADR-KI-TOOL-RIG-008-catalogue-scoped-resource-retirement.md); dry-run projection; specification, decision, guide, help, manual, changelog and test alignment.
- **Out:** installing the `nftables` package or Tailscale (the host's bootstrap provides them); `ufw`, `iptables`, `firewalld` and `/etc/nftables.conf`, which Rig neither edits, enables nor reads; forwarded traffic, including container ports published through Docker's `FORWARD` path; arbitrary CIDR allow-lists, outbound rules or NAT; any change to the macOS provider's behaviour; any personal or recipe declaration; any apply on a real host.

## Current state

- `src/rig/29-firewall.bash` implements `macos-pf` only. `rig_validate_firewall` requires `provider = "macos-pf"` and macOS platforms; observation and preflight return `unsupported-platform` off macOS; retirement dispatches `macos-pf` in `src/rig/21-provider-state.bash`.
- The isolation helper already roots `RIG_SYSTEM_ROOT` in each test's tree and stubs `sudo`, `pfctl` and `netstat`.
- The attended grant ([RIG-ORCH-043](../specs/orchestration.md)) is platform-neutral: `rig_sudo_start` uses `sudo -v`, `sudo -n -v` and a keeper loop that run unchanged on Linux.
- Ubuntu ships `ss` (iproute2) on every image; `netstat` (net-tools) is not installed by default.
- The agent-host stack's VPC is `10.90.0.0/24` with no IPv6, so it does not overlap Tailscale's `100.64.0.0/10`.

## Steps

- [ ] Re-read authority and source, establish the immutable baseline through `ki-implement`, and keep the boundary. Stop for review if source drift changes the provider, sudo or retirement assumptions below.
- [ ] Register `linux-nftables` as a built-in adapter with `resource-observe`, `resource-apply` and `resource-retire`. Make `rig_validate_firewall` accept either provider, requiring `platforms = ["macos"]` for `macos-pf` and `platforms = ["linux"]` for `linux-nftables`. Keep the locator, port, port-22 and `allow` rules unchanged. Reject two firewall declarations whose derived nftables table names collide.
- [ ] Render deterministically: the rules file `/etc/rig/firewall/LOCATOR.nft` and the unit `/etc/systemd/system/LOCATOR.service`, each opening with the "Managed by rig" comment. The table is `inet rig_NAME`, where NAME is the locator with `.` and `-` replaced by `_`. Its one base chain hooks `input` at `priority filter` with `policy accept`; for each declared port it accepts `iif "lo"`, accepts tailnet-to-tailnet on both families (source and destination both in `100.64.0.0/10`, or both in `fd7a:115c:a1e0::/48`), then drops the port from anywhere else. The file opens with `table inet rig_NAME` and `delete table inet rig_NAME`, so one `nft -f` replaces the table atomically. The unit is a `oneshot` with `RemainAfterExit=yes`, `ExecStart=/usr/sbin/nft -f FILE`, `ExecStop=-/usr/sbin/nft delete table inet rig_NAME`, with `DefaultDependencies=no`, `Wants=network-pre.target`, `After=nftables.service ufw.service`, `Before=network-pre.target shutdown.target`, `Conflicts=shutdown.target` and `WantedBy=multi-user.target`, the same early-boot shape as Ubuntu's own `nftables.service`.
- [ ] Observe without privilege: rendered and on-disk files compared byte for byte; `systemctl show LOCATOR.service -p LoadState -p ActiveState -p UnitFileState -p Result`; and a fixed read-only `ss -Hltun` listener source (injectable as `RIG_SS_COMMAND`) for whether each declared port listens on every address. Report `present` with `kernel-rules-unverified`, `missing`, `drifted` or `unavailable` per [RIG-STATE-021](../specs/state.md), with the drift reasons in [Proposed contract](#proposed-contract). Read-only commands never call `sudo` or `nft`.
- [ ] Apply only under `rig apply --sudo` through the attended grant with `sudo -n`; without it a firewall needing work is `skipped` with `administrator-grant-required`, as on macOS. Order: `nft -c -f RENDERED` (check only); install the rules file and unit root-owned `0644` with `install -D`; `systemctl daemon-reload` when the unit changed; `systemctl enable LOCATOR.service` when not enabled; `systemctl restart LOCATOR.service`; reread with `nft list table inet rig_NAME` and fail unless it matches the rendered rules. A correct, enabled, active resource whose loaded rules match is a no-op.
- [ ] Retire when the catalogue no longer declares the locator: `systemctl disable --now LOCATOR.service`, `nft delete table inet rig_NAME` only if `nft list table` finds it, remove both files, then `systemctl daemon-reload`. Never `nft flush ruleset`, never touch another table.
- [ ] Extend dry-run projection, `rig show firewall:ID` text and JSON, the doctor counts and help so they describe the Linux files, table and commands.
- [ ] Extend `tests/helpers/isolate.bash` to refuse `nft`, `systemctl` and `ss` by default (`RIG_NFT`, `RIG_SYSTEMCTL`, `RIG_SS_COMMAND`) and add isolated Bats coverage, `tests/rig-firewall-linux.bats`, with `RIG_PLATFORM=linux`, stubbed `sudo`, `nft`, `systemctl` and `ss`, and every system path beneath `RIG_SYSTEM_ROOT`. Extend the isolation guard in `tests/rig.bats`.
- [ ] Align specifications, propose a decision record, update guides, help, manual and the active changelog; assemble `bin/rig`; run the focused set and the complete gate; assemble an honest review packet. Live acceptance stays withheld.

## Files touched

Planning changes this record, [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) (a cross-link in its Discussion) and [the issue ledger](_ISSUES.md). Expected delivery scope:

- [Firewall module](../../src/rig/29-firewall.bash) and a new `src/rig/29-firewall-nftables.bash`; [configuration](../../src/rig/10-configuration.bash), [orchestration](../../src/rig/20-orchestration.bash), [provider state](../../src/rig/21-provider-state.bash), [application](../../src/rig/23-application.bash), [commands](../../src/rig/30-commands.bash), [runtime help](../../src/rig/00-runtime.bash), [assembler](../../scripts/assemble-rig) and the assembled [executable](../../bin/rig).
- New `tests/rig-firewall-linux.bats`; [isolation helper](../../tests/helpers/isolate.bash); [isolation guard](../../tests/rig.bats); [macOS firewall tests](../../tests/rig-firewall.bats) only where a shared message changes.
- [Configuration](../specs/configuration.md), [orchestration](../specs/orchestration.md) and [state](../specs/state.md) specifications; a new proposed ADR and [the decision index](../decisions/README.md); [operational resources](../guides/user/operational-resources.md) and [commands](../guides/user/commands.md) guides; [README](../../README.md); [manual](../../man/rig.1); [changelog](../../CHANGELOG.md).

## Verify

Every test calls `rig_test_isolate` first, sets `RIG_PLATFORM=linux`, and asserts on stub argument logs, never on the machine.

- **Validation:** `linux-nftables` with `platforms = ["macos"]`, or `macos-pf` with `["linux"]`, fails; `tcp:22` and `udp:22` fail for both providers; colliding derived table names fail; a `linux-nftables` declaration selected on macOS is refused by the existing platform rule.
- **Rendering:** the rules file and unit for `["tcp:5900", "udp:5900"]` match golden text exactly; every rule names port 5900; no rule names 22 or lacks a port match; the chain's policy is `accept`; both tailnet ranges appear as source and destination; the unit's `ExecStart` and `ExecStop` name only Rig's table.
- **Read-only boundary:** `status`, `doctor`, `show` and `apply --dry-run` log no `sudo`, `nft` or `systemctl` mutation and write nothing under the redirected system root.
- **Observation:** current files with an enabled, active unit are `present` with `kernel-rules-unverified`; absent files and unit are `missing`; edited files, a disabled or inactive unit, or a failed result are `drifted` with the reasons below; a declared port listening on every address adds `exposed-beyond-tailnet` when the restriction is not present; `ss` or `systemctl show` failure reports `unavailable` or `unknown`.
- **Apply:** with a grant, the exact ordered argv runs once and a second apply is a no-op; `nft -c` failure installs nothing; a reread mismatch fails; without the grant, the firewall is skipped with `administrator-grant-required` and no native call runs. `ufw`, `iptables`, `/etc/nftables.conf` and `flush ruleset` appear in no log.
- **Retirement:** deleting the declaration retires exactly the receipted locator in the order above; profile deselection retires nothing; a failed retirement keeps its receipt row.

Run the focused set with stdin closed:

```sh
bats tests/rig-firewall-linux.bats tests/rig-firewall.bats tests/rig-sudo-session.bats tests/rig-profile-authority.bats tests/rig-cli-surface.bats </dev/null
```

Then run [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository), including a hostile inherited `XDG_STATE_HOME` run because the isolation helper changes.

**Live acceptance, withheld.** It needs a Linux host and Kris's separate approval. For the agent host it also waits for the Techne Programme Hold to allow remote-environment management. The check: with a Tailscale SSH session open, apply on a disposable or attended host, then confirm Tailscale SSH still connects, the declared port answers over the tailnet and is refused from the VPC, the table survives a reboot, and `nft list table` output matches the normalised rendering.

## Dependencies / blocks

`blocks: []` and `blocked_by: []`. The code builds on KI-TOOL-RIG-CORE-047's module on `main`; review is easiest after, or together with, that record's review. The agent-host recipe's adoption is handed to `ki-techne-harness` as its own record; it depends on a Rig release that contains this provider.

## Documentation impact

### Decision Records

Propose `ADR-KI-TOOL-RIG-010` (Linux firewall through a Rig-owned nftables table): why nftables with its own table rather than `ufw`, why a Rig-owned systemd unit rather than `/etc/nftables.conf`, and how it coexists with other firewalls. [ADR-KI-TOOL-RIG-009](../decisions/ADR-KI-TOOL-RIG-009-system-domain-resources-under-an-attended-grant.md) stays unchanged while it is under review.

### Specifications

Extend RIG-CONF-030 with the provider and platform pairing and the table-name collision; RIG-ORCH-023 or a Linux companion with `linux-nftables` and its never-touch list; RIG-ORCH-043 is unchanged in wording because a firewall already counts as grant-needing work; RIG-STATE-045 with the Linux evidence and drift reasons.

### Guides

Extend "Restrict a listener to the tailnet" in [operational resources](../guides/user/operational-resources.md) with a Linux declaration, what Rig installs, what doctor can see, coexistence with `ufw`, and a no-Rig rollback stated before the apply step (`sudo systemctl disable --now LOCATOR.service` and `sudo nft delete table inet rig_NAME`). Update [commands](../guides/user/commands.md), help, the manual and the changelog.

### Roadmap

Kris approved this record and its plan in principle in Decision 51; see [Plan approval](#plan-approval).

## Discussion

### Provider choice

**nftables with a Rig-owned table**, not `ufw`.

- **Additive and narrow.** An nftables table is Rig's alone. Its chain only ever drops the declared ports from outside the tailnet, with `policy accept`, so it cannot block anything else. In nftables every base chain on the `input` hook sees the packet, and a `drop` in any chain is final, so Rig's table restricts the declared ports whatever other firewall is present, and never loosens one.
- **`ufw` is a whole-host policy manager.** Using it means enabling it, which applies its default-deny incoming policy to every port, including SSH unless an allow rule exists first. That is the lockout this design must avoid, and it would make Rig the owner of the host's entire inbound policy, beyond the declared ports.
- **Ubuntu fit.** Ubuntu's `ufw` and `iptables` already run on the nftables kernel back end (`iptables-nft`), so a separate `inet` table is the native way for a second component to add rules. Ubuntu 22.04 and later ship `nft` 1.0 or newer; the `table` then `delete table` idiom works on every release.

**If `ufw` is active,** Rig leaves it alone. Both apply: `ufw`'s rules still govern every other port; a `ufw` allow of a declared port from anywhere is narrowed by Rig's drop; a `ufw` deny of a declared port still wins, so Rig cannot open a port `ufw` blocks. Doctor cannot see `ufw` rules without root and does not try. **If `nftables.service` is enabled,** Ubuntu's `/etc/nftables.conf` starts with `flush ruleset`. Rig's unit is ordered after it, so a boot loads Rig's table last; a later manual `systemctl restart nftables` or `nft flush ruleset` removes Rig's table until the next boot or `apply --sudo`. That is the same residual risk as a VPN client flushing pf on macOS, recorded in the ADR.

### Proposed contract

```toml
[firewall.dev-server-tailnet]
name = "Agent dev server on the tailnet only"
purpose = "Keep agent-started listeners off the VPC and the internet"
rationale = "Agent tools bind every address by default"
provider = "linux-nftables"
locator = "org.example.rig.firewall.dev-server"
platforms = ["linux"]
ports = ["tcp:3000"]
allow = ["tailnet"]
profiles = ["agent-host"]
```

- **One model, one declaration per platform.** A firewall resource has one provider, as every resource does. A profile serving both platforms holds one `macos-pf` and one `linux-nftables` declaration with the same ports; selection picks the one for the running platform.
- **Match by address, as on macOS.** The tailnet rule needs source and destination both in a tailnet range, so a VPC or carrier-grade NAT peer holding a `100.64.0.0/10` address cannot reach the port unless the host's own address is also a tailnet address. Matching `tailscale0` was considered and not chosen: Tailscale's userspace-networking mode has no such interface, and the address rule is already proven on macOS.
- **Paths.** Rules at `/etc/rig/firewall/LOCATOR.nft`, unit at `/etc/systemd/system/LOCATOR.service`; neither is a distribution-owned file, so package upgrades leave them alone.
- **Persistence.** The enabled unit loads the table at every boot, after `nftables.service` and `ufw.service` and before the network comes up. Stopping the unit removes the table.
- **Doctor's view.** Without root, doctor sees both files, the unit's load, active and enablement state, and whether a declared port listens on every address. Listing the table needs root, so a present restriction is reported `kernel-rules-unverified`; `apply --sudo` rereads it every run.
- **Drift reasons.** `rules-missing`, `rules-changed`, `unit-missing`, `unit-changed`, `unit-not-enabled`, `unit-not-active` and `unit-result:RESULT`, plus `exposed-beyond-tailnet` and `kernel-rules-unverified` exactly as on macOS. They match KI-TOOL-RIG-CORE-047's `anchor-*`, `daemon-*`, `daemon-not-loaded` and `daemon-last-exit:N` in structure; the names follow the native objects, because a pf anchor and a LaunchDaemon do not exist on Linux. `unit-not-enabled` is new: it is the Linux form of "will not survive a restart".
- **Sudo route.** Unchanged: the attended `apply --sudo` grant, consumed with `sudo -n`; an agent host is reached over Tailscale SSH, where the operator answers the one prompt.

### Risks

- **Locking the operator out.** Port 22 is refused at validation; the agent host has no OpenSSH listener at all and is reached through Tailscale SSH, which `tailscaled` serves and the declared-port rules never name. The chain has no default drop, `nft -c` checks before load, and the guide's rollback needs only two commands. Declaring Tailscale's own UDP 41641 would push peers to relays but not cut access; the guide warns against it.
- **AWS networking.** Security groups sit outside the host and are unaffected. Instance metadata, DNS, Time Sync, SSM and Tailscale are outbound; Rig's chain hooks `input` only and names declared ports only.
- **`nftables` absent.** Preflight reports `nft-unavailable` and the firewall stays unapplied; the host's bootstrap must install the package. Rig has no `apt` provider and does not gain one here.
- **Forwarded traffic.** Container ports published through Docker reach the host on the `forward` hook, not `input`, so this resource does not restrict them. Recorded as a boundary, not silently implied.
- **Reread formatting.** Comparing `nft list table` output with the rendering is proven only against fixtures; a mismatch fails apply safely. Confirmed in live acceptance.

### Approval boundary

Approval moves this record to Ready and permits local, fixture-backed delivery through `ki-implement` to Awaiting review only. It grants no personal or recipe declaration, no `rig apply` on any host, no live `nft`, `systemctl` or `sudo` call, no remote or AWS action, and no acceptance, pruning or release.

### Plan approval

Kris approved this work in mac-studio-bootstrap Decision 51 (14 October 2026): "a Linux firewall provider in tools-rig, Next horizon, planned to Ready and delivered now (fixtures only), plus a ki-techne-harness roadmap item for the agent-host recipe to declare it. No live apply on the agent host (Techne Programme Hold)." The task approved the plan in principle where it follows KI-TOOL-RIG-CORE-047's shape with no new authority. It does: the same declaration, the same attended grant, the same unprivileged doctor, the same retirement rule, Rig-owned files only, and no new privilege or remote action. The one new choice, nftables over `ufw`, narrows Rig's reach rather than widening it, so the record is Ready at Next under that approval.
