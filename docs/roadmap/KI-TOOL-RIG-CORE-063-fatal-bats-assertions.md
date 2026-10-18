---
id: KI-TOOL-RIG-CORE-063
area: CORE
title: Fatal Bats assertions
purpose: debt
theme: rig
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-18T17:10:50Z
updated_at: 2026-10-18T18:07:57Z
---

# Fatal Bats Assertions

## Goal

Every bare `[[ ]]` or `!` assertion in tools-rig's nine warning suites ends `|| false`, so a failing check in the middle of a test fails it under macOS Bash 3.2, and the `ki-repo-tools` `SHELL-FATAL` warning clears for this repository.

## Context

Under macOS Bash 3.2, Bats does not stop a test at a failing bare `[[ ]]` or `!` command that is not the test's last, so the failure is logged and the test still passes. tools-mgit `00ef0de` fixed this in its main suite and exposed latent faults. [KI-HARNESS-GOV-211](/Users/krisbrown/workspaces/knowledge-islands/ki-agentic-harness/docs/roadmap/KI-HARNESS-GOV-211-bats-fatal-assertions.md) made the rule part of `ki-repo-tools` and added the `SHELL-FATAL` warning. Its run of 18 October found nine tools-rig suites with 64 such lines:

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

## Dependencies / blocks

None. Blocks nothing.

## Discussion

Origin: the ways-of-working bats-rule run of 18 October 2026. The line counts are that run's read-only sample and should be re-counted against the audit at planning. Planning questions: whether to fix suite by suite so each exposed fault is reviewed on its own, and whether any exposed fault is a real Rig defect that needs its own record. Capture only; adoption, priority and plan belong to this repository.

### Flaky firewall assertion

Finding, unfixed. `assert_no_global_firewall` in `tests/rig-firewall.bats` matches `pfctl (-d|.*-X)` against the whole native log line, so a temporary path containing `-X`, such as the Bats run directory `bats-run-X9wm9S`, makes a correct anchor-scoped `pfctl` call look like a global flush and fails the test at random. The rig-lock-review run of 18 October 2026 saw it once, at test 580, and it passed on re-run. Kris agreed on 18 October 2026 (RIG-FLAKY-FIREWALL a), ways-of-working decisions log, 19:05 BST owner answers) to fold it here as the same kind of test-hygiene debt. The fix should anchor the flag match to `pfctl`'s own arguments, for example `pfctl( [^ ]+)* -(d|X)( |$)`, and keep it fatal.
