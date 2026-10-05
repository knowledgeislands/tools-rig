# Develop Rig

Keep Rig's installed core compatible with macOS Bash 3.2 and free of required runtime dependencies beyond Bash. Native package managers and platform commands are optional targets; external provider executables are required only when selected private configuration explicitly trusts them.

## Respect the repository boundary

[See Rig's manager-of-managers architecture](architecture.md) for a source-backed interactive map of the observation and mutation paths across native tools.

This repository owns Rig's portable executable, native lifecycle, declarative schema, built-in provider registry and adapters, extension protocol, public documentation, tests, and releases. A Rig owner's private configuration owns catalogue entries, profiles, resource values and trusted external executables. Rig owns package-selection intent without a Brewfile; native managers retain execution state and credentials, and chezmoi retains its source and templates.

When a change crosses that boundary, define and verify the portable contract here first. A generally useful provider adapter, bootstrap stage, setting type, inventory source, or resource lifecycle belongs in Rig rather than a personal workstation script. Do not copy personal declarations into this repository or reimplement portable Rig behaviour in dotfiles.

Built-in providers are product code. Rig infers their supported installation kinds and lifecycle operations from its internal registry, so ordinary configuration must not repeat adapter capabilities or protocol markers.

The declaration inventory lives in `src/rig/05-declarations.bash`. Its registry names each authored table type, role, identity shape and reader-facing label; the parser uses it to recognise supported declarations. Setup items include ports even though they never materialise sockets, while retired applications are observation-only records. When adding a type, update the registry and the canonical table identities in RIG-CONF-008; include setup and observation types in the item list in [Getting Started](../user/getting-started.md#what-rig-can-manage). `tests/rig-declaration-registry.bats` checks those lists against the registry. Dock items remain components of a layout, and tool artifacts remain fields of their owning tool.

External providers are explicit extensions. They require `adapter = "custom"`, an operation allow-list, and either a configured executable or the exact `${RIG_DATA_HOME}/providers/ID` location. Only extensions receive the versioned `rig-provider-v1` protocol. Configuration must never become an arbitrary task runner.

Generated artifacts remain observation-only parts of their owning tool. Their native owner remains responsible for creation, update, and removal.

## Make a change

[Maintain the command surface](command-surface.md) maps each command and authored module, and identifies the shared report, option, progress, and outcome owners.

Edit the domain-focused authored modules beneath `src/rig/`, then run:

```sh
scripts/assemble-rig --write
```

The assembled `bin/rig` is the one installed executable; do not edit it directly. Update tests with behaviour changes and apply the `ki-repo-tools` change-readiness checklist for public-surface alignment.

Use the governing documentation skills for durable knowledge placement. Use isolated XDG and Rig-specific environment values in tests so no developer configuration or state is read or written.

Use `scripts/benchmark-rig` after parser, resolution, or query changes. The normal gate has a five-second portability ceiling; `RIG_BENCHMARK_BUDGET_SECONDS=2` exercises the reference macOS target. `scripts/smoke-native-providers` performs only bounded version probes and reports absent optional providers as skips.

Before presenting a change for review, complete the [definition of done](definition-of-done.md).

## Verify the repository

Run the complete gate once the edit batch is finished:

```sh
ki repo audit --repo .
shellcheck bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers
for script in bin/rig install.sh src/rig/*.bash scripts/assemble-rig scripts/benchmark-rig scripts/smoke-native-providers; do
  bash -n "$script" || exit 1
done
scripts/assemble-rig --check
scripts/benchmark-rig
scripts/smoke-native-providers
bats tests/ </dev/null
mandoc -T lint man/rig.1
git diff --check
```

After a manual layout change, also inspect its rendered form:

```sh
mandoc -T utf8 man/rig.1 | col -b
```

If a required checker is absent, install it through the workstation's existing package-management policy. Do not add it as a Rig runtime dependency.

Continuous verification runs a narrower gate on two runners. [Read the continuous verification gate](continuous-verification.md) explains what each job proves, what a stated skip means, and how to reproduce either runner locally.

## Release

Follow [Release Rig](releasing.md) for the pre-release review, explicit publication authority, and downstream distribution handoff.
