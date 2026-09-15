# Develop Rig

Keep Rig's installed core compatible with Bash 3.2 and free of runtime dependencies beyond Bash. Native package managers, configuration managers, and richer extension commands remain optional targets.

## Make a change

Update the public command surface in `bin/rig`, then keep `tests/rig.bats`, `man/rig.1`, README usage, and completion output aligned. Record durable rationale in Decision Records, accepted behaviour in Specifications, and future delivery in the roadmap.

Do not embed a personal machine profile in the executable. Use isolated XDG and Rig-specific environment values in tests so no developer configuration or state is read or written.

## Verify

Run:

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh
bats tests/
mandoc -T lint man/rig.1
```

Inspect manual rendering after any layout change:

```sh
mandoc -T utf8 man/rig.1 | col -b
```

If a required checker is absent, install it through your workstation's existing package-management policy; do not add it as a Rig runtime dependency.
