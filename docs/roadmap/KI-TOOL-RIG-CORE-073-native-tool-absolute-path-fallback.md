---
id: KI-TOOL-RIG-CORE-073
area: CORE
title: Native tool absolute-path fallback
purpose: corrective
theme: rig
kind: deliver
status: awaiting-review
horizon: now
priority: medium
size: s
blocks: []
blocked_by: []
baseline_ref: 4944b1b420140a6a44cc1bf3d75d57a98fe69c7d
created_at: 2026-10-24T10:50:17Z
updated_at: 2026-10-27T02:40:00Z
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

## Current state

Grounded at `4944b1b420140a6a44cc1bf3d75d57a98fe69c7d` on 27 October 2026. `rig_lsof_command` and `rig_ps_command` in [22-observation.bash](../../src/rig/22-observation.bash) took the `RIG_*_COMMAND` override or `command -v` and nothing else; `rig_firewall_netstat` in [29-firewall.bash](../../src/rig/29-firewall.bash) took the override or the fixed `/usr/sbin/netstat` and never `PATH`. Every other native lookup, `launchctl`, `defaults`, `killall`, `plutil`, `osascript`, `mdls`, `xcode-select`, `pkgutil`, `sw_vers`, `ifconfig` and `pfctl`, already names a fixed absolute path behind its override, so a minimal `PATH` cannot lose it. A missing `lsof` and a failed `lsof` run both reported `listener-observation-unavailable`.

## Steps

- [x] Add `rig_native_command`, one discovery rule: the explicit override, then `PATH`, then the fixed directories `/usr/sbin:/sbin:/usr/bin:/bin`, which `RIG_NATIVE_TOOL_DIRS` replaces so a fixture never reaches the real `/usr/sbin`.
- [x] Route `lsof`, `ps` and the firewall's `netstat` through it; leave the fixed-path lookups as they are.
- [x] Report `lsof-missing` when no location names the tool, keeping `listener-observation-unavailable` for a run that fails or returns malformed output.
- [x] Add the Bats regression: status under `PATH=/usr/bin:/bin` with the fake at the fallback directory observes the port; with no fallback it reports `lsof-missing`.
- [x] Align RIG-ORCH-031, the operational-resources guide, the man page and the changelog; reassemble `bin/rig`; run the full gate.

## Files touched

- `src/rig/22-observation.bash`, `src/rig/29-firewall.bash`, `src/rig/00-runtime.bash`, `src/rig/10-configuration.bash`, and the assembled `bin/rig`
- `tests/rig.bats`
- `docs/specs/orchestration.md` (RIG-ORCH-031), `docs/guides/user/operational-resources.md`, `man/rig.1`, `CHANGELOG.md`
- This record.

## Verify

- `bats tests/` passes, including the new test under a `PATH` of `/usr/bin:/bin` alone.
- `shellcheck` and `bash -n` over the modules and executable, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1`, `git diff --check` and `ki repo audit --repo .` pass.
- A status run with `RIG_LSOF_COMMAND` unset and `PATH=/usr/bin:/bin` finds `/usr/sbin/lsof` on macOS; `terra`'s scheduled health job is left to confirm on its next run, since its environment is not changed here.

## Dependencies / blocks

None. Blocks nothing. [KI-TOOL-RIG-CORE-071](KI-TOOL-RIG-CORE-071-firewall-exposure-wording.md) touches the firewall observer's reason wording, not the `netstat` lookup, so the two do not overlap.

## Documentation impact

### Decision Records

None.

### Specifications

RIG-ORCH-031 in `docs/specs/orchestration.md` states the discovery rule and the `lsof-missing` detail.

### Guides

`docs/guides/user/operational-resources.md` tells a reader how `lsof` is found and what `lsof-missing` means; `man/rig.1` carries the same under private ports.

### Roadmap

This record only.

## Review

### Delivered

The Boundary's In clause and nothing more: one discovery rule for the native tools Rig observes with, applied to `lsof`, `ps` and `netstat`, the other native lookups reviewed and left as they are because each already names a fixed path, a detail that names the missing tool, the Bats regression under a minimal `PATH`, and the spec, guide, man page and changelog aligned. No job environment was changed. Immutable baseline `4944b1b420140a6a44cc1bf3d75d57a98fe69c7d` on `main`.

Adopted from triage to Now and delivered on 27 October 2026 under Kris's "Do the quick wins now" on the ways-of-working [roadmap sweep](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/design/roadmap-sweep.md), bucket C. The Discussion's open point, whether the fixed location should come before `PATH`, is settled as the Boundary wrote it: `PATH` first, so a deliberate override on `PATH` still works and the explicit `RIG_*_COMMAND` override settles any shadowing; `netstat` therefore now consults `PATH` before `/usr/sbin`, where before it never did.

### Change Summary

- `src/rig/22-observation.bash`: `rig_native_command TOOL OVERRIDE` resolves the override, then `PATH`, then `RIG_NATIVE_TOOL_DIRS` or the default `/usr/sbin:/sbin:/usr/bin:/bin`; `rig_lsof_command` and `rig_ps_command` call it; `rig_load_listeners` sets `RIG_LISTENER_OBSERVATION_DETAIL=lsof-missing` when no location names `lsof`, and the two unavailable rows print that detail.
- `src/rig/29-firewall.bash`: `rig_firewall_netstat` calls the shared rule.
- `src/rig/00-runtime.bash`, `src/rig/10-configuration.bash`: `RIG_LISTENER_OBSERVATION_DETAIL` initialised and reset to `listener-observation-unavailable`.
- `tests/rig.bats`: "listener observation finds lsof in its system directory when PATH stops at /bin".
- `docs/specs/orchestration.md`, `docs/guides/user/operational-resources.md`, `man/rig.1`, `CHANGELOG.md`: the rule, the detail and the test described.
- `bin/rig`: reassembled.

### Verification

- `bats tests/`: 646 tests pass, the new fallback test among them.
- `shellcheck` and `bash -n` over `bin/rig`, `install.sh`, every module and the three scripts: pass.
- `scripts/assemble-rig --check`, `scripts/benchmark-rig` (show 1s, show-all 2s, status 3s, all within budget), `scripts/smoke-native-providers` (npm, chezmoi, mas pass), `mandoc -T lint man/rig.1`, `git diff --check`: pass.
- `ki repo audit --repo .`: FAIL=1 WARN=5, the one failure being SHELL-HOOK's reading of the untouched `.githooks/pre-commit` (it takes the hook's `quiet_audit` function as a non-check-only gate), present at baseline and not changed by this record.
- Pre-commit hook (shellcheck, `bash -n`, mandoc lint, staged `ki-repo-tools` audit): ran on the commit.
- Not run: a live `rig status` under a minimal `PATH` against the workstation.

### Outstanding concerns

- `terra`'s daily health job now carries `/usr/sbin:/sbin` in its own `PATH` through chezmoi, so its next run proves nothing about the fallback; a run with `PATH=/usr/bin:/bin` by hand does.
- `netstat` discovery now consults `PATH` before `/usr/sbin`, a behaviour change the firewall tests do not exercise because they always set `RIG_NETSTAT_COMMAND`.

### Post-change review

Goal met: `lsof` is found in its system directory when `PATH` stops at `/bin`, a missing tool is named, and the test proves it without reaching the real `/usr/sbin`. Scope held to the In clause. Regression risk is low: resolution order is unchanged for every caller that sets an override or has the tool on `PATH`, and the only new reporting value appears where observation was already unavailable. Ready for acceptance.

### Mini recap

Delivered the shared native-tool discovery rule with its named missing-tool detail, test and documents; verified by the full gate; outstanding is a by-hand confirmation under a minimal `PATH` on a workstation. Learning route: none proposed.

## Discussion

- Whether the fixed location should come before `PATH`, as `netstat` does today, so a shadowing `lsof` earlier on `PATH` cannot change the observation, or after it, so a deliberate override on `PATH` still works.
