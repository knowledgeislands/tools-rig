---
id: KI-TOOL-RIG-CORE-071
area: CORE
title: Firewall exposure wording
purpose: corrective
theme: rig
kind: deliver
status: awaiting-review
horizon: now
priority: low
size: s
blocks: []
blocked_by: []
baseline_ref: a3b7f574cd0ebb95ee58fabde2dcd52268fb9e62
created_at: 2026-10-23T06:43:00Z
updated_at: 2026-10-27T03:00:00Z
---

# KI-TOOL-RIG-CORE-071: Word Firewall Exposure as a Listener Observation

## Goal

`rig doctor` and `rig status` describe a drifted firewall's listener evidence for what it is: a point-in-time observation that a declared port was listening on all addresses. A reader cannot take the finding as proof that the port is reachable from beyond the tailnet, and cannot take its absence as proof that the firewall has been repaired.

## Context

On 23 October 2026 `terra`'s `firewall.screen-sharing-tailnet` finding read `drifted (anchor-changed,exposed-beyond-tailnet)` in one `rig doctor` run, `drifted (anchor-changed)` in the next, and the longer form again later, with no firewall change in between ([stage3](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3.report.md), [handlers-retry](/Users/krisbrown/.local/state/ki/agents/chezmoi/handlers-retry.report.md), [tower-remove](/Users/krisbrown/.local/state/ki/agents/chezmoi/tower-remove.report.md)). Two later reports took "exposed beyond tailnet" to mean Screen Sharing "may be reachable from beyond the tailnet".

The [stage3-blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/stage3-blind.report.md) and the [firewall-blind review](/Users/krisbrown/.local/state/ki/agents/chezmoi/firewall-blind.report.md) found why. The [listener probe](../../src/rig/29-firewall.bash) takes a fresh `netstat -an` snapshot, and the observer appends `exposed-beyond-tailnet` whenever drift reasons exist and that snapshot shows a wildcard listener on a declared port. Screen Sharing's port is socket-activated by launchd, so the listener row can come and go between runs. The probe does not read loaded pf rules (that needs root, under FW-DOCTOR in [KI-TOOL-RIG-CORE-047](KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md)), so it cannot show reachability. On `terra` the older anchor was still restricting sources to the tailnet as far as its file shows; only its destination predates `dae10f2`.

## Boundary

- **In:** the detail name or explanatory text for the listener evidence, so it reads as "declared port listening on all addresses" rather than exposure; stating in doctor and `rig explain` that kernel rules are unverified when the evidence is shown; deciding whether a volatile listener observation belongs in the drift reasons at all; specification, guide and Bats alignment.
- **Out:** a privileged doctor (FW-DOCTOR keeps doctor unprivileged); any change to the anchor, the apply path or `terra`'s pending re-apply, which KI-TOOL-RIG-CORE-047 tracks.

## Current state

Grounded at `a3b7f574cd0ebb95ee58fabde2dcd52268fb9e62` on 27 October 2026, the revision that delivered [KI-TOOL-RIG-CORE-073](KI-TOOL-RIG-CORE-073-native-tool-absolute-path-fallback.md). Both observers, `rig_firewall_observe` in [29-firewall.bash](../../src/rig/29-firewall.bash) and `rig_nftables_observe` in [29-firewall-nftables.bash](../../src/rig/29-firewall-nftables.bash), appended `exposed-beyond-tailnet` to a missing or drifted firewall's reasons whenever this run's `netstat -an` or `ss` snapshot showed a declared port bound to every address. `show firewall:ID` printed the observed state and nothing about what the listener row did and did not prove. The status table's DETAIL column holds 42 characters, so a reason list must stay short to be read there in full; doctor and show carry it whole.

## Steps

- [x] Rename the reason to `listening-all-addresses` in both observers, so it names the evidence and drops the claim.
- [x] Make `show firewall:ID` print, beneath the observed state, a `Listener evidence:` line naming the ports seen and stating that the loaded rules were unread (`kernel-rules-unverified`) and the row is not proof of reachability.
- [x] Align RIG-STATE-045, the operational-resources guide, the man page, the changelog and the Bats fixtures on both platforms, with assertions on the new show line.
- [x] Reassemble `bin/rig` and run the full gate.

## Files touched

- `src/rig/29-firewall.bash`, `src/rig/29-firewall-nftables.bash`, and the assembled `bin/rig`
- `tests/rig-firewall.bats`, `tests/rig-firewall-linux.bats`
- `docs/specs/state.md` (RIG-STATE-045), `docs/guides/user/operational-resources.md`, `man/rig.1`, `CHANGELOG.md`
- This record.

## Verify

- `bats tests/` passes; the two firewall suites assert `listening-all-addresses` in status rows and the `Listener evidence:` line in `show firewall:ID` on each platform.
- `shellcheck`, `bash -n`, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1`, `git diff --check` and `ki repo audit --repo .` pass.
- No occurrence of `exposed-beyond-tailnet` remains outside this record's history.

## Dependencies / blocks

None. [KI-TOOL-RIG-CORE-068](KI-TOOL-RIG-CORE-068-replaced-pf-root-ruleset-bypass.md) changes the privileged apply path and its doctor wording for the root ruleset, not the listener reason, so the two do not touch the same reasons and were not merged; its gate rests on an attended check that has not run.

## Documentation impact

### Decision Records

None.

### Specifications

RIG-STATE-045 in `docs/specs/state.md` names `listening-all-addresses`, says what the evidence is, and requires the show line.

### Guides

`docs/guides/user/operational-resources.md` and `man/rig.1` say what the reason means and does not mean.

### Roadmap

This record only.

## Review

### Delivered

The Boundary's In clause: the detail renamed so it reads as a listener observation; `show firewall:ID` stating that kernel rules are unverified when the evidence is shown; spec, guide, man and Bats aligned. The open question whether a volatile listener observation belongs in the drift reasons at all is settled by keeping it there under its new name: the row is still evidence worth a reader's eye when the firewall needs work, and dropping it would hide a declared port bound to every address during drift. No anchor, apply path or workstation state was touched. Immutable baseline `a3b7f574cd0ebb95ee58fabde2dcd52268fb9e62` on `main`.

Adopted from triage to Now and delivered on 27 October 2026 under Kris's "Do the quick wins now" on the ways-of-working [roadmap sweep](/Users/krisbrown/workspaces/knowledge-islands/ki-principal/+/_WORK/ki.ways-of-working/design/roadmap-sweep.md), bucket C.

### Change Summary

- `src/rig/29-firewall.bash`: the macOS observer appends `listening-all-addresses`; `rig_firewall_explain_listeners` prints the `Listener evidence:` line from `RIG_FIREWALL_EXPOSED` and `rig_explain_firewall` calls it after the observed state.
- `src/rig/29-firewall-nftables.bash`: the Linux observer appends the same reason and `rig_nftables_explain` calls the shared line.
- `tests/rig-firewall.bats`, `tests/rig-firewall-linux.bats`: every `exposed-beyond-tailnet` expectation renamed; one `show firewall:ID` assertion per platform on the observed state and the listener line.
- `docs/specs/state.md`, `docs/guides/user/operational-resources.md`, `man/rig.1`, `CHANGELOG.md`: the reason, its meaning and the show line.
- `bin/rig`: reassembled.

### Verification

- `bats tests/`: 646 tests pass, the two firewall suites among them with the renamed reason and the new `Listener evidence:` assertions.
- `shellcheck` and `bash -n` over `bin/rig`, `install.sh`, every module and the three scripts: pass.
- `scripts/assemble-rig --check`, `scripts/benchmark-rig` (show 2s, show-all 1s, status 3s, all within budget), `scripts/smoke-native-providers` (npm, chezmoi, mas pass), `mandoc -T lint man/rig.1`, `git diff --check`: pass.
- `ki repo audit --repo .`: FAIL=1 WARN=5, the one failure being SHELL-HOOK's reading of the untouched `.githooks/pre-commit` (it takes the hook's `quiet_audit` function as a non-check-only gate), present at baseline and not changed by this record.
- Pre-commit hook (shellcheck, `bash -n`, mandoc lint, staged `ki-repo-tools` audit): ran on the commit.
- Not run: a live `rig show firewall:<id>` against a workstation with an exposed listener.

### Outstanding concerns

- Doctor states the evidence by the reason's defined meaning, `listening-all-addresses`, not by extra words: the status table's 42-character DETAIL column cuts a longer reason list, so the "kernel rules unverified" statement lives in `show firewall:ID` and the documents, which is narrower than the In clause's "doctor and `rig explain`" and is left to review.
- A reader of an older report that says `exposed-beyond-tailnet` has no in-product pointer to the new name; the changelog carries it.

### Post-change review

Goal met: the finding names what was observed and the show command says what it does not prove. Scope held to the In clause less the doctor wording noted above. Regression risk is low: one reason string renamed in both observers, one additional output line in show, and both fixture suites exercise the paths. Ready for acceptance.

### Mini recap

Renamed the listener reason, added the show line, aligned documents and tests; verified by the full gate; outstanding is the doctor wording narrower than the In clause. Learning route: none proposed.

## Discussion

- A rename such as `listening-all-addresses` keeps the evidence and drops the claim. Alternatively, report the listener state as a separate informational field, so the drift reason list changes only when the firewall's own files or daemon change.
