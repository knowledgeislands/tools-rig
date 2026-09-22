# Run external provider actions

Use an external provider only when host-specific behaviour cannot be expressed through a built-in provider or declarative managed resource. An external executable is an advanced trust boundary, not the normal way to configure Homebrew, launchd, macOS settings, Dock layouts, bootstrap, updates, maintenance, manifest capture, or a workstation.

## Declare one bounded action

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

A non-built-in provider requires `adapter = "custom"` and an allow-list of operations Rig may invoke. An explicit executable fixes the trusted target. When it is omitted, Rig resolves only `${RIG_DATA_HOME}/providers/PROVIDER-ID`; it does not search neighbouring files or infer trust.

The action fixes its mode, description, platforms, base arguments, and caller-argument policy. Observation and mutation are distinct capabilities.

## Invoke the declared action

```sh
rig run local inspect-device
rig run local inspect-device -- verbose
```

Configured arguments precede caller arguments. By default, every caller argument must exactly match an `allowed-arguments` entry. Use `argument-policy = "provider"` only when the selected extension's own native configuration deliberately owns further validation.

Values remain literal throughout dispatch. Rig does not evaluate shell text or infer an undeclared action.

## Understand the boundary

`rig run` is not a general shell escape. Private configuration owns the extension identity and trust decision; the executable owns its native operation and output. Rig validates the bounded declaration, invokes it once, passes output through, and preserves the provider status required by the command contract.

Rig inserts its versioned extension protocol marker when invoking the executable. `rig-provider-v1` is not a command option or configuration value, and built-in providers never receive it. Extension authors can use the protocol reference in `man rig`; ordinary users do not need to reproduce its argument layout.
