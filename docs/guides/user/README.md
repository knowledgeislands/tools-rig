# Use Rig

Rig is for people who want their working setup to be understandable as a whole, not only reproducible through a collection of unrelated installers and configuration managers.

A Rig declaration tells you what tools matter, what each one is for, why it belongs, which contexts need it, and which native system is responsible for it. Rig can then compare that declaration with the current machine and coordinate provider work without taking ownership away from Homebrew, uv, chezmoi, or another provider.

## Start with the questions

Rig is useful when you want durable answers to questions such as:

- What is my rig?
- Which tools do I use for navigation, development, writing, or operations?
- Why is a particular tool part of the setup?
- Which tools belong on this laptop, a minimal machine, or a developer workstation?
- Which parts are present here, and which provider reported that state?
- What can I share publicly without publishing private configuration or observed machine state?

## Understand the four core concepts

- **Catalogue** — the complete description of tools you care about. Each entry can record category, purpose, rationale, relationships, supported platforms, and installation metadata.
- **Profile** — a named selection of catalogue tools for a machine, role, or context. Profiles may compose other profiles and tool requirements.
- **Provider** — the bridge to a system that already owns installation or observation. Rig selects and orders work; the provider retains its own manifests and state.
- **State** — the comparison between a resolved profile and provider observations on the current machine.

Publication is an optional projection of that model. It exports one deliberately public profile as versioned data; a website owns how that data is presented.

## Follow the everyday lifecycle

1. **Declare** a catalogue, profiles, and any provider-backed installations.
2. **Understand** the resolved setup with `rig show`, `rig list`, and `rig explain`.
3. **Check Rig itself** with `rig diag`.
4. **Assess the machine** with `rig doctor` for a summary or `rig status` for full expected-versus-observed detail.
5. **Preview change** with `rig apply --dry-run`.
6. **Materialise** with `rig apply`, or use `rig bootstrap` for a profile intended for a new machine.
7. **Publish deliberately** with offline `rig export` followed by explicit `rig publish` when configured.

Inspection comes before mutation. Rig never turns a read-only catalogue query into provider execution, and a dry run never applies provider changes.

## Choose a guide

- [Get started](getting-started.md) — install Rig, create a small configuration, understand it, check the machine, and preview the first application.
- [Use the commands](commands.md) — choose the right command and understand whether it reads configuration, observes providers, mutates providers, or publishes data.
- [Publish a rig](publishing.md) — create a safe public profile, inspect its versioned JSON, and hand it to a trusted publisher.
- [Run custom provider actions](provider-actions.md) — expose bounded host-specific observations or maintenance through private configuration.

For the exhaustive configuration grammar, environment variables, provider protocol, and exit-status contract, use `man rig`. Specifications are maintained for implementers and verification; most users should start with these guides.

## Configuration location

By default, Rig reads:

1. `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.toml`, when present;
2. regular `${XDG_CONFIG_HOME:-$HOME/.config}/rig/conf.d/*.toml` fragments in bytewise filename order.

Set `RIG_CONFIG_HOME` to replace the complete Rig configuration directory. Similar `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME` overrides replace the corresponding Rig application directories.

The root `rig.toml` is optional when fragments supply the complete model, including exactly one `[rig]` table.
