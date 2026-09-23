---
id: RIG-DIST-008
area: DIST
title: Restore the verification gate
theme: distribution
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-23T18:55:00Z
updated_at: 2026-09-23T18:55:00Z
---

## Goal

Make continuous verification tell the truth again, so a green run means Rig works on a stock Linux box and a stock macOS one, and a red run means something is actually broken rather than that the suite assumes the machine it was written on.

## Context

Continuous verification has failed on every push to `main` since 2026-09-19. The last green run was `chore(release): prepare v0.2.0` on 2026-09-18, so the `v0.3.0` preview was tagged over a red gate and every commit since has landed without a working check. The local gate is green, which is exactly why the red one stopped being read: two signals disagreed and the convenient one won.

The failures split into two causes, neither of which is a defect in `rig` itself.

The macOS job runs the suite under `PATH=/usr/bin:/bin:/usr/sbin:/sbin` to prove Rig needs nothing beyond system tools. Two configuration tests parse the fixture with `python3 -c 'import tomllib'` to prove the grammar is interoperable TOML; the system interpreter is Python 3.9.6, and `tomllib` arrived in 3.11. Reproduced locally: the same two tests fail under that PATH and pass under a normal one. The test's use of a real TOML parser is test infrastructure, not a Rig dependency, so the restricted PATH is testing the wrong thing for those two cases.

The Linux job fails nine tests that assume macOS: the built-in launchd resource, platform installation variant selection, provider preflight paths, progress reporting, and the documentation and help surface. Rig declares which platforms it supports, so the question is what the Linux runner is for — proving portable behaviour is portable, or proving the whole suite runs anywhere. The suite currently answers neither.

## Boundary

This concerns the verification gate and the test suite's platform assumptions. It does not change Rig's behaviour, its supported platforms, or what the local gate runs.

## Shaping

Open questions to settle before this is ready.

- What does the Linux runner assert? Either the suite gains a portability boundary — macOS-specific cases skip with a stated reason on other platforms — or the runner is retired and portability is asserted by the specification alone. Skipping silently on the platform a feature targets would be worse than either.
- How does a tomllib-capable interpreter reach the macOS job without weakening the restricted PATH? A separate variable naming the interpreter keeps the PATH constraint about Rig while letting the test infrastructure use a modern Python; adding Python to the PATH would quietly relax the constraint the job exists to hold.
- Should the gate be enforced rather than merely reported? Nothing stopped nine days of red runs. A required status check, or a release job that refuses a tag over a red gate, would have.
- Is there a case for running the local gate's full command list in CI? The two gates currently differ, which is part of how they came to disagree.

## Discussion

The cost here is not the failing tests. It is that `v0.3.0` shipped with no working evidence that it runs anywhere but this workstation, and that a person reading the badge would have been told the opposite. A gate that is red for reasons everyone has learned to ignore is worse than no gate, because it still absorbs the attention a real failure would need.

Worth noting for whoever picks this up: the Linux failures are not new breakage from recent work. They are the accumulated cost of writing tests on the machine they run on, and each one is a small decision about what Rig promises off macOS.
