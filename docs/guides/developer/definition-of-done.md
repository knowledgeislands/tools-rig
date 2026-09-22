# Complete a Rig change

Use this checklist before presenting a Rig change for review. It defines delivery readiness for the repository; a roadmap record becomes `done` only after a human accepts its review packet through the selected KI workflow. Mark an inapplicable check explicitly in that packet rather than silently skipping it.

Release publication has additional steps in [Release Rig](releasing.md).

## Confirm the contract

- [ ] The change stays within the catalogue, profile, provider, state, managed-resource, extension, or publication boundary described by the repository.
- [ ] Durable rationale is in a Decision Record, accepted behaviour is in a Specification, practical procedure is in a guide, and future work is in the canonical roadmap.
- [ ] Ordinary configuration remains declarative: Rig infers built-in adapters, capabilities, lifecycle sequencing, and protocol markers.
- [ ] Any generally useful bootstrap stage, provider adapter, inventory source, setting type, or resource lifecycle is implemented in Rig rather than delegated to a personal workstation provider.
- [ ] Personal catalogue data, host-specific values, credentials, provider-native state, external executables, and observed state remain outside the public executable and public projection.
- [ ] Runtime code remains compatible with macOS Bash 3.2 and adds no required runtime dependency beyond Bash.
- [ ] Authored `src/rig/` modules assemble byte-for-byte into committed `bin/rig`, and every assembled payload passes Bash syntax and ShellCheck gates.
- [ ] Configuration, data, state, and cache behaviour preserve the XDG and Rig-override contract.

## Align affected public surfaces

- [ ] CLI help, command-local help, README orientation, user and developer guides, `man/rig.1`, Bash and Zsh completions, Specifications, Decision Records, and `CHANGELOG.md` agree wherever the change affects them.

## Check distribution impact

- [ ] `install.sh`, installer help, user guidance, and manual installation guidance agree when installation changes.
- [ ] The executable and manual continue to install or link together into documented, overrideable destinations.
- [ ] Version source, `rig --version`, tag, release entry, and companion Homebrew formula agree for a release candidate.
- [ ] Release-event publication is included when distribution changes affect enrolled consumers.
- [ ] First-time registry entries, maturity changes, personal-site updates, and consumers outside automation are named as explicit receiver-owned handoffs.

## Verify the repository

- [ ] Run `ki repo audit --repo .` and resolve findings within approved authority, recording approval-gated external findings separately.
- [ ] Run the ShellCheck, Bash syntax, assembly drift, benchmark, native-provider smoke, Bats, mandoc, and diff checks in [Develop Rig](README.md).
- [ ] Use the two-second reference benchmark budget when assessing parser, resolution, or query performance.
- [ ] Inspect rendered manual output after a layout change.
- [ ] Run focused authoring, guide, Specification, Decision Record, and roadmap audits for touched documentation.
- [ ] Exercise affected commands against isolated fixtures and, when safe and relevant, a live personal catalogue without applying changes.

## Prepare review

- [ ] The roadmap record contains its immutable baseline, completed steps, verification evidence, outstanding concerns, post-change assessment, and mini recap.
- [ ] The record is `awaiting-review` before any separately authorised acceptance or pruning.
- [ ] Stage only intended paths, preserve unrelated working-tree changes, and create a Conventional Commit for the verified delivery.
- [ ] After a hook-backed commit, inspect `git show --name-status HEAD`; rebuild an unpushed commit if it captured unrelated staged work.
- [ ] Do not push, publish a release, apply chezmoi, or mutate another repository without explicit authority for that external or cross-repository action.
