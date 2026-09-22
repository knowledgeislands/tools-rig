# Rig guides

These guides help people adopt, operate, develop, and release Rig. They explain practical workflows in progressive order. Decision Records explain why the architecture exists, Specifications define accepted behaviour, and roadmap records track future delivery.

## Use Rig

Start with the [user-guide journey](user/README.md). It begins with a small catalogue and moves gradually into profiles, machine resources, skills, extensions, and publication.

1. [Get started](user/getting-started.md) — install Rig, create a small configuration, inspect it, check the machine, and preview an application.
2. [Choose a command](user/commands.md) — understand which commands only read, which observe native state, and which can make changes.
3. [Build complete profiles and safe views](user/profiles.md) — describe genuinely different machines or contexts without duplicating catalogue entries.
4. [Manage operational resources and private ports](user/operational-resources.md) — add services, scheduled jobs, typed settings, Dock layouts, and listener intent.
5. [Manage user-level skills](user/skills.md) — declare agent capabilities and their native authorities without copying instruction content into Rig.
6. [Run external provider actions](user/provider-actions.md) — add a bounded host-specific extension only when the native Rig model does not fit.
7. [Publish a public rig](user/publishing.md) — export a deliberately public view as data and hand it to a trusted publisher.

For exhaustive syntax and provider matrices, use `man rig`. The guides focus on completing user outcomes rather than restating the reference contract.

## Develop Rig

- [Develop Rig](developer/README.md) — preserve the portable product boundary and run the repository verification gate.
- [Definition of done](developer/definition-of-done.md) — align affected public surfaces and prepare an evidence-backed review.
- [Release Rig](developer/releasing.md) — verify a release candidate, publish only with explicit authority, and complete downstream distribution.
