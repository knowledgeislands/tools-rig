---
id: KI-TOOL-RIG-CORE-073
area: CORE
title: Native tool absolute-path fallback
purpose: corrective
theme: rig
status: triage
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-24T10:50:17Z
updated_at: 2026-10-24T10:50:17Z
---

# KI-TOOL-RIG-CORE-073: Find Native macOS Tools Outside a Minimal PATH

## Goal

Rig finds the macOS system tools it observes with, such as `lsof`, in their fixed system locations when they are not on `PATH`. A Rig run under launchd, cron or any other minimal environment observes declared listeners exactly as an interactive run does, and a test proves it under a `PATH` of `/usr/bin:/bin` alone.

## Context

`terra`'s scheduled workstation health job reported `port.headroom`, `port.mcporter-http` and `port.observatory` as `unavailable (listener-observation-unavailable)` every day, while an interactive `rig doctor` found them healthy (`HEALTH-PORTS` in the [hk-query-review report](/Users/krisbrown/.local/state/ki/agents/chezmoi/hk-query-review.report.md)). The job's declared `PATH` stopped at `/bin`. [`rig_lsof_command`](../../src/rig/22-observation.bash) at line 41 takes `RIG_LSOF_COMMAND` or `command -v lsof` and nothing else, and `/usr/sbin/lsof` is not on such a `PATH`, so [`rig_load_listeners`](../../src/rig/22-observation.bash) at line 117 marks listener observation unavailable for every port. The chezmoi source now gives its scheduled jobs `/usr/sbin:/sbin`, which removes the symptom on Kris's machines but not the cause for any other caller.

The firewall probe already does the other half: `rig_firewall_netstat` in [29-firewall.bash](../../src/rig/29-firewall.bash) takes `RIG_NETSTAT_COMMAND` or the fixed `/usr/sbin/netstat`, never `PATH`. Listener observation and firewall observation therefore disagree about where the same class of tool is found.

## Boundary

- **In:** one shared discovery rule for native macOS tools Rig observes with: the explicit `RIG_*_COMMAND` override first, then `PATH`, then a fixed absolute location under `/usr/sbin`, `/sbin`, `/usr/bin` or `/bin`; applying it to `lsof`, and reviewing other native lookups (`netstat`, `launchctl`, `defaults`, `plutil`, `pfctl` and similar) for the same gap; a `doctor` detail that names the missing tool when none is found; a Bats regression test that runs listener observation under the isolation helper's `/usr/bin:/bin` `PATH` with a stub at the fallback location; specification and guide alignment.
- **Out:** changing any personal job's environment, which the chezmoi source owns; observing listeners on Linux; privileged observation.

## Dependencies / blocks

None. Blocks nothing. The fallback location must stay overridable in tests, so planning decides how a test points it at a stub without reaching the real `/usr/sbin`; [KI-TOOL-RIG-CORE-071](KI-TOOL-RIG-CORE-071-firewall-exposure-wording.md) also touches the firewall listener probe, so check for overlap.

## Discussion

- Whether the fixed location should come before `PATH`, as `netstat` does today, so a shadowing `lsof` earlier on `PATH` cannot change the observation, or after it, so a deliberate override on `PATH` still works.
