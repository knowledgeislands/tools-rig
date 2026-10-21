---
id: KI-TOOL-RIG-CORE-048
area: CORE
title: Signed-release install kind
purpose: capability
theme: rig
kind: deliver
status: ready
horizon: next
size: m
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T22:53:48Z
updated_at: 2026-10-21T02:25:43Z
---

# Signed-Release Install Kind

## Goal

Rig installs a tool shipped as a signed release, such as `ki` or `techne`, through a built-in install kind: it fetches the per-platform archive for an exact or minimum version, verifies the release's checksum manifest against its Ed25519 signature and a declared public key, and installs into the user's home without root. Any role profile or Cheztoi fragment can then declare such tools on macOS or Linux, with no custom provider.

## Context

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted all ten decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md); the plain-language summary is [Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md). Decision 5 places a signed-release install kind in `tools-rig`, replacing a custom provider the Techne harness had planned to ship beside its recipe. Decision 6 makes one KI release contract the canonical artefact for every KI and personal tool (per-platform archives including linux-arm64, a checksum manifest, an Ed25519 signature and an installer with the key embedded), with this kind as one of three thin channels beside the Homebrew tap and the installer.

Today the built-in `direct-download` `executable` kind covers a single binary checked by SHA-256, not a signed `tar.gz` archive, and an owner's payload may not carry a custom provider. `ki` and `techne` already share the archive pattern, which is the condition the audit set for a built-in kind.

## Boundary

- In: the install kind, its configuration fields and validation, signature and checksum verification that never falls back to SHA-256 only, version reporting for `rig status`, specifications and tests.
- In: whether one `agentic-rig` role profile, published by the Techne harness, can be included by both remote agentic rigs (`vega` through Cheztoi and `sol` through a person's own configuration), carrying exact pins on one and minimums on the other; if existing `inherits` and `conf.d` composition already covers it, a worked example records that finding. Merged from KI-TOOL-RIG-CORE-049 below.
- Out: changes to any tool's release signing or installer; producing linux-arm64 builds, which each `tools-*` repository owns; bootstrapping Rig itself.

## Shaping

- Approach: the accepted built-in signed-release kind, under Decision 5 of the boundary audit, not a custom provider beside the Techne harness's recipe. It fetches the per-platform `tar.gz` archive for an exact or minimum version, verifies the checksum manifest against its Ed25519 signature and a declared public key, checks the archive against the verified manifest, and installs into the user's home without root. Verification never falls back to SHA-256 alone. `rig status` reports the installed version against the declared pin or minimum.
- Scope: the shared-role question merged from KI-TOOL-RIG-CORE-049 stays in scope as written above: whether one `agentic-rig` role profile can serve both `vega` and `sol` with exact pins on one and minimums on the other through existing `inherits` and `conf.d` composition, recorded as a worked example if it can, or as the smallest added capability if it cannot.
- Dependencies: none inside Rig. `ki` and `techne` releases already carry the signed archive pattern the kind consumes; a linux-arm64 archive is not needed for vega, which is x86.
- What delivery clears: only the signed-install prerequisite of the Techne harness's plan to converge vega's tools through Rig. That plan (KI-TECHNE-OPS-018 in ki-techne-harness) still needs the binding owner's evidence of a clean `rig status` through a pin bump on vega, and its weekly pin bump (KI-TECHNE-OPS-024) still needs the role-profile move to `roles/`. Both stay held there; delivering this record releases neither.

### Bounded planning authority

The 21 October owner dispatch for `wow-night-rig-048-g` explicitly selects this unit, promotes Soon to Next, and grants the remaining bounded planning choices and fixture-only delivery. The coordinator's tools-rig writer designation selects this run's isolated worktree. This grant does not release acceptance, publication, downstream host convergence or the Techne role move.

### Configuration choices

Extend `direct-download` with kind `signed-release`, preserving kind `executable`. Add string fields `install.release-name`, `install.public-key`, `install.version` and `install.minimum-version`, including platform variants and their derived bindings. The locator is the HTTPS repository release base; the destination is a command inside the user's home. The release name is a safe command basename; the public key is a regular local PEM file, accepting the existing leading `~/` convention. Never fetch a trust key. Exact and minimum versions use stable `vMAJOR.MINOR.PATCH` syntax. Reject malformed or contradictory policies, checksum-only metadata and installation arguments for this kind.

An exact version pins that release. Without an exact version, the minimum is the immutable release to install when missing or too old; retain an already installed compatible newer version. Do not discover latest releases. One bounded numeric comparator serves both policies, with no prerelease or build-metadata ordering. Permit the minimum field on Homebrew formulae too: native observation supplies the installed version, and Homebrew retains native resolution, install and upgrade semantics. This is the smallest added capability needed by the merged shared-role scope, not a generic version manager. A below-floor Homebrew installation uses native upgrade; an absent installation uses native install. Unparseable native versions stay unknown rather than satisfying the floor. Homebrew numeric formula revisions do not change the upstream version. Keep cask application update policies outside this CLI-role floor capability. Version components are canonical decimal integers of at most nine digits, with no leading zeros except zero itself.

### Release and installation choices

Consume `<name>-<version>-<target>.tar.gz`, `<name>-checksums.txt` and `<name>-checksums.txt.sig` beneath `/releases/download/<version>/`. The signed manifest starts with `format=<name>-release-checksums-v1` and `version=<version>`, then unique SHA-256 archive rows for supported targets, including the selected target. Support `darwin-arm64`, `darwin-x64`, `linux-arm64` and `linux-x64`; this does not claim every producer publishes every target. Select from Rig's platform and the native architecture, with a documented `RIG_ARCH` override, and reject unsupported combinations.

Use installed OpenSSL selected by `RIG_OPENSSL` or PATH, require an Ed25519 public key and raw signature verification, and fail closed without a verifier. Verify the signature before parsing the manifest or requesting the archive, then check the archive digest. Require exactly two regular archive members, `<name>` and `man/<name>.1`, rejecting links, duplicate members and every other path. Materialise only the command, so installation has one final replacement rather than an executable/manual pair. Stage beside the home-only destination, verify the staged command's reported version, recheck destination safety and replace by one rename. Failures preserve an existing executable and clean staging; no root or checksum-only fallback is permitted.

### Shared-role composition

One synthetic role fragment owns one tool with Linux signed-release exact/minimum metadata and a macOS Homebrew minimum variant. Host profiles inherit its complete profile through ordinary `conf.d` composition. Fragments define distinct declarations; they do not override duplicate tables. Prove composition against fixtures and explain it in a worked guide example without changing Techne roles or personal configuration.

## Current state

Immutable source baseline: `52d0d8b202931942b832e47821e47e23e350e1c2`, the exact local main commit, matching the local origin/main observation. The isolated worktree started clean. The canonical pre-commit matches its no-package asset byte-for-byte and contains no Bats invocation. A fresh copied audit home uses harness `7dc5bb8aa8d8a0e0fce3a34084a90260033ba643`, IP network denial and copied-home-only Capital registration. Full audit has no failures and only the expressly allowed OWN-1, MATURITY-1 and missing-size warnings. Every baseline gate passed. The complete Bats run passed with two interpreter-discovery skips; both skipped TOML-parser checks then passed explicitly with the installed Python 3.15 interpreter, covering all 611 tests. Activation changes stay local and uncommitted.

Rig currently has no signed-release kind or version comparator. Existing inheritance and platform variants supply shared membership; minimum-version observation is the missing policy capability. Implementation records its separate immutable start commit after the Ready plan is committed.

## Steps

- [ ] Complete the baseline, record the bounded choices and commit the approved Ready plan.
- [ ] Extend and validate tool/variant installation fields and bounded version policies.
- [ ] Implement fail-closed signature, manifest, digest, archive and atomic home-only command installation with preflight checks.
- [ ] Report exact/minimum versions, retaining native Homebrew resolution for shared-role floors.
- [ ] Add disposable signed fixtures and exact stubs covering supported platforms, tampering, wrong keys, unsafe archives and preserved destinations on failure.
- [ ] Prove inherited shared-role composition, and align specifications, guide, help, manual and changelog.
- [ ] Assemble the executable, complete all gates, review the delivered scope and submit awaiting-review with all six Review headings and the exact commit range.

## Files touched

`src/rig/10-configuration.bash`, `src/rig/21-provider-state.bash`, `src/rig/21-signed-release.bash`, `src/rig/20-orchestration.bash`, `scripts/assemble-rig`, `src/rig/00-runtime.bash`, generated `bin/rig`, `tests/rig-signed-release.bats`, `docs/specs/configuration.md`, `docs/specs/orchestration.md`, `docs/guides/user/signed-releases.md`, `docs/guides/user/README.md`, `man/rig.1`, `CHANGELOG.md` and this record. Leave `.ki.toml`, `.rumdl.toml`, other records, producer releases, test isolation policy and host configuration unchanged.

## Verify

Run the complete command list in `docs/guides/developer/README.md`: whole-repository audit, ShellCheck, Bash syntax, assembly check, benchmark, bounded native-provider version smoke, `bats tests/ </dev/null`, mandoc and whitespace check. Use installed dependencies only. The enumerated pre-existing audit warnings are permitted; every new warning or failure stops the unit. Preserve evidence beside the run report.

Every setup starts with `rig_test_isolate`. Generate disposable test keys and stub downloads and native managers. Cover exact/floor installation, newer-version retention, numerical ordering, version status, macOS/Linux targets, home-only destinations and inherited shared-role composition. Missing or invalid signatures, wrong/unsupported keys, altered manifests/archives, malformed manifests, unsafe/duplicate/non-regular archive members, incorrect payload versions and unsafe destinations must fail without partial replacement or checksum-only fallback. No live apply, provider mutation, host convergence or downstream hold release is authorised.

## Dependencies / blocks

Not blocked; `tools-ki` releases already carry a signed manifest. It blocks the Techne harness's plan to converge the agent host's tools through Rig, whose first gate is Rig installing a signed `ki` release.

## Documentation impact

### Decision Records

No new decision record: the accepted boundary audit already assigns signed-release consumption to Rig. These bounded configuration and fixture choices implement that decision.

### Specifications

Extend configuration and orchestration requirements for signed-release fields, verification order, home-only atomic installation, bounded version policies and Homebrew floors.

### Guides

Add a user guide with a complete worked inherited shared-role example, verification and recovery; link it from the user index and align help and the manual.

### Roadmap

Only this existing record changes. Downstream Techne host convergence and profile relocation remain held; no acceptance, new record or downstream change is authorised.

## Discussion

Origin: `ki-principal`, state-of-play thread, under Kris Brown's acceptance of the audit decisions. Capture only; adoption, priority and plan belong to this repository.

### Adoption

On 14 October 2026 Kris approved the state-of-play thread's triage burn-down as written, under Kris's instruction to burn the roadmap down: adopted as `deliver / Hold` until 2026-11-16. Its only consumer is the Techne harness's plan to converge the agent host's tools through Rig, which is itself held until vega is rebuilt. Adoption grants no planning, implementation or acceptance authority.

### Merged from KI-TOOL-RIG-CORE-049 on 2026-10-14

Kris approved merging KI-TOOL-RIG-CORE-049 (shared agentic-rig role) into this record on 14 October 2026, in the state-of-play run ('RC-ALL: approve all' to the roadmap census): both wait for the same trigger, vega being rebuilt, and the shared role is how a signed install reaches both hosts. Its Goal and Boundary, carried as written:

- **Goal.** One `agentic-rig` role profile serves both remote agentic rigs: `vega`, a rebuildable cloud host set up by the Techne harness, and `sol`, Kris's owned Mac Studio configured through chezmoi. Both hosts include the same role from its single published source, with platform variants (Homebrew on macOS), so they carry the same KI toolchain without a second copy of its declaration.
- **Context.** The Rig and Techne boundary audit makes Rig own the role layer (its Decision 1), places the role profile in a recipe-independent `roles/` folder in `ki-techne-harness` (Decision 3), and sets the version policy per role: exact pins on rebuildable hosts, newest through Homebrew on workstations, with the role declaring minimums both satisfy (Decision 4).
- **In:** establishing whether existing composition covers this, and if not, the smallest Rig capability that does; the exact-versus-minimum version policy for one role across hosts; specifications and tests.
- **Out:** the role's contents and home, which `ki-techne-harness` owns; Kris's own `studio` profile and catalogue, which chezmoi owns.

### Release on 20 October 2026

Released from hold to Soon under Kris's OVERNIGHT authority of 20 October 2026, answering the agent-host work's CHAIN-GATE query with option a), reviewed blind by query-review-6, which agreed. The hold waited for vega to be rebuilt, which happened on 14 October, and for the Techne harness's converge-through-Rig work to leave its hold, which itself waits for this kind, so the two holds only waited on each other. Release grants no planning, implementation or acceptance authority.
