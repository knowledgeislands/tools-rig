# Complete a Rig change

Use this checklist before presenting a Rig change for review.

Apply the `ki-repo-tools` change-readiness checklist for shared documentation, verification, and authority requirements, `ki-git` for commit practice, and the selected work adapter for record lifecycle. The checks below are Rig's local additions.

Release publication has additional steps in [Release Rig](releasing.md).

## Confirm the contract

- [ ] The change stays within the catalogue, profile, provider, state, managed-resource, extension, or public-export boundary described by the repository.
- [ ] Ordinary configuration remains declarative: Rig infers built-in adapters, capabilities, lifecycle sequencing, and protocol markers.
- [ ] Any generally useful declared prerequisite stage, provider adapter, inventory source, setting type, or resource lifecycle is implemented in Rig rather than delegated to a personal workstation provider.
- [ ] Personal catalogue data, host-specific values, credentials, provider-native state, external executables, and observed state remain outside the public executable and public projection.
- [ ] Runtime code remains compatible with macOS Bash 3.2 and adds no required runtime dependency beyond Bash.
- [ ] Authored `src/rig/` modules assemble byte-for-byte into committed `bin/rig`, and every assembled payload passes Bash syntax and ShellCheck gates.
- [ ] Configuration, data, state, and cache behaviour preserve the XDG and Rig-override contract.

## Align affected public surfaces

- [ ] Terminal progress changes have isolated pseudo-terminal coverage for native output, redirected line events, completion, failure, and cleanup; never reproduce a destructive apply defect on the live machine.

## Verify the repository

- [ ] Run the ShellCheck, Bash syntax, assembly drift, benchmark, native-provider smoke, Bats, mandoc, and diff checks in [Develop Rig](README.md).
- [ ] Use the two-second reference benchmark budget when assessing parser, resolution, or query performance.
- [ ] Exercise affected commands against isolated fixtures and, when safe and relevant, a live personal catalogue without applying changes.
