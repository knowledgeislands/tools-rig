---
id: KI-TOOL-RIG-CORE-063
area: CORE
title: Fatal Bats assertions
purpose: debt
theme: rig
kind: deliver
horizon: now
status: awaiting-review
size: s
blocks: []
blocked_by: []
baseline_ref: 41adda24ccafba4d39044a927b96ca01f481e2de
created_at: 2026-10-18T17:10:50Z
updated_at: 2026-10-19T22:43:23Z
---

# Fatal Bats Assertions

## Goal

Every bare `[[ ]]` or `!` assertion in tools-rig's nine warning suites ends `|| false`, so a failing check in the middle of a test fails it under macOS Bash 3.2, and the `ki-repo-tools` `SHELL-FATAL` warning clears for this repository.

## Context

Under macOS Bash 3.2, Bats does not stop a test at a failing bare `[[ ]]` or `!` command that is not the test's last, so the failure is logged and the test still passes. tools-mgit `00ef0de` fixed this in its main suite and exposed latent faults. [KI-HARNESS-GOV-211](https://github.com/knowledgeislands/ki-agentic-harness/blob/87da1b262fcc60678a31850461dd63c4a848e592/docs/roadmap/KI-HARNESS-GOV-211-bats-fatal-assertions.md) made the rule part of `ki-repo-tools` and added the `SHELL-FATAL` warning. Its run of 18 October found nine tools-rig suites with 64 such lines:

- `tests/rig.bats`: 17.
- `tests/rig-app-clis.bats`: 17.
- `tests/rig-application-updates.bats`: 8.
- `tests/rig-default-applications.bats`: 7.
- `tests/rig-software-removal.bats`: 7.
- `tests/rig-skills.bats`: 4.
- `tests/rig-macos.bats`: 2.
- `tests/rig-homebrew-authority.bats`: 1.
- `tests/rig-human-config.bats`: 1.

Kris agreed on 18 October 2026 (BATS-CLEANUP a), ways-of-working decisions log, 17:59 BST owner answers) to capture one triage record each in tools-mgit and tools-rig.

## Boundary

- In: adding `|| false` to each bare assertion in the nine suites; fixing any test or code fault that making them fatal exposes; confirming `SHELL-FATAL` passes for the repository.
- Out: changing the `SHELL-FATAL` criterion; other repositories' suites, including tools-mgit's ([KI-TOOL-MGIT-CLI-027](/Users/krisbrown/workspaces/knowledge-islands/tools-mgit/docs/roadmap/KI-TOOL-MGIT-CLI-027-fatal-bats-assertions.md)); any live apply.

## Current state

Re-counted on 19 October 2026 against `ki repo audit --skill ki-repo-tools`: `SHELL-FATAL` warns on the same nine suites with the same 64 lines as the capture sample. Every reported line is a single-line `[[ ... ]]` string match or a `! grep ...` negative check; none is a test's only assertion of its kind, and none uses `&&` or `||`. `assert_no_global_firewall` in `tests/rig-firewall.bats` already ends `|| false`, so its flake is a pattern fault, not a fatality one.

## Steps

- [x] Append `|| false` to each of the 64 reported lines, suite by suite, preserving each line's existing command and redirections.
- [x] Run each changed suite with stdin closed; for any test that now fails, establish whether the assertion or the code is wrong. Fix a wrong assertion in place; stop and report a real Rig defect for its own record rather than fixing behaviour here.
- [x] Anchor `assert_no_global_firewall`'s `pfctl` match to its own arguments, `pfctl( [^ ]+)* -[dX]( |$)`, keeping it fatal.
- [x] Re-run the `SHELL-FATAL` audit and the complete local gate.

## Files touched

- `tests/rig.bats`, `tests/rig-app-clis.bats`, `tests/rig-application-updates.bats`, `tests/rig-default-applications.bats`, `tests/rig-software-removal.bats`, `tests/rig-skills.bats`, `tests/rig-macos.bats`, `tests/rig-homebrew-authority.bats`, `tests/rig-human-config.bats`.
- `tests/rig-firewall.bats`.
- This record.

No runtime source, `bin/rig`, specification or guide changes.

## Verify

- `ki repo audit --skill ki-repo-tools --repo .` reports no `SHELL-FATAL` finding.
- An anchor-scoped `pfctl` line whose path contains `bats-run-X9wm9S` no longer matches the firewall pattern, while `pfctl -d`, `pfctl -X token` and `sudo -n -- pfctl -a anchor -F all -X token` still do; checked with `grep -E` on sample lines.
- [Develop Rig's complete gate](../guides/developer/README.md#verify-the-repository) passes, `bats tests/ </dev/null` included. No live apply.

## Dependencies / blocks

None. Blocks nothing.

## Documentation impact

### Decision Records

None.

### Specifications

None; no behaviour changes.

### Guides

None; [Continuous verification](../guides/developer/continuous-verification.md) and `AGENTS.md` already state the `|| false` rule.

### Roadmap

This record moves to Awaiting review at delivery.

## Review

### Delivered

Within the approved boundary: every bare `[[ ]]` or `!` assertion in the nine warning suites now ends `|| false`, and `assert_no_global_firewall` matches `pfctl`'s own `-d` or `-X` argument rather than any `-X` on the line. Baseline `41adda24ccafba4d39044a927b96ca01f481e2de`; the delivery commit follows it. No runtime source, `bin/rig`, specification or guide changed, and nothing was applied live.

### Change Summary

- 64 lines across `tests/rig.bats` (17), `tests/rig-app-clis.bats` (17), `tests/rig-application-updates.bats` (8), `tests/rig-default-applications.bats` (7), `tests/rig-software-removal.bats` (7), `tests/rig-skills.bats` (4), `tests/rig-macos.bats` (2), `tests/rig-homebrew-authority.bats` (1) and `tests/rig-human-config.bats` (1) gain `|| false`; the `rig-human-config.bats` assertion is a backslash continuation, so the suffix sits on its final line.
- `tests/rig-firewall.bats`: the global-firewall pattern becomes `pfctl( [^ ]+)* -[dX]( |$)`, still fatal.
- No deviations from the plan.

### Verification

- `ki repo audit --skill ki-repo-tools --repo .`: no `SHELL-FATAL` finding (was 9 warnings, 64 lines).
- Firewall pattern on sample lines: an anchor-scoped `pfctl -E ... -f /tmp/bats-run-X9wm9S/anchor` and `pfctl -a ... -F all` do not match; `pfctl -d`, `pfctl -X token` and `sudo -n -- pfctl -a anchor -F all -X token` do.
- `bats tests/ </dev/null`: 582 of 582 pass; making the assertions fatal exposed no latent fault.
- shellcheck, `bash -n` on every script, `scripts/assemble-rig --check`, `scripts/benchmark-rig`, `scripts/smoke-native-providers`, `mandoc -T lint man/rig.1` and `git diff --check`: pass.
- `ki repo audit --repo .`: no failures; the remaining warnings are other records' `size` migration-window notes and pre-existing judgement items.

### Outstanding concerns

None for this record. The hostile inherited `XDG_STATE_HOME` run was not repeated because `tests/helpers/isolate.bash` did not change.

### Post-change review

The goal holds: a failing mid-test assertion in these suites now fails its test under macOS Bash 3.2, and the audit warning is clear. Scope stayed inside test files and this record. Regression risk is low: each edit only makes an existing check fatal, and the full suite passes. The firewall pattern is strictly narrower than before for path text and unchanged for real `-d` and `-X` arguments. Ready for acceptance review.

### Mini recap

Made 64 Bats assertions fatal and de-flaked the firewall global-flush check; full gate green, no Rig defect exposed. Learning route, not promoted: `SHELL-FATAL`'s own continuation handling joins lines, so a mechanical fix must place `|| false` on the continuation's last line; that note would belong with `ki-repo-tools` remediation guidance.

## Discussion

### Approval

Kris, 19 October 2026 23:27 BST, RIG-ORDER a): "All three are high confidence to do them", authorising this record's adoption to Now, planning to Ready and delivery to Awaiting review in one background run.

Origin: the ways-of-working bats-rule run of 18 October 2026. The line counts are that run's read-only sample and should be re-counted against the audit at planning. Planning questions: whether to fix suite by suite so each exposed fault is reviewed on its own, and whether any exposed fault is a real Rig defect that needs its own record. Capture only; adoption, priority and plan belong to this repository.

### Flaky firewall assertion

Finding, unfixed. `assert_no_global_firewall` in `tests/rig-firewall.bats` matches `pfctl (-d|.*-X)` against the whole native log line, so a temporary path containing `-X`, such as the Bats run directory `bats-run-X9wm9S`, makes a correct anchor-scoped `pfctl` call look like a global flush and fails the test at random. The rig-lock-review run of 18 October 2026 saw it once, at test 580, and it passed on re-run. Kris agreed on 18 October 2026 (RIG-FLAKY-FIREWALL a), ways-of-working decisions log, 19:05 BST owner answers) to fold it here as the same kind of test-hygiene debt. The fix should anchor the flag match to `pfctl`'s own arguments, for example `pfctl( [^ ]+)* -(d|X)( |$)`, and keep it fatal.
