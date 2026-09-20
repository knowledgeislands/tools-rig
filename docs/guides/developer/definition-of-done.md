# Complete a Rig change

Use this checklist before presenting a Rig change for review. It defines delivery readiness for this repository; a roadmap record becomes `done` only after a human accepts its review packet through the selected KI workflow.

Mark an inapplicable item explicitly in the review packet rather than silently skipping it. Release publication has additional steps in [Release Rig](releasing.md).

## Confirm the contract

- [ ] The change stays within the catalogue, profile, provider, state, operation, or publication boundary described by this repository.
- [ ] New durable rationale is in a Decision Record, accepted behaviour is in a Specification, practical procedure is in a guide, and future work is in the canonical roadmap.
- [ ] Personal catalogue data, host-specific paths, credentials, provider-native state, and private observed state remain outside the public executable and public projection.
- [ ] Runtime code remains compatible with macOS Bash 3.2 and adds no required runtime dependency beyond Bash.
- [ ] Configuration, data, state, and cache behaviour preserve the XDG and Rig override contract.

## Align affected public surfaces

- [ ] CLI help, the README, user and developer guides, `man/rig.1`, Bash and Zsh completions, `CHANGELOG.md`, tests, Specifications, and Decision Records all describe the same shipped commands, options, defaults, behaviour, compatibility, and trust boundaries wherever the change applies.

## Check distribution impact

- [ ] `install.sh`, installer help, README installation examples, user guides, and manual installation guidance agree when installation changes.
- [ ] The executable and manual continue to install or link together into documented, overrideable destinations.
- [ ] The version source, `rig --version`, tag, release entry, and companion Homebrew formula agree for a release candidate.
- [ ] The Homebrew tap remains the distribution owner and verified release-event dispatcher; consumer repositories remain responsible for their own review and publication.
- [ ] First-time entries, maturity changes, personal-site updates, or consumers outside automation are named as explicit receiver-owned handoffs.

## Verify the repository

- [ ] Run `ki repo audit --repo .` and resolve findings within approved authority, recording approval-gated external findings separately.
- [ ] Run `shellcheck bin/rig install.sh`.
- [ ] Run `bash -n bin/rig install.sh`.
- [ ] Run `bats tests/`.
- [ ] Run `mandoc -T lint man/rig.1` and inspect `mandoc -T utf8 man/rig.1 | col -b` after a manual layout change.
- [ ] Run `git diff --check` and focused KI authoring, guide, specification, decision, and roadmap audits for touched documentation.
- [ ] Exercise affected commands against isolated fixtures and, where safe and relevant, a live personal catalogue without applying changes.

## Prepare the review

- [ ] The roadmap record has its immutable baseline, completed steps, verification evidence, outstanding concerns, post-change review, and mini recap.
- [ ] Intended files are committed with a Conventional Commit; unrelated working-tree changes remain unstaged and untouched.
- [ ] Commit contents have been inspected after hooks, and the working tree contains only known unrelated changes.
- [ ] Nothing was pushed, released, applied to chezmoi, or changed in another repository without explicit authority.
- [ ] Work stops at `awaiting-review` until a human approves acceptance; accepted records are committed before any separately authorised pruning.
