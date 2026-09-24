---
id: RIG-DIST-008
area: DIST
title: Restore the verification gate
theme: distribution
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: bd8083cb8d7d2ffbab3157e17a5dc3e5aa965ea5
created_at: 2026-09-23T18:55:00Z
updated_at: 2026-09-24T10:20:00Z
---

## Goal

Make continuous verification tell the truth again, so a green run means Rig works on a stock Linux box and a stock macOS one, and a red run means something is actually broken rather than that the suite assumes the machine it was written on.

## Context

Continuous verification has failed on every push to `main` since 2026-09-19. The last green run was `chore(release): prepare v0.2.0` on 2026-09-18, so the `v0.3.0` preview was tagged over a red gate and every commit since has landed without a working check. The local gate is green, which is exactly why the red one stopped being read: two signals disagreed and the convenient one won.

The failures split into two causes, neither of which is a defect in `rig` itself.

The macOS job runs the suite under `PATH=/usr/bin:/bin:/usr/sbin:/sbin` to prove Rig needs nothing beyond system tools. Two configuration tests parse the fixture with `python3 -c 'import tomllib'` to prove the grammar is interoperable TOML; the system interpreter is Python 3.9.6, and `tomllib` arrived in 3.11. Reproduced locally: the same two tests fail under that PATH and pass under a normal one. The test's use of a real TOML parser is test infrastructure, not a Rig dependency, so the restricted PATH is testing the wrong thing for those two cases.

The Linux job fails eight tests. They are not explained by the platform value: running the whole suite locally with `RIG_PLATFORM=linux` passes, so the cause is the Linux environment itself — GNU versus BSD tool behaviour, absent macOS facilities, or an assumption about what a system provides. No Linux machine or container runtime is available on this workstation, so each one has to be diagnosed from CI output, and the current output does not print the failing command's actual result.

## Boundary

This concerns the verification gate, what the two runners assert, and the test suite's platform assumptions. It does not change Rig's behaviour, its supported platforms, or what the local gate runs. Where a Linux failure turns out to be a real defect in portable behaviour, this work reports it as its own record rather than fixing it here.

## Current state

`.github/workflows/ci.yml` has four jobs. `lint` runs ShellCheck over `bin/rig` and `install.sh` only, where the local gate also covers `src/rig/*.bash` and the three scripts. `test` runs a two-runner matrix installing Bats from `apt` on Linux and `brew` on macOS, so the two runners can disagree about Bats itself. `manual` lints the manual. `release-tag` runs on a tag with no `needs:`, so it can pass while every other job is red — which is how `v0.3.0` was tagged.

Neither runner runs `scripts/assemble-rig --check`, `bash -n`, or the benchmark, so the CI gate and the local gate assert different things.

Bats reports a failing assertion but not the output that failed it, which is why the eight Linux failures have stayed opaque.

## Decisions

- **The Linux runner stays, and its contract becomes explicit.** It asserts that Rig's portable core — parsing, configuration, catalogue and profile resolution, state comparison, export — behaves the same away from macOS. A test that needs a macOS-only facility declares that and skips elsewhere with a stated reason, so a skip is visible rather than silent. Retiring the runner would be cheaper and would throw away the only evidence that the Bash core is portable at all.
- **Test infrastructure is allowed a modern interpreter; Rig is not.** The restricted PATH exists to prove Rig needs nothing beyond system tools, and that stays. A `RIG_TEST_PYTHON` variable names an interpreter for the two TOML interoperability tests, which skip with a stated reason when no interpreter with `tomllib` is available. Adding Python to the PATH would quietly relax the constraint the job exists to hold.
- **Both runners install the same Bats.** A pinned `bats-core` checkout replaces `apt` and `brew`, so a failure means the suite failed rather than that two runners run different harnesses, and `--print-output-on-failure` is available on both.
- **The CI gate matches the local gate where it can.** ShellCheck covers the authored modules and scripts, `bash -n` covers the same set, and `scripts/assemble-rig --check` proves the committed executable matches its sources. The benchmark stays local: a shared runner's timing is not evidence.
- **A tag cannot pass over a red gate.** `release-tag` gains `needs: [lint, test, manual]`.

## Steps

- [x] Pin Bats on both runners, enable `--print-output-on-failure`, and add `workflow_dispatch` so the gate can be run without inventing a commit.
- [x] Align the `lint` job with the local gate: ShellCheck and `bash -n` over `bin/rig`, `install.sh`, `src/rig/*.bash` and the three scripts, plus `scripts/assemble-rig --check`.
- [x] Add `needs: [lint, test, manual]` to `release-tag`.
- [x] Give the two TOML interoperability tests a `RIG_TEST_PYTHON` interpreter with an explicit skip when none has `tomllib`, and supply one on the macOS runner without touching the restricted PATH.
- [ ] Push the diagnostic gate, read the Linux output, and record what each of the eight failures actually is.
- [ ] Introduce one test helper that skips a macOS-only case on another platform with a stated reason, and apply it to each failure that is genuinely macOS-bound.
- [ ] For any failure that is a real portable-behaviour defect rather than a macOS assumption, fix it here when it is small, and capture it as its own record when it is not.
- [ ] Document the gate: what each runner asserts, what a skip means, and how to run the gate locally.

## Files touched

- `.github/workflows/ci.yml` for the job shape, pinned harness, aligned lint, and release gating.
- `tests/helpers/` for the platform-skip helper and the interpreter probe.
- `tests/rig.bats` and whichever suite files hold the eight Linux failures.
- `docs/guides/developer/` for the gate documentation.
- `docs/specs/portability.md` where RIG-PORT-001 and RIG-PORT-011 describe what verification covers.
- `CHANGELOG.md`.

## Verify

- `bats tests/` green locally, and green again under `PATH=/usr/bin:/bin:/usr/sbin:/sbin` with the system Bash, which is what the macOS runner does.
- A full CI run green on both runners, with every skip carrying a stated reason and no skip hiding a macOS-bound assertion on macOS.
- `scripts/assemble-rig --check`, ShellCheck, and `bash -n` pass in CI over the same set the local gate covers.
- A tag pushed over a red gate does not produce a passing `release-tag` job.

## Dependencies / blocks

No delivery dependency. This blocks any release: `v0.4.0` should not be tagged until the gate is green, because the tag job is the only thing that checks the tag against the assembled version.

## Documentation impact

### Decision Records

None. What each runner asserts is a verification choice, not an architectural commitment; [ADR-RIG-001](../decisions/ADR-RIG-001-shell-only-runtime.md) already fixes the runtime boundary this work tests.

### Specifications

`docs/specs/portability.md` gains the verification contract: which platforms the suite asserts, and that a platform-bound case must skip with a stated reason rather than silently.

### Guides

A developer guide states what the gate runs, what each runner proves, and how to reproduce both runs locally.

### Roadmap

Any Linux failure that turns out to be a real defect in portable behaviour is captured as its own record rather than absorbed here.

## Discussion

The cost here is not the failing tests. It is that `v0.3.0` shipped with no working evidence that it runs anywhere but this workstation, and that a person reading the badge would have been told the opposite. A gate that is red for reasons everyone has learned to ignore is worse than no gate, because it still absorbs the attention a real failure would need.

Worth noting for whoever picks this up: the Linux failures are not new breakage from recent work. They are the accumulated cost of writing tests on the machine they run on, and each one is a small decision about what Rig promises off macOS. The diagnostic step is unavoidable rather than lazy — there is no Linux available here, and guessing at eight assertions from their text would produce eight plausible fixes and no evidence.
