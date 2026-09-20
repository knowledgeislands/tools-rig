# Develop Rig

Keep Rig's installed core compatible with Bash 3.2 and free of runtime dependencies beyond Bash. Native package managers, configuration managers, and richer extension commands remain optional targets.

## Respect the repository boundary

This repository owns Rig's portable executable, configuration schema, provider protocols, public documentation, tests, and releases. A Rig owner's configuration repository owns their catalogue, profiles, publication choices, private provider executables, provider-native manifests, and host policy.

When a change crosses that boundary, define and verify the portable contract here first, then update the owner's configuration against a released Rig version or an explicitly linked development checkout. Do not copy personal declarations into this repository or reimplement portable Rig behaviour in dotfiles.

## Make a change

Update the public command surface in `bin/rig`, then keep `tests/rig.bats`, `man/rig.1`, README usage, and completion output aligned. Record durable rationale in Decision Records, accepted behaviour in Specifications, and future delivery in the roadmap.

Before presenting a change for review, complete the [definition of done](done.md). It is the canonical repository checklist for affected documentation, command, completion, distribution, test, and roadmap surfaces.

Do not embed a personal machine profile in the executable. Use isolated XDG and Rig-specific environment values in tests so no developer configuration or state is read or written.

## Verify

Run:

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh
bash -n bin/rig install.sh
bats tests/
mandoc -T lint man/rig.1
git diff --check
```

Inspect manual rendering after any layout change:

```sh
mandoc -T utf8 man/rig.1 | col -b
```

If a required checker is absent, install it through your workstation's existing package-management policy; do not add it as a Rig runtime dependency.

## Release

Follow [Release Rig](releasing.md) to verify, publish, and hand a new recommended version to the Knowledge Islands website without transferring release authority.
