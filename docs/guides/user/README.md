# Use Rig

Rig is for people who want their working setup to be understandable as a whole, not only reproducible through unrelated installers and configuration managers.

A Rig declaration tells you which tools and managed resources matter, what each one is for, why it belongs, which contexts need it, and which native system is responsible for it. Rig can then compare the declaration with the current machine and coordinate native managers without making you configure its built-in adapters.

## Start with the questions

Rig is useful when you want durable answers to questions such as:

- What is my rig?
- Which tools do I use for navigation, development, writing, or operations?
- Why is a particular tool part of the setup?
- Which tools and settings belong on this laptop, a minimal machine, or a developer workstation?
- Which parts are present here, and which native system reported that state?
- What can I share publicly without publishing private configuration or observed machine state?

## Understand the five core concepts

- **Catalogue** — the complete description of tools you care about. Each entry can record category, purpose, rationale, relationships, supported platforms, and installation metadata.
- **Managed resource** — a service, scheduled job, typed setting, or semantic layout whose identity, intent, and desired state Rig declares while a provider owns native projection and operation.
- **Profile** — complete machine or role intent, or a non-appliable view. Selectable declarations own direct membership; omission means the configured default, and profiles inherit shared intent explicitly. A workstation is a complete profile, not a provider.
- **Provider** — a native system that already owns installation or state. Built-in providers such as Homebrew and launchd need no adapter or capability declarations; external providers are explicit trust boundaries.
- **State** — the comparison between a resolved profile and provider observations on the current machine.

Publication is an optional projection of that model. It exports one deliberately public non-appliable view as versioned data; a website owns how that data is presented.

## Follow the everyday lifecycle

1. **Declare** a catalogue, managed resources, profiles, and the native provider for each materialised item.
2. **Understand** the resolved setup with `rig show`, `rig list`, and `rig explain`.
3. **Check Rig itself** with `rig diag`.
4. **Assess the machine** with `rig doctor` for a summary or `rig status` for full expected-versus-observed detail.
5. **Preview change** with `rig apply --dry-run`.
6. **Materialise** with `rig apply`, or use Rig's native `rig bootstrap` lifecycle to stage the fixed Homebrew → mise → npm manager chain when declared and then materialise the selected bootstrap profile.
7. **Advance explicitly** with dry-run-first `rig update`, `rig maintain`, or `rig capture` when tools, provider state, or a native manifest should change outside reconciliation.
8. **Publish deliberately** with offline `rig export` followed by explicit `rig publish` when configured.

Inspection comes before mutation. Rig never turns a read-only declaration query into provider execution, and a dry run never applies provider changes.

Generated paths stay with the tool whose capability they expose. Their `artifacts` paths make them visible to `explain`, `status`, and `doctor`; they are not separate tools. Rig observes those paths, while their native owner remains responsible for creating, updating, and removing them.

## Choose a guide

- [Get started](getting-started.md) — install Rig, create a small configuration, understand it, check a machine, and preview the first application.
- [Build complete profiles and safe views](profiles.md) — place membership beside declarations, inherit shared intent, switch complete profiles safely, and publish an explicit view.
- [Use commands](commands.md) — choose the right command and understand whether it reads declarations, observes providers, mutates state, or publishes data.
- [Publish a rig](publishing.md) — choose a safe public profile, inspect its versioned JSON, and hand it to a trusted publisher.
- [Run external provider actions](provider-actions.md) — expose bounded host-specific operations only when no built-in declarative integration fits.
- [Manage resources](operational-resources.md) — declare services, scheduled jobs, typed settings, and Dock layouts and preview their desired state.

For the exhaustive configuration grammar, environment variables, built-in provider matrix, extension protocol, and exit-status contract, use `man rig`. Specifications are maintained for implementers and verification; most users should start with these guides.

## Configuration location

By default, Rig reads:

1. `${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.toml`, when present;
2. regular `${XDG_CONFIG_HOME:-$HOME/.config}/rig/conf.d/*.toml` fragments in bytewise filename order.

Set `RIG_CONFIG_HOME` to replace the complete Rig configuration directory. Similar `RIG_DATA_HOME`, `RIG_STATE_HOME`, and `RIG_CACHE_HOME` overrides replace the corresponding Rig application directories.

The root `rig.toml` is optional when fragments supply the complete model, including exactly one `[rig]` table.
