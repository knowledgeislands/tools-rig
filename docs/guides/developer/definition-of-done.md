# Complete a Rig change

Use this checklist before presenting a Rig change for review. It defines delivery readiness for this repository; a roadmap record becomes `done` only after a human accepts its review packet through the selected KI workflow. Mark an inapplicable item explicitly in the review packet rather than silently skipping it.

Release publication has additional steps in [Release Rig](releasing.md).

## Confirm the contract

- [ ] The change stays within the catalogue, profile, provider, state, managed-resource, extension, or publication boundary described by the repository.
- [ ] New durable rationale is in a Decision Record, accepted behaviour is in a Specification, practical procedure is in a guide, and future work is in the canonical roadmap.
- [ ] Ordinary configuration remains declarative: built-in adapters, capabilities, lifecycle sequencing, and protocol markers are inferred by Rig rather than repeated by the user.
- [ ] A generally useful bootstrap stage, provider adapter, inventory source, setting type, or resource lifecycle is implemented in Rig rather than delegated to a personal workstation provider.
- [ ] Personal catalogue data, host-specific values, credentials, provider-native state, external executables, and private observed state remain outside the public executable and public projection.
- [ ] Runtime code remains compatible with macOS Bash 3.2 and adds no required runtime dependency beyond Bash.
- [ ] Authored `src/rig/` modules assemble byte-for-byte into committed `bin/rig`; every module and the assembled payload passes Bash 3.2 syntax and ShellCheck gates.
- [ ] Configuration, data, state, and cache behaviour preserve the XDG and Rig-override contract.

## Align affected public surfaces

- [ ] CLI help, README, user and developer guides, `man/rig.1`, Bash and Zsh completions, `CHANGELOG.md`, tests, Specifications, and Decision Records describe the same shipped commands, options, configuration, defaults, lifecycle operations, fixed built-in provider behaviour, extension boundary, and trust transitions wherever the change applies.

## Check distribution impact

- [ ] `install.sh`, installer help, README installation examples, user guides, and manual installation guidance agree when installation changes.
- [ ] The executable and manual continue to install or link together into documented, overrideable destinations.
- [ ] The version source, `rig --version`, tag, release entry, and companion Homebrew formula agree for a release candidate.
- [ ] Release-event publication is included when distribution changes affect enrolled consumers.
- [ ] First-time entries, maturity changes, personal-site updates, and consumers outside automation are named as explicit receiver-owned handoffs.

## Verify the repository

- [ ] Run `ki repo audit --repo .` and resolve findings within approved authority, recording approval-gated external findings separately.
- [ ] Run `shellcheck bin/rig install.sh`.
- [ ] Run `shellcheck src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers`.
- [ ] Run `bash -n bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers`.
- [ ] Run `scripts/assemble-rig --check` and `scripts/benchmark-rig`; use the two-second reference budget when assessing parser, resolution, or query performance.
- [ ] Run `scripts/smoke-native-providers`, treating unavailable optional providers as explicit skips and any failed available read-only probe as a failure.
- [ ] Run `bats tests/`.
- [ ] Run `mandoc -T lint man/rig.1` and inspect `mandoc -T utf8 man/rig.1 | col -b` after a manual layout change.
- [ ] Run `git diff --check` and focused KI authoring, guide, specification, decision, and roadmap audits for touched documentation.
- [ ] Exercise affected commands against isolated fixtures and, where safe and relevant, a live personal catalogue without applying changes.

## Prepare review

- [ ] The roadmap record contains its immutable baseline, completed steps, verification evidence, outstanding concerns, post-change review, and mini recap.
- [ ] Intended files are committed with a Conventional Commit; unrelated working-tree changes remain unstaged and untouched.
- [ ] Commit contents have been inspected after hooks, and the working tree contains only known unrelated changes.
- [ ] Nothing was pushed, released, applied to chezmoi, or changed in another repository without explicit authority.
- [ ] Work stops at `awaiting-review` until a human approves acceptance; accepted records are committed before any separately authorised pruning.
