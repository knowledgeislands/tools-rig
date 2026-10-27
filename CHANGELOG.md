# Changelog

This is the consolidated Pre-1.0 baseline for Rig's current command surface and notable capabilities and changes. It is updated as the tool evolves rather than divided into 0.x release entries. Tags, GitHub releases, and commit history retain the exact public-preview snapshots.

## Pre-1.0 baseline

### Command surface

- `rig init`
- `rig repair`
- `rig show`
- `rig status`
- `rig capture`
- `rig apply`
- `rig remove`
- `rig upgrade`
- `rig doctor`
- `rig diag`
- `rig export`
- `rig completion`
- `rig help [COMMAND]`, `rig --help`, and `rig --version`

Run `rig help COMMAND` or `rig COMMAND --help` for options and exact arguments.

### Capabilities

- Resource subject links explain which selected settings, services, jobs, firewalls and default applications configure each tool. `rig show TOOL` reports the full catalogue relationship; profile JSON includes an additive `configured_by` array.
- Existing v0.7.0 configuration remains readable without a mandatory rewrite. Review the [migration notes](docs/guides/user/migrating-command-surface.md#move-from-v070-to-v080) for stricter repeated status options, additive query fields, optional manager adoption and changed macOS firewall observation.
- Catalogue tools can provide Homebrew, mas, mise, npm, uv or chezmoi. Platform-resolved derived prerequisites combine with declared requires, retain targeted apply closure and support manager deferral through catalogue data. Homebrew remains observation-only; doctor attributes missing managers once, lists built-in and custom availability, and opts adopted catalogues into undeclared-manager warnings. Public export excludes provides and derived edges; configurations without provides keep the existing fallback.
- Direct-download `signed-release` verifies a detached Ed25519 checksum-manifest signature against a local public key before archive verification and one atomic home-only command install. Exact and minimum versions, four macOS/Linux targets, fail-closed fixtures and observed version reporting are supported; shared roles compose platform variants and native Homebrew formula floors through ordinary inheritance and fragments.
- Every command reads options with one grammar: a long option's value may follow `=` (`--profile=work`), `--json` is the same as `--format json`, `-n` is short for `--dry-run`, and `--` ends the options. `--format text|json` remains accepted, and `status` now rejects a repeated `--format` like the other commands.
- Mac App Store applications have their own built-in `mas` provider, declared `install.provider = "mas"` with `install.kind = "app"` and a numeric App Store locator; Rig output names `mas`, never `homebrew`, for them. The former `homebrew` provider with kind `mas` still works as a deprecated alias that `rig doctor` lists under Warnings.
- Tailnet-only macOS firewall restrictions: a `[firewall.ID]` declaration keeps chosen listener ports reachable only from loopback and the tailnet through a Rig-owned pf anchor and LaunchDaemon, changed only under `apply --sudo` and observed without administrator rights. The anchor passes tailnet sources only to the Mac's own tailnet addresses, read from `ifconfig` at each check and apply; an undiscoverable address leaves the firewall `unknown` with `tailnet-address-undiscoverable` and apply changes nothing, and a changed one reports `tailnet-address-stale`.
- Tailnet-only Linux firewall restrictions: the `linux-nftables` provider applies the same `[firewall.ID]` declaration through a Rig-owned nftables table and systemd unit, leaving `ufw`, `iptables`, `/etc/nftables.conf` and every other table untouched.
- Private macOS default applications for UTI, extension and URL schemes, with owned-app verification and effective-result checks.
- Explicit attended `apply --sudo` with native validation, owned noninteractive refresh and cleanup.
- Explicit native software removal with default preview, confirmation and doctor classification; no implicit deletion.
- macOS applications can declare self-managed updates. Healthy app artifacts satisfy presence across install sources; apply and upgrade skip self-updating apps, and doctor gives honest source evidence and manual correction guidance for foreign copies.
- One Dock layout can serve several profiles: a Dock item may link to its tool, and each resolved profile shows only the items it selects, in the declared order. `show dock:ID --profile NAME`, status, doctor, dry-run and apply agree on the filtered list, an excluded app's missing path is no longer a preflight failure, and status and doctor report any included item whose path is missing, linked or not, as drift.
- Observe-only macOS menu bar layouts: a `[menu-bar.ID]` declaration names `[menu-bar-item.ID]` icons by preference domain and autosave name, in left-to-right order with an optional `visible = false`. Status and doctor report an unreadable domain, an unplaced icon, and visibility or order drift; apply skips the layout as `observe-only` and never writes a menu bar preference.
- Doctor names the cause behind silent services and failing Homebrew work: a missing program or working directory makes a service or scheduled job `unlaunchable` and is named as the cause of its port's silence, and missing or outdated Command Line Tools are reported once rather than as one failure per Homebrew item.
- A private port owned by a tool run as `python -m MODULE` is recognised as owned when the module is the tool identifier or its locator with hyphens as underscores, so a working interpreter service is no longer reported as `conflicting`.
- Applications can declare named CLI companions within the same tool entry. Status and doctor check their executable and expected link; apply and upgrade reconcile them through their Homebrew cask or explicit missing-link materialisation, preserving conflicting paths.
- A readable catalogue declares tools, user-level agent skills, managed services and scheduled jobs, typed machine settings, Dock layout, private ports, relationships, providers, and profiles. Profiles select a machine or role setup; provider observations produce expected-versus-observed state.
- `show`, `status`, and `doctor` explain intent, observed state, and capability or health findings without changing the machine. `status --unmanaged` and `status --retired` add informational observations; `capture` proposes additive declarations for review.
- `init` writes unversioned configuration. Recognised legacy `schema = 1` input remains readable; `repair` previews a repaired source or writes a reviewable proposal outside active configuration without rewriting it.
- `apply` supports exact target selection, complete preflight, dependency order, non-mutating dry runs, and independent outcomes. Reconciliation preserves receipts for declared resources outside the selected profile and retires a resource only when no catalogue declaration still owns it.
- `upgrade` delegates execution to the appropriate native provider. Homebrew, uv, chezmoi, direct downloads, and declared custom providers retain their own resolution, credentials, and installation state. Rig owns selection and reporting, not a competing package database.
- `export` generates a deterministic, platform-neutral `rig-publication` version 1 JSON view of an explicitly selected public profile. Private paths, credentials, runtime mappings, state, and private ports are excluded.
- Terminal progress keeps diagnostics visible, redacts private values, and leaves machine-readable standard output stable. Native operations retain terminal ownership; multi-item native phases use compact target-and-count handoff headers, retain skips, failures and final counts, and omit routine success chatter. The Bash and Zsh completion definitions follow the current commands and options.

### Changed and removed

- Configuration identities remain lowercase ASCII regardless of the host's collation locale, including macOS Bash 3.2.
- Supported declaration kinds share one parser registry, with mechanical checks keeping the setup-item guide and canonical table specification aligned.
- Diagnostics share a common tool/version, proven installation mode, runtime host and configuration-presence baseline. Doctor exposes read-only coverage and item-based pass/warn/fail/skipped counts, explicitly distinguishing declared health from package freshness. Tables wrap complete prose at interactive terminal width, use labelled entries on narrow terminals, and preserve identifiers and deterministic plain redirected output.
- The CLI exposes only the current command surface. Unknown commands print a syntax error and current usage without retired-name migration hints. Imperative provider operations and housekeeping remain native; Rig exports data, while a receiving system owns publication and transport.
- Homebrew Bundle, Brewfile orchestration, and Homebrew autoupdate management are retired. Rig configuration declares desired packages; retired configuration fields fail with migration guidance. No migration deletes an existing Brewfile, package, timer, or state file.
- Managed-resource retirement follows catalogue ownership rather than the last applied profile, avoiding unloads of still-declared services and scheduled jobs. Launchd replacement waits for a departing service before bootstrapping its successor; failures withhold retirement and receipt replacement.
- A mise tool can name the executables Rig observes with `install.executables`, so `rust` and `cargo:` packages are observed by their binaries; without it Rig observes the locator without a trailing `@VERSION`, while install, upgrade and removal keep the full locator.
- Planning a large catalogue no longer grows cubically: dependency ordering, binding lookup, resource ordering, native-target conflict checks and cycle validation each scan the model once, so a targeted `rig apply --dry-run` against a 191-tool catalogue drops from about 24 seconds to about 5, with unchanged output and native probes still limited to the target's dependency closure.
- A live `rig apply` and a live `rig upgrade`, including the unattended upgrade a scheduled job starts, share one per-platform operation lock, so neither starts while the other runs; the second refuses at once with the owner's details, and an unattended upgrade refused this way records why in `last-upgrade`. The resource reconciliation lock now nests inside it, and a default-application or firewall step records its outcome in apply history like every other dispatched target.
- A confirmed `rig remove --apply` takes the same operation lock before its first observation and refuses while an apply, upgrade or other removal holds it. `rig doctor` now reads the operation and reconciliation locks: a running owner is a warning, a stale or unknown owner or unsafe lock path is a finding, and text output names the exact command to remove a dead owner's lock by hand.
- Provider and observation fixes preserve stable identities, distinguish unavailable evidence from proven conflicts, handle dual-stack listeners without duplicate rows, and keep native diagnostics intact through terminal progress.
- A drifted or missing firewall whose declared port is seen listening on every address reports `listening-all-addresses` in place of `exposed-beyond-tailnet`, naming the point-in-time listener evidence without claiming reachability from beyond the tailnet; `show firewall:ID` adds that the loaded rules were not read.
- Listener observation finds `lsof`, `ps` and `netstat` by one rule, the `RIG_*_COMMAND` override, then `PATH`, then the fixed system directories, so a scheduled job whose `PATH` stops at `/bin` observes ports as an interactive run does, and a port whose tool no location names reports `lsof-missing`.

### Distribution baseline

- One deterministic, dependency-free Bash 3.2 executable is assembled from domain modules; XDG-aware `install.sh` supports exact release selection and a linked development checkout.
- The physical `rig(1)` manual, Bash and Zsh completions, isolated Bats suite, ShellCheck, and macOS/Linux CI accompany the command surface.
