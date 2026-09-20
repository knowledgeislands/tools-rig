# Run custom provider actions

Use declared actions for host-specific observations or maintenance that belong in private configuration but need one bounded Rig command surface. Prefer portable built-in adapters for ordinary installation and observation.

## Declare the provider and action

```toml
[provider.local]
adapter = "custom"
executable = "~/.local/libexec/rig-local-provider"

[action.local.service-status]
mode = "observe"
description = "Inspect configured launchd services"
platforms = ["macos"]
arguments = ["user"]
allowed-arguments = ["verbose"]
```

The action names exactly one custom provider. `mode = "observe"` dispatches the provider's observation verb; `mode = "mutate"` dispatches its application verb.

## Invoke the declared action

```sh
rig run local service-status
rig run local service-status -- verbose
```

Configured `arguments` always precede caller arguments. By default, every caller argument must exactly match one `allowed-arguments` entry. Set `argument-policy = "provider"` only when the provider's native configuration is intentionally authoritative for further validation.

An action can instead declare `resource-kinds = ["service", "scheduled-job"]`. Its first caller argument must then be a selected qualified target such as `service:indexer`; Rig passes the resource kind, identity, locator, and complete resolved declaration literally before `--` and any remaining caller arguments. Resource-aware actions require `argument-policy = "provider"` so the provider can validate its native operation.

Values remain literal throughout dispatch. Rig does not evaluate shell text, search for adjacent executables, or infer an action that was not declared.

## Understand the boundary

`rig run` is neither a general shell escape nor a portable Rig command family. The private configuration owns the action identity and trust decision; the custom provider owns its native operation and output. Rig validates the bounded declaration, invokes it once, passes output through, and returns the provider's native status.

Use command-local help for syntax and `man rig` for the complete `rig-provider-v1` protocol.
