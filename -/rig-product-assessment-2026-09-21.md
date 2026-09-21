# Rig product assessment

Assessment snapshot: 2026-09-21 at commit `84b841f`.

This is a review note, not a normative product contract or an implementation plan. Its purpose is to make the current judgement easy to assess before findings are routed into Decision Records, Specifications, Guides, or roadmap work.

## Outcome summary

Rig is now a credible, well-tested personal workstation manager with a sound central model. The catalogue-first approach should be retained: tools and resources describe personal intent, profiles select that intent, providers retain native authority, state compares expectation with observation, and publication derives a deliberately public data projection.

The migration away from chezmoi-owned behaviour has substantially succeeded. Portable lifecycle and macOS integrations now live in Rig, the active personal configuration matches its chezmoi source, and the former personal operation surfaces are absent.

Rig is suitable for continued personal use and, after a focused correction pass, another `0.x` preview. It is not yet ready to claim general multi-machine or cross-platform workstation management. The main work is no longer adding commands. It is clarifying profile and reconciliation authority, making realistic TOML pleasant for a human to maintain, simplifying and correcting the documentation, improving query performance, and restoring an honest relationship between the development checkout and released version.

The recommended direction is therefore to keep the product model, tighten its semantics, improve its human experience, and only then broaden its reach.

## Overall judgement

| Area | Judgement |
| --- | --- |
| Product model | Strong and worth retaining |
| macOS workstation coverage | Broad and operational |
| Chezmoi migration | Consistent and substantially complete |
| Automated verification | Very strong |
| Configuration ergonomics | Functional, but not humane enough at realistic scale |
| User documentation | Comprehensive, but too dense and occasionally contradictory |
| Profile semantics | Insufficiently defined for multiple profiles |
| Multi-platform support | Runtime-portable, configuration-limited |
| Engineering maintainability | Increasing risk from the monolithic Bash implementation |
| Release state | Not coherent enough for the next preview without correction |
| Website publication | Implemented in Rig, but not configured in the active personal rig |

## Evidence reviewed

The assessment covered the complete Decision Record collection, Specifications, user and developer Guides, README, roadmap, changelog, manual, command help and completions, implementation, tests, and the active and chezmoi-source personal configurations.

Three independent high-reasoning reviews considered product architecture, reader and configuration experience, and engineering maturity. Their findings were reconciled against the implementation and live configuration.

The repository verification evidence was:

- `ki repo audit --repo .` passed all 16 selected repository skills.
- ShellCheck passed for `bin/rig` and `install.sh`.
- All 181 Bats tests passed.
- `mandoc -T lint man/rig.1` passed.
- The working tree was clean.
- The specification corpus contained 100 numbered requirements, all marked conforming.
- The roadmap contained no live work items, only its durable issue ledger.

The active personal configuration was valid and matched its chezmoi source byte-for-byte. It contained 12 categories, 102 tools, one profile, 35 settings, 37 Dock items, two services, four scheduled jobs, one provider configuration, and no publication declaration.

## Product model

The product model is coherent:

```text
Catalogue
   selected by a profile
Resolved intent
   planned and ordered by Rig
Provider-owned materialisation and observation
   compared as
Expected versus observed state

Public profile
   deliberately projected by Rig
Versioned public data
   rendered and deployed by
Website-owned presentation
```

The strongest architectural choices are:

- One logical tool owns its identity, purpose, rationale, relationships, installation, and durable generated artifacts.
- Built-in integrations are Rig product code rather than adapter and capability boilerplate in personal configuration.
- Services, scheduled jobs, typed settings, and semantic layouts are visible declarations rather than hidden scripts.
- External executables cross an explicit trust boundary.
- Publication is a narrow, versioned data projection; the website never becomes configuration or observed-state authority.
- Chezmoi may deliver personal declarations, but it no longer defines Rig's product model or lifecycle.

These choices are expressed principally by [PDR-RIG-001](../docs/decisions/PDR-RIG-001-catalogue-led-working-setup.md) and [ADR-RIG-006](../docs/decisions/ADR-RIG-006-declarative-operational-resources.md).

## Architectural issues to resolve

### Profile authority

Profiles are described as selections for machines, roles, contexts, and public projections. Applying a profile currently has stronger semantics than that description suggests.

Service and scheduled-job receipts are platform-wide rather than profile-specific. Applying another profile retires previously managed services and jobs omitted from the new selection. Omitted tools are not uninstalled, artifacts are not removed, and settings and Dock state remain as last applied.

| Declaration | Effect when omitted from a later profile apply |
| --- | --- |
| Tool or package | Remains installed |
| Tool artifact | Remains present |
| Setting | Last applied value remains |
| Dock layout | Last applied layout remains |
| Service | Retired when previously receipted |
| Scheduled job | Retired when previously receipted |

This behaviour is coherent if an appliable profile always means the complete managed configuration of a machine. It is surprising if profiles are temporary role or context subsets. Before multiple profiles become normal, Rig needs an explicit product decision covering:

- whether every appliable profile represents complete desired machine intent;
- whether view-only or publication-only profiles may be applied;
- whether retirement ownership belongs to a profile, platform, or future target identity;
- how switching profiles should behave.

### Conflicting native targets

Validation does not yet consistently operate over the resolved native targets.

- Two selected settings may target the same macOS domain and key with different values.
- Two different Dock layouts may be selected together.
- Both cases can validate independently while describing a state that cannot remain satisfied.
- Conversely, service and job locator collisions are rejected across the whole catalogue, even when the declarations belong to mutually exclusive profiles.

Conflict validation should reject contradictory selected intent while permitting alternatives that cannot be selected together.

### Provider operation scope

A selected profile does not always bound every native mutation to its selected tools. With a Homebrew manifest, update can operate on the complete Brewfile and maintenance can invoke `brew bundle cleanup --force`. Rig's dry run reports the provider work item, but does not necessarily disclose the package removal set.

Each lifecycle work item should state whether its effective scope is one tool, one manifest, or the whole provider. The documentation and preview should make any native cleanup consequence explicit.

### Broader applicability

Rig's runtime is portable, but the current configuration model is less general. Each logical tool has one installation provider and locator. Platform filters can disable that installation, but cannot express Homebrew on macOS and another manager on Linux while retaining one logical tool identity. Artifacts have the same global shape.

This is adequate for the current Mac. A genuine second-platform use case should drive bounded installation and artifact variants without returning to duplicate logical tool entries.

Managed resources can depend on tools, but cannot yet express ordering between resources. Bootstrap is also deliberately narrow: it stages the supported Homebrew to mise to npm chain rather than universally installing every missing manager. Those are reasonable current boundaries, but they should be stated plainly.

### Private port allocations and listeners

Ports are another meaningful part of private machine intent. The current workstation has stable-looking loopback listeners for apps-observatory on TCP 1675, the MCP proxy on TCP 3333, and Headroom on TCP 8787, alongside dynamic application listeners and normal macOS services.

Rig should be able to explain which stable ports have been allocated, what owns them, whether a listener is required or on demand, and whether its bind scope is loopback-only or intentionally broader. It should compare those declarations with local observations and distinguish an absent required listener, an unexpected occupant, and a listener whose network exposure has drifted.

This should be a first-class private operational resource rather than a generic provider action. Rig should not open, close, reserve, or kill sockets: the associated service or tool retains lifecycle ownership. Dynamic application and system listeners can remain optional unmanaged inventory rather than all becoming declarations.

Port declarations, observations, process details, bind addresses, and unmanaged-listener inventory must be excluded from every public projection. The versioned website data should continue to contain only its explicit catalogue allow-list.

### User-level agent skills

User-level skills are another material part of the working setup, but they are only partially managed today. `npx skills list -g` discovers 16 global skills. Only `caveman` has remote source provenance in the Skills CLI's XDG-state lock; seven KI skills are local symlinks into `ki-agentic-harness`, and eight Cloudflare skills are physical Claude and Codex copies reported as local. Rig declares none of them.

Rig should consider a first-class skill declaration containing human meaning, trusted source, user scope, target agent runtimes, and native owner. Profiles would select these capabilities; `show`, qualified `explain`, `status`, and `doctor` would distinguish declared intent from the native inventory. The Skills CLI, `ki bootstrap`, runtime plugin managers, and explicitly trusted local sources should retain their own installation and update authority.

Repository-local skills should remain repository concerns, while runtime-bundled and plugin-cached skills remain runtime-owned. Rig must not adopt an arbitrary directory merely because it contains `SKILL.md`: skills change agent behaviour and therefore cross an explicit trust boundary.

Unlike ports, a skill's reviewed catalogue metadata may be suitable for deliberate publication. Public name, purpose, rationale, and source should be considered separately from private installation paths, runtime mappings, lock data, and observed state. Installation alone must never imply disclosure.

## Human configuration

TOML remains the right format. The main problem is the deliberately restricted subset, not TOML itself.

Schema 1 rejects multiline arrays. The live default tool selection is consequently a 1,305-character line. This harms scanning, comments, code review, adding or removing entries, and conflict resolution. Supporting bounded multiline arrays of strings would remain inert and valid TOML, would preserve the Bash-only runtime, and can be added compatibly to schema 1.

Profiles also contain membership but no human explanation. A profile should be able to declare at least a name and purpose so that `rig show` can explain what the resolved selection represents.

The active data demonstrates a further distinction between schema completeness and human quality. Eighty-seven application entries use essentially the same rationale, “Intentionally retained in the workstation declaration.” All 35 settings similarly use generic purpose and rationale text. The fields exist, but many values answer why the declaration is in Rig rather than why the person chose that tool or setting.

The human-oriented configuration pass should:

- support multiline string arrays in schema 1;
- give profiles a name and purpose;
- put profiles in a dedicated, discoverable fragment;
- remove redundant `bootstrap-profile = "default"` when default fallback is sufficient;
- curate tool and resource rationales without inventing personal preferences;
- retain one declaration per identity and fail-closed duplicate handling;
- continue forbidding arbitrary commands, general interpolation, and last-wins overrides.

## Documentation

The documentation structure is strong: README, user guides, developer guides, Decision Records, Specifications, manual, changelog, and roadmap all exist. Its principal problem is progressive disclosure.

The getting-started guide initially follows a useful one-tool path, but then introduces receipt replacement, resource-local preflight, artifacts, Homebrew autoupdate, provider update and maintenance, manifest capture, profile composition, workstation settings, and completion. A new reader encounters internal safety mechanics before seeing one concise end-to-end outcome.

Two guides also say bootstrap does not install missing manager systems, which conflicts with the staged bootstrap contract. The accurate boundary is that bootstrap can establish supported declared prerequisites through its fixed staging model, but does not install arbitrary manager systems.

The recommended reading progression is:

1. README: what Rig gives the user and why it exists.
2. Getting started: install, one tool, understand, observe, dry run, apply, verify.
3. Configure your rig: tools, rationale, fragments, relationships, and profiles.
4. Operate your rig: status interpretation, bootstrap, apply, update, maintain, and capture.
5. Manage workstation resources: settings, services, jobs, layouts, and deselection.
6. Publish your rig: public profile, offline export, and website handoff.
7. Extend Rig: the advanced custom-provider trust boundary.
8. Manual: exhaustive syntax, provider, and protocol reference.

The user guides should show small, stable examples of actual `show`, `doctor`, `status`, and dry-run output and explain what a person should infer from each state. The manual's schema material should move beneath a structured `CONFIGURATION` section, leaving `FILES` to document filesystem locations.

The definition of done already requires public-surface synchronisation. It should add a separate human-readability criterion:

> A new user can follow the affected guide from stated prerequisites to a recognisable result; concepts appear when needed, examples are copyable, and realistic configuration remains readable and reviewable by its owner.

## Decision Record consolidation

The existing records should be retained, but their responsibilities should be tightened:

- `GDR-RIG-001`: retain as the governance decision.
- `PDR-RIG-001`: retain as the authoritative product model.
- `ADR-RIG-001`: retain and acknowledge the maintenance cost of Bash-only implementation.
- `ADR-RIG-002`: retain XDG placement; move extension executable lookup details to Specifications.
- `ADR-RIG-003`: retain TOML, inertness, and deterministic composition; move field inventories and detailed provider rules to Specifications.
- `XDR-RIG-001`: retain as the sole trust-boundary decision; update its stale mutation wording to include native update, maintenance, capture, and cleanup commands.
- `ADR-RIG-004`: retain publication separation; move exact JSON inventory to the publication Specification.
- `ADR-RIG-005`: shorten substantially. It currently duplicates bootstrap exceptions, lifecycle commands, ABI layout, state vocabulary, and preflight behaviour owned by Specifications.
- `ADR-RIG-006`: retain first-class resources and receipt rationale; add the resolved-profile ownership and deselection semantics.

Current normative documentation should avoid describing superseded models. The changelog remains the correct place for historical migration information.

## Performance and maintainability

On the real 1,893-line configuration:

- `rig diag` took approximately 16.8 seconds.
- `rig show` took approximately 15.7 seconds.
- A bounded `rig doctor` run displayed progress correctly, but after 30 seconds had loaded configuration and only begun the first of 99 tool observations.

The progress requirement works, but declaration-only queries should normally be quick enough not to need progress. The large-catalogue test proves functional scale, not acceptable latency. Rig needs explicit performance budgets and profiling for parsing, repeated section lookup, profile resolution, and provider observation batching.

The single installed Bash executable remains a good distribution contract. It does not require one authored source file. A deterministic assembly step from separated Bash modules could preserve the zero-dependency runtime while reducing change coupling and review risk.

Concurrent apply also lacks an explicit authority model. Receipt replacement is atomic, but separate applications are not serialized around the same platform receipt.

## Release and publication state

The development and release stories are currently out of alignment:

- HEAD is 45 commits after `v0.2.0`.
- The development executable still reports `0.2.0`.
- README installs tagged `v0.2.0` while documenting substantial later behaviour.
- The changelog frames development as `1.0.0 — in progress` while delivery remains incremental `0.x` previews.

An `Unreleased` heading would describe the current state more honestly. A specific `0.3.0` entry should be created only when the correction pass is complete.

The publication engine exists, but the active personal configuration declares no public profile or publication. `rig.midnight.ninja` is therefore not currently driven by `rig publish` from this rig. Before wiring it in, profile authority should make it impossible or clearly invalid to apply a publication-only view accidentally.

## Recommended delivery sequence

1. Decide profile and resource authority, deselection behaviour, publication-only profile safety, and resolved native-target conflict rules.
2. Improve human configuration with multiline arrays, profile meaning, a configuration-authoring guide, and smaller canonical examples.
3. Consolidate Decision Records and Guides, correct bootstrap wording, document lifecycle ownership and provider scope, and reorganise the manual.
4. Establish performance budgets, improve parser and observation performance, and define concurrent-apply behaviour.
5. Curate the personal catalogue, separate its profile fragment, and configure a deliberate public projection for `rig.midnight.ninja`.
6. Introduce maintainable authored modules if appropriate, complete native smoke testing, align release surfaces, and cut the next `0.x` preview.

## Reusable assessment prompt

Use the following prompt to recreate this style of assessment against the state of the repository at that time:

```text
Perform a detailed, read-only, judgemental product and engineering audit of Rig in:

/Users/krisbrown/workspaces/kit/knowledgeislands/tools-rig

This is an assessment, not an implementation task. Do not edit files, change external state, apply chezmoi, push, publish, or create roadmap records.

Start by reading the repository AGENTS.md and the applicable KI authoring, Decision Record, Specification, Guide, tools-repository, and roadmap standards. Then inspect:

- README.md, ROADMAP.md, CHANGELOG.md, AGENTS.md
- every record in docs/decisions/
- every Specification in docs/specs/
- every Guide in docs/guides/
- man/rig.1, install.sh, command help, and generated completions
- bin/rig and the complete Bats test surface
- the active Rig configuration under ~/.config/rig
- its chezmoi source under ~/.local/share/chezmoi/dot_config/rig
- any residual chezmoi Rig, env, machine, service, operation, or workstation surfaces relevant to migration

Use independent high-reasoning review tracks for at least:

1. product architecture and applicability;
2. reader experience and human configuration ergonomics;
3. implementation maturity, safety, verification, and release readiness.

Reconcile those reviews yourself against the actual implementation. Do not merely report mechanical conformance.

Evaluate whether the catalogue, profiles, providers, state, managed resources, lifecycle, and publication model form a coherent product. Pay particular attention to:

- authority and ownership boundaries;
- profile selection, switching, application, and deselection semantics;
- native-target conflicts and dependency ordering;
- provider and manifest operation scope;
- cross-machine and cross-platform applicability;
- bootstrap boundaries;
- external execution and public disclosure trust boundaries;
- concurrency and state-receipt safety;
- user-level agent skill provenance, source-manager ownership, and runtime projections;
- Bash 3.2 maintainability;
- query and observation performance on the real personal catalogue.

Review every Decision Record for current-state wording, single-decision focus, overlap, stale statements, and misplaced Specification detail. Recommend whether each record should be retained, amended, shortened, merged, or superseded.

Judge the documentation as an unfamiliar external user would encounter it. Check progressive disclosure, stated prerequisites, copyable examples, actual output interpretation, recovery guidance, manual navigation, and alignment across help, man page, completions, README, Guides, Specifications, Decision Records, tests, and changelog.

Judge the TOML for a human owner, not only parser validity. Inspect realistic line lengths, fragment organisation, profile readability, rationale quality, duplication, comments, discoverability, and whether the schema makes invalid or surprising configurations possible. Preserve the inert configuration and Bash-only trust boundary in any recommendations.

Run the complete read-only verification gate where available:

- ki repo audit --repo .
- shellcheck bin/rig install.sh
- bash -n bin/rig install.sh
- bats tests/
- mandoc -T lint man/rig.1
- git diff --check

Measure representative declaration-only and observation commands against the active configuration without applying changes. Confirm whether progress appears for slow operations. Compare the live Rig configuration with its chezmoi source without exposing credentials or private values unnecessarily.

Report:

1. a concise outcome summary suitable for a decision-maker;
2. a maturity scorecard by product area;
3. current operational and migration state with concrete counts;
4. strongest architectural choices;
5. prioritized defects, semantic ambiguities, and scaling limits;
6. Decision Record consolidation recommendations record by record;
7. a progressive documentation information architecture;
8. human configuration improvements;
9. performance, maintainability, safety, and release findings;
10. a bounded recommended delivery sequence.

Distinguish clearly between a defect, an intentional current boundary, and a future capability. Support material findings with clickable absolute file links and line numbers. End by stating whether Rig is suitable for personal operation, another 0.x preview, and broader multi-machine use. State explicitly that no files were changed.
```

## Disposition

No repository, personal configuration, chezmoi, publication, or external state was changed while producing the assessment. Findings remain review material until deliberately routed into their canonical owners.
