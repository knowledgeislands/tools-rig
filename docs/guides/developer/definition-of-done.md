# Complete a Rig change

Use this checklist before presenting a Rig change for review. It defines delivery readiness for this repository; a roadmap record becomes `done` only after a human accepts its review packet through the selected KI workflow.

Mark an inapplicable item explicitly in the review packet rather than silently skipping it. Release publication has additional steps in [Release Rig](releasing.md).

## Confirm the contract

- [ ] The change stays within the catalogue, profile, provider, state, operation, or publication boundary described by the repository.
- [ ] New durable rationale is in a Decision Record, accepted behaviour is in a Specification, practical procedure is in a Guide, and future work is in the canonical roadmap.
- [ ] Personal catalogue data, host-specific paths, credentials, provider-native state, and private observed state remain outside the public executable and public projection.
- [ ] Runtime code remains compatible with macOS Bash 3.2 and adds no required runtime dependency beyond Bash.
- [ ] Configuration, data, state, and cache behaviour preserves the XDG and Rig override contract.

## Align affected public surfaces

When a command, option, default, output contract, configuration field, or compatibility rule changes, review every applicable surface:

- [ ] `bin/rig` top-level help and command-local help describe the implemented syntax and behaviour.
- [ ] `README.md` command summaries and examples describe the same shipped surface.
- [ ] Applicable user and developer guides describe the current procedure and recovery path.
- [ ] `man/rig.1` aligns its synopsis, commands, files, installation, completion, exit status, and date.
- [ ] Bash and Zsh output from `rig completion` includes the same commands and options and still evaluates correctly.
- [ ] `CHANGELOG.md` records the user-visible change under the active pre-1.0 baseline or a dated release entry.
- [ ] `tests/rig.bats` covers success, invalid syntax, trust-boundary non-execution, and failure behaviour appropriate to the change.
- [ ] Relevant Specifications state the accepted behaviour and verification evidence; relevant Decision Records remain accurate.

## Check distribution impact

- [ ] `install.sh`, installer help, README installation examples, and manual installation guidance agree when installation changes.
- [ ] Executable and manual continue to install or link together into their documented overrideable destinations.
- [ ] Version source, `rig --version`, tag, release entry, and companion Homebrew formula agree for a release candidate.
- [ ] Website registry, personal-site renderer, Homebrew tap, or other cross-repository handoffs are named explicitly and remain owned by their receiving repositories.

## Verify the repository

- [ ] Run `ki repo audit --repo .` and resolve findings within the approved authority, recording approval-gated external findings separately.
- [ ] Run `shellcheck bin/rig install.sh`.
- [ ] Run `bash -n bin/rig install.sh`.
- [ ] Run `bats tests/`.
- [ ] Run `mandoc -T lint man/rig.1` and inspect `mandoc -T utf8 man/rig.1 | col -b` after a manual layout change.
- [ ] Run `git diff --check` and the focused KI authoring, guide, specification, decision, or roadmap audits for touched documentation.
- [ ] Exercise affected commands against isolated fixtures and, where safe and relevant, the live personal catalogue without applying changes.

## Prepare review

- [ ] The roadmap record has its immutable baseline, checked delivery steps, verification evidence, outstanding concerns, post-change review, and mini recap.
- [ ] Intended files are committed with a Conventional Commit; unrelated working-tree changes remain unstaged and untouched.
- [ ] The commit contents were inspected after hooks, and the working tree contains only known unrelated changes.
- [ ] Nothing was pushed, released, applied to chezmoi, or changed in another repository without explicit authority.
- [ ] The work stops at `awaiting-review` until a human approves acceptance; accepted records are committed before any separately authorised pruning.
