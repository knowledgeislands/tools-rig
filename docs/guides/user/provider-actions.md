# Run external provider actions

Use an external provider only when host-specific behaviour cannot be expressed through a built-in provider or declarative managed resource. External executables are an advanced trust boundary, not the normal way to configure Homebrew, launchd, macOS settings, Dock layout, bootstrap, or a workstation.

## Declare the extension and action

```toml
[provider.local]
adapter = "custom"
executable = "~/.local/libexec/rig-local-provider"
capabilities = ["observe"]

[action.local.inspect-device]
mode = "observe"
description = "Inspect a host-specific attached device"
platforms = ["macos"]
arguments = ["summary"]
allowed-arguments = ["verbose"]
```

A non-built-in provider requires `adapter = "custom"` and an allow-list of operations Rig may invoke. `executable` may name an exact path; when omitted, Rig resolves only `${RIG_DATA_HOME}/providers/PROVIDER-ID`. Rig does not search for provider executables or infer trust from neighbouring files.

The action fixes its mode, description, platforms, configured arguments, and caller-argument policy. `mode = "observe"` requires the provider's observation operation; `mode = "mutate"` requires its mutation operation.

## Invoke the declared action

```sh
rig run local inspect-device
rig run local inspect-device -- verbose
```

Configured `arguments` always precede caller arguments. By default, every caller argument must exactly match one `allowed-arguments` entry. Set `argument-policy = "provider"` only when the selected extension's own native configuration intentionally owns further validation.

Values remain literal throughout dispatch. Rig does not evaluate shell text, search for adjacent executables, or infer an action that was not declared.

## Understand the boundary

`rig run` is not a general shell escape. The private configuration owns the extension identity and trust decision; the executable owns its native operation and output. Rig validates the bounded declaration, invokes it once, passes output through, and returns the provider's native status.

Rig automatically inserts its versioned extension protocol marker when it invokes the executable. `rig-provider-v1` is not a command option or configuration value and built-in providers never receive it. Extension authors can use the advanced protocol reference in `man rig`; ordinary users do not need to understand the argument layout.
