# Use external providers safely

Use an external provider when a built-in provider cannot express a tool's observation or application. It is an explicit executable trust boundary, not a generic command runner.

## Declare native ownership

```toml
[provider.local]
adapter = "custom"
executable = "~/.local/libexec/rig-local-provider"
capabilities = ["observe", "apply"]
```

Bind a tool or supported resource to this provider in its declaration. Rig invokes the allowed observation during status and doctor, and the allowed application during an explicit apply. A configured executable fixes the trusted target; without it Rig resolves only the exact provider path below its data home.

Rig keeps arguments literal and includes a versioned extension-protocol marker. Built-in providers do not receive that protocol. The manual documents the ABI for extension authors.

## Keep imperative actions native

There is no public `rig run` command. Invoke a component's documented native command for service restart, logs, repair or other imperative operations. Do not mechanically run an extension executable with guessed protocol arguments.

Existing action records remain validated metadata but have no public action-dispatch entry point. Remove unused records from your personal configuration only after reviewing their consumers. A custom provider's observe/apply bindings remain supported.

Rig configuration owns desired package selection, but does not take ownership of another provider's source files, credentials or templates. ChezMoi remains the owner of its native source and application semantics.
