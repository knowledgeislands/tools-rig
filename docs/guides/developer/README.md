# Develop Rig

Keep Rig's installed core compatible with Bash 3.2 and free of runtime dependencies beyond Bash. Native package managers and platform commands remain optional targets; external provider executables are required only when selected configuration trusts them.

## Respect the repository boundary

This repository owns Rig's portable executable, native lifecycle, declarative schema, built-in provider registry and adapters, extension protocol, public documentation, tests, and releases. A Rig owner's configuration repository owns catalogue entries, profiles, resource values, publication choices, explicitly trusted external executables, provider-native manifests, and private credentials.

When a change crosses that boundary, define and verify the portable contract here first. A generally useful provider adapter, bootstrap stage, setting type, inventory source, or resource lifecycle belongs here rather than in a personal workstation provider. Update the owner's configuration against a released Rig version or an explicitly linked development checkout. Do not copy personal declarations into this repository or reimplement portable Rig behaviour in dotfiles.

Built-in providers are product code. They infer supported installation kinds and fixed reconcile, update, maintenance, and capture operations from Rig's internal registry and must not require users to repeat adapter or capability declarations. External providers are extensions: they require `adapter = "custom"` and an operation allow-list, resolve through an explicit executable or the exact `${RIG_DATA_HOME}/providers/ID` path, and alone receive the versioned `rig-provider-v1` protocol. Configuration must never become an arbitrary lifecycle task runner.

Generated artifacts remain part of their owning tool and are observation-only. Keep their native creation, update, and removal lifecycle outside Rig; do not turn a personal operation script into an artifact hook, custom provider, or general task runner.

## Make a change

Edit the domain-focused files beneath `src/rig/`, then run `scripts/assemble-rig --write` to regenerate the single installed `bin/rig`. Update tests and keep `man/rig.1`, README usage, command guides, completion output, and changelog aligned when the public surface changes. Record durable rationale in Decision Records, accepted behaviour in Specifications, and future delivery in the roadmap.

Use `scripts/benchmark-rig` after parser, resolution, or query changes. Its default five-second ceiling is the portable regression guard; use `RIG_BENCHMARK_BUDGET_SECONDS=2` to check the reference macOS target. `scripts/smoke-native-providers` performs only bounded version probes and reports unavailable provider tools as skips.

Before presenting a change for review, complete the [definition of done](definition-of-done.md). Use isolated XDG and Rig-specific environment values in tests so no developer configuration or state is read or written.

## Verify

Run:

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers
bash -n bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers
scripts/assemble-rig --check
scripts/benchmark-rig
scripts/smoke-native-providers
bats tests/
mandoc -T lint man/rig.1
git diff --check
```

Inspect manual rendering after a layout change:

```sh
mandoc -T utf8 man/rig.1 | col -b
```

If a required checker is absent, install it through the workstation's existing package-management policy; do not add a Rig runtime dependency.

## Release

Follow [Release Rig](releasing.md) to verify and publish a release, then let the Homebrew tap distribute its verified release event to enrolled consumers without transferring release authority.
