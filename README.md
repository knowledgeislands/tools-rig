# Rig

Rig is a declarative description and manager of a person's working setup. It gives tools, agent skills, managed resources, and private port allocations one understandable catalogue, then compares that declared intent with the machine in front of you.

Rig answers questions such as:

- What is in my setup, and why did I choose it?
- Which parts belong on this machine or in this role?
- Which native system installs or observes each part?
- What is present, missing, drifted, unavailable, or unknown?
- Which deliberately public subset can I publish without exposing machine state?

Rig coordinates native systems rather than replacing them. Homebrew, uv, mise, npm, chezmoi, launchd, macOS defaults, and trusted extensions keep their own manifests, resolution rules, credentials, and state.

## The model

- A **catalogue** records the identity, purpose, rationale, relationships, and supported platforms of each tool.
- A **skill** records a user-level agent capability and the native authority responsible for it.
- A **managed resource** records desired services, scheduled jobs, typed machine settings, and semantic layouts.
- A **private port** records stable TCP intent without opening, reserving, or publishing a socket.
- A **profile** selects a complete machine or role setup, or a non-appliable view such as a public subset.
- A **provider** is the native system that materialises or observes declared intent.
- **State** is Rig's comparison between a resolved profile and provider observations on the current machine.

That makes Rig a manager of managers beneath a catalogue people can read.

## Start here

Rig is a pre-v1 public preview. Follow [Get started with Rig](docs/guides/user/getting-started.md) to install the current preview, write a small human-readable configuration, inspect it, check the machine, and preview the first application.

The [user-guide journey](docs/guides/user/README.md) then introduces profiles, machine resources, user-level skills, provider boundaries, and publication in stages. Use `man rig` for the exhaustive command and configuration reference.

## Documentation

- [User guides](docs/guides/user/README.md) explain how to adopt and operate Rig.
- [Developer guides](docs/guides/developer/README.md) explain how to change and release Rig.
- [Decision Records](docs/decisions/README.md) explain durable architectural choices.
- [Specifications](docs/specs/index.md) define accepted, testable behaviour.
- [Roadmap](ROADMAP.md) identifies canonical forward work.

## Contributing

Issues and pull requests are welcome. Start with [Develop Rig](docs/guides/developer/README.md) and use the [definition of done](docs/guides/developer/definition-of-done.md) before presenting a change for review.

## License

[MIT](LICENSE) © 2026 Kris Brown.
